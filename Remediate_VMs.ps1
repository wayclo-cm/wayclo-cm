Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false
Set-PowerCLIConfiguration -Scope AllUsers -ParticipateInCEIP $false -Confirm:$false
Set-ExecutionPolicy Unrestricted

# Importar el módulo de VMware PowerCLI
Import-Module VMware.VimAutomation.Core -WarningAction SilentlyContinue
Import-Module VMware.PowerCLI

# Solicitar la dirección IP del servidor vCenter
$vCenterServer = Read-Host "Ingrese la direccion IP del servidor vCenter"

# Solicitar las credenciales de usuario
$credential = Get-Credential -Message "Ingrese las credenciales para el servidor vCenter"

# Solicitar el nombre del archivo de salida
$outputFileName = Read-Host "Ingrese el nombre del archivo de salida (sin extension)"

# Conectar a vCenter
Connect-VIServer -Server $vCenterServer -Credential $credential

# Configuraciones avanzadas a aplicar
$settings = @{
    "mks.enable3d" = $false;
    "isolation.device.edit.disable" = $true;
    "RemoteDisplay.maxConnections" = 1;
    "log.keepOld" = 10;
    "log.rotateSize" = 2048000;
    "tools.guest.desktop.autolock" = $true;
}

# VMs excluidas
$excludedVMs = @("VM_Exclude1", "VM_Exclude2")

# Obtener todas las VMs
$vms = Get-VM

# Lista para almacenar los resultados
$resultados = @()
$excluidos = @()

# Aplicar las configuraciones avanzadas en cada VM
foreach ($vm in $vms) {
    if ($excludedVMs -contains $vm.Name) {
        Write-Host "Excluyendo la VM '$($vm.Name)' de las configuraciones..."
        $excluidos += $vm.Name
        continue
    }

    Write-Host "Verificando configuraciones en la VM '$($vm.Name)'..."

    foreach ($key in $settings.Keys) {
        $expectedValue = $settings[$key]

        # Obtener el valor actual del setting
        $currentSetting = Get-AdvancedSetting -Entity $vm -Name $key -ErrorAction SilentlyContinue

        if ($currentSetting) {
            $currentValue = $currentSetting.Value

            # Convertir el valor actual a tipo booleano o entero según el valor esperado
            if ($expectedValue -is [bool]) {
                $currentValue = [bool]::Parse($currentValue)
            } elseif ($expectedValue -is [int]) {
                $currentValue = [int]$currentValue
            }

            if ($currentValue -ne $expectedValue) {
                # Actualizar el valor si es incorrecto
                Set-AdvancedSetting -AdvancedSetting $currentSetting -Value $expectedValue -Confirm:$false
                $status = "Actualizado"
                Write-Host "ALERTA: Configuracion '$key' en la VM '$($vm.Name)' ha sido actualizada de '$currentValue' a '$expectedValue'."
            } else {
                $status = "Correcto"
                Write-Host "Configuracion '$key' en la VM '$($vm.Name)' ya es correcta."
            }
        } else {
            # Crear y establecer el valor si no existe
            New-AdvancedSetting -Entity $vm -Name $key -Value $expectedValue -Confirm:$false
            $status = "Creado"
            Write-Host "ALERTA: Configuracion '$key' no existía en la VM '$($vm.Name)' y ha sido creada con valor '$expectedValue'."
        }

        $resultado = @{
            VM = $vm.Name
            Setting = $key
            ExpectedValue = $expectedValue
            Status = $status
        }

        $resultados += $resultado
    }
}

# Crear el contenido HTML
$html = @"
<html>
<head>
    <title>Aplicación de Configuraciones Avanzadas de VMs</title>
    <style>
        table { width: 100%; border-collapse: collapse; }
        th, td { border: 1px solid black; padding: 8px; text-align: left; }
        th { background-color: #F2F2F2; }
        .actualizado { background-color: #7CDAF9; } /* Rojo pastel */
        .correcto { background-color: #B0F2C2; }  /* Verde pastel */
        .creado { background-color: #FFF3CD; } /* Amarillo pastel */
    </style>
    <script>
        function filterTable() {
            var hostInput = document.getElementById('hostFilter').value.toLowerCase();
            var settingInput = document.getElementById('settingFilter').value.toLowerCase();
            var statusInput = document.getElementById('statusFilter').value.toLowerCase();
            var table = document.getElementById('resultsTable');
            var tr = table.getElementsByTagName('tr');
            for (var i = 1; i < tr.length; i++) {
                var tdHost = tr[i].getElementsByTagName('td')[0];
                var tdSetting = tr[i].getElementsByTagName('td')[1];
                var tdStatus = tr[i].getElementsByTagName('td')[3];
                if (tdHost && tdSetting && tdStatus) {
                    var hostValue = tdHost.textContent || tdHost.innerText;
                    var settingValue = tdSetting.textContent || tdSetting.innerText;
                    var statusValue = tdStatus.textContent || tdStatus.innerText;
                    if (hostValue.toLowerCase().indexOf(hostInput) > -1 &&
                        settingValue.toLowerCase().indexOf(settingInput) > -1 &&
                        statusValue.toLowerCase().indexOf(statusInput) > -1) {
                        tr[i].style.display = '';
                    } else {
                        tr[i].style.display = 'none';
                    }
                }
            }
        }
    </script>
</head>
<body>
    <h1 style="text-align:center;">Aplicacion de Configuraciones Avanzadas de VMs</h1>
    <table id="resultsTable">
        <tr>
            <th>VM<br><input type="text" id="hostFilter" onkeyup="filterTable()"></th>
            <th>Configuración<br><input type="text" id="settingFilter" onkeyup="filterTable()"></th>
            <th>Valor Esperado</th>
            <th>Estado<br><input type="text" id="statusFilter" onkeyup="filterTable()"></th>
        </tr>
"@
foreach ($resultado in $resultados) {
    $estadoClase = ""
    switch ($resultado.Status) {
        "Actualizado" { $estadoClase = "actualizado" }
        "Correcto" { $estadoClase = "correcto" }
        "Creado" { $estadoClase = "creado" }
    }
    $html += @"
        <tr class='$estadoClase'>
            <td>$($resultado.VM)</td>
            <td>$($resultado.Setting)</td>
            <td>$($resultado.ExpectedValue)</td>
            <td>$($resultado.Status)</td>
        </tr>
"@
}
$html += @"
    </table>
    <h2>Se excluyeron las siguientes VMs de la remediación:</h2>
    <table>
        <tr>
            <th>VM</th>
        </tr>
"@
foreach ($excluido in $excluidos) {
    $html += @"
        <tr>
            <td>$excluido</td>
        </tr>
"@
}
$html += @"
    </table>
</body>
</html>
"@
# Guardar el contenido HTML en un archivo
$outputFilePath = "C:\$outputFileName.html"
$html | Out-File -FilePath $outputFilePath -Encoding UTF8

# Desconectar de vCenter
Disconnect-VIServer -Server $vCenterServer -Confirm:$false

# Informar al usuario la ubicación del archivo generado
Write-Host "El archivo de aplicación ha sido guardado en $outputFilePath"

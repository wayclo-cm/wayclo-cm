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

# Configuraciones avanzadas a verificar
$settings = @{
    "mks.enable3d" = $false;
    "isolation.device.edit.disable" = $true;
    "RemoteDisplay.maxConnections" = 1;
    "log.keepOld" = 10;
    "log.rotateSize" = 2048000;
    "tools.guest.desktop.autolock" = $true;
}

# Obtener todas las VMs
$vms = Get-VM

# Lista para almacenar los resultados
$resultados = @()

# Verificar las configuraciones avanzadas en cada VM
foreach ($vm in $vms) {
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

            $status = "OK"

            if ($currentValue -ne $expectedValue) {
                $status = "Warning"
            }

            $resultado = @{
                VM = $vm.Name
                Setting = $key
                ExpectedValue = $expectedValue
                CurrentValue = $currentValue
                Status = $status
            }

            if ($status -eq "Warning") {
                Write-Host "ALERTA: Configuracion '$key' en la VM '$($vm.Name)' tiene el valor '$currentValue'."
            } else {
                Write-Host "Configuración '$key' en la VM '$($vm.Name)' es correcta."
            }
        } else {
            $resultado = @{
                VM = $vm.Name
                Setting = $key
                ExpectedValue = $expectedValue
                CurrentValue = "No existe"
                Status = "No existe"
            }
            Write-Host "ALERTA: Configuracion '$key' no existe en la VM '$($vm.Name)'."
        }

        $resultados += $resultado
    }
}

# Crear el contenido HTML
$html = @"
<html>
<head>
    <title>Verificacion de Configuraciones Avanzadas de VMs</title>
    <style>
        table { width: 100%; border-collapse: collapse; }
        th, td { border: 1px solid black; padding: 8px; text-align: left; }
        th { background-color: #F2F2F2; }
        .warning { background-color: #FFCCCB; } /* Rojo pastel */
        .OK { background-color: #B0F2C2; }  /* Verde pastel */
        .noexiste { background-color: #FFF3CD; } /* Amarillo pastel */
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
                var tdStatus = tr[i].getElementsByTagName('td')[4];
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
    <h1 style="text-align:center;">Verificacion de Configuraciones Avanzadas de VMs</h1>
    <table id="resultsTable">
        <tr>
            <th>VM<br><input type="text" id="hostFilter" onkeyup="filterTable()"></th>
            <th>Configuracion<br><input type="text" id="settingFilter" onkeyup="filterTable()"></th>
            <th>Valor Esperado</th>
            <th>Valor Actual</th>
            <th>Estado<br><input type="text" id="statusFilter" onkeyup="filterTable()"></th>
        </tr>
"@
foreach ($resultado in $resultados) {
    $estadoClase = ""
    switch ($resultado.Status) {
        "Warning" { $estadoClase = "warning" }
        "OK" { $estadoClase = "ok" }
        "No existe" { $estadoClase = "noexiste" }
    }
    $html += @"
        <tr class='$estadoClase'>
            <td>$($resultado.VM)</td>
            <td>$($resultado.Setting)</td>
            <td>$($resultado.ExpectedValue)</td>
            <td>$($resultado.CurrentValue)</td>
            <td>$($resultado.Status)</td>
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
Write-Host "El archivo de verificacion ha sido guardado en $outputFilePath"

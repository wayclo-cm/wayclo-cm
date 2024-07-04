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
    "Config.HostAgent.plugins.hostsvc.esxAdminsGroupAutoAdd" = $false;
    "Config.HostAgent.plugins.vimsvc.authValidateInterval" = 90;
    "Security.AccountUnlockTime" = 900;
    "Security.AccountLockFailures" = 5;
    "Security.PasswordHistory" = 5;
    "Syslog.global.logDir" = "Sitio Especifico";
    "Syslog.global.logHost" = "Sitio Especifico";
    "UserVars.ESXiShellInteractiveTimeOut" = 900;
    "UserVars.ESXiShellTimeOut" = 600;
    "Security.PasswordQualityControl" = "retry=3 min=disabled,15,15,15,15 max=64 similar=deny passphrase=3";
    "UserVars.SuppressHyperthreadWarning" = 0;
    "UserVars.DcuiTimeOut" = 600;
    "Config.HostAgent.plugins.solo.enableMob" = $false;
    "DCUI.Access" = "root";
    "Config.HostAgent.log.level" = "info";
    "Net.BlockGuestBPDU" = 1;
    "UserVars.ESXiVPsDisabledProtocols" = "sslv3,tlsv1,tlsv1.1";
    "Mem.ShareForceSalting" = 2;
    "Syslog.global.auditRecord.storageEnable" = $true;
    "Syslog.global.auditRecord.storageCapacity" = 100;
    "Syslog.global.auditRecord.storageDirectory" = "Sitio Especifico";
    "Syslog.global.auditRecord.remoteEnable" = $true;
    "Syslog.global.logLevel" = "info";
    "Syslog.global.certificate.strictX509Compliance" = $true;
    "Mem.MemEagerZero" = 1;
    "ConfigManager.HostAccessManager.LockdownMode" = "lockdownNormal";
}

# Obtener todos los hosts ESXi
$esxiHosts = Get-VMHost

# Lista para almacenar los resultados
$resultados = @()

# Verificar las configuraciones avanzadas en cada host ESXi
foreach ($esxi in $esxiHosts) {
    Write-Host "Verificando configuraciones en el host '$($esxi.Name)'..."

    foreach ($key in $settings.Keys) {
        $expectedValue = $settings[$key]

        # Obtener el valor actual del setting
        if ($key -eq "ConfigManager.HostAccessManager.LockdownMode") {
            $currentSetting = (Get-View (Get-VMHost -Name $esxi | Get-View).ConfigManager.HostAccessManager).LockdownMode
        } else {
            $currentSetting = Get-AdvancedSetting -Entity $esxi -Name $key -ErrorAction SilentlyContinue
        }

        if ($currentSetting) {
            $currentValue = if ($key -eq "ConfigManager.HostAccessManager.LockdownMode") {
                $currentSetting
            } else {
                $currentSetting.Value
            }

            # Convertir el valor actual a tipo booleano o entero según el valor esperado
            if ($expectedValue -is [bool]) {
                $currentValue = [bool]::Parse($currentValue)
            } elseif ($expectedValue -is [int]) {
                $currentValue = [int]$currentValue
            }
            $status = "OK"

            if ($key -eq "Syslog.global.logDir" -or $key -eq "Syslog.global.logHost" -or $key -eq "Syslog.global.auditRecord.storageDirectory") {
                if ($currentValue -eq "[] /scratch/Log" -or $currentValue -eq "[] /scratch/auditLog" -or $currentValue -eq "N/A") {
                    $status = "Warning"
                } elseif ([string]::IsNullOrEmpty($currentValue)) {
                    $status = "No existe"
                }
            } elseif ($currentValue -ne $expectedValue) {
                $status = "Warning"
            }

            $resultado = @{
                Host = $esxi.Name
                Setting = $key
                ExpectedValue = $expectedValue
                CurrentValue = $currentValue
                Status = $status
            }
            
            if ($status -eq "Warning") {
                Write-Host "ALERTA: Configuracion '$key' en el host '$($esxi.Name)' tiene el valor '$currentValue'."
            } else {
                Write-Host "Configuracion '$key' en el host '$($esxi.Name)' es correcta."
            }
        } else {
            $resultado = @{
                Host = $esxi.Name
                Setting = $key
                ExpectedValue = $expectedValue
                CurrentValue = "No existe"
                Status = "No existe"
            }
            Write-Host "ALERTA: Configuracion '$key' no existe en el host '$($esxi.Name)'."
        }

        $resultados += $resultado
    }
}

# Crear el contenido HTML
$html = @"
<html>
<head>
    <title>Verificacion de Configuraciones Avanzadas de ESXi</title>
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
    <h1 style="text-align:center;">Verificacion de Configuraciones Avanzadas de ESXi</h1>
    <table id="resultsTable">
        <tr>
            <th>Host<br><input type="text" id="hostFilter" onkeyup="filterTable()"></th>
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
            <td>$($resultado.Host)</td>
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

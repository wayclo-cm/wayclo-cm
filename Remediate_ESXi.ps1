Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false
Set-PowerCLIConfiguration -Scope AllUsers -ParticipateInCEIP $false -Confirm:$false
Set-ExecutionPolicy Unrestricted

# Importar el mÛdulo de VMware PowerCLI
Import-Module VMware.VimAutomation.Core -WarningAction SilentlyContinue
Import-Module VMware.PowerCLI

# Solicitar la direcciÛn IP del servidor vCenter
$vCenterServer = Read-Host "Ingrese la direcciÛn IP del servidor vCenter"

# Solicitar las credenciales de usuario
$credential = Get-Credential -Message "Ingrese las credenciales para el servidor vCenter"

# Solicitar el nombre del archivo de salida
$outputFileName = Read-Host "Ingrese el nombre del archivo de salida (sin extension)"

# Conectar a vCenter
Connect-VIServer -Server $vCenterServer -Credential $credential

# Configuraciones avanzadas a aplicar
$settings = @{
    "Config.HostAgent.plugins.hostsvc.esxAdminsGroupAutoAdd" = $false;
    "Config.HostAgent.plugins.vimsvc.authValidateInterval" = 90;
    "Security.AccountUnlockTime" = 900;
    "Security.AccountLockFailures" = 5;
    "Security.PasswordHistory" = 5;
    "UserVars.ESXiShellInteractiveTimeOut" = 900;
    "UserVars.ESXiShellTimeOut" = 600;
    "Security.PasswordQualityControl" = "retry=3 min=disabled,15,15,15,15 max=64 similar=deny passphrase=3";
    "UserVars.SuppressHyperthreadWarning" = 0;
    "UserVars.DcuiTimeOut" = 600;
    "Config.HostAgent.plugins.solo.enableMob" = $false;
    "DCUI.Access" = "root";
    "Config.HostAgent.log.level" = "info";
    "Net.BlockGuestBPDU" = 1;
    "UserVars.SuppressShellWarning" = 0;
    "UserVars.ESXiVPsDisabledProtocols" = "sslv3,tlsv1,tlsv1.1";
    "Mem.ShareForceSalting" = 2;
    "Syslog.global.auditRecord.storageEnable" = $true;
    "Syslog.global.auditRecord.storageCapacity" = 100;
    "Syslog.global.auditRecord.remoteEnable" = $true;
    "Syslog.global.logLevel" = "info";
    "Syslog.global.certificate.strictX509Compliance" = $true;
    "Mem.MemEagerZero" = 1;
    "ConfigManager.HostAccessManager.LockdownMode" = "lockdownNormal";
}

# Obtener todos los hosts ESXi
$esxiHosts = Get-VMHost

# Hosts excluidos
$excludedHosts = @("ESXi1_Exclude", "ESXi2_Exclude", "ESXi3_Exclude")

# Lista para almacenar los resultados
$resultados = @()
$excluidos = @()

# Aplicar las configuraciones avanzadas en cada host ESXi
foreach ($esxi in $esxiHosts) {
    if ($excludedHosts -contains $esxi.Name) {
        Write-Host "Excluyendo el host '$($esxi.Name)' de las configuraciones..."
        $excluidos += $esxi.Name
        continue
    }

    Write-Host "Aplicando configuraciones en el host '$($esxi.Name)'..."

    foreach ($key in $settings.Keys) {
        $expectedValue = $settings[$key]

        if ($key -eq "ConfigManager.HostAccessManager.LockdownMode") {
            # Configurar LockdownMode usando el comando especÌfico
            $currentMode = (Get-View (Get-VMHost -Name $esxi.Name | Get-View).ConfigManager.HostAccessManager).LockdownMode
            if ($currentMode -ne 'lockdownNormal') {
                (Get-View (Get-VMHost -Name $esxi.Name | Get-View).ConfigManager.HostAccessManager).ChangeLockdownMode('lockdownNormal')
                Write-Host "ALERTA: Configuracion 'LockdownMode' en el host '$($esxi.Name)' ha sido actualizada de '$currentMode' a 'lockdownNormal'."
                $status = "Actualizado"
            } else {
                Write-Host "Configuracion 'LockdownMode' en el host '$($esxi.Name)' ya es correcta."
                $status = "Correcto"
            }
        } else {
            # Obtener el valor actual del setting
            $currentSetting = Get-AdvancedSetting -Entity $esxi -Name $key -ErrorAction SilentlyContinue

            if ($currentSetting) {
                # La configuraciÛn ya existe, actualizar si es necesario
                if ($currentSetting.Value -ne $expectedValue) {
                    Set-AdvancedSetting -AdvancedSetting $currentSetting -Value $expectedValue -Confirm:$false
                    Write-Host "ALERTA: ConfiguraciÛn '$key' en el host '$($esxi.Name)' ha sido actualizada de '$($currentSetting.Value)' a '$expectedValue'."
                    $status = "Actualizado"
                } else {
                    Write-Host "ConfiguraciÛn '$key' en el host '$($esxi.Name)' ya es correcta."
                    $status = "Correcto"
                }
            } else {
                # La configuraciÛn no existe, crearla
                New-AdvancedSetting -Entity $esxi -Name $key -Value $expectedValue -Confirm:$false
                Write-Host "ALERTA: ConfiguraciÛn '$key' creada en el host '$($esxi.Name)' con valor '$expectedValue'."
                $status = "Creado"
            }
        }

        $resultado = @{
            Host = $esxi.Name
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
    <title>Aplicacion de Configuraciones Avanzadas de Hosts ESXi</title>
    <style>
        table { width: 100%; border-collapse: collapse; }
        th, td { border: 1px solid black; padding: 8px; text-align: left; }
        th { background-color: #F2F2F2; }
        .actualizado { background-color: #7CDAF9; } /* Celeste pastel */
        .correcto { background-color: #B0F2C2; }  /* Verde pastel */
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
    <h1 style="text-align:center;">Aplicacion de Configuraciones Avanzadas de Hosts ESXi</h1>
    <table id="resultsTable">
        <tr>
            <th>Host<br><input type="text" id="hostFilter" onkeyup="filterTable()"></th>
            <th>ConfiguraciÛn<br><input type="text" id="settingFilter" onkeyup="filterTable()"></th>
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
            <td>$($resultado.Host)</td>
            <td>$($resultado.Setting)</td>
            <td>$($resultado.ExpectedValue)</td>
            <td>$($resultado.Status)</td>
        </tr>
"@
}
$html += @"
    </table>
    <h2>Se excluyeron los siguientes hosts de la remediacion:</h2>
    <table>
        <tr>
            <th>Host</th>
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

# Informar al usuario la ubicaciÛn del archivo generado
Write-Host "El archivo de aplicacion ha sido guardado en $outputFilePath"

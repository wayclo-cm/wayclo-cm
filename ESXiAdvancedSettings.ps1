# Importar el módulo de VMware PowerCLI
Import-Module VMware.PowerCLI

# Variables de conexión
$vCenterServer = "vcenter"
$user = "tu_usuario"
$password = "tu_contraseña"

# Conectar a vCenter
Connect-VIServer -Server $vCenterServer -User $user -Password $password

# Configuraciones avanzadas a cambiar
$settings = @{
    "Config.HostAgent.plugins.hostsvc.esxAdminsGroupAutoAdd" = "false";
    "Config.HostAgent.plugins.vimsvc.authValidateInterval" = "90";
    “Security.AccountUnlockTime” = "900";
    “Security.AccountLockFailures” = "5";
    “Security.PasswordHistory” = "5";
    “Syslog.global.logDir” = "Site Specific";
    “Syslog.global.logHost” = "Site Specific";
    “Net.BlockGuestBPDU” = "1";
    “UserVars.ESXiShellInteractiveTimeOut” = "900";
    “UserVars.ESXiShellTimeOut” = "600";
    “Security.PasswordQualityControl” = "retry=3 min=disabled,15,15,15,15 max=64 similar=deny passphrase=3";
    “UserVars.SuppressHyperthreadWarning” = "0";
    “UserVars.DcuiTimeOut” = "600";
    “Config.HostAgent.plugins.solo.enableMob” = "false";
    “DCUI.Access” = "root";
    “Config.HostAgent.log.level” = "info";
    “Net.DVFilterBindIpAddress” = "N/A";
    “UserVars.SuppressShellWarning” = "0";
    “UserVars.ESXiVPsDisabledProtocols” = "sslv3,tlsv1,tlsv1.1";
    “Mem.ShareForceSalting” = "2";
    “Syslog.global.auditRecord.storageEnable” = "true";
    “Syslog.global.auditRecord.storageCapacity” = "100";
    “Syslog.global.auditRecord.storageDirectory” = "Site Specific";
    “Syslog.global.auditRecord.remoteEnable” = "true";
    “Syslog.global.logLevel” = "info";
    “Syslog.global.certificate.strictX509Compliance” = "true";
    “Mem.MemEagerZero” = "1";
    “Net.BMCNetworkEnable” = "0";
    “ConfigManager.HostAccessManager.LockdownMode” = "normal";
}

# Obtener todos los hosts ESXi
$esxiHosts = Get-VMHost

# Cambiar las configuraciones avanzadas en cada host ESXi
foreach ($esxi in $esxiHosts) {
    foreach ($key in $settings.Keys) {
        $settingName = $key
        $settingValue = $settings[$key]
        $currentSetting = Get-AdvancedSetting -Entity $esxi -Name $settingName -ErrorAction SilentlyContinue
        if ($currentSetting) {
            Set-AdvancedSetting -AdvancedSetting $currentSetting -Value $settingValue -Confirm:$false
            Write-Host "Configuración '$settingName' en el host '$($esxi.Name)' actualizada a '$settingValue'."
        } else {
            # Crear la configuración si no existe
            New-AdvancedSetting -Entity $esxi -Name $settingName -Value $settingValue -Confirm:$false
            Write-Host "Configuración '$settingName' creada en el host '$($esxi.Name)' con valor '$settingValue'."
        }
    }
}

# Desconectar de vCenter
Disconnect-VIServer -Server $vCenterServer -Confirm:$false

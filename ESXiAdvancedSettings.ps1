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
    “Security.AccountUnlockTime” =
    “Security.AccountLockFailures” =
    “Security.PasswordHistory” =
    “Syslog.global.logDir” =
    “Syslog.global.logHost” =
    “Net.BlockGuestBPDU” =
    “UserVars.ESXiShellInteractiveTimeOut” =
    “UserVars.ESXiShellTimeOut” =
    “Security.PasswordQualityControl” =
    “UserVars.SuppressHyperthreadWarning” =
    “UserVars.DcuiTimeOut” =
    “Config.HostAgent.plugins.solo.enableMob” =
    “DCUI.Access” =
    “Config.HostAgent.log.level” =
    “Net.DVFilterBindIpAddress” =
    “UserVars.SuppressShellWarning” =
    “UserVars.ESXiVPsDisabledProtocols” =
    “Mem.ShareForceSalting” =
    “Syslog.global.auditRecord.storageEnable” =
    “Syslog.global.auditRecord.storageCapacity” =
    “Syslog.global.auditRecord.storageDirectory” =
    “Syslog.global.auditRecord.remoteEnable” =
    “Syslog.global.logLevel” =
    “Syslog.global.certificate.strictX509Compliance” =
    “Mem.MemEagerZero” =
    “Net.BMCNetworkEnable” =
    “ConfigManager.HostAccessManager.LockdownMode” =
    “” =
    “” =
    “” =
    “” =
    “” =
    “” =
    “” =
    “” =
    “” =
    “” =
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

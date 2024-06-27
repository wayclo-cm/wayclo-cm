# Importar el módulo de VMware PowerCLI
Import-Module VMware.PowerCLI

# Solicitar las credenciales de usuario
$vCenterServer = "172.30.6.71"
$credential = Get-Credential -Message "Ingrese las credenciales para el servidor vCenter"

# Solicitar el nombre del archivo de salida
$outputFileName = Read-Host "Ingrese el nombre del archivo de salida (sin extensión)"

# Conectar a vCenter
Connect-VIServer -Server $vCenterServer -Credential $credential

# Configuraciones avanzadas a verificar
$settings = @{
    "Config.HostAgent.plugins.hostsvc.esxAdminsGroupAutoAdd" = $false;
    "Config.HostAgent.plugins.vimsvc.authValidateInterval" = 90;
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
        $currentSetting = Get-AdvancedSetting -Entity $esxi -Name $key -ErrorAction SilentlyContinue
        if ($currentSetting) {
            $currentValue = $currentSetting.Value
            # Convertir el valor actual a tipo booleano o entero según el valor esperado
            if ($expectedValue -is [bool]) {
                $currentValue = [bool]::Parse($currentSetting.Value)
            } elseif ($expectedValue -is [int]) {
                $currentValue = [int]$currentSetting.Value
            }
            if ($currentValue -ne $expectedValue) {
                $resultado = @{
                    Host = $esxi.Name
                    Setting = $key
                    ExpectedValue = $expectedValue
                    CurrentValue = $currentSetting.Value
                    Status = "Incorrecto"
                }
                Write-Host "ALERTA: Configuración '$key' en el host '$($esxi.Name)' tiene el valor '$($currentSetting.Value)' en lugar de '$expectedValue'."
            } else {
                $resultado = @{
                    Host = $esxi.Name
                    Setting = $key
                    ExpectedValue = $expectedValue
                    CurrentValue = $currentSetting.Value
                    Status = "Correcto"
                }
                Write-Host "Configuración '$key' en el host '$($esxi.Name)' es correcta."
            }
        } else {
            $resultado = @{
                Host = $esxi.Name
                Setting = $key
                ExpectedValue = $expectedValue
                CurrentValue = "No existe"
                Status = "No existe"
            }
            Write-Host "ALERTA: Configuración '$key' no existe en el host '$($esxi.Name)'."
        }
        $resultados += $resultado
    }
}

# Ruta del logotipo de Wayclo
$logoWayclo = "C:\Scripts\wayclo.png"

# Crear el contenido HTML
$html = @"
<html>
<head>
    <title>Verificación de Configuraciones Avanzadas de ESXi</title>
    <style>
        table { width: 100%; border-collapse: collapse; }
        th, td { border: 1px solid black; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .incorrecto { background-color: #ffcccb; } /* Rojo pastel */
        .correcto { background-color: #6afaf0; }  /* #6afaf0 */
        .noexiste { background-color: #fff3cd; }
    </style>
</head>
<body>
    <div style="text-align:center;">
        <img src="$logoWayclo" alt="Wayclo" style="height: 100px;"/>
    </div>
    <h1 style="text-align:center;">Control de configuraciones en los hosts</h1>
    <table>
        <tr>
            <th>Host</th>
            <th>Configuración</th>
            <th>Valor Esperado</th>
            <th>Valor Actual</th>
            <th>Estado</th>
        </tr>
"@

foreach ($resultado in $resultados) {
    $estadoClase = ""
    switch ($resultado.Status) {
        "Incorrecto" { $estadoClase = "incorrecto" }
        "Correcto" { $estadoClase = "correcto" }
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
$outputFilePath = "$outputFileName.html"
$html | Out-File -FilePath $outputFilePath -Encoding UTF8

# Desconectar de vCenter
Disconnect-VIServer -Server $vCenterServer -Confirm:$false

# Informar al usuario la ubicación del archivo generado
Write-Host "El archivo de verificación ha sido guardado en $outputFilePath"

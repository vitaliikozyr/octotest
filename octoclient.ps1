$serverThumbprint = "DE99179CAAF5F5CC01814355A770670A564AE262"
$serverUri = "https://octopus.sys-national.com"
$tentacleInstallApiKey = "API-ZOLLQUMDDMBAKBE2CDZMPD1IHM"
$role = "Dev"
$environment = "Development"


function Tentacle-Configure([string]$arguments)
{
    Write-Output "Configuring Tentacle with $arguments"

    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = "C:\Program Files\Octopus Deploy\Tentacle\Tentacle.exe"
    $pinfo.RedirectStandardError = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.CreateNoWindow = $true; 
    $pinfo.UseShellExecute = $false;
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = $arguments
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    $p.WaitForExit()
    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()
    
    Write-Host $stdout
    Write-Host $stderr
    
    if ($p.ExitCode -ne 0) {
        Write-Host "Exit code: " + $p.ExitCode
        throw "Configuration failed"
    }
}

function Get-ExternalIP {
    return (Invoke-WebRequest http://myexternalip.com/raw -UseBasicParsing).Content.TrimEnd()
}


Write-Output "Beginning Tentacle installation"

Write-Output "Downloading Octopus Tentacle MSI..."
$downloader = new-object System.Net.WebClient
$downloader.DownloadFile("https://octopus.com/downloads/latest/OctopusTentacle64", "Tentacle.msi")

Write-Output "Installing Tentacle"
$msiExitCode = (Start-Process -FilePath "msiexec.exe" -ArgumentList "/i Tentacle.msi /quiet" -Wait -Passthru).ExitCode
if ($msiExitCode -ne 0) {
    Write-Output "Tentacle MSI installer returned exit code $msiExitCode"
    throw "Installation aborted"
}

$ipAddress = Get-ExternalIP
Write-Output "Detected IP address as $ipAddress"

Write-Output "Configuring Tentacle"
Tentacle-Configure "create-instance --instance `"Tentacle`" --config `"C:\Octopus\Tentacle.config`" --console"
Tentacle-Configure "new-certificate --instance `"Tentacle`" --if-blank --console"
Tentacle-Configure "configure --instance `"Tentacle`" --reset-trust --console"
Tentacle-Configure "configure --instance `"Tentacle`" --home `"C:\Octopus`" --app `"C:\Octopus\Applications`" --port `"10933`" --console"
Tentacle-Configure "configure --instance `"Tentacle`" --trust `"$serverThumbprint`" --console"
netsh advfirewall firewall add rule "name=Octopus Deploy Tentacle" dir=in action=allow protocol=TCP localport=10933
Tentacle-Configure "register-with --instance `"Tentacle`" --server `"$serverUri`" --apiKey=`"$tentacleInstallApiKey`" --publicHostName `"$ipAddress`" --role `"$role`" --environment `"$environment`" --comms-style TentaclePassive --console"
Tentacle-Configure "service --instance `"Tentacle`" --install --start --console"

Write-Output "Installation Tentacle"

Remove-Item "Tentacle.msi"
Remove-Item $PSCommandPath

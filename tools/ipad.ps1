# Helpers for talking to the jailbroken iPad over SSH.
# Usage:
#   . .\tools\ipad.ps1
#   Install-RealNews-IPad

$script:IPadKey = Join-Path $env:USERPROFILE '.ssh\ipad_ios6'
$script:IPadDefaultHost = '192.168.1.166'

$localCfg = Join-Path $PSScriptRoot 'local.json'
if (Test-Path $localCfg) {
    $cfg = Get-Content $localCfg -Raw | ConvertFrom-Json
    if ($cfg.ipad) { $script:IPadDefaultHost = $cfg.ipad }
}

function Get-IPadSshArgs {
    @('-i', $script:IPadKey, '-oHostKeyAlgorithms=+ssh-rsa', '-oStrictHostKeyChecking=accept-new', '-oConnectTimeout=10', '-oBatchMode=yes', '-oLogLevel=ERROR')
}

function Invoke-IPad {
    param([Parameter(Mandatory = $true)][string]$Command, [string]$IPadHost = $script:IPadDefaultHost)
    $ErrorActionPreference = 'Continue'
    $sshArgs = Get-IPadSshArgs
    & ssh.exe @sshArgs "root@$IPadHost" $Command 2>&1 |
        ForEach-Object { if ($_ -is [Management.Automation.ErrorRecord]) { $_.Exception.Message } else { $_ } }
}

function Copy-ToIPad {
    param([Parameter(Mandatory = $true)][string]$LocalPath, [Parameter(Mandatory = $true)][string]$RemotePath, [string]$IPadHost = $script:IPadDefaultHost)
    $ErrorActionPreference = 'Continue'
    $sshArgs = Get-IPadSshArgs
    & scp.exe -O @sshArgs $LocalPath "root@${IPadHost}:$RemotePath" 2>&1 |
        ForEach-Object { if ($_ -is [Management.Automation.ErrorRecord]) { $_.Exception.Message } else { $_ } }
    if ($LASTEXITCODE -ne 0) { throw "scp failed for $LocalPath" }
}

function Copy-FromIPad {
    param([Parameter(Mandatory = $true)][string]$RemotePath, [Parameter(Mandatory = $true)][string]$LocalPath, [string]$IPadHost = $script:IPadDefaultHost)
    $ErrorActionPreference = 'Continue'
    $sshArgs = Get-IPadSshArgs
    & scp.exe -O @sshArgs "root@${IPadHost}:$RemotePath" $LocalPath 2>&1 |
        ForEach-Object { if ($_ -is [Management.Automation.ErrorRecord]) { $_.Exception.Message } else { $_ } }
    if ($LASTEXITCODE -ne 0) { throw "scp failed for $RemotePath" }
}

function Get-IPadSnapshot {
    param([string]$Name = 'shot', [string]$IPadHost = $script:IPadDefaultHost, [string]$OutDir = '')
    if (-not $OutDir) { $OutDir = Join-Path $PSScriptRoot '..\packages\shots-ipad' }
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
    Invoke-IPad -IPadHost $IPadHost -Command "rm -f /tmp/$Name.png; uiopen realnews:snapshot; sleep 1; cp /tmp/realnews-screen.png /tmp/$Name.png" | Out-Null
    $local = Join-Path $OutDir "$Name.png"
    Copy-FromIPad -IPadHost $IPadHost -RemotePath "/tmp/$Name.png" -LocalPath $local
    Get-Item $local
}


function Install-RealNews-IPad {
    param([string]$IPadHost = $script:IPadDefaultHost)
    $debs = Get-ChildItem -Path "$PSScriptRoot\..\packages" -Recurse -Filter "*iphoneos-arm.deb" | Sort-Object LastWriteTime -Descending
    if (-not $debs) {
        Write-Error "No arm.deb package found in packages\"
        return
    }
    $targetDeb = $debs[0].FullName
    Write-Host "Installing $targetDeb to iPad at $IPadHost ..."
    Invoke-IPad -IPadHost $IPadHost -Command 'killall RealNews 2>/dev/null; echo stopped' | Out-Null
    Copy-ToIPad -LocalPath $targetDeb -RemotePath '/tmp/realnews.deb' -IPadHost $IPadHost
    $out = Invoke-IPad -IPadHost $IPadHost -Command 'dpkg -i /tmp/realnews.deb 2>&1 && { su - mobile -c uicache 2>/dev/null; echo DEB_OK; }' | Out-String
    Write-Host $out
    if ($out -match 'DEB_OK') {
        Write-Host "RealNews successfully installed on iPad!" -ForegroundColor Green
    }
}

function Launch-RealNews-IPad {
    param([string]$IPadHost = $script:IPadDefaultHost)
    Invoke-IPad -IPadHost $IPadHost -Command 'sblaunch com.samcejko.realnews'
}

function Get-RealNewsLog {
    param([string]$IPadHost = $script:IPadDefaultHost)
    Invoke-IPad -IPadHost $IPadHost -Command 'grep -i RealNews /var/log/syslog'
}

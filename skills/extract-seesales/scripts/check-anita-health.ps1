# Snapshot + classify every live AniTa window; optional reconnect for Disconnected titles.
[CmdletBinding()]
param([switch]$ReconnectDisconnected)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$launch = Join-Path $scriptDir 'launch-anita-hidden.ps1'
$exe = Join-Path $env:LOCALAPPDATA 'Temp\anita-capture\anita-bg.exe'
$reader = Join-Path $scriptDir 'read-anita-screen.py'
$python = 'C:\Program Files\Python311\python.exe'
$labs = @(
    @{ Host = 'use-idb057'; Label = 'wheatridge'; Tile = 0; Ip = '10.149.0.5' }
    @{ Host = 'use-idb059'; Label = 'dayton'; Tile = 1; Ip = '10.149.0.5' }
    @{ Host = 'use-idb066'; Label = 'orlando'; Tile = 2; Ip = '10.149.0.26' }
    @{ Host = 'use-idb062'; Label = 'scott'; Tile = 3; Ip = '10.149.0.28' }
    @{ Host = 'use-idb064'; Label = 'houston'; Tile = 4; Ip = '10.149.0.24' }
)

function Test-Telnet23([string]$ip) {
    try {
        $t = New-Object System.Net.Sockets.TcpClient
        $iar = $t.BeginConnect($ip, 23, $null, $null)
        $ok = $iar.AsyncWaitHandle.WaitOne(3000, $false)
        if ($ok -and $t.Connected) { $t.Close(); return $true }
        $t.Close()
        return $false
    } catch { return $false }
}

$report = @()
foreach ($lab in $labs) {
    $proc = Get-Process Anita -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowTitle -match [regex]::Escape($lab.Host) } |
        Select-Object -First 1
    $title = if ($proc) { $proc.MainWindowTitle } else { '' }
    $telnet = Test-Telnet23 $lab.Ip
    $disconnected = ($title -match 'Disconnected')
    $screen = ''
    if ($proc -and (Test-Path $exe) -and -not $disconnected) {
        [Environment]::SetEnvironmentVariable('ANITA_CAPTURE_LABEL', $lab.Label, 'Process')
        $snap = 'health-check.png'
        & $exe snap $snap $lab.Host 2>&1 | Out-Null
        if ((Test-Path $python) -and (Test-Path $reader)) {
            $screen = (& $python $reader $snap --lims 2>&1 | Select-Object -Last 1) -replace '^\s+', ''
        }
    }
    $state = if (-not $proc) { 'missing' }
        elseif ($disconnected) { 'disconnected' }
        elseif ($title -match 'Connecting') { 'connecting' }
        else { 'connected' }
    $report += [pscustomobject]@{
        Lab        = $lab.Label
        Host       = $lab.Host
        Ip         = $lab.Ip
        Telnet23   = $telnet
        Pid        = if ($proc) { $proc.Id } else { $null }
        Title      = $title
        State      = $state
        Classifier = $screen
    }
}

$report | Format-Table -AutoSize -Wrap
Write-Output ''
foreach ($r in $report) {
    Write-Output ("ANITA_HEALTH lab={0} host={1} state={2} telnet23={3} pid={4}" -f $r.Lab, $r.Host, $r.State, $r.Telnet23, $r.Pid)
}

if ($ReconnectDisconnected) {
    foreach ($lab in $labs) {
        $row = $report | Where-Object { $_.Lab -eq $lab.Label }
        if ($row.State -ne 'disconnected') { continue }
        Write-Output "RECONNECT $($lab.Label) close stale window and relaunch"
        if ($row.Pid) {
            Stop-Process -Id $row.Pid -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 4
        }
        & $launch -HostName $lab.Host -Label $lab.Label -TileIndex $lab.Tile -ShowWindow
        Start-Sleep -Seconds 8
        $proc2 = Get-Process Anita -ErrorAction SilentlyContinue |
            Where-Object { $_.MainWindowTitle -match [regex]::Escape($lab.Host) } |
            Select-Object -First 1
        Write-Output "RECONNECT_RESULT lab=$($lab.Label) title=$($proc2.MainWindowTitle)"
    }
}

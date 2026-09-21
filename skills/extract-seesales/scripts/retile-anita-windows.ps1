# Re-tile every running AniTa window (after parallel launch or login).
# Win11 shows one taskbar icon for Anita.exe — hover it or Alt+Tab to switch.
[CmdletBinding()]
param([switch]$Json)

$ErrorActionPreference = 'Stop'
$tileByHost = @{
    'use-idb057' = 0
    'use-idb059' = 1
    'use-idb066' = 2
    'use-idb062' = 3
    'use-idb064' = 4
}
$captureRoot = Join-Path $env:LOCALAPPDATA 'Temp\anita-capture'
$exe = Join-Path $captureRoot 'anita-bg.exe'
if (-not (Test-Path $exe)) {
    throw "Missing $exe. Run login-seesales.ps1 once to compile anita-bg."
}
[Environment]::SetEnvironmentVariable('ANITA_SHOW_WINDOW', '1', 'Process')
$live = @(Get-Process Anita -ErrorAction SilentlyContinue)
$out = @()
foreach ($p in $live) {
    $hostNeedle = $null
    foreach ($h in $tileByHost.Keys) {
        if ($p.MainWindowTitle -match [regex]::Escape($h)) { $hostNeedle = $h; break }
    }
    if (-not $hostNeedle) { continue }
    [Environment]::SetEnvironmentVariable('ANITA_TILE_INDEX', "$($tileByHost[$hostNeedle])", 'Process')
    $lines = & $exe park $hostNeedle 2>&1 | ForEach-Object { "$_" }
    $out += [pscustomobject]@{ Pid = $p.Id; Host = $hostNeedle; Title = $p.MainWindowTitle; Park = ($lines -join ' ') }
}
if ($Json) {
    $out | ConvertTo-Json -Depth 3
} else {
    Write-Output "ANITA_LIVE count=$($live.Count)"
    $out | Format-Table -AutoSize
    if ($live.Count -lt 2) {
        Write-Output 'Only one AniTa process. Others exited (idle disconnect or parallel test closed them).'
    }
}

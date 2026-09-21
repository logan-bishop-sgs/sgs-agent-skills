# List AniTa processes and the session manifest written by launch-anita-hidden.ps1.
[CmdletBinding()]
param([switch]$Json)

$ErrorActionPreference = 'Stop'
$captureRoot = Join-Path $env:LOCALAPPDATA 'Temp\anita-capture'
$manifest = Join-Path $captureRoot 'anita-sessions.jsonl'

$rows = @()
if (Test-Path $manifest) {
    Get-Content -LiteralPath $manifest | ForEach-Object {
        if ($_.Trim()) {
            try { $rows += $_ | ConvertFrom-Json } catch { }
        }
    }
}

$live = @(Get-Process Anita -ErrorAction SilentlyContinue | ForEach-Object {
    @{
        pid   = $_.Id
        title = $_.MainWindowTitle
    }
})

if ($Json) {
    @{ manifest = $rows; live = $live } | ConvertTo-Json -Depth 5
    return
}

Write-Output "ANITA_CAPTURE_ROOT=$captureRoot"
Write-Output "ANITA_SESSION_MANIFEST=$manifest"
Write-Output '--- live Anita.exe ---'
if (-not $live.Count) {
    Write-Output '(none)'
} else {
    foreach ($p in $live) {
        Write-Output ("pid={0} title={1}" -f $p.pid, $p.title)
    }
}
Write-Output '--- manifest (append-only; may include closed PIDs) ---'
if (-not $rows.Count) {
    Write-Output '(empty)'
} else {
    foreach ($r in $rows | Select-Object -Last 20) {
        Write-Output ("pid={0} host={1} label={2} at={3}" -f $r.pid, $r.host, $r.label, $r.at)
    }
}

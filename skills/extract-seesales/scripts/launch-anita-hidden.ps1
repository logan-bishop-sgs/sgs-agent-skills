# Launch AniTa minimized, no chrome, no host-picker popup.
# Export still needs the AniTa process. This only keeps it off Logan's desktop.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$HostName,
    [Parameter(Mandatory = $true)][string]$Label,
    [int]$TileIndex = -1,
    [switch]$ShowWindow
)

$ErrorActionPreference = 'Stop'
$cap = Join-Path $env:LOCALAPPDATA 'Temp\anita-capture'
New-Item -ItemType Directory -Force -Path $cap | Out-Null
$src = Join-Path $cap 'seesales-login.wcf'
if (-not (Test-Path $src)) {
    Copy-Item 'C:\Program Files (x86)\AniTa\anita.wcf' $src -Force
}
$dst = Join-Path $cap ($Label + '.wcf')
Copy-Item -LiteralPath $src -Destination $dst -Force
$raw = Get-Content -LiteralPath $dst -Raw
$repl = @{
    'HostName="[^"]*"'            = "HostName=`"$HostName`""
    'MaxInstance=\d+'             = 'MaxInstance=8'
    'Description="[^"]*"'         = "Description=`"$Label`""
    'TelnetOptionsInit=No'        = 'TelnetOptionsInit=Yes'
    'PromptForHost=Yes'           = 'PromptForHost=No'
    'BrowseForHost=Yes'           = 'BrowseForHost=No'
    'AutoLogin=Yes'               = 'AutoLogin=No'
    'AutoUser1="[^"]*"'           = 'AutoUser1=%null%'
    'AutoHost1="[^"]*"'           = 'AutoHost1=%null%'
    'AutoHost2="[^"]*"'           = 'AutoHost2=%null%'
    'BlankScreenTimeout=\d+'      = 'BlankScreenTimeout=0'
    'BlankAutoLogin=(Yes|No)'     = 'BlankAutoLogin=No'
    'LockKbdAutoLogin=Yes'        = 'LockKbdAutoLogin=No'
    'MciShowError=Yes'            = 'MciShowError=No'
    'KeepAliveSeconds=0'          = 'KeepAliveSeconds=45'
}
foreach ($k in $repl.Keys) { $raw = [regex]::Replace($raw, $k, $repl[$k]) }
if (-not $ShowWindow) {
    $hideChrome = @{
        'ShowTitlebar=Yes'      = 'ShowTitlebar=No'
        'ShowMenu=Yes'          = 'ShowMenu=No'
        'ShowSysMenu=Yes'       = 'ShowSysMenu=No'
        'Toolbar=Yes'           = 'Toolbar=No'
        'Statusbar=Yes'         = 'Statusbar=No'
        'EnableButtonPanel=Yes' = 'EnableButtonPanel=No'
        'EnableAppHelpTips=Yes' = 'EnableAppHelpTips=No'
    }
    foreach ($k in $hideChrome.Keys) { $raw = [regex]::Replace($raw, $k, $hideChrome[$k]) }
}
$raw = [regex]::Replace($raw, 'BlankAutoLogin=\w+', 'BlankAutoLogin=No')
$raw = [regex]::Replace($raw, 'AutoUser2="[^"]*"', 'AutoUser2=%null%')
Set-Content -LiteralPath $dst -Value $raw -NoNewline
$blank = [regex]::Match($raw, 'BlankAutoLogin=\w+').Value
Write-Output "wcf $blank AutoUser1=$([regex]::Match($raw, 'AutoUser1=\"[^\"]*\"').Value)"
$live = @(Get-Process Anita -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowTitle -match [regex]::Escape($HostName) -and $_.MainWindowTitle -notmatch 'Disconnected|Connecting' })
if ($live.Count -gt 0) {
    $p = $live[0]
    Write-Output "SKIP_LAUNCH pid=$($p.Id) host=$HostName label=$Label title=$($p.MainWindowTitle)"
    if ($TileIndex -ge 0 -and -not $p.HasExited) {
        [Environment]::SetEnvironmentVariable('ANITA_TILE_INDEX', "$TileIndex", 'Process')
        if ($ShowWindow) { [Environment]::SetEnvironmentVariable('ANITA_SHOW_WINDOW', '1', 'Process') }
        $exe = Join-Path $cap 'anita-bg.exe'
        if (Test-Path $exe) { & $exe park $HostName 2>&1 | ForEach-Object { Write-Output $_ } }
    }
    return
}
# Keep the window normal-size so PrintWindow can read the canvas.
# anita-bg parks it bottom-right, behind other windows, no activate.
$p = Start-Process -FilePath 'C:\Program Files (x86)\AniTa\Anita.exe' -ArgumentList $dst -PassThru
$parkDeadline = (Get-Date).AddSeconds(45)
do {
    Start-Sleep -Milliseconds 400
    try { $p.Refresh() } catch { }
} while ((Get-Date) -lt $parkDeadline -and $p.HasExited -eq $false -and $p.MainWindowHandle -eq 0)
if ($TileIndex -ge 0 -and -not $p.HasExited) {
    [Environment]::SetEnvironmentVariable('ANITA_TILE_INDEX', "$TileIndex", 'Process')
    if ($ShowWindow) {
        [Environment]::SetEnvironmentVariable('ANITA_SHOW_WINDOW', '1', 'Process')
    }
    $exe = Join-Path $cap 'anita-bg.exe'
    if (Test-Path $exe) {
        & $exe park $HostName 2>&1 | ForEach-Object { Write-Output $_ }
    }
}
$sessionLine = (@{
    pid   = $p.Id
    host  = $HostName
    label = $Label
    wcf   = $dst
    at    = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
} | ConvertTo-Json -Compress)
Add-Content -LiteralPath (Join-Path $cap 'anita-sessions.jsonl') -Value $sessionLine
Write-Output "SESSION pid=$($p.Id) host=$HostName label=$Label wcf=$dst"
Write-Output "LAUNCH pid=$($p.Id) host=$HostName label=$Label wcf=$dst"

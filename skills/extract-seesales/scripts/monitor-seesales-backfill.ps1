# Append a status block every N minutes while Jan-Feb backfill runs.
param(
    [string]$LogPath = (Get-ChildItem (Join-Path $env:TEMP 'seesales-janfeb2025-*.log') | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName,
    [int]$IntervalMinutes = 10,
    [int]$MaxTicks = 24
)
$py = 'C:\Program Files\Python311\python.exe'
$reader = Join-Path $PSScriptRoot 'read-anita-screen.py'
$monitorLog = Join-Path $env:TEMP ("seesales-backfill-monitor-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
$cap = Join-Path $env:LOCALAPPDATA 'Temp\anita-capture'

function Write-Block([string]$title) {
    $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')
    Add-Content -LiteralPath $monitorLog -Value "`n=== $title @ $ts ==="
}

for ($t = 1; $t -le $MaxTicks; $t++) {
    Write-Block "tick $t"
    $runner = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match 'run-seesales-extract' -and $_.CommandLine -match '2025-01' }
    Add-Content -LiteralPath $monitorLog -Value ("runner_procs=" + @($runner).Count)
    if ($LogPath -and (Test-Path -LiteralPath $LogPath)) {
        $saved = (Select-String -LiteralPath $LogPath -Pattern '^SAVED ' -AllMatches).Count
        $doneLab = Select-String -LiteralPath $LogPath -Pattern '^DONE lab=' | ForEach-Object { $_.Line }
        $retry = Select-String -LiteralPath $LogPath -Pattern '^RETRY lab=' | Select-Object -Last 3 | ForEach-Object { $_.Line }
        $last = Get-Content -LiteralPath $LogPath -Tail 8
        Add-Content -LiteralPath $monitorLog -Value "backfill_log=$LogPath"
        Add-Content -LiteralPath $monitorLog -Value "SAVED_count=$saved"
        Add-Content -LiteralPath $monitorLog -Value ("DONE_labs=" + ($doneLab -join ' | '))
        if ($retry) { Add-Content -LiteralPath $monitorLog -Value ("recent_RETRY=" + ($retry -join ' | ')) }
        Add-Content -LiteralPath $monitorLog -Value '--- log tail ---'
        $last | ForEach-Object { Add-Content -LiteralPath $monitorLog -Value $_ }
    } else {
        Add-Content -LiteralPath $monitorLog -Value "WARN missing log $LogPath"
    }
    $snaps = @()
    if (Test-Path $cap) {
        $snaps = Get-ChildItem -LiteralPath $cap -Recurse -Filter '*-canvas.png' -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 3
    }
    foreach ($s in $snaps) {
        $rel = $s.FullName.Substring($cap.Length).TrimStart('\')
        $class = 'n/a'
        if (Test-Path $py) {
            $env:ANITA_CAPTURE_LABEL = ''
            if ($rel -match '^([^\\]+)\\') { $env:ANITA_CAPTURE_LABEL = $Matches[1] }
            $class = & $py $s.FullName --lims 2>$null | Select-Object -Last 1
        }
        Add-Content -LiteralPath $monitorLog -Value ("snap $($s.LastWriteTime.ToString('HH:mm:ss')) $rel -> $class")
    }
    Write-Output "MONITOR tick=$t log=$monitorLog SAVED=$saved"
    if (@($runner).Count -eq 0) {
        Add-Content -LiteralPath $monitorLog -Value 'runner_exited=1'
        Write-Output 'MONITOR runner finished; stopping'
        break
    }
    if ($t -lt $MaxTicks) { Start-Sleep -Seconds (60 * $IntervalMinutes) }
}
Write-Output "MONITOR_LOG=$monitorLog"

# Launch one AniTa window per lab, then log in **one lab at a time** (KeepOtherAnita).
# Five hosts stay connected in parallel; WM_CHAR runs serially so telnet does not drop.
#   powershell -File test-seesales-login-parallel.ps1 -Lab all -Passes 2
[CmdletBinding()]
param(
    [string]$Lab = 'all',
    [int]$Passes = 2,
    [int]$ConnectWaitSeconds = 90,
    [switch]$CleanUpAll
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$login = Join-Path $scriptDir 'login-seesales.ps1'
$launch = Join-Path $scriptDir 'launch-anita-hidden.ps1'

$labOrder = @('wheatridge', 'dayton', 'orlando', 'scott', 'houston')
$labMap = @{
    wheatridge = @{ Host = 'use-idb057'; Invoice = 'i'; Tile = 0 }
    dayton     = @{ Host = 'use-idb059'; Invoice = 'i'; Tile = 1 }
    orlando    = @{ Host = 'use-idb066'; Invoice = 'i'; Tile = 2 }
    scott      = @{ Host = 'use-idb062'; Invoice = 'I'; Tile = 3 }
    houston    = @{ Host = 'use-idb064'; Invoice = 'I'; Tile = 4 }
}

$names = New-Object System.Collections.Generic.List[string]
if ($Lab.Trim().ToLowerInvariant() -eq 'all') {
    foreach ($n in $labOrder) { $names.Add($n) }
} else {
    foreach ($token in ($Lab.Split(',') | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ })) {
        if (-not $labMap.ContainsKey($token)) { throw "Unknown lab $token" }
        if (-not $names.Contains($token)) { $names.Add($token) }
    }
}

function Get-AnitaTitle([string]$hostNeedle) {
    $p = Get-Process Anita -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowTitle -match [regex]::Escape($hostNeedle) } |
        Select-Object -First 1
    if ($p) { return $p.MainWindowTitle }
    return ''
}

function Set-AllAnitaTiles {
    $captureRoot = Join-Path $env:LOCALAPPDATA 'Temp\anita-capture'
    $exe = Join-Path $captureRoot 'anita-bg.exe'
    if (-not (Test-Path $exe)) { return }
    [Environment]::SetEnvironmentVariable('ANITA_SHOW_WINDOW', '1', 'Process')
    foreach ($loc in $names) {
        $info = $labMap[$loc]
        [Environment]::SetEnvironmentVariable('ANITA_TILE_INDEX', "$($info.Tile)", 'Process')
        & $exe park $info.Host 2>&1 | Out-Null
    }
    $n = @(Get-Process Anita -ErrorAction SilentlyContinue).Count
    Write-Output "LIMS_PARALLEL_ANITA_COUNT count=$n (Win11: one taskbar icon; hover or Alt+Tab for each host)"
}

function Wait-AllAnitaConnected([string[]]$hosts, [int]$seconds) {
    $deadline = (Get-Date).AddSeconds($seconds)
    do {
        $states = @()
        foreach ($h in $hosts) {
            $t = Get-AnitaTitle $h
            $ok = ($t -and $t -notmatch 'Disconnected|Connecting')
            $states += "$h=$t"
        }
        Write-Output ("LIMS_PARALLEL_CONN " + ($states -join ' | '))
        $allOk = $true
        foreach ($h in $hosts) {
            $t = Get-AnitaTitle $h
            if (-not $t -or $t -match 'Disconnected|Connecting') { $allOk = $false }
        }
        if ($allOk) { return $true }
        Start-Sleep -Seconds 3
    } while ((Get-Date) -lt $deadline)
    return $false
}

$auditRun = Join-Path $env:TEMP ("seesales-login-audit/parallel-{0:yyyyMMdd-HHmmss}" -f (Get-Date))
New-Item -ItemType Directory -Force -Path $auditRun | Out-Null
Write-Output "LOGIN_PARALLEL labs=$($names -join ',') passes=$Passes mode=launch-parallel-login-serial"
Write-Output "LOGIN_AUDIT_RUN=$auditRun"
$allResults = @()

for ($pass = 1; $pass -le $Passes; $pass++) {
    Write-Output "=== PASS $pass/$Passes ==="
    Get-Process Anita -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 6

    foreach ($loc in $names) {
        $info = $labMap[$loc]
        & $launch -HostName $info.Host -Label $loc -TileIndex $info.Tile -ShowWindow
        Start-Sleep -Seconds 2
    }
    Get-Process Anita -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Output "LIMS_PARALLEL_PID pid=$($_.Id) title=$($_.MainWindowTitle)"
    }

    $hostList = @($names | ForEach-Object { $labMap[$_].Host })
    if (-not (Wait-AllAnitaConnected $hostList $ConnectWaitSeconds)) {
        throw "Not all AniTa hosts connected within ${ConnectWaitSeconds}s on pass $pass"
    }
    Set-AllAnitaTiles

    foreach ($loc in $names) {
        $info = $labMap[$loc]
        $title = Get-AnitaTitle $info.Host
        if (-not $title -or $title -match 'Disconnected|Connecting') {
            Write-Output "LIMS_PARALLEL relaunch $loc (was: $title) idle hosts drop off login: while another lab logs in"
            & $launch -HostName $info.Host -Label $loc -TileIndex $info.Tile -ShowWindow
            $oneHost = @($info.Host)
            if (-not (Wait-AllAnitaConnected $oneHost 60)) {
                throw "Could not reconnect $loc ($($info.Host)) before login"
            }
        }
        $logPath = Join-Path $env:TEMP ("seesales-login-parallel-{0}-pass{1}.log" -f $loc, $pass)
        $attemptAudit = Join-Path $auditRun ("{0}-pass{1}" -f $loc, $pass)
        New-Item -ItemType Directory -Force -Path $attemptAudit | Out-Null
        [Environment]::SetEnvironmentVariable('ANITA_LOGIN_AUDIT_DIR', $attemptAudit, 'Process')
        Write-Output "--- serial login $loc pass $pass (other AniTa windows stay open) ---"
        $t0 = Get-Date
        $logLines = [System.Collections.Generic.List[string]]::new()
        $ok = $false
        $err = ''
        try {
            & $login -HostName $info.Host -Label $loc -InvoiceKey $info.Invoice -TileIndex $info.Tile -ShowWindowForTile `
                -KeepOtherAnita -SkipLaunch -LoginAttempts 2 *>&1 | ForEach-Object {
                $line = "$_"
                [void]$logLines.Add($line)
                Write-Output $line
            } | Tee-Object -FilePath $logPath | Out-Null
            $statusLine = $logLines | Where-Object { $_ -match '^LOGIN_STATUS=success' } | Select-Object -Last 1
            if (-not $statusLine) {
                $failLine = $logLines | Where-Object { $_ -match '^LOGIN_STATUS=fail' } | Select-Object -Last 1
                if ($failLine -match 'reason=(.+)$') { $err = $Matches[1] } else { $err = 'no LOGIN_STATUS=success' }
                throw $err
            }
            $ok = $true
        } catch {
            if (-not $err) { $err = $_.Exception.Message }
            $logLines | Out-File -LiteralPath $logPath -Encoding utf8
        }
        $ms = [int]((Get-Date) - $t0).TotalMilliseconds
        if ($ok) {
            Write-Output "LOGIN_RESULT status=success lab=$loc pass=$pass mode=parallel-serial ms=$ms"
            $allResults += [pscustomobject]@{ Lab = $loc; Pass = $pass; Ok = $true; Ms = $ms; Error = '' }
        } else {
            Write-Output "LOGIN_RESULT status=fail lab=$loc pass=$pass mode=parallel-serial ms=$ms reason=$err"
            $allResults += [pscustomobject]@{ Lab = $loc; Pass = $pass; Ok = $false; Ms = $ms; Error = $err }
        }
        Set-AllAnitaTiles
        Start-Sleep -Seconds 3
    }

    if ($CleanUpAll) {
        Get-Process Anita -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 8
        Write-Output 'LIMS_PARALLEL_CLEANUP closed all AniTa (-CleanUpAll)'
    } else {
        Write-Output 'LIMS_PARALLEL_LEAVE windows left open (pass finished; use -CleanUpAll to force-close)'
    }
}

Write-Output ''
Write-Output 'SUMMARY'
$allResults | Format-Table -AutoSize
$summaryPath = Join-Path $env:TEMP 'seesales-login-parallel-summary.json'
$allResults | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $summaryPath
Write-Output "SUMMARY_JSON $summaryPath"
$fail = @($allResults | Where-Object { -not $_.Ok })
if ($fail.Count -gt 0) {
    throw "Parallel login: $($fail.Count) failure(s) of $($allResults.Count)."
}
Write-Output "Parallel login: $($allResults.Count)/$($allResults.Count) OK."

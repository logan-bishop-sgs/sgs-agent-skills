# Two full logins (Linux + IFORMS + Invoice + See Sales) per lab. No export.
#   powershell -File test-seesales-login.ps1
#   powershell -File test-seesales-login.ps1 -Passes 2 -Lab houston,orlando
#   powershell -File test-seesales-login.ps1 -KeepAllWindowsOpen -Passes 1 -Lab all
[CmdletBinding()]
param(
    [string]$Lab = 'all',
    [int]$Passes = 2,
    [switch]$KeepAllWindowsOpen
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$login = Join-Path $scriptDir 'login-seesales.ps1'

$labOrder = @('wheatridge', 'dayton', 'orlando', 'scott', 'houston')
$labMap = @{
    wheatridge = @{ Host = 'use-idb057'; Invoice = 'i'; Tile = 0 }
    dayton     = @{ Host = 'use-idb059'; Invoice = 'i'; Tile = 1 }
    orlando    = @{ Host = 'use-idb066'; Invoice = 'i'; Tile = 2 }
    scott      = @{ Host = 'use-idb062'; Invoice = 'I'; Tile = 3 }
    houston    = @{ Host = 'use-idb064'; Invoice = 'I'; Tile = 4 }
}
$retile = Join-Path $scriptDir 'retile-anita-windows.ps1'

$names = New-Object System.Collections.Generic.List[string]
if ($Lab.Trim().ToLowerInvariant() -eq 'all') {
    foreach ($n in $labOrder) { $names.Add($n) }
} else {
    foreach ($token in ($Lab.Split(',') | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ })) {
        if (-not $labMap.ContainsKey($token)) {
            throw "Unknown lab $token. Use wheatridge, dayton, orlando, scott, houston, or all."
        }
        if (-not $names.Contains($token)) { $names.Add($token) }
    }
}

$auditRun = Join-Path $env:TEMP ("seesales-login-audit/{0:yyyyMMdd-HHmmss}" -f (Get-Date))
New-Item -ItemType Directory -Force -Path $auditRun | Out-Null
Write-Output "LOGIN_AUDIT_RUN=$auditRun"
if ($KeepAllWindowsOpen) {
    Write-Output "LOGIN_STABILITY mode=serial-accumulate (one login at a time; AniTa stays open on SEE SALES)"
    if ($Passes -gt 1) {
        Write-Output "LOGIN_STABILITY warn=Passes>1 with -KeepAllWindowsOpen re-logins on existing windows on pass 2+"
    }
}
Write-Output "LOGIN_STABILITY labs=$($names -join ',') passes=$Passes keepWindows=$KeepAllWindowsOpen"
$results = @()
$accumulateStarted = $false
foreach ($loc in $names) {
    $info = $labMap[$loc]
    for ($p = 1; $p -le $Passes; $p++) {
        $t0 = Get-Date
        Write-Output "--- $loc pass $p/$Passes host=$($info.Host) ---"
        $attemptAudit = Join-Path $auditRun ("{0}-pass{1}" -f $loc, $p)
        [Environment]::SetEnvironmentVariable('ANITA_LOGIN_AUDIT_DIR', $attemptAudit, 'Process')
        $logLines = @()
        $status = 'unknown'
        $msg = ''
        try {
            $logLines = [System.Collections.Generic.List[string]]::new()
            $loginParams = @{
                HostName    = $info.Host
                Label       = $loc
                InvoiceKey  = $info.Invoice
            }
            if ($KeepAllWindowsOpen) {
                $loginParams['TileIndex'] = $info.Tile
                $loginParams['ShowWindowForTile'] = $true
                if ($accumulateStarted -or $p -gt 1) {
                    $loginParams['KeepOtherAnita'] = $true
                }
                if ($p -gt 1) {
                    $loginParams['SkipLaunch'] = $true
                }
            }
            & $login @loginParams *>&1 | ForEach-Object {
                $line = "$_"
                [void]$logLines.Add($line)
                Write-Output $line
            }
            $statusLine = $logLines | Select-String -Pattern '^LOGIN_STATUS=' | Select-Object -Last 1
            if ($statusLine -match 'LOGIN_STATUS=success') {
                $status = 'success'
            } elseif ($statusLine -match 'LOGIN_STATUS=fail') {
                $status = 'fail'
                if ($statusLine -match 'reason=(.+)$') { $msg = $Matches[1] }
            } else {
                throw "login-seesales did not emit LOGIN_STATUS (host=$($info.Host))"
            }
            if ($status -ne 'success') {
                throw $(if ($msg) { $msg } else { 'LOGIN_STATUS=fail' })
            }
            $ms = [int]((Get-Date) - $t0).TotalMilliseconds
            Write-Output "LOGIN_RESULT status=success lab=$loc pass=$p host=$($info.Host) ms=$ms"
            $results += [pscustomobject]@{ Lab = $loc; Pass = $p; Status = 'success'; Ok = $true; Ms = $ms; Error = '' }
            if ($KeepAllWindowsOpen) {
                $accumulateStarted = $true
                $n = @(Get-Process Anita -ErrorAction SilentlyContinue).Count
                Write-Output "LOGIN_ACCUMULATE anita_count=$n after=$loc"
                if (Test-Path $retile) { & $retile 2>&1 | Out-Null }
            }
        } catch {
            $ms = [int]((Get-Date) - $t0).TotalMilliseconds
            if (-not $msg) { $msg = $_.Exception.Message }
            if ($status -eq 'unknown') {
                $statusLine = $logLines | Select-String -Pattern '^LOGIN_STATUS=fail' | Select-Object -Last 1
                if ($statusLine -match 'reason=(.+)$') { $msg = $Matches[1] }
                $status = 'fail'
            }
            Write-Output "LOGIN_RESULT status=fail lab=$loc pass=$p host=$($info.Host) ms=$ms reason=$msg"
            $logLines | Select-String -Pattern '^(LIMS_SNAP|LIMS_AUDIT|LIMS_PHASE|LIMS_CONN|LIMS_WARN|LIMS_ACTION|LIMS_WAIT)=' |
                Select-Object -Last 16 |
                ForEach-Object { Write-Output "LIMS_FAIL_TAIL $($_.Line)" }
            $results += [pscustomobject]@{ Lab = $loc; Pass = $p; Status = 'fail'; Ok = $false; Ms = $ms; Error = $msg }
        }
        if (-not $KeepAllWindowsOpen) {
            Get-Process Anita -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 8
        } else {
            Start-Sleep -Seconds 3
        }
    }
}
if ($KeepAllWindowsOpen) {
    $n = @(Get-Process Anita -ErrorAction SilentlyContinue).Count
    Write-Output "LOGIN_ACCUMULATE final_anita_count=$n (windows left open)"
    Get-Process Anita -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Output "LOGIN_ACCUMULATE pid=$($_.Id) title=$($_.MainWindowTitle)"
    }
}

Write-Output ''
Write-Output 'SUMMARY'
$results | Format-Table -AutoSize
$fail = @($results | Where-Object { -not $_.Ok })
if ($fail.Count -gt 0) {
    throw "Login stability: $($fail.Count) failure(s) of $($results.Count) attempts."
}
Write-Output "Login stability: $($results.Count)/$($results.Count) OK."
$summaryPath = Join-Path $env:TEMP 'seesales-login-summary.json'
$results | ConvertTo-Json -Compress | Set-Content -LiteralPath $summaryPath -Encoding UTF8
Write-Output "SUMMARY_JSON $summaryPath"

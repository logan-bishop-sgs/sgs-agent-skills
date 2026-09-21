# Hands-off SEE SALES by-group extract. Lab + month range. No AI watching.
# One lab, a comma list, or -Lab all (sequential; each host is its own login).
#
#   powershell -File run-seesales-extract.ps1 -Lab orlando -ThisMonth
#   powershell -File run-seesales-extract.ps1 -Lab houston,scott -ThisMonth
#   powershell -File run-seesales-extract.ps1 -Lab all -ThisMonth
#   powershell -File run-seesales-extract.ps1 -Lab all -From 2026-01 -To 2026-09
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Lab,
    [string]$From,
    [string]$To,
    [switch]$Ytd,
    [switch]$ThisMonth,
    [string]$OnMonth,
    [string]$Groups,
    [switch]$ExpandHistory,
    [int]$ExportWaitSeconds = 25,
    [switch]$SkipSharePoint,
    [switch]$StampOutlook,
    [int]$Retries = 3,
    [int]$MaxReviveRounds = 48,
    [switch]$KeepAllWindowsOpen,
    [switch]$ParallelLaunch,
    [int]$ConnectWaitSeconds = 90,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir 'anita-llm-assist.ps1')
Set-AnitaLlmEscalation $false
$login = Join-Path $scriptDir 'login-seesales.ps1'
$export = Join-Path $scriptDir 'export-seesales-groups.ps1'
$launch = Join-Path $scriptDir 'launch-anita-hidden.ps1'
$retile = Join-Path $scriptDir 'retile-anita-windows.ps1'

$labOrder = @('wheatridge', 'dayton', 'orlando', 'scott', 'houston')
$labMap = @{
    wheatridge = @{ Host = 'use-idb057'; Invoice = 'i'; Tile = 0; Groups = 'MET,GEN,MSS,MSU,GCS,SUB,MISC,GCU,FLD' }
    dayton     = @{ Host = 'use-idb059'; Invoice = 'i'; Tile = 1; Groups = 'GEN,GCS,MSU,LCMS,MSS,MET,MSA,MISC,SUB,GCU' }
    orlando    = @{ Host = 'use-idb066'; Invoice = 'i'; Tile = 2; Groups = 'LCMS,MSU,MSS,GCU,GCS,MET,GEN,MISC,SUB,FLD' }
    scott      = @{ Host = 'use-idb062'; Invoice = 'I'; Tile = 3; Groups = 'MSS,MSU,GEN,MET,GCS,MISC,GCU,LCMS,SUB' }
    houston    = @{ Host = 'use-idb064'; Invoice = 'I'; Tile = 4; Groups = 'MSA,MSU,MISC,GEN,GCA' }
}
$aliases = @{
    wheat = 'wheatridge'; wr = 'wheatridge'; ridge = 'wheatridge'; co = 'wheatridge'
    '057' = 'wheatridge'; '57' = 'wheatridge'; 'use-idb057' = 'wheatridge'
    nj = 'dayton'; '059' = 'dayton'; '59' = 'dayton'; 'use-idb059' = 'dayton'
    fla = 'orlando'; fl = 'orlando'
    '066' = 'orlando'; '66' = 'orlando'; 'use-idb066' = 'orlando'
    la = 'scott'; scott62 = 'scott'
    '062' = 'scott'; '62' = 'scott'; 'use-idb062' = 'scott'
    tx = 'houston'; scott64 = 'houston'
    '064' = 'houston'; '64' = 'houston'; 'use-idb064' = 'houston'
}

function Resolve-LabName([string]$raw) {
    $key = $raw.Trim().ToLowerInvariant()
    if ($aliases.ContainsKey($key)) { $key = $aliases[$key] }
    if (-not $labMap.ContainsKey($key)) {
        throw "Lab must be wheatridge, dayton, orlando, scott, houston, a host number, a comma list, or all. Got $raw"
    }
    return $key
}

$tokens = @($Lab.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
if ($tokens.Count -lt 1) { throw 'Pass -Lab (one name, a comma list, or all).' }
$resolved = New-Object System.Collections.Generic.List[string]
foreach ($token in $tokens) {
    $key = $token.Trim().ToLowerInvariant()
    if ($key -eq 'all' -or $key -eq '*') {
        foreach ($name in $labOrder) {
            if (-not $resolved.Contains($name)) { $resolved.Add($name) }
        }
        continue
    }
    $name = Resolve-LabName $token
    if (-not $resolved.Contains($name)) { $resolved.Add($name) }
}
if ($Groups -and $resolved.Count -gt 1) {
    throw '-Groups is per-lab walk order. Use it with one -Lab, not all / a list.'
}

$hasRange = [bool]($Ytd -or $ThisMonth -or $From -or $To)
if (-not $hasRange) { $ThisMonth = $true }

function New-ExportArgs([string]$loc, [string]$groupArg, [string]$hostName, [switch]$DryRun) {
    $splat = @{
        Location  = $loc
        Groups    = $groupArg
        HostTitle = $hostName
    }
    if ($DryRun) { $splat.WhatIf = $true }
    else { $splat.ExportWaitSeconds = $ExportWaitSeconds }
    if ($Ytd) { $splat.Ytd = $true }
    elseif ($ThisMonth) { $splat.ThisMonth = $true }
    else {
        if ($From) { $splat.From = $From }
        if ($To) { $splat.To = $To }
    }
    if ($OnMonth) { $splat.OnMonth = $OnMonth }
    if (-not $DryRun -and $SkipSharePoint) { $splat.SkipSharePoint = $true }
    if (-not $DryRun -and $StampOutlook) { $splat.StampOutlook = $true }
    return $splat
}

Write-Output ("PLAN labs=" + ($resolved -join ','))

if ($WhatIf) {
    foreach ($loc in $resolved) {
        $cfg = $labMap[$loc]
        $groupArg = if ($Groups) { $Groups } else { $cfg.Groups }
        Write-Output "PLAN lab=$loc host=$($cfg.Host) groups=$groupArg invoice=$($cfg.Invoice)"
        $exportArgs = New-ExportArgs $loc $groupArg $cfg.Host -DryRun
        & $export @exportArgs
    }
    return
}

function Stop-LabHost([string]$hostName) {
    Get-Process Anita -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowTitle -match [regex]::Escape($hostName) } |
        Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

function Stop-DisconnectedAnita {
    Get-Process Anita -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowTitle -match 'Disconnected' } |
        Stop-Process -Force -ErrorAction SilentlyContinue
}

function Get-AnitaTitle([string]$hostNeedle) {
    $matches = @(Get-Process Anita -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowTitle -match [regex]::Escape($hostNeedle) })
    if (-not $matches.Count) { return '' }
    $live = @($matches | Where-Object { $_.MainWindowTitle -notmatch 'Disconnected' })
    $p = if ($live.Count) { $live[0] } else { $matches[0] }
    return $p.MainWindowTitle
}

function Test-LabSessionReady([string]$hostName) {
    $t = Get-AnitaTitle $hostName
    return ($t -and $t -notmatch 'Disconnected|Connecting')
}

function Wait-AllAnitaConnected([string[]]$hosts, [int]$seconds) {
    $deadline = (Get-Date).AddSeconds($seconds)
    do {
        $states = @()
        $allOk = $true
        foreach ($h in $hosts) {
            $t = Get-AnitaTitle $h
            $states += "$h=$t"
            if (-not $t -or $t -match 'Disconnected|Connecting') { $allOk = $false }
        }
        Write-Output ("MULTI_CONN " + ($states -join ' | '))
        if ($allOk) { return $true }
        Start-Sleep -Seconds 3
    } while ((Get-Date) -lt $deadline)
    return $false
}

function Invoke-LabLogin([string]$loc, [switch]$KeepOthers, [switch]$SkipLaunch) {
    $cfg = $labMap[$loc]
    $hostName = $cfg.Host
    Write-Output "LOGIN lab=$loc host=$hostName keepOthers=$KeepOthers skipLaunch=$SkipLaunch"
    $loginParams = @{
        HostName   = $hostName
        Label      = $loc
        InvoiceKey = $cfg.Invoice
    }
    if ($KeepAllWindowsOpen) {
        $loginParams['TileIndex'] = $cfg.Tile
        $loginParams['ShowWindowForTile'] = $true
        if ($KeepOthers) { $loginParams['KeepOtherAnita'] = $true }
        if ($SkipLaunch) { $loginParams['SkipLaunch'] = $true }
    }
    $loginOut = @(& $login @loginParams 2>&1)
    $loginOut | ForEach-Object { Write-Output $_ }
    $loginText = ($loginOut | ForEach-Object { "$_" }) -join "`n"
    if ($loginText -notmatch 'LOGIN_STATUS=success') {
        $failLine = ($loginOut | Select-String 'LOGIN_STATUS=fail' | Select-Object -Last 1)
        throw "login-seesales failed for $loc. $failLine"
    }
    if ($KeepAllWindowsOpen -and (Test-Path $retile)) {
        & $retile 2>&1 | Out-Null
    }
}

function Invoke-LabExport([string]$loc) {
    $cfg = $labMap[$loc]
    $groupArg = if ($Groups) { $Groups } else { $cfg.Groups }
    $hostName = $cfg.Host
    [Environment]::SetEnvironmentVariable('ANITA_CAPTURE_LABEL', $loc, 'Process')
    Write-Output "EXPORT lab=$loc host=$hostName groups=$groupArg"
    if ($ExpandHistory) {
        Write-Output "SKIP F11 for $loc (company-wide dumps the session)"
    }
    $exportArgs = New-ExportArgs $loc $groupArg $hostName
    & $export @exportArgs
    if ($LASTEXITCODE -ne 0) { throw "export-seesales-groups failed for $loc" }
    Write-Output "DONE lab=$loc"
}

function Invoke-MultiWindowLogin([string[]]$labs) {
    if ($ParallelLaunch) {
        Write-Output 'MULTI_LOGIN_WARN ParallelLaunch is ignored: unauthenticated AniTa connects time out while another host is logging in. Launch+login one host at a time.'
    }
    Write-Output ("MULTI_LOGIN mode=sequential-launch labs=" + ($labs -join ','))
    Stop-DisconnectedAnita
    $loginFailed = New-Object System.Collections.Generic.List[string]
    foreach ($loc in $labs) {
        $hostName = $labMap[$loc].Host
        if (Test-LabSessionReady $hostName) {
            Write-Output "MULTI_SKIP_LOGIN lab=$loc title=$(Get-AnitaTitle $hostName)"
            continue
        }
        Stop-LabHost $hostName
        $keepOthers = @(Get-Process Anita -ErrorAction SilentlyContinue).Count -gt 0
        try {
            Invoke-LabLogin $loc -KeepOthers:$keepOthers
        } catch {
            Write-Output "MULTI_LOGIN_FAIL lab=$loc $($_.Exception.Message)"
            $loginFailed.Add($loc)
        }
        $cnt = @(Get-Process Anita -ErrorAction SilentlyContinue).Count
        Write-Output "MULTI_ACCUMULATE after=$loc anita_count=$cnt"
    }
    if ($loginFailed.Count -gt 0) {
        throw "Multi-window login failed for: $($loginFailed -join ',')"
    }
}

function Invoke-LabPull([string]$loc) {
    $cfg = $labMap[$loc]
    $groupArg = if ($Groups) { $Groups } else { $cfg.Groups }
    $hostName = $cfg.Host
    Write-Output "PLAN lab=$loc host=$hostName groups=$groupArg invoice=$($cfg.Invoice)"
    if (-not $KeepAllWindowsOpen) {
        Stop-LabHost $hostName
        Invoke-LabLogin $loc
        Invoke-LabExport $loc
        return
    }
    $title = Get-AnitaTitle $hostName
    if (-not $title -or $title -match 'Disconnected|Connecting') {
        Invoke-LabLogin $loc -KeepOthers
    }
    Invoke-LabExport $loc
}

function Invoke-LabFailureRecover {
    param(
        [Parameter(Mandatory = $true)][string]$Loc,
        [Parameter(Mandatory = $true)][int]$FailStreak
    )
    $hostName = $labMap[$Loc].Host
    if ($FailStreak -lt 2) {
        Set-AnitaLlmEscalation $false
        Write-Output "RETRY_TIER=1_shutdown-anita lab=$Loc streak=$FailStreak"
        Stop-LabHost $hostName
    } else {
        Set-AnitaLlmEscalation $true
        Write-Output "RETRY_TIER=2_azure-openai lab=$Loc streak=$FailStreak"
        if (-not (Test-LabSessionReady $hostName)) {
            Write-Output "RETRY_TIER=2 relaunch (session dead) lab=$Loc"
            Stop-LabHost $hostName
        }
    }
    $keepOthers = $KeepAllWindowsOpen -and @(Get-Process Anita -ErrorAction SilentlyContinue).Count -gt 0
    Invoke-LabLogin $Loc -KeepOthers:$keepOthers
    Invoke-LabExport $Loc
}

if ($Retries -lt 1) { $Retries = 1 }
$pending = New-Object System.Collections.Generic.List[string]
foreach ($loc in $resolved) { $pending.Add($loc) }
$failed = New-Object System.Collections.Generic.List[string]
$failureBudget = $Retries
$labFailStreak = @{}
$reviveRound = 0
while ($pending.Count -gt 0 -and $reviveRound -lt $MaxReviveRounds) {
    $reviveRound++
    $batch = @($pending)
    $pending.Clear()
    Write-Output "REVIVE round=$reviveRound failureBudget=$failureBudget labs=$($batch -join ',') keepWindows=$KeepAllWindowsOpen parallelLaunch=$ParallelLaunch"
    if ($KeepAllWindowsOpen) {
        try {
            Invoke-MultiWindowLogin $batch
        } catch {
            Write-Output "MULTI_LOGIN_BATCH_FAIL round=$reviveRound $($_.Exception.Message)"
            foreach ($loc in $batch) {
                if (-not (Test-LabSessionReady $labMap[$loc].Host)) { $pending.Add($loc) }
            }
            if ($pending.Count -eq $batch.Count) { continue }
        }
    }
    foreach ($loc in $batch) {
        Set-AnitaLlmEscalation $false
        $labOk = $false
        try {
            if ($KeepAllWindowsOpen) {
                Invoke-LabExport $loc
            } else {
                Invoke-LabPull $loc
            }
            $labOk = $true
        } catch {
            if (-not $labFailStreak.ContainsKey($loc)) { $labFailStreak[$loc] = 0 }
            $labFailStreak[$loc]++
            $streak = $labFailStreak[$loc]
            Write-Output "FAIL lab=$loc round=$reviveRound streak=$streak budget=$failureBudget $($_.Exception.Message)"
            if ($failureBudget -gt 0) {
                $failureBudget--
                Write-Output "RETRY lab=$loc budget_remaining=$failureBudget"
                try {
                    Invoke-LabFailureRecover -Loc $loc -FailStreak $streak
                    $labOk = $true
                } catch {
                    Write-Output "RETRY_RECOVER_FAIL lab=$loc $($_.Exception.Message)"
                }
            } else {
                Write-Output "RETRY_EXHAUSTED lab=$loc (failure budget 0)"
            }
        }
        if ($labOk) {
            $failureBudget = $Retries
            $labFailStreak[$loc] = 0
            Set-AnitaLlmEscalation $false
            Write-Output "RETRY_BUDGET_RESET lab=$loc budget=$failureBudget after success"
        } else {
            if ($failureBudget -le 0) {
                $failed.Add($loc)
            } else {
                $pending.Add($loc)
            }
        }
    }
}
foreach ($loc in $pending) {
    if (-not $failed.Contains($loc)) { $failed.Add($loc) }
}

$fileInbox = Join-Path $scriptDir 'file-seesales-inbox.ps1'
if (Test-Path $fileInbox) {
    Write-Output 'FILE Inbox SeeSales mail out of Inbox'
    try {
        & $fileInbox -SkipRules
    } catch {
        Write-Output "WARN file-seesales-inbox: $($_.Exception.Message)"
    }
}

if ($failed.Count -gt 0) {
    throw "Failed labs: $($failed -join ',')"
}
Write-Output ("DONE labs=" + ($resolved -join ','))

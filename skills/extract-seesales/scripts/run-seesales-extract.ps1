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
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$login = Join-Path $scriptDir 'login-seesales.ps1'
$export = Join-Path $scriptDir 'export-seesales-groups.ps1'

$labOrder = @('wheatridge', 'dayton', 'orlando', 'scott', 'houston')
$labMap = @{
    wheatridge = @{ Host = 'use-idb057'; Invoice = 'i'; Groups = 'MET,GEN,MSS,MSU,GCS,SUB,MISC,GCU,FLD' }
    dayton     = @{ Host = 'use-idb059'; Invoice = 'i'; Groups = 'GEN,GCS,MSU,LCMS,MSS,MET,MSA,MISC,SUB,GCU' }
    orlando    = @{ Host = 'use-idb066'; Invoice = 'i'; Groups = 'LCMS,MSU,MSS,GCU,GCS,MET,GEN,MISC,SUB,FLD' }
    scott      = @{ Host = 'use-idb062'; Invoice = 'I'; Groups = 'MSS,MSU,GEN,MET,GCS,MISC,GCU,LCMS,SUB' }
    houston    = @{ Host = 'use-idb064'; Invoice = 'I'; Groups = 'MSA,MSU,MISC,GEN,GCA' }
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

function Invoke-LabPull([string]$loc) {
    $cfg = $labMap[$loc]
    $groupArg = if ($Groups) { $Groups } else { $cfg.Groups }
    $hostName = $cfg.Host
    Write-Output "PLAN lab=$loc host=$hostName groups=$groupArg invoice=$($cfg.Invoice)"
    Stop-LabHost $hostName
    & $login -HostName $hostName -Label $loc -InvoiceKey $cfg.Invoice
    if ($LASTEXITCODE -ne 0) { throw "login-seesales failed for $loc" }
    if ($ExpandHistory) {
        Write-Output "SKIP F11 for $loc (company-wide dumps the session)"
    }
    $exportArgs = New-ExportArgs $loc $groupArg $hostName
    & $export @exportArgs
    if ($LASTEXITCODE -ne 0) { throw "export-seesales-groups failed for $loc" }
    Write-Output "DONE lab=$loc"
}

if ($Retries -lt 1) { $Retries = 1 }
$pending = New-Object System.Collections.Generic.List[string]
foreach ($loc in $resolved) { $pending.Add($loc) }
$failed = New-Object System.Collections.Generic.List[string]
$attempt = 0
while ($pending.Count -gt 0 -and $attempt -lt $Retries) {
    $attempt++
    $batch = @($pending)
    $pending.Clear()
    Write-Output "REVIVE attempt=$attempt of $Retries labs=$($batch -join ',')"
    foreach ($loc in $batch) {
        try {
            Invoke-LabPull $loc
        } catch {
            Write-Output "RETRY lab=$loc attempt=$attempt $($_.Exception.Message)"
            Stop-LabHost $labMap[$loc].Host
            $pending.Add($loc)
        }
    }
}
foreach ($loc in $pending) { $failed.Add($loc) }

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

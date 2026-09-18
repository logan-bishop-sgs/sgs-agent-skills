# Export SEE SALES by group at the PRODUCT breakout (not group totals).
# For each service group: Page Down (products) -> Export -> Page Up -> next group.
# Prerequisite: AniTa is on SEE SALES, cursor on Month (not F11).
# -Count is groups per month (form "1 of M", usually 4-12 by location).
# Files land as seesales-seegroupprod-loganb_*.xls.
[CmdletBinding()]
param(
    [int]$Count,
    [string]$Location,
    [string]$Groups = 'MET,GEN,MSS,MSU,GCS,SUB,MISC,GCU,FLD',
    [string]$From,
    [string]$To,
    [switch]$Ytd,
    [switch]$ThisMonth,
    [string]$OnMonth,
    [switch]$AlreadyOnGroups,
    [int]$ExportWaitSeconds = 25,
    [int]$AfterDownMs = 2000,
    [switch]$StampOutlook,
    [switch]$SkipSharePoint,
    [string]$HostTitle,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir '..\..\..\..')).Path
$cap = Join-Path $env:LOCALAPPDATA 'Temp\anita-capture'
New-Item -ItemType Directory -Force -Path $cap | Out-Null

function Import-RepoEnv([string]$path) {
    if (-not (Test-Path $path)) { return }
    Get-Content -LiteralPath $path | ForEach-Object {
        $line = $_.Trim()
        if (-not $line -or $line.StartsWith('#')) { return }
        $eq = $line.IndexOf('=')
        if ($eq -lt 1) { return }
        $k = $line.Substring(0, $eq).Trim()
        $v = $line.Substring($eq + 1).Trim().Trim('"').Trim("'")
        if (-not [Environment]::GetEnvironmentVariable($k, 'Process')) {
            [Environment]::SetEnvironmentVariable($k, $v, 'Process')
        }
    }
}
Import-RepoEnv (Join-Path $repoRoot '.env')

$groupList = @($Groups.Split(',') | ForEach-Object { $_.Trim().ToUpperInvariant() } | Where-Object { $_ })
if ($groupList.Count -lt 1) { throw 'Pass -Groups as comma codes in walk order (e.g. MET,GEN,MSS).' }
if (-not $Count) { $Count = $groupList.Count }
if ($Count -ne $groupList.Count) {
    throw "Count $Count does not match Groups ($($groupList.Count)): $($groupList -join ',')"
}
if ($Count -gt 20) { throw "Count $Count looks too high (expected 4-12)." }
$locAliases = @{
    wheatridge = 'wheatridge'; wheat = 'wheatridge'; wr = 'wheatridge'; ridge = 'wheatridge'; co = 'wheatridge'
    dayton = 'dayton'; nj = 'dayton'
    orlando = 'orlando'; fla = 'orlando'; fl = 'orlando'
    scott = 'scott'; la = 'scott'; scott62 = 'scott'
    houston = 'houston'; tx = 'houston'; scott64 = 'houston'
    nam = 'nam'
}
$locRaw = if ($Location) { $Location.Trim().ToLowerInvariant() } else { '' }
if ($locRaw -and $locAliases.ContainsKey($locRaw)) { $locRaw = $locAliases[$locRaw] }
if ($locRaw -and $locRaw -notmatch '^[a-z0-9]{2,16}$') {
    throw "Location must be a lab name (wheatridge/dayton/orlando/scott/houston) or LIMS code. Got $Location"
}
$loc = $locRaw
if (-not $HostTitle -and $loc) {
    $hostByLoc = @{
        wheatridge = 'use-idb057'; dayton = 'use-idb059'; orlando = 'use-idb066'
        scott = 'use-idb062'; houston = 'use-idb064'
    }
    if ($hostByLoc.ContainsKey($loc)) { $HostTitle = $hostByLoc[$loc] }
}
if ($HostTitle) { Write-Output "HOST $HostTitle" }

function Parse-YearMonth([string]$value, [string]$name) {
    if (-not $value) { throw "$name is required (YYYY-MM), or use -Ytd / -ThisMonth." }
    if ($value -notmatch '^(20\d{2})-(0[1-9]|1[0-2])$') {
        throw "$name must be YYYY-MM (got '$value')."
    }
    return Get-Date -Year ([int]$Matches[1]) -Month ([int]$Matches[2]) -Day 1
}

$now = Get-Date
$hasRange = [bool]($Ytd -or $ThisMonth -or $From -or $To)
$months = New-Object System.Collections.Generic.List[datetime]
if (-not $hasRange) {
    $onDate = if ($OnMonth) { Parse-YearMonth $OnMonth 'OnMonth' } else { Get-Date -Year $now.Year -Month $now.Month -Day 1 }
    $fromDate = $onDate
    $toDate = $onDate
    $months.Add($onDate)
    $navSteps = 0
    Write-Output "PLAN current form month only location=$loc groups=$($groupList -join ',') files=$Count"
} else {
    if ($Ytd) {
        $fromDate = Get-Date -Year $now.Year -Month 1 -Day 1
        $toDate = Get-Date -Year $now.Year -Month $now.Month -Day 1
    } elseif ($ThisMonth) {
        $fromDate = Get-Date -Year $now.Year -Month $now.Month -Day 1
        $toDate = $fromDate
    } else {
        $fromDate = Parse-YearMonth $From 'From'
        $toDate = Parse-YearMonth $To 'To'
    }
    if ($fromDate -gt $toDate) { throw "From $($fromDate.ToString('yyyy-MM')) is after To $($toDate.ToString('yyyy-MM'))." }
    $onDate = if ($OnMonth) { Parse-YearMonth $OnMonth 'OnMonth' } else { Get-Date -Year $now.Year -Month $now.Month -Day 1 }
    $cursor = $toDate
    while ($cursor -ge $fromDate) {
        $months.Add($cursor)
        $cursor = $cursor.AddMonths(-1)
    }
    function MonthIndex([datetime]$d) { return ($d.Year * 12) + $d.Month }
    $navSteps = (MonthIndex $onDate) - (MonthIndex $toDate)
    Write-Output "PLAN months=$($months.Count) from=$($fromDate.ToString('yyyy-MM')) to=$($toDate.ToString('yyyy-MM')) on=$($onDate.ToString('yyyy-MM')) navSteps=$navSteps location=$loc groups=$($groupList -join ',') files=$($Count * $months.Count)"
    Write-Output (("months " + (($months | ForEach-Object { $_.ToString('yyyy-MM') }) -join ', ')))
}
$fileExpect = $Count * $months.Count
if ($WhatIf) { return }

$ledger = Join-Path $cap ("seegroup-ledger-{0:yyyyMMddHHmmss}.jsonl" -f (Get-Date).ToUniversalTime())
$runStartUtc = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
Write-Output "LEDGER $ledger"

function Ensure-AnitaBg {
    $exe = Join-Path $cap 'anita-bg.exe'
    $src = Join-Path $scriptDir 'anita-bg.cs'
    $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
    if (-not (Test-Path $csc)) { throw "csc.exe not found at $csc" }
    $needBuild = -not (Test-Path $exe) -or ((Get-Item $src).LastWriteTimeUtc -gt (Get-Item $exe).LastWriteTimeUtc)
    if ($needBuild) {
        & $csc /nologo /target:exe /out:$exe /r:System.Drawing.dll $src
        if ($LASTEXITCODE -ne 0) { throw 'Failed to compile anita-bg.exe' }
    }
    return $exe
}

function Invoke-Anita([string]$exe) {
    $argList = @($args)
    if ($HostTitle) { $argList += $HostTitle }
    $out = & $exe @argList 2>&1 | ForEach-Object { "$_" }
    $out | ForEach-Object { Write-Output $_ }
    return @{ Code = $LASTEXITCODE; Text = ($out -join "`n") }
}

$bg = Ensure-AnitaBg
$st = Invoke-Anita $bg 'status'
if ($st.Text -match 'no AniTa') { throw 'AniTa is not running. Open SEE SALES first, then rerun.' }
if ($st.Text -match 'Disconnected' -or $st.Code -eq 4) { throw 'AniTa title is Disconnected. Relogin, open SEE SALES, then rerun.' }

$reader = Join-Path $scriptDir 'read-anita-screen.py'
$python = 'C:\Program Files\Python311\python.exe'
function Read-Snap([string]$name) {
    [void](Invoke-Anita $bg 'snap' $name)
    $line = 'CLASS=unknown KEYS=-'
    if (Test-Path $python) {
        $line = (& $python $reader $name 2>$null | Select-Object -Last 1)
        if (-not $line) { $line = 'CLASS=empty KEYS=-' }
    }
    Write-Output "SCREEN $name $line"
    return $line
}
function Assert-Healthy([string]$line, [string]$where) {
    $stat = Invoke-Anita $bg 'status'
    if ($stat.Text -match 'Disconnected') { throw "AniTa disconnected ($where). Stop. Relogin." }
    if ($line -match 'invaliduser') {
        throw "Session is on login ($where). Relogin. Do not keep exporting."
    }
    if ($line -match 'iforms' -and $line -notmatch 'seesales|done') {
        throw "Session is on login ($where). Relogin. Do not keep exporting."
    }
    if ($line -match 'companywide') {
        throw "Company-wide screen ($where). Stop. Relogin without F11."
    }
}

function Send-DownOrUp([int]$n) {
    if ($n -eq 0) { return }
    $vk = if ($n -gt 0) { 40 } else { 38 }
    $abs = [Math]::Abs($n)
    for ($i = 0; $i -lt $abs; $i++) {
        [void](Invoke-Anita $bg 'key' "$vk")
        Start-Sleep -Milliseconds $AfterDownMs
    }
}

function Open-GroupView {
    $tries = @(
        { Write-Output 'F7 service Group'; [void](Invoke-Anita $bg 'key' '118'); Start-Sleep -Seconds 4 },
        { Write-Output 'NAVIGATE 1,2 then service Group (g)'; [void](Invoke-Anita $bg 'host' '\x1b}s1,2\r'); Start-Sleep -Seconds 2; [void](Invoke-Anita $bg 'type' 'g'); Start-Sleep -Seconds 3 },
        { Write-Output 'NAVIGATE 1,3 then g'; [void](Invoke-Anita $bg 'host' '\x1b}s1,3\r'); Start-Sleep -Seconds 2; [void](Invoke-Anita $bg 'type' 'g'); Start-Sleep -Seconds 3 }
    )
    $n = 0
    foreach ($step in $tries) {
        $n++
        & $step
        $line = Read-Snap "groups-open-$n.png"
        Assert-Healthy $line "open groups try $n"
        if ($line -match 'accountview') {
            Write-Output 'WARN landed in accounts; Esc back'
            [void](Invoke-Anita $bg 'key' '27')
            Start-Sleep -Seconds 2
            continue
        }
        if ($line -match 'groups') {
            Write-Output "GROUP_VIEW try=$n $line"
            return
        }
        Write-Output "WARN still on month list after open try $n ($line)"
    }
    throw 'Never reached service Group (still on the month list). Relogin and open Group the way Logan does.'
}

function Return-SeeSales {
    Write-Output 'NAVIGATE 1,2 then See sales (s)'
    [void](Invoke-Anita $bg 'host' '\x1b}s1,2\r')
    Start-Sleep -Seconds 2
    [void](Invoke-Anita $bg 'type' 's')
    Start-Sleep -Seconds 3
}

function Export-Groups([string]$label) {
    for ($i = 1; $i -le $Count; $i++) {
        Write-Output "PAGEDOWN $label group $i / $Count (product breakout)"
        [void](Invoke-Anita $bg 'key' '34')
        Start-Sleep -Seconds 3
        $before = Read-Snap "groups-$label-$i-prod.png"
        Assert-Healthy $before "$label group $i before Export"
        if ($before -match 'accountview') {
            throw "Page Down opened accounts ($label group $i). Need service Group first."
        }
        Write-Output "EXPORT $label group $i / $Count"
        $sent = Invoke-Anita $bg 'host' '\x1b}s2,20\r'
        if ($sent.Code -ne 0) { throw "Export send failed for $label group $i" }
        $deadline = (Get-Date).AddSeconds($ExportWaitSeconds)
        $poll = 0
        $snapName = "groups-$label-$i.png"
        $sawDone = $false
        do {
            Start-Sleep -Seconds 4
            $poll++
            $snapName = "groups-$label-$i-$poll.png"
            $line = Read-Snap $snapName
            Assert-Healthy $line "$label group $i export wait"
            Write-Output "  wait $label group=$i poll=$poll snap=$snapName"
            if ($line -match 'done') { $sawDone = $true; break }
        } while ((Get-Date) -lt $deadline)
        Write-Output "WAITED $label group=$i ${ExportWaitSeconds}s (confirm snap $snapName / SharePoint)"
        $gcode = $groupList[$i - 1]
        if ($StampOutlook) {
            if (-not $loc) { throw '-StampOutlook requires -Location' }
            $stampScript = Join-Path $scriptDir 'stamp-seegroup-outlook.ps1'
            & $stampScript -Location $loc -Group $gcode -Month $label -After (Get-Date).AddMinutes(-10) -WaitSeconds 90
            if ($LASTEXITCODE -ne 0) {
                throw "No SEEGROUPPROD mail after $label group $i ($gcode). Snap $snapName. Stop."
            }
        } elseif (-not $sawDone) {
            throw "No DONE on snap after $label group $i. Snap $snapName. Stop. Do not keep walking."
        }
        $row = @{ seq = $i; month = $label; location = $loc; group = $gcode; exportedAtUtc = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ') } | ConvertTo-Json -Compress
        Add-Content -LiteralPath $ledger -Value $row
        Write-Output "PAGEUP $label group $i (back to group list)"
        [void](Invoke-Anita $bg 'key' '33')
        Start-Sleep -Milliseconds $AfterDownMs
        if ($i -lt $Count) {
            Send-DownOrUp 1
        }
    }
}

if ($AlreadyOnGroups -and $navSteps -ne 0) {
    throw 'Cannot use -AlreadyOnGroups when the form month is not -To. Return to the month list or pass -OnMonth.'
}

if (-not $AlreadyOnGroups) {
    $beforeNav = Read-Snap 'groups-before-nav.png'
    Assert-Healthy $beforeNav 'before month walk'
    if ($navSteps -ne 0 -and $beforeNav -match 'oneofone') {
        Write-Output "WARN form opened 1 of 1; Down-arrow still walks older months (count grows)."
    }
    Write-Output "NAVIGATE $navSteps month steps to $($toDate.ToString('yyyy-MM'))"
    Send-DownOrUp $navSteps
    Start-Sleep -Milliseconds $AfterDownMs
    $afterNav = Read-Snap 'groups-month-start.png'
    Assert-Healthy $afterNav 'after month walk'
}

for ($m = 0; $m -lt $months.Count; $m++) {
    $label = $months[$m].ToString('yyyy-MM')
    Write-Output "MONTH $label ($($m + 1)/$($months.Count))"
    if (-not ($AlreadyOnGroups -and $m -eq 0)) {
        Open-GroupView
        [void](Invoke-Anita $bg 'snap' "groups-$label-start.png")
    }
    Export-Groups $label
    if ($m -lt $months.Count - 1) {
        Return-SeeSales
        Send-DownOrUp 1
        [void](Invoke-Anita $bg 'snap' "groups-after-$label.png")
    }
}

Write-Output "EXPORT_FINISHED months=$($months.Count) groupsPerMonth=$Count files=$fileExpect ledger=$ledger"
Write-Output "Next: stamp location+group then confirm SharePoint seesales-seegroupprod-{location}-{group}-{yyyy-MM}_*.xls"

if (-not $SkipSharePoint) {
    $pyCheck = Join-Path $scriptDir 'check-sharepoint-seesales.py'
    $pyStamp = Join-Path $scriptDir 'stamp-seegroupprod.py'
    $pythonExe = $null
    foreach ($candidate in @(
            (Get-Command python -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source),
            (Get-Command py -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source),
            'C:\Program Files\Python311\python.exe'
        )) {
        if ($candidate -and (Test-Path $candidate)) { $pythonExe = $candidate; break }
    }
    if ($pythonExe) {
        Write-Output 'Waiting 90s for Power Automate, then stamping SharePoint names...'
        Start-Sleep -Seconds 90
        if ($loc -and (Test-Path $pyStamp)) {
            & $pythonExe $pyStamp --location $loc --ledger $ledger --after $runStartUtc --apply
        } elseif (-not $loc) {
            Write-Output 'WARN: pass -Location to rename loganb files with lab+group. Files landed unstamped.'
        }
        if (Test-Path $pyCheck) {
            & $pythonExe $pyCheck --kind group --expect $fileExpect
        }
    }
}

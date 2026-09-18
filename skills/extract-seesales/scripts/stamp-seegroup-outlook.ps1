# After an AniTa SEE GROUP PROD email lands, save the attachment, rename it
# with location+group+month, and send that file to datadrop so Power Automate
# drops a stamped name. Does not move the original to Deleted Items.
#
# Walk order is the classifier — the email does not name location or group.
# Call once per export (export-seesales-groups.ps1 -StampOutlook) or pass a ledger.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Location,
    [Parameter(Mandatory = $true)][string]$Group,
    [Parameter(Mandatory = $true)][string]$Month,
    [datetime]$After = (Get-Date).AddMinutes(-15),
    [int]$WaitSeconds = 90,
    [string]$Datadrop
)

$ErrorActionPreference = 'Stop'
$locAliases = @{
    wheatridge = 'wheatridge'; wheat = 'wheatridge'; wr = 'wheatridge'; ridge = 'wheatridge'; co = 'wheatridge'
    dayton = 'dayton'; nj = 'dayton'
    orlando = 'orlando'; fla = 'orlando'; fl = 'orlando'
    scott = 'scott'; la = 'scott'
    houston = 'houston'; tx = 'houston'
    nam = 'nam'
}
$loc = $Location.Trim().ToLowerInvariant()
if ($locAliases.ContainsKey($loc)) { $loc = $locAliases[$loc] }
$grp = $Group.Trim().ToUpperInvariant()
if ($Month -notmatch '^20\d{2}-(0[1-9]|1[0-2])$') { throw "Month must be YYYY-MM (got $Month)" }
if ($loc -notmatch '^[a-z0-9]{2,16}$') { throw "Location must be a lab name (got $Location)" }

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir '..\..\..\..')).Path
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
if (-not $Datadrop) {
    $Datadrop = $env:DATADROP_TO
    if (-not $Datadrop) { $Datadrop = 'us.ehs.datadrop@sgs.com' }
}

$cap = Join-Path $env:LOCALAPPDATA 'Temp\anita-capture'
New-Item -ItemType Directory -Force -Path $cap | Out-Null

$ol = New-Object -ComObject Outlook.Application
$ns = $ol.GetNamespace('MAPI')
$inbox = $ns.GetDefaultFolder(6)

function Find-NewGroupMail {
    $items = $inbox.Items
    $items.Sort('[ReceivedTime]', $true)
    $n = [Math]::Min(40, $items.Count)
    for ($i = 1; $i -le $n; $i++) {
        $it = $items.Item($i)
        if ($it.ReceivedTime -lt $After) { continue }
        $from = ''
        try { $from = [string]$it.SenderEmailAddress } catch {}
        $subj = [string]$it.Subject
        if ("$from $subj" -notmatch 'SeeSales|SEE SALES|SEE GROUP|seed2|idb057|Accutest') { continue }
        $cats = ''
        try { $cats = [string]$it.Categories } catch {}
        if ($cats -match 'SeeSalesStamped') { continue }
        if ($it.Attachments.Count -lt 1) { continue }
        return $it
    }
    return $null
}

$deadline = (Get-Date).AddSeconds($WaitSeconds)
$mail = $null
do {
    $mail = Find-NewGroupMail
    if ($mail) { break }
    Start-Sleep -Seconds 5
} while ((Get-Date) -lt $deadline)

if (-not $mail) {
    Write-Output "NO_MAIL after ${WaitSeconds}s (OST may be stale; stamp on SharePoint instead)"
    exit 2
}

$att = $mail.Attachments.Item(1)
$rawName = [string]$att.FileName
$stamp = Get-Date $mail.ReceivedTime.ToUniversalTime() -Format 'yyyyMMddHHmmss'
$newName = "seesales-seegroupprod-$loc-$grp-$Month`_$stamp.xls"
$tmp = Join-Path $cap $newName
$att.SaveAsFile($tmp)
Write-Output "SAVED $tmp from $rawName received=$($mail.ReceivedTime)"

$out = $ol.CreateItem(0)
$out.To = $Datadrop
$out.Subject = "SeeSales group prod $loc $grp $Month"
$out.Body = "Stamped by extract-seesales walk order. Original: $rawName"
[void]$out.Attachments.Add($tmp)
$out.Send()
Write-Output "SENT $newName to $Datadrop"

try {
    $mail.Categories = 'SeeSalesStamped'
    $mail.Save()
} catch {
    Write-Output "WARN could not tag original mail"
}
exit 0

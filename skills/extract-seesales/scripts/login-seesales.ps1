# Hand-path login (walked 2026-09-18 on Wheat Ridge).
# Wait for each painted prompt. chars / WM_CHAR only. Never key 13
# (that hung up Linux). Never type Invoice on Please Log On.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$HostName,
    [Parameter(Mandatory = $true)][string]$Label,
    [string]$InvoiceKey = 'i'
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir '..\..\..\..')).Path
$cap = Join-Path $env:LOCALAPPDATA 'Temp\anita-capture'
$launch = Join-Path $scriptDir 'launch-anita-hidden.ps1'
$exe = Join-Path $cap 'anita-bg.exe'
$cs = Join-Path $scriptDir 'anita-bg.cs'
$reader = Join-Path $scriptDir 'read-anita-screen.py'
$python = 'C:\Program Files\Python311\python.exe'

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
if (-not [Environment]::GetEnvironmentVariable('ANITA_PASSWORD', 'Process')) {
    throw 'ANITA_PASSWORD is empty. Load repo .env or set the process env.'
}

$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$needBuild = -not (Test-Path $exe) -or ((Get-Item $cs).LastWriteTimeUtc -gt (Get-Item $exe).LastWriteTimeUtc)
if ($needBuild) {
    & $csc /nologo /target:exe /out:$exe /r:System.Drawing.dll $cs
    if ($LASTEXITCODE -ne 0) { throw 'anita-bg compile failed' }
}

function Invoke-Bg {
    $out = & $exe @args 2>&1 | ForEach-Object { "$_" }
    $out | ForEach-Object { Write-Host $_ }
    if ($out -join "`n" -match 'Disconnected') { throw "AniTa disconnected ($HostName)" }
    return @{ Code = $LASTEXITCODE; Text = ($out -join "`n") }
}

function Read-Screen([string]$name) {
    [void](Invoke-Bg snap "$name.png" $HostName)
    $line = 'CLASS=empty KEYS=-'
    if (Test-Path $python) {
        $line = (& $python $reader "$name.png" 2>$null | Select-Object -Last 1)
        if (-not $line) { $line = 'CLASS=empty KEYS=-' }
    }
    Write-Host "SCREEN $name $line"
    return [string]$line
}

function Wait-Painted([string]$name, [int]$seconds, [string]$pattern) {
    $deadline = (Get-Date).AddSeconds($seconds)
    $n = 0
    $line = 'CLASS=empty KEYS=-'
    do {
        Start-Sleep -Seconds 2
        $n++
        $line = Read-Screen "$name-$n"
        if ($line -match $pattern) { return $line }
    } while ((Get-Date) -lt $deadline)
    return $line
}

function Get-Title {
    $p = Get-Process Anita -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowTitle -match [regex]::Escape($HostName) } |
        Select-Object -First 1
    if ($p) { return $p.MainWindowTitle }
    return ''
}

Get-Process Anita -ErrorAction SilentlyContinue | Where-Object {
    $_.MainWindowTitle -match [regex]::Escape($HostName)
} | Stop-Process
Start-Sleep -Seconds 2

& $launch -HostName $HostName -Label $Label
$deadline = (Get-Date).AddSeconds(45)
do {
    Start-Sleep -Seconds 2
    $title = Get-Title
    Write-Host "WAIT title=$title"
} while ((Get-Date) -lt $deadline -and ($title -match 'Connecting|Disconnected|auto-login' -or -not $title))
if ($title -match 'Disconnected' -or -not $title) { throw "AniTa did not connect ($HostName)" }

$anitaUser = [Environment]::GetEnvironmentVariable('ANITA_USER', 'Process')
if (-not $anitaUser) { $anitaUser = 'loganb' }

# 1. Linux login:  — first snap is often blank; wait until text paints.
# login: is sparse glyphs (CLASS=logon). A blank canvas is empty/text
# from chrome and must not get the username yet.
$scr = Wait-Painted "$Label-linux-login" 30 'CLASS=logon'
if ($scr -notmatch 'CLASS=logon') {
    throw "Linux login: never painted ($HostName). Will not type."
}
Write-Host "TYPE linux user $anitaUser"
[void](Invoke-Bg chars $anitaUser enter $HostName)

# 2. Password: paints a few seconds after username (CLASS=logon when
# headerless, CLASS=text with chrome). Do not sit on this prompt.
Start-Sleep -Seconds 3
$scr = Read-Screen "$Label-linux-password"
if ($scr -match 'CLASS=empty') {
    $scr = Wait-Painted "$Label-linux-password" 12 'CLASS=(text|logon)'
}
if ($scr -match 'CLASS=empty') {
    throw "Linux Password: never painted ($HostName). Will not type password."
}
Write-Host 'TYPE linux password'
[void](Invoke-Bg chars env:ANITA_PASSWORD enter $HostName)

# 3. REMOVE? (text) or Please Log On (logon) or menu (form).
# Sleep first so we do not treat Password: as REMOVE.
Start-Sleep -Seconds 5
$scr = Wait-Painted "$Label-after-linux" 20 'CLASS=(logon|form)|remove'
if ($scr -match 'remove' -or ($scr -match 'CLASS=text' -and $scr -notmatch 'CLASS=form')) {
    Write-Host 'TYPE y for REMOVE?'
    [void](Invoke-Bg chars y enter $HostName)
    # Extra CR here used to submit a blank IFORMS password. Wait it out.
    Start-Sleep -Seconds 8
    $scr = Wait-Painted "$Label-after-remove" 20 'CLASS=(logon|form)'
}
if ($scr -match 'invaliduser' -and $scr -notmatch 'CLASS=logon') {
    throw "Linux/IFORMS logon denied ($HostName). Will retry clean."
}

# 4. IFORMS Please Log On. One prompt at a time. Same snap must not
#    send both user and password (that typed the password as User ID).
if ($scr -match 'CLASS=logon') {
    if ($scr -match 'invaliduser') {
        Write-Host 'IFORMS already denied once. One retry only.'
    }
    Start-Sleep -Seconds 3
    $scr = Read-Screen "$Label-userid-before"
    if ($scr -match 'CLASS=form') {
        Write-Host 'Already on menu after settle.'
    } else {
        Write-Host "TYPE IFORMS user $anitaUser"
        [void](Invoke-Bg chars $anitaUser $HostName)
        Start-Sleep -Seconds 2
        [void](Read-Screen "$Label-userid-echo")
        [void](Invoke-Bg host '\r' $HostName)
        Start-Sleep -Seconds 3
        $scr = Read-Screen "$Label-iforms-password"
        if ($scr -match 'invaliduser') { throw "IFORMS user denied ($HostName)." }
        if ($scr -match 'CLASS=form') {
            Write-Host 'Menu after IFORMS user (no password line).'
        } else {
            Write-Host 'TYPE IFORMS password (password line only)'
            [void](Invoke-Bg chars env:ANITA_PASSWORD enter $HostName)
            Start-Sleep -Seconds 6
            $scr = Read-Screen "$Label-menu"
        }
    }
}

if ($scr -match 'invaliduser') { throw "IFORMS password denied ($HostName)." }
if ($scr -notmatch 'CLASS=form') {
    $scr = Wait-Painted "$Label-menu-wait" 16 'CLASS=form'
}
if ($scr -notmatch 'CLASS=form') {
    throw "Not on ACCULIMS menu after IFORMS ($HostName). Will not type Invoice."
}

# 5. Invoice hotkey, then Enter on See Sales (already highlighted).
Write-Host "OPEN Invoice hotkey=$InvoiceKey then See Sales"
[void](Invoke-Bg chars $InvoiceKey $HostName)
Start-Sleep -Seconds 3
$scr = Read-Screen "$Label-invoice"
if ($scr -match 'CLASS=logon|invaliduser|iforms') {
    throw "Invoice dumped us to login ($HostName). Stop."
}
[void](Invoke-Bg host '\r' $HostName)
Start-Sleep -Seconds 6
$scr = Read-Screen "$Label-seesales"

$st = Invoke-Bg status $HostName
if ($st.Text -match 'Disconnected') { throw "AniTa disconnected after See Sales ($HostName)" }
if ($scr -match 'invaliduser') {
    throw "Still on Please Log On after Invoice ($HostName). Logged in wrong."
}
if ($scr -match 'companywide') {
    throw "See Sales landed company-wide ($HostName). Relogin without F11."
}
Write-Host "PARK $HostName after SEE SALES (never during Password:)"
[void](Invoke-Bg park $HostName)
Write-Host "LOGIN_OK $HostName $Label on SEE SALES month list"
if ($scr -match 'oneofone') { Write-Host "WARN $Label form opened 1 of 1; Down-arrow for older months" }

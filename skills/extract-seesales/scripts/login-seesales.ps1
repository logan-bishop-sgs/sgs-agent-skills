# Hand-path login (walked 2026-09-18 on Wheat Ridge).
# Wait for each painted prompt. chars / WM_CHAR only. Never key 13
# (that hung up Linux). Never type Invoice on Please Log On.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$HostName,
    [Parameter(Mandatory = $true)][string]$Label,
    [string]$InvoiceKey = 'i',
    [switch]$KeepOtherAnita,
    [switch]$SkipLaunch,
    [int]$LoginAttempts = 2,
    [int]$TileIndex = -1,
    [switch]$ShowWindowForTile,
    [switch]$UseLlmAssist
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir '..\..\..\..')).Path
$captureRoot = Join-Path $env:LOCALAPPDATA 'Temp\anita-capture'
$cap = Join-Path $captureRoot $Label
New-Item -ItemType Directory -Force -Path $captureRoot, $cap | Out-Null
[Environment]::SetEnvironmentVariable('ANITA_CAPTURE_LABEL', $Label, 'Process')
if ($TileIndex -ge 0) {
    [Environment]::SetEnvironmentVariable('ANITA_TILE_INDEX', "$TileIndex", 'Process')
}
if ($ShowWindowForTile) {
    [Environment]::SetEnvironmentVariable('ANITA_SHOW_WINDOW', '1', 'Process')
}
$launch = Join-Path $scriptDir 'launch-anita-hidden.ps1'
$exe = Join-Path $captureRoot 'anita-bg.exe'
$cs = Join-Path $scriptDir 'anita-bg.cs'
$reader = Join-Path $scriptDir 'read-anita-screen.py'
$invert = Join-Path $scriptDir 'invert-snap.py'
$llmAssist = Join-Path $scriptDir 'anita-llm-assist.py'
$llmPs = Join-Path $scriptDir 'anita-llm-assist.ps1'
. $llmPs
$python = 'C:\Program Files\Python311\python.exe'
$script:AuditSeq = 0
$script:LlmAssistCalls = 0

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
    $out | ForEach-Object { Write-Output $_ }
    $text = $out -join "`n"
    $code = $LASTEXITCODE
    $cmd = if ($args.Count -gt 0) { "$($args[0])" } else { '' }
    if ($LASTEXITCODE -eq 2 -and $cmd -in @('chars', 'type', 'key', 'host', 'snap')) {
        throw "AniTa window not found for $HostName (close stray hosts; one session only)."
    }
    if ($code -eq 4 -or $text -match '(?m)^refuse: disconnected') {
        $titleLine = ($text -split "`n" | Where-Object { $_ -match '^title=' } | Select-Object -First 1)
        throw "AniTa disconnected ($HostName) $titleLine"
    }
    $titleLine = ($text -split "`n" | Where-Object { $_ -match '^title=' } | Select-Object -First 1)
    if ($titleLine -and $titleLine -match 'Disconnected' -and $cmd -notin @('status', 'snap')) {
        throw "AniTa disconnected ($HostName) $titleLine"
    }
    return @{ Code = $code; Text = $text }
}

function Write-LimsPhase([string]$Phase) {
    Write-Output "LIMS_PHASE=$Phase host=$HostName label=$Label"
}

function Get-ScreenClass([string]$line) {
    if ($line -match '\bCLASS=(\w+)') { return $Matches[1] }
    return ''
}

function Get-ScreenKeys([string]$line) {
    if ($line -notmatch '\bKEYS=([^\s]+)') { return @() }
    $raw = $Matches[1]
    if ($raw -eq '-') { return @() }
    return @($raw.Split(','))
}

function Test-ScreenClass([string]$line, [string]$class) {
    return (Get-ScreenClass $line) -ceq $class
}

function Test-ScreenKey([string]$line, [string]$key) {
    return (Get-ScreenKeys $line) -contains $key
}

function Test-ScreenRemove([string]$line) {
    if (Test-ScreenKey $line 'remove') { return $true }
    if ($line -match 'LIMS_OCR="[^"]*(REMOVE\?|SESSIONS CURRENTLY|If session should be removed)') { return $true }
    return $false
}

function Test-ScreenOnSeeSales([string]$line) {
    if (Test-ScreenKey $line 'invaliduser' -or Test-ScreenKey $line 'iforms') { return $false }
    if (Test-ScreenKey $line 'seesales') { return $true }
    if ((Test-ScreenClass $line 'form') -and ((Test-ScreenKey $line 'menu') -or (Test-ScreenKey $line 'seesales'))) {
        return $true
    }
    return $false
}

function Test-WaitToken([string]$line, [string]$tok) {
    if ($tok -match '^CLASS=\((.+)\)$') {
        $opts = $Matches[1].Split('|')
        $c = Get-ScreenClass $line
        return $opts -contains $c
    }
    if ($tok -match '^CLASS=(\w+)$') { return Test-ScreenClass $line $Matches[1] }
    return Test-ScreenKey $line $tok
}

function Write-LimsConn([string]$Where) {
    $st = Invoke-Bg status $HostName
    $title = ($st.Text -split "`n" | Where-Object { $_ -match '^title=' } | Select-Object -First 1)
    $bar = ($st.Text -split "`n" | Where-Object { $_ -match 'statusbar' } | Select-Object -First 1)
    $conn = if ($st.Text -match 'Disconnected' -or $title -match 'Disconnected') { 'disconnected' }
            elseif ($bar -match 'Connected' -or $st.Code -eq 0) { 'connected' }
            else { 'unknown' }
    Write-Output "LIMS_CONN where=$Where host=$HostName state=$conn $title"
}

function Get-LoginAuditDir {
    $d = [Environment]::GetEnvironmentVariable('ANITA_LOGIN_AUDIT_DIR', 'Process')
    if (-not $d) {
        $d = Join-Path $env:TEMP ("seesales-login-audit/single-{0:yyyyMMdd-HHmmss}-{1}" -f (Get-Date), $Label)
        [Environment]::SetEnvironmentVariable('ANITA_LOGIN_AUDIT_DIR', $d, 'Process')
    }
    New-Item -ItemType Directory -Force -Path $d | Out-Null
    return $d
}

function Save-AuditSnap([string]$name, [string]$classLine) {
    $audit = Get-LoginAuditDir
    $script:AuditSeq++
    $seq = '{0:D3}' -f $script:AuditSeq
    $base = "$seq-$name"
    $copied = @()
    foreach ($suffix in @('.png', '-canvas.png')) {
        $src = Join-Path $cap ($name + $suffix)
        if (-not (Test-Path -LiteralPath $src)) { continue }
        $dst = Join-Path $audit ($base + $suffix)
        Copy-Item -LiteralPath $src -Destination $dst -Force
        $copied += $dst
    }
    if ((Test-Path $python) -and (Test-Path $invert) -and (Test-Path (Join-Path $cap "$name.png"))) {
        & $python $invert "$name.png" "--out-dir=$audit" "--prefix=$base" 2>$null | Out-Null
    }
    $canvasInv = Join-Path $audit "$base-canvas-inv.png"
    $windowInv = Join-Path $audit "$base-inv.png"
    $auditView = if (Test-Path -LiteralPath $canvasInv) { $canvasInv }
                 elseif (Test-Path -LiteralPath $windowInv) { $windowInv }
                 elseif ($copied.Count -gt 0) { $copied[-1] }
                 else { '' }
    Write-Output "LIMS_AUDIT seq=$seq snap=$name dir=$audit view=$auditView $classLine"
    $manifest = Join-Path $audit 'manifest.jsonl'
    $row = [ordered]@{
        seq   = $seq
        snap  = $name
        class = $classLine
        at    = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        view  = $auditView
        files = $copied
    }
    Add-Content -LiteralPath $manifest -Value ($row | ConvertTo-Json -Compress)
}

function Read-Screen([string]$name) {
    [void](Invoke-Bg snap "$name.png" $HostName)
    $line = 'CLASS=empty KEYS=-'
    if (Test-Path $python) {
        $line = (& $python $reader "$name.png" --lims 2>$null | Select-Object -Last 1)
        if (-not $line) { $line = 'CLASS=empty KEYS=-' }
    }
    Write-Output "LIMS_SNAP snap=$name $line"
    Save-AuditSnap $name $line
    return [string]$line
}

function Get-LatestAuditCanvasPath {
    $audit = Get-LoginAuditDir
    $f = Get-ChildItem -LiteralPath $audit -Filter '*-canvas-inv.png' -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1
    if ($f) { return $f.FullName }
    return ''
}

function Invoke-LlmAssist {
    param([string]$Phase, [string]$ClassifierLine)
    if ($UseLlmAssist) { Set-AnitaLlmEscalation $true }
    if (-not (Test-AnitaLlmEscalation)) { return $null }
    if ($script:LlmAssistCalls -ge 3) { return $null }
    $img = Get-LatestAuditCanvasPath
    if (-not $img) {
        [void](Read-Screen 'llm-assist-probe')
        $img = Get-LatestAuditCanvasPath
    }
    if (-not $img) { return $null }
    $script:LlmAssistCalls++
    return Invoke-AnitaLlmAssist -Phase $Phase -HostTitle $HostName -ClassifierLine $ClassifierLine `
        -Mode login -RepoRoot $repoRoot -ImagePath $img
}

function Apply-LlmAction($obj) {
    if (-not $obj) { return $false }
    $act = [string]$obj.action
    Write-Output "LIMS_LLM action=$act reason=$($obj.reason)"
    switch ($act) {
        'y_enter' {
            Write-Output 'LIMS_LLM executing y_enter'
            [void](Invoke-Bg chars y enter $HostName)
            Start-Sleep -Seconds 8
            return $true
        }
        'wait_10s' {
            Start-Sleep -Seconds 10
            return $true
        }
        'abort_relogin' {
            throw "LLM advised abort_relogin: $($obj.reason)"
        }
        default { return $false }
    }
}

function Wait-Painted([string]$name, [int]$seconds, [string]$pattern) {
    $tokens = $pattern.Split('|')
    $deadline = (Get-Date).AddSeconds($seconds)
    $n = 0
    $line = 'CLASS=empty KEYS=-'
    do {
        Start-Sleep -Seconds 2
        $n++
        $line = Read-Screen "$name-$n"
        foreach ($tok in $tokens) {
            if (Test-WaitToken $line $tok.Trim()) { return $line }
        }
    } while ((Get-Date) -lt $deadline)
    return $line
}

function Get-Title {
    $matches = @(Get-Process Anita -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowTitle -match [regex]::Escape($HostName) })
    if (-not $matches.Count) { return '' }
    $live = @($matches | Where-Object { $_.MainWindowTitle -notmatch 'Disconnected' })
    $p = if ($live.Count) { $live[0] } else { $matches[0] }
    return $p.MainWindowTitle
}

function Stop-AnitaSession {
    if ($KeepOtherAnita) {
        Get-Process Anita -ErrorAction SilentlyContinue |
            Where-Object { $_.MainWindowTitle -match [regex]::Escape($HostName) } |
            Stop-Process -Force -ErrorAction SilentlyContinue
    } else {
        Get-Process Anita -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 6
}

function Write-LoginStatus([ValidateSet('success', 'fail')][string]$Result, [string]$Reason = '') {
    $reasonOneLine = ($Reason -replace '[\r\n]+', ' ').Trim()
    if ($Result -eq 'success') {
        Write-Output "LOGIN_STATUS=success host=$HostName label=$Label"
    } else {
        Write-Output "LOGIN_STATUS=fail host=$HostName label=$Label reason=$reasonOneLine"
    }
}

$anitaUser = [Environment]::GetEnvironmentVariable('ANITA_USER', 'Process')
if (-not $anitaUser) { $anitaUser = 'loganb' }
$iformsPassword = [Environment]::GetEnvironmentVariable('ANITA_IFORMS_PASSWORD', 'Process')
if (-not $iformsPassword) {
    $iformsPassword = [Environment]::GetEnvironmentVariable('ANITA_PASSWORD', 'Process')
}
# anita-bg chars env:NAME — keep IFORMS secret on the env block, not argv.
[Environment]::SetEnvironmentVariable('ANITA_IFORMS_PASSWORD', $iformsPassword, 'Process')
[Environment]::SetEnvironmentVariable('ANITA_LOGIN_ONLY', '1', 'Process')
$loginOk = $false
$lastLoginError = ''
for ($loginAttempt = 1; $loginAttempt -le $LoginAttempts; $loginAttempt++) {
$script:AuditSeq = 0
try {
Write-Output "LOGIN_ATTEMPT=$loginAttempt of $LoginAttempts host=$HostName label=$Label"
$script:LlmAssistCalls = 0
$auditDir = Get-LoginAuditDir
Write-Output "LOGIN_AUDIT_DIR=$auditDir host=$HostName label=$Label"

# One window per host. With KeepOtherAnita, drop only this host's stale/disconnected PIDs.
if ($loginAttempt -eq 1 -and -not $KeepOtherAnita) {
    Stop-AnitaSession
} else {
    Stop-AnitaSession
}

$connected = $false
for ($connectTry = 1; $connectTry -le 2; $connectTry++) {
    if (-not $SkipLaunch) {
        & $launch -HostName $HostName -Label $Label
    }
    $deadline = (Get-Date).AddSeconds(90)
    do {
        Start-Sleep -Seconds 2
        $title = Get-Title
        Write-Output "LIMS_WAIT try=$connectTry title=$title"
    } while ((Get-Date) -lt $deadline -and ($title -match 'Connecting|Disconnected|auto-login' -or -not $title))
    if ($title -and $title -notmatch 'Disconnected') {
        $connected = $true
        break
    }
    Write-Output "LIMS_WARN connect try $connectTry failed title=$title; retry launch"
    Stop-AnitaSession
    Start-Sleep -Seconds 6
    $SkipLaunch = $false
}
if (-not $connected) { throw "AniTa did not connect ($HostName) after 2 launches. VPN ok if manual AniTa works; check host $HostName." }
Write-LimsConn 'connected'
if ($KeepOtherAnita) {
    Start-Sleep -Seconds 5
}

# 1. Linux login:  — first snap is often blank; wait until text paints.
# login: is sparse glyphs (CLASS=logon). A blank canvas is empty/text
# from chrome and must not get the username yet.
$scr = Wait-Painted "$Label-linux-login" 30 'CLASS=logon'
if (-not (Test-ScreenClass $scr 'logon')) {
    throw "Linux login: never painted ($HostName). Will not type."
}
Write-LimsPhase 'linux-user'
Write-Output "LIMS_ACTION=type linux user $anitaUser enter"
[void](Invoke-Bg chars $anitaUser enter $HostName)

# 2. Linux Password: — classifier often misses "Password:" (no OCR). Wait a beat,
# then send password unless we already left the Linux hop (menu / login failed).
Start-Sleep -Seconds 5
$scr = Read-Screen "$Label-linux-password"
if ((Test-ScreenKey $scr 'loginincorrect') -or (Test-ScreenKey $scr 'linuxlogin')) {
    throw "Linux login failed on $HostName before Password:. Close AniTa and retry."
}
if (-not ((Test-ScreenClass $scr 'form') -or (Test-ScreenKey $scr 'menu') -or (Test-ScreenKey $scr 'seesales'))) {
    Write-LimsPhase 'linux-password'
    Write-Output 'LIMS_ACTION=type linux password enter'
    [void](Invoke-Bg chars env:ANITA_PASSWORD enter $HostName)
    Write-LimsConn 'after-linux-password'
}

# 3. REMOVE? (text) or Please Log On (logon) or menu (form).
# Sleep first so we do not treat Password: as REMOVE.
Start-Sleep -Seconds 6
$scr = Wait-Painted "$Label-after-linux" 40 'remove|iforms|CLASS=form|menu|linuxlogin|loginincorrect|invaliduser'
if (-not (Test-ScreenRemove $scr) -and -not (Test-ScreenKey $scr 'iforms') -and -not (Test-ScreenClass $scr 'form') -and ($scr -match 'CLASS=(empty|text|logon)')) {
    $llm = Invoke-LlmAssist 'after-linux-stuck' $scr
    if (Apply-LlmAction $llm) {
        $scr = Wait-Painted "$Label-after-llm" 25 'remove|iforms|CLASS=form|menu|linuxlogin|loginincorrect|invaliduser'
    }
}
if ((Test-ScreenKey $scr 'linuxlogin') -or (Test-ScreenKey $scr 'loginincorrect')) {
    throw "Linux login failed on $HostName (bad user/password or keys landed on login:). Close AniTa and retry."
}
if ((Test-ScreenKey $scr 'seesales') -and (Test-ScreenClass $scr 'form')) {
    Write-Host "Already on SEE SALES after Linux ($HostName)."
    [void](Invoke-Bg park $HostName)
    Write-LoginStatus success
    Write-Host "LOGIN_OK $HostName $Label on SEE SALES month list"
    $loginOk = $true
    return
}
if (Test-ScreenRemove $scr) {
    Write-Host 'TYPE y for REMOVE?'
    [void](Invoke-Bg chars y enter $HostName)
    # Extra CR here used to submit a blank IFORMS password. Wait it out.
    Start-Sleep -Seconds 8
    $scr = Wait-Painted "$Label-after-remove" 20 'CLASS=(logon|form)'
}
if ((Test-ScreenKey $scr 'invaliduser') -and -not (Test-ScreenClass $scr 'logon')) {
    throw "Linux/IFORMS logon denied ($HostName). Will retry clean."
}

# 4. IFORMS Please Log On. One prompt at a time. Same snap must not
#    send both user and password (that typed the password as User ID).
$doIforms = (Test-ScreenKey $scr 'iforms') -and -not (Test-ScreenKey $scr 'linuxlogin')
if (-not $doIforms -and -not (Test-ScreenClass $scr 'form') -and -not (Test-ScreenKey $scr 'menu') -and -not (Test-ScreenKey $scr 'remove') -and -not (Test-ScreenKey $scr 'seesales') -and -not (Test-ScreenKey $scr 'loginincorrect') -and -not (Test-ScreenKey $scr 'linuxlogin') -and -not (Test-ScreenKey $scr 'invaliduser')) {
    Write-Host 'Post-Linux screen untagged; hand path IFORMS (password only, then fallback).'
    $doIforms = $true
}
if ($doIforms) {
    Write-LimsPhase 'iforms-start'
    Write-LimsConn 'before-iforms'
    Start-Sleep -Seconds 3
    $scr = Read-Screen "$Label-userid-before"
    if (Test-ScreenKey $scr 'invaliduser') {
        $llm = Invoke-LlmAssist 'iforms-denied-start' $scr
        if (Apply-LlmAction $llm) {
            Start-Sleep -Seconds 3
            $scr = Read-Screen "$Label-userid-after-llm"
        }
        if (Test-ScreenKey $scr 'invaliduser') {
            throw "IFORMS already showing logon denied ($HostName). Close AniTa and retry clean."
        }
    }
    if ((Test-ScreenClass $scr 'form') -and ((Test-ScreenKey $scr 'menu') -or (Test-ScreenKey $scr 'seesales'))) {
        Write-Output 'LIMS_ACTION=skip iforms (already on acculims menu)'
    } else {
        # Manual path on acculims.mu: Linux user+password, then IFORMS password
        # only (User ID often prefilled as loganb — retyping user causes ORA-01017).
        $pwdLen = $iformsPassword.Length
        Write-LimsPhase 'iforms-password-only'
        Write-Output "LIMS_ACTION=iforms password only after linux (pwd len=$pwdLen)"
        [void](Invoke-Bg chars env:ANITA_IFORMS_PASSWORD enter $HostName)
        Start-Sleep -Seconds 12
        $scr = Read-Screen "$Label-menu"
        Write-LimsConn 'after-iforms-password-only'
        $needFullIforms = (Test-ScreenKey $scr 'invaliduser') -or
            ((Test-ScreenKey $scr 'iforms') -and -not (Test-ScreenClass $scr 'form'))
        if ($needFullIforms) {
            Write-Output 'LIMS_WARN iforms password-only did not reach menu; fallback user+password'
            if (Test-ScreenKey $scr 'invaliduser') {
                [void](Invoke-Bg key 9 $HostName)
                Start-Sleep -Seconds 1
            }
            Write-LimsPhase 'iforms-user'
            [void](Invoke-Bg chars $anitaUser $HostName)
            Start-Sleep -Seconds 2
            [void](Invoke-Bg host '\r' $HostName)
            Start-Sleep -Seconds 5
            $scr = Read-Screen "$Label-iforms-password"
            if (Test-ScreenKey $scr 'invaliduser') {
                throw "IFORMS logon denied ($HostName). Close AniTa and retry clean."
            }
            Write-LimsPhase 'iforms-password'
            [void](Invoke-Bg chars env:ANITA_IFORMS_PASSWORD enter $HostName)
            Start-Sleep -Seconds 12
            $scr = Read-Screen "$Label-menu"
            Write-LimsConn 'after-iforms-password'
            if (Test-ScreenKey $scr 'invaliduser') {
                throw "IFORMS password denied ($HostName). Close AniTa; do not retry on this session."
            }
        }
    }
}

if (Test-ScreenKey $scr 'invaliduser') { throw "IFORMS password denied ($HostName)." }
if ((Test-ScreenKey $scr 'iforms') -and -not (Test-ScreenClass $scr 'form')) {
    throw "Still on IFORMS Please Log On ($HostName). Last screen: $scr"
}

# 5. Invoice hotkey, then Enter on See Sales (manual path every time).
Write-LimsPhase 'acculims-menu-invoice'
Write-Output "LIMS_ACTION=open invoice hotkey=$InvoiceKey then see sales"
[void](Invoke-Bg chars $InvoiceKey $HostName)
Start-Sleep -Seconds 3
$scr = Read-Screen "$Label-invoice"
if ((Test-ScreenKey $scr 'invaliduser') -or (Test-ScreenKey $scr 'linuxlogin') -or (Test-ScreenKey $scr 'loginincorrect')) {
    throw "Invoice dumped us to login ($HostName). Stop."
}
if ((Test-ScreenClass $scr 'logon') -and -not (Test-ScreenOnSeeSales $scr)) {
    throw "Invoice step still on logon ($HostName). Last screen: $scr"
}
[void](Invoke-Bg host '\r' $HostName)
Start-Sleep -Seconds 6
$scr = Read-Screen "$Label-seesales"
Write-LimsPhase 'seesales-month-list'
Write-LimsConn 'on-seesales'

$st = Invoke-Bg status $HostName
if ($st.Text -match 'Disconnected') { throw "AniTa disconnected after See Sales ($HostName)" }
if (Test-ScreenKey $scr 'invaliduser') {
    throw "Still on Please Log On after Invoice ($HostName). Logged in wrong."
}
if (Test-ScreenKey $scr 'iforms') {
    throw "Still on IFORMS after Invoice ($HostName). ORA-01017? Fix ANITA_IFORMS_PASSWORD. Screen: $scr"
}
if (-not (Test-ScreenOnSeeSales $scr)) {
    throw "SEE SALES not confirmed ($HostName). Classifier: $scr. Open LIMS_AUDIT view= for this snap."
}
if (Test-ScreenKey $scr 'companywide') {
    throw "See Sales landed company-wide ($HostName). Relogin without F11."
}
Write-Host "PARK $HostName after SEE SALES (never during Password:)"
[void](Invoke-Bg park $HostName)
Write-LoginStatus success
Write-Host "LOGIN_OK $HostName $Label on SEE SALES month list"
if (Test-ScreenKey $scr 'oneofone') {
    Write-Host "WARN $Label form opened 1 of 1 - use Down-arrow for older months"
}
$loginOk = $true
break
} catch {
    $lastLoginError = $_.Exception.Message
    try {
        [void](Invoke-Bg snap 'login-fail.png' $HostName)
        Save-AuditSnap 'login-fail' ("ERROR=$lastLoginError")
    } catch {
        Write-Output "LIMS_AUDIT fail-snap-skipped reason=$($_.Exception.Message)"
    }
    Write-LoginStatus fail $lastLoginError
    if ($loginAttempt -lt $LoginAttempts) {
        Write-Output "LOGIN_RETRY will relaunch AniTa (attempt $loginAttempt failed)"
        $SkipLaunch = $false
        Stop-AnitaSession
        continue
    }
    throw
} finally {
    [Environment]::SetEnvironmentVariable('ANITA_LOGIN_ONLY', $null, 'Process')
}
}
if (-not $loginOk) {
    $script:LASTEXITCODE = 1
    throw $(if ($lastLoginError) { $lastLoginError } else { "Login failed ($HostName)" })
}

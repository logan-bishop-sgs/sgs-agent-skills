# Open SGS ServiceNow catalog in real Edge (same pattern as Workday expenses).
# Cursor's helper browser is a different session — use this window for login + fill.
# Usage: powershell -File .cursor/skills/sgs-it-tickets/scripts/Open-ServiceNow-Edge.ps1
# Agents attach via http://127.0.0.1:9223 (Playwright CDP)

param(
    [ValidateSet('portal', 'entra-app-registration', 'entra-app-registration-legacy')]
    [string]$Catalog = 'entra-app-registration-legacy',
    [string]$Url
)

$ErrorActionPreference = "Stop"

$CatalogUrls = @{
    'portal' = 'https://sgs.service-now.com/sp'
    'entra-app-registration' = 'https://sgs.service-now.com/sp?id=sc_cat_item&sys_id=7dec6166477f8594a1a7efb2e36d43de'
    'entra-app-registration-legacy' = 'https://sgs.service-now.com/sp?id=sc_cat_item&sys_id=01714e3edb523f404ee710284b961975'
}

$target = if ($Url) { $Url } else { $CatalogUrls[$Catalog] }
if (-not $target) {
    throw "Unknown catalog: $Catalog"
}

$edge = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
if (-not (Test-Path -LiteralPath $edge)) {
    $edge = "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
}
if (-not (Test-Path -LiteralPath $edge)) {
    throw "Microsoft Edge was not found."
}

$profileName = $env:SERVICENOW_EDGE_PROFILE
if ([string]::IsNullOrWhiteSpace($profileName)) {
    $profileName = "SgsServiceNowEdge"
}
$profile = Join-Path $env:LOCALAPPDATA $profileName
New-Item -ItemType Directory -Force -Path $profile | Out-Null

$cdpPort = $env:SERVICENOW_CDP_PORT
if ([string]::IsNullOrWhiteSpace($cdpPort)) {
    $cdpPort = "9223"
}
$cdpBase = "http://127.0.0.1:$cdpPort"

$alreadyOpen = $false
try {
    Invoke-WebRequest -Uri "$cdpBase/json/version" -UseBasicParsing -TimeoutSec 2 | Out-Null
    $alreadyOpen = $true
} catch {
    $alreadyOpen = $false
}

if (-not $alreadyOpen) {
    Start-Process -FilePath $edge -ArgumentList @(
        "--remote-debugging-port=$cdpPort",
        "--remote-allow-origins=*",
        "--user-data-dir=$profile",
        "--no-first-run",
        "--no-default-browser-check",
        $target
    )
}

$ok = $false
foreach ($i in 1..25) {
    try {
        Invoke-WebRequest -Uri "$cdpBase/json/version" -UseBasicParsing -TimeoutSec 2 | Out-Null
        $ok = $true
        break
    } catch {
        Start-Sleep -Milliseconds 400
    }
}

if (-not $ok) {
    throw "Edge opened but the agent could not attach on $cdpBase. Ask if a company prompt is blocking it."
}

Write-Output "Edge is ready for ServiceNow on $cdpBase"
Write-Output "URL: $target"

# Fill ServiceNow Entra catalog form on the Edge tab opened by Open-ServiceNow-Edge.ps1
param(
    [string]$Draft = "",
    [string]$Cdp = "http://127.0.0.1:9223"
)

$ErrorActionPreference = "Stop"
$dir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($Draft)) {
    $root = $dir
    while ($root) {
        $candidate = Join-Path $root "ehs_dashboard\CONTEXT\drafts\servicenow-entra-sso-graph-2026-09-21.txt"
        if (Test-Path -LiteralPath $candidate) {
            $Draft = $candidate
            break
        }
        $parent = Split-Path -Parent $root
        if ($parent -eq $root) { break }
        $root = $parent
    }
}
if (-not (Test-Path -LiteralPath $Draft)) {
    throw "Draft file not found. Pass -Draft path to servicenow draft .txt"
}

$py = Get-Command python -ErrorAction SilentlyContinue
if (-not $py) {
    throw "python not found. Run setup-agent full track or install Python 3.13."
}

& python (Join-Path $dir "fill_servicenow_entra.py") --draft $Draft --cdp $Cdp
exit $LASTEXITCODE

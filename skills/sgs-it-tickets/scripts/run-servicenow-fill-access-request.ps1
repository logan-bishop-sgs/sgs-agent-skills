# Fill ServiceNow Access Request catalog form on the Edge tab (CDP 9223). Does not Submit.
param(
    [string]$Draft = "",
    [string]$Cdp = "http://127.0.0.1:9223"
)

$ErrorActionPreference = "Stop"
$dir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($Draft)) {
    $root = $dir
    while ($root) {
        $candidate = Join-Path $root "ehs_dashboard\CONTEXT\drafts\servicenow-azure-rbac-team-access-2026-09-21.txt"
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
    throw "Draft file not found. Pass -Draft path."
}

$py = Get-Command python -ErrorAction SilentlyContinue
if (-not $py) {
    throw "python not found."
}

& python (Join-Path $dir "fill_servicenow_access_request.py") --draft $Draft --cdp $Cdp
exit $LASTEXITCODE

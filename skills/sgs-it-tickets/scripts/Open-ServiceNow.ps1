# Optional escape hatch: system default browser (steals focus).
# Agents default to cursor-ide-browser background navigate — see browser.md.
param(
    [ValidateSet('portal', 'entra-app-registration', 'entra-app-registration-legacy')]
    [string]$Catalog = 'portal',
    [string]$Url,
    [switch]$UseSystemBrowser,
    [switch]$PrintUrlOnly
)

$CatalogUrls = @{
    'portal' = 'https://sgs.service-now.com/sp'
    'entra-app-registration' = 'https://sgs.service-now.com/sp?id=sc_cat_item&sys_id=7dec6166477f8594a1a7efb2e36d43de'
    'entra-app-registration-legacy' = 'https://sgs.service-now.com/sp?id=sc_cat_item&sys_id=01714e3edb523f404ee710284b961975'
}

$target = if ($Url) { $Url } else { $CatalogUrls[$Catalog] }
if (-not $target) {
    Write-Error "Unknown catalog: $Catalog"
    exit 1
}

if ($PrintUrlOnly) {
    Write-Output $target
    exit 0
}

if (-not $UseSystemBrowser) {
    Write-Host "Default is Cursor background browser (browser.md). URL:"
    Write-Host $target
    Write-Host "To open desktop browser anyway: -UseSystemBrowser"
    exit 0
}

Write-Host "Opening in system browser: $target"
Start-Process $target
exit 0

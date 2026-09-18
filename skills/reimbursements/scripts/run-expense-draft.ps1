# Fill a Workday expense *draft* through the Edge window on CDP 9222.
# Usage:
#   powershell -File .cursor/skills/reimbursements/scripts/run-expense-draft.ps1 -Job path\to\job.json
#   powershell -File .cursor/skills/reimbursements/scripts/run-expense-draft.ps1 -DryCheck

param(
    [string]$Job = "",
    [string]$Overlay = "",
    [string]$Cdp = "http://127.0.0.1:9222",
    [switch]$DryCheck
)

$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
$py = Join-Path $here "expense_draft.py"

function Find-Python {
    foreach ($name in @("py", "python", "python3")) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }
    throw "Python was not found. Full setup installs it; light track: ask IT."
}

$python = Find-Python
$argsList = @($py, "--cdp", $Cdp)
if ($DryCheck) {
    $argsList += "--dry-check"
}
if ($Job) {
    $argsList += @("--job", (Resolve-Path -LiteralPath $Job).Path)
}
if ($Overlay) {
    $argsList += @("--overlay", (Resolve-Path -LiteralPath $Overlay).Path)
}

& $python @argsList
exit $LASTEXITCODE

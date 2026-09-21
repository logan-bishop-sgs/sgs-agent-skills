# Azure OpenAI vision assist — only after tier-2 escalation (see run-seesales-extract retry).
# ANITA_LLM_ASSIST=0 disables all vision calls. Cap: 3 vision requests per escalation episode.

$script:AnitaLlmVisionCalls = 0
$script:AnitaLlmVisionCap = 3

function Set-AnitaLlmEscalation([bool]$On) {
    [Environment]::SetEnvironmentVariable('ANITA_LLM_ESCALATE', $(if ($On) { '1' } else { '0' }), 'Process')
    if (-not $On) { $script:AnitaLlmVisionCalls = 0 }
}

function Test-AnitaLlmEscalation {
    if ([Environment]::GetEnvironmentVariable('ANITA_LLM_ASSIST', 'Process') -eq '0') { return $false }
    return [Environment]::GetEnvironmentVariable('ANITA_LLM_ESCALATE', 'Process') -eq '1'
}

function Get-AnitaLlmCaptureDir {
    $root = Join-Path $env:LOCALAPPDATA 'Temp\anita-capture'
    $label = [Environment]::GetEnvironmentVariable('ANITA_CAPTURE_LABEL', 'Process')
    if ($label) {
        $sub = Join-Path $root $label
        if (Test-Path $sub) { return $sub }
    }
    return $root
}

function Get-AnitaLlmImagePath([string]$SnapBaseName) {
    $cap = Get-AnitaLlmCaptureDir
    $candidates = @(
        (Join-Path $cap "$SnapBaseName-canvas-inv.png"),
        (Join-Path $cap "$SnapBaseName-canvas.png"),
        (Join-Path $cap "$SnapBaseName-inv.png"),
        (Join-Path $cap "$SnapBaseName.png")
    )
    foreach ($p in $candidates) {
        if (Test-Path $p) { return $p }
    }
    $latest = Get-ChildItem -LiteralPath $cap -Filter '*-canvas*.png' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($latest) { return $latest.FullName }
    return ''
}

function Invoke-AnitaLlmAssist {
    param(
        [Parameter(Mandatory = $true)][string]$Phase,
        [Parameter(Mandatory = $true)][string]$HostTitle,
        [string]$ClassifierLine = '',
        [string]$SnapBaseName = '',
        [string]$ImagePath = '',
        [ValidateSet('login', 'export')][string]$Mode = 'export',
        [string]$RepoRoot = ''
    )
    if (-not (Test-AnitaLlmEscalation)) {
        Write-Output "LIMS_LLM skip phase=$Phase (tier-1 heuristics only; escalate after second failure)"
        return $null
    }
    if ($script:AnitaLlmVisionCalls -ge $script:AnitaLlmVisionCap) {
        Write-Output "LIMS_LLM skip phase=$Phase cap=$($script:AnitaLlmVisionCap) vision calls this escalation"
        return $null
    }

    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $llmPy = Join-Path $scriptDir 'anita-llm-assist.py'
    $python = 'C:\Program Files\Python311\python.exe'
    if (-not $RepoRoot) {
        $RepoRoot = (Resolve-Path (Join-Path $scriptDir '..\..\..\..')).Path
    }
    if (-not (Test-Path $llmPy) -or -not (Test-Path $python)) { return $null }

    $img = if ($ImagePath) { $ImagePath } elseif ($SnapBaseName) { Get-AnitaLlmImagePath $SnapBaseName } else { '' }
    if (-not $img) { $img = Get-AnitaLlmImagePath 'groups-open-1' }
    if (-not $img) { return $null }

    $script:AnitaLlmVisionCalls++
    Write-Output "LIMS_LLM call=$($script:AnitaLlmVisionCalls)/$($script:AnitaLlmVisionCap) phase=$Phase mode=$Mode"
    $raw = & $python $llmPy --phase $Phase --host $HostTitle --classifier $ClassifierLine `
        --image $img --repo-root $RepoRoot --mode $Mode 2>&1 | Select-Object -Last 1
    Write-Output "LIMS_LLM raw=$raw"
    try { return ($raw | ConvertFrom-Json) } catch { return $null }
}

function Apply-AnitaLlmExportAction {
    param(
        $Obj,
        [Parameter(Mandatory = $true)][string]$BgExe,
        [Parameter(Mandatory = $true)][string]$HostTitle,
        [string]$Nav12,
        [string]$Nav13
    )
    if (-not $Obj) { return $false }
    $act = [string]$Obj.action
    Write-Output "LIMS_LLM action=$act reason=$($Obj.reason)"
    switch ($act) {
        'see_sales_s' {
            Write-Output 'LIMS_LLM executing see_sales_s'
            [void](& $BgExe 'host' $Nav12 $HostTitle 2>&1)
            Start-Sleep -Seconds 2
            [void](& $BgExe 'type' 's' $HostTitle 2>&1)
            Start-Sleep -Seconds 3
            return $true
        }
        'group_g' {
            Write-Output 'LIMS_LLM executing group_g'
            [void](& $BgExe 'host' $Nav12 $HostTitle 2>&1)
            Start-Sleep -Seconds 2
            [void](& $BgExe 'type' 'g' $HostTitle 2>&1)
            Start-Sleep -Seconds 4
            return $true
        }
        'key_f7' {
            Write-Output 'LIMS_LLM executing key_f7'
            [void](& $BgExe 'key' '118' $HostTitle 2>&1)
            Start-Sleep -Seconds 6
            return $true
        }
        'key_esc' {
            Write-Output 'LIMS_LLM executing key_esc'
            [void](& $BgExe 'key' '27' $HostTitle 2>&1)
            Start-Sleep -Seconds 2
            return $true
        }
        'page_up' {
            Write-Output 'LIMS_LLM executing page_up'
            [void](& $BgExe 'key' '33' $HostTitle 2>&1)
            Start-Sleep -Seconds 2
            return $true
        }
        'y_enter' {
            Write-Output 'LIMS_LLM executing y_enter'
            [void](& $BgExe 'chars' 'y' 'enter' $HostTitle 2>&1)
            Start-Sleep -Seconds 8
            return $true
        }
        'wait_10s' {
            Start-Sleep -Seconds 10
            return $true
        }
        'escalate_human' {
            throw "LLM escalate to human: $($Obj.reason)"
        }
        default { return $false }
    }
}

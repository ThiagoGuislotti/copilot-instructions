<#
.SYNOPSIS
    Validates repository-owned VS Code agent hook configuration under .github/hooks.

.DESCRIPTION
    Ensures hook configuration files are valid JSON, required lifecycle events
    are present, and referenced runtime hook scripts exist in the repository.

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.PARAMETER WarningOnly
    When true, failures are emitted as warnings and the script exits with code 0.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/validation/validate-agent-hooks.ps1 -RepoRoot . -WarningOnly:$false

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [bool] $WarningOnly = $true,
    [switch] $Verbose
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:CommonBootstrapPath = Join-Path $PSScriptRoot '..\common\common-bootstrap.ps1'
if (-not (Test-Path -LiteralPath $script:CommonBootstrapPath -PathType Leaf)) {
    $script:CommonBootstrapPath = Join-Path $PSScriptRoot '..\..\common\common-bootstrap.ps1'
}
if (-not (Test-Path -LiteralPath $script:CommonBootstrapPath -PathType Leaf)) {
    $script:CommonBootstrapPath = Join-Path $PSScriptRoot '..\..\shared-scripts\common\common-bootstrap.ps1'
}
if (-not (Test-Path -LiteralPath $script:CommonBootstrapPath -PathType Leaf)) {
    throw "Missing shared common bootstrap helper: $script:CommonBootstrapPath"
}
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('console-style', 'repository-paths', 'validation-logging')
$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
$script:IsVerboseEnabled = [bool] $Verbose
Start-ExecutionSession `
    -Name 'validate-agent-hooks' `
    -Metadata ([ordered]@{
            'Warning-only mode' = [bool] $WarningOnly
        }) `
    -IncludeMetadataInDefaultOutput | Out-Null

# Records either a failure or a warning based on validation mode.
function Add-ValidationMessage {
    param(
        [string] $Message,
        [System.Collections.Generic.List[string]] $Warnings,
        [System.Collections.Generic.List[string]] $Failures,
        [bool] $WarningOnlyMode
    )

    if ($WarningOnlyMode) {
        $Warnings.Add($Message) | Out-Null
        Write-ValidationOutput ("[WARN] {0}" -f $Message)
    }
    else {
        $Failures.Add($Message) | Out-Null
        Write-ValidationOutput ("[FAIL] {0}" -f $Message)
    }
}

$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
$warnings = New-Object System.Collections.Generic.List[string]
$failures = New-Object System.Collections.Generic.List[string]

$hooksRoot = Join-Path $resolvedRepoRoot '.github/hooks'
$bootstrapHookPath = Join-Path $hooksRoot 'super-agent.bootstrap.json'
$selectorPath = Join-Path $hooksRoot 'super-agent.selector.json'
$scriptDirectory = Join-Path $hooksRoot 'scripts'

if (-not (Test-Path -LiteralPath $hooksRoot -PathType Container)) {
    Add-ValidationMessage -Message 'Missing .github/hooks directory.' -Warnings $warnings -Failures $failures -WarningOnlyMode $WarningOnly
}

if (-not (Test-Path -LiteralPath $bootstrapHookPath -PathType Leaf)) {
    Add-ValidationMessage -Message 'Missing required hook file .github/hooks/super-agent.bootstrap.json.' -Warnings $warnings -Failures $failures -WarningOnlyMode $WarningOnly
}
else {
    try {
        $hookDocument = Get-Content -Raw -LiteralPath $bootstrapHookPath | ConvertFrom-Json -Depth 100
    }
    catch {
        $hookDocument = $null
        Add-ValidationMessage -Message ('.github/hooks/super-agent.bootstrap.json is not valid JSON: {0}' -f $_.Exception.Message) -Warnings $warnings -Failures $failures -WarningOnlyMode $WarningOnly
    }

    if ($null -ne $hookDocument) {
        $requiredEvents = @('SessionStart', 'PreToolUse', 'SubagentStart')
        foreach ($eventName in $requiredEvents) {
            $entries = @($hookDocument.hooks.$eventName)
            if ($entries.Count -eq 0) {
                Add-ValidationMessage -Message ("Hook event '{0}' is missing from .github/hooks/super-agent.bootstrap.json." -f $eventName) -Warnings $warnings -Failures $failures -WarningOnlyMode $WarningOnly
                continue
            }

            foreach ($entry in $entries) {
                if ([string] $entry.type -ne 'command') {
                    Add-ValidationMessage -Message ("Hook event '{0}' must use type 'command'." -f $eventName) -Warnings $warnings -Failures $failures -WarningOnlyMode $WarningOnly
                }

                $commandText = [string] $entry.command
                if ([string]::IsNullOrWhiteSpace($commandText)) {
                    Add-ValidationMessage -Message ("Hook event '{0}' must define a command." -f $eventName) -Warnings $warnings -Failures $failures -WarningOnlyMode $WarningOnly
                    continue
                }

                $expectedScriptName = switch ($eventName) {
                    'SessionStart' { 'session-start.ps1' }
                    'PreToolUse' { 'pre-tool-use.ps1' }
                    'SubagentStart' { 'subagent-start.ps1' }
                    default { $null }
                }

                if (-not [string]::IsNullOrWhiteSpace($expectedScriptName)) {
                    $expectedScriptPath = Join-Path $scriptDirectory $expectedScriptName
                    if (-not (Test-Path -LiteralPath $expectedScriptPath -PathType Leaf)) {
                        Add-ValidationMessage -Message ("Referenced hook script missing: .github/hooks/scripts/{0}" -f $expectedScriptName) -Warnings $warnings -Failures $failures -WarningOnlyMode $WarningOnly
                    }
                }
            }
        }
    }
}

if (-not (Test-Path -LiteralPath $selectorPath -PathType Leaf)) {
    Add-ValidationMessage -Message 'Missing required hook file .github/hooks/super-agent.selector.json.' -Warnings $warnings -Failures $failures -WarningOnlyMode $WarningOnly
}
else {
    try {
        $selectorDocument = Get-Content -Raw -LiteralPath $selectorPath | ConvertFrom-Json -Depth 100
    }
    catch {
        $selectorDocument = $null
        Add-ValidationMessage -Message ('.github/hooks/super-agent.selector.json is not valid JSON: {0}' -f $_.Exception.Message) -Warnings $warnings -Failures $failures -WarningOnlyMode $WarningOnly
    }

    if ($null -ne $selectorDocument) {
        if ([string]::IsNullOrWhiteSpace([string] $selectorDocument.defaultAgent.skillName)) {
            Add-ValidationMessage -Message '.github/hooks/super-agent.selector.json must define defaultAgent.skillName.' -Warnings $warnings -Failures $failures -WarningOnlyMode $WarningOnly
        }

        if ([string]::IsNullOrWhiteSpace([string] $selectorDocument.defaultAgent.displayName)) {
            Add-ValidationMessage -Message '.github/hooks/super-agent.selector.json must define defaultAgent.displayName.' -Warnings $warnings -Failures $failures -WarningOnlyMode $WarningOnly
        }

        if ([string]::IsNullOrWhiteSpace([string] $selectorDocument.overrideSources.environment.skillVariable)) {
            Add-ValidationMessage -Message '.github/hooks/super-agent.selector.json must define overrideSources.environment.skillVariable.' -Warnings $warnings -Failures $failures -WarningOnlyMode $WarningOnly
        }

        if ([string]::IsNullOrWhiteSpace([string] $selectorDocument.overrideSources.environment.displayVariable)) {
            Add-ValidationMessage -Message '.github/hooks/super-agent.selector.json must define overrideSources.environment.displayVariable.' -Warnings $warnings -Failures $failures -WarningOnlyMode $WarningOnly
        }

        if ([string]::IsNullOrWhiteSpace([string] $selectorDocument.overrideSources.localOverrideFile)) {
            Add-ValidationMessage -Message '.github/hooks/super-agent.selector.json must define overrideSources.localOverrideFile.' -Warnings $warnings -Failures $failures -WarningOnlyMode $WarningOnly
        }
    }
}

foreach ($requiredScript in @('common.ps1', 'session-start.ps1', 'pre-tool-use.ps1', 'subagent-start.ps1')) {
    $scriptPath = Join-Path $scriptDirectory $requiredScript
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        Add-ValidationMessage -Message ("Missing hook helper script: .github/hooks/scripts/{0}" -f $requiredScript) -Warnings $warnings -Failures $failures -WarningOnlyMode $WarningOnly
    }
}

$commonScriptPath = Join-Path $scriptDirectory 'common.ps1'
if (Test-Path -LiteralPath $commonScriptPath -PathType Leaf) {
    $commonScriptContent = Get-Content -Raw -LiteralPath $commonScriptPath

    if ($commonScriptContent -match 'Resolve-ProjectedRuntimeHookScriptPath') {
        $canonicalCommonScriptPath = Join-Path $resolvedRepoRoot 'scripts\runtime\hooks\common.ps1'
        if (-not (Test-Path -LiteralPath $canonicalCommonScriptPath -PathType Leaf)) {
            Add-ValidationMessage -Message 'Canonical runtime hook helper missing: scripts/runtime/hooks/common.ps1.' -Warnings $warnings -Failures $failures -WarningOnlyMode $WarningOnly
        }
        else {
            $commonScriptContent = Get-Content -Raw -LiteralPath $canonicalCommonScriptPath
        }
    }

    foreach ($requiredMarker in @(
        'workspace-adapter',
        'global-runtime',
        '.build/super-agent/planning/active',
        '.build/super-agent/specs/active'
    )) {
        if ($commonScriptContent -notmatch [regex]::Escape($requiredMarker)) {
            Add-ValidationMessage -Message ("Hook helper contract missing required marker '{0}' in .github/hooks/scripts/common.ps1." -f $requiredMarker) -Warnings $warnings -Failures $failures -WarningOnlyMode $WarningOnly
        }
    }
}

Write-ValidationOutput ''
Write-ValidationOutput 'Agent hooks validation summary'
Write-ValidationOutput ("  Warnings: {0}" -f $warnings.Count)
Write-ValidationOutput ("  Failures: {0}" -f $failures.Count)

$sessionStatus = if ($failures.Count -gt 0) { 'failed' } elseif ($warnings.Count -gt 0) { 'warning' } else { 'passed' }
Complete-ExecutionSession -Name 'validate-agent-hooks' -Status $sessionStatus -Summary ([ordered]@{
        'Warnings' = $warnings.Count
        'Failures' = $failures.Count
    }) | Out-Null

if ($failures.Count -gt 0) {
    exit 1
}

Write-ValidationOutput 'Agent hooks validation passed.'
exit 0
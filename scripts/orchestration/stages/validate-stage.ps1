<#
.SYNOPSIS
    Executes repository validation checks and produces validation artifacts.

.DESCRIPTION
    Runs deterministic validation scripts and writes:
    - validation-report json artifact
    - output artifact manifest for handoff
    - stage state metadata for orchestration observability

.PARAMETER RepoRoot
    Repository root path.

.PARAMETER RunDirectory
    Absolute run directory for generated artifacts.

.PARAMETER TraceId
    Unique trace identifier for the pipeline run.

.PARAMETER StageId
    Current stage identifier.

.PARAMETER AgentId
    Current agent identifier.

.PARAMETER RequestPath
    Path to the request text artifact.

.PARAMETER InputArtifactManifestPath
    Path to input artifact manifest.

.PARAMETER OutputArtifactManifestPath
    Path where this stage writes its output artifact manifest.

.PARAMETER AgentsManifestPath
    Optional path to the orchestration agent manifest used by scripted validation backends.

.PARAMETER DispatchMode
    Validation dispatch mode. Defaults to `scripted`.

.PARAMETER PromptTemplatePath
    Optional prompt template path for delegated validation backends.

.PARAMETER ResponseSchemaPath
    Optional response schema path for delegated validation backends.

.PARAMETER DispatchCommand
    Command used when delegated validation dispatch is enabled.

.PARAMETER ExecutionBackend
    Validation backend selector. Defaults to `script-only`.

.PARAMETER EffectiveModel
    Optional resolved model override for future delegated validation backends.

.PARAMETER StageStatePath
    Optional path where stage execution metadata is written.

.PARAMETER DetailedOutput
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File .\scripts\orchestration\stages\validate-stage.ps1 -RepoRoot . -RunDirectory .temp\runs\trace-001 -TraceId trace-001 -StageId validate -AgentId tester -RequestPath .temp\runs\trace-001\request.txt -InputArtifactManifestPath .temp\runs\trace-001\stages\implement\output-artifacts.json -OutputArtifactManifestPath .temp\runs\trace-001\stages\validate\output-artifacts.json

.NOTES
    This stage stays scripted in phase 1 and acts as the deterministic quality gate before review.
#>

param(
    [Parameter(Mandatory = $true)] [string] $RepoRoot,
    [Parameter(Mandatory = $true)] [string] $RunDirectory,
    [Parameter(Mandatory = $true)] [string] $TraceId,
    [Parameter(Mandatory = $true)] [string] $StageId,
    [Parameter(Mandatory = $true)] [string] $AgentId,
    [Parameter(Mandatory = $true)] [string] $RequestPath,
    [Parameter(Mandatory = $true)] [string] $InputArtifactManifestPath,
    [Parameter(Mandatory = $true)] [string] $OutputArtifactManifestPath,
    [string] $AgentsManifestPath,
    [string] $DispatchMode = 'scripted',
    [string] $PromptTemplatePath,
    [string] $ResponseSchemaPath,
    [string] $DispatchCommand = 'codex',
    [string] $ExecutionBackend = 'script-only',
    [string] $EffectiveModel,
    [string] $StageStatePath,
    [switch] $DetailedOutput
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
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('console-style', 'repository-paths')
$script:IsVerboseEnabled = [bool] $DetailedOutput

# Builds a checksum-bearing artifact descriptor for the stage manifest.
function Get-ArtifactDescriptor {
    param(
        [string] $Name,
        [string] $Path,
        [string] $Root
    )

    $hash = Get-FileHash -LiteralPath $Path -Algorithm SHA256
    return [ordered]@{
        name = $Name
        path = (Convert-ToRelativeRepoPath -Root $Root -Path $Path)
        checksum = ("sha256:{0}" -f $hash.Hash.ToLowerInvariant())
    }
}

# Reads a JSON file using a repository-wide deep parse depth.
function Read-JsonFile {
    param([string] $Path)

    return (Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -Depth 200)
}

# Reads a property safely from PSCustomObject or hashtable values.
function Get-ObjectValue {
    param(
        [object] $Object,
        [string] $Name,
        [object] $DefaultValue = $null
    )

    if ($null -eq $Object -or [string]::IsNullOrWhiteSpace($Name)) {
        return $DefaultValue
    }

    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($Name)) {
            return $Object[$Name]
        }

        return $DefaultValue
    }

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $DefaultValue
    }

    return $property.Value
}

# Converts an artifact manifest into a name-to-path lookup table.
function Convert-ArtifactManifestToMap {
    param(
        [object] $Manifest,
        [string] $Root
    )

    $map = @{}
    foreach ($artifact in @($Manifest.artifacts)) {
        $name = [string] $artifact.name
        $path = [string] $artifact.path
        if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($path)) {
            continue
        }

        $map[$name] = Resolve-FullPath -BasePath $Root -Candidate $path
    }

    return $map
}

# Writes JSON deterministically without adding an implicit trailing newline.
function Write-JsonFile {
    param(
        [string] $Path,
        [object] $Value
    )

    $directory = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    Set-Content -LiteralPath $Path -Value ($Value | ConvertTo-Json -Depth 100) -Encoding UTF8 -NoNewline
}

# Blocks destructive commands from planned verification.
function Test-IsBlockedValidationCommand {
    param([string] $CommandText)

    $normalized = ($CommandText ?? '').Trim().ToLowerInvariant()
    $blockedPrefixes = @(
        'git reset --hard',
        'git checkout --',
        'remove-item -recurse -force',
        'del /f /s /q',
        'format-volume'
    )

    foreach ($blockedPrefix in $blockedPrefixes) {
        if ($normalized.StartsWith($blockedPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    return $false
}

# Defers recursive meta-validation commands that would loop back into this stage.
function Test-IsDeferredValidationCommand {
    param([string] $CommandText)

    $normalized = ($CommandText ?? '').Trim().ToLowerInvariant()
    $deferredPatterns = @(
        'scripts/validation/validate-runtime-script-tests.ps1',
        'scripts/validation/validate-all.ps1',
        'scripts/tests/runtime/agent-orchestration-engine.tests.ps1',
        'scripts/runtime/run-agent-pipeline.ps1',
        'scripts/runtime/healthcheck.ps1'
    )

    foreach ($pattern in $deferredPatterns) {
        if ($normalized.Contains($pattern)) {
            return $true
        }
    }

    return $false
}

# Executes one repository validation script and returns structured timing/output metadata.
function Invoke-ValidationScript {
    param(
        [string] $Name,
        [string] $ScriptPath,
        [string] $Root
    )

    $startedAt = Get-Date
    $status = 'failed'
    $exitCode = 1
    $errorMessage = $null

    try {
        & $ScriptPath -RepoRoot $Root | Out-Host
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        if ($exitCode -eq 0) {
            $status = 'passed'
        }
    }
    catch {
        $exitCode = 1
        $errorMessage = $_.Exception.Message
    }

    $finishedAt = Get-Date
    return [pscustomobject]@{
        name = $Name
        script = (Convert-ToRelativeRepoPath -Root $Root -Path $ScriptPath)
        status = $status
        exitCode = $exitCode
        startedAt = $startedAt.ToString('o')
        finishedAt = $finishedAt.ToString('o')
        durationMs = [int] ($finishedAt - $startedAt).TotalMilliseconds
        error = $errorMessage
    }
}

# Executes one planned verification command from the task plan.
function Invoke-PlannedCommandCheck {
    param(
        [string] $Name,
        [string] $CommandText,
        [string] $ExpectedOutcome,
        [string] $Root
    )

    $startedAt = Get-Date
    $status = 'failed'
    $exitCode = 1
    $errorMessage = $null

    if ([string]::IsNullOrWhiteSpace($CommandText)) {
        $errorMessage = 'Planned verification command is empty.'
    }
    elseif (Test-IsBlockedValidationCommand -CommandText $CommandText) {
        $errorMessage = ("Blocked planned verification command: {0}" -f $CommandText)
    }
    elseif (Test-IsDeferredValidationCommand -CommandText $CommandText) {
        $status = 'deferred'
        $exitCode = 0
        $errorMessage = 'Deferred recursive meta-validation command because the validate stage already executes equivalent repository quality gates.'
    }
    else {
        try {
            $escapedRoot = $Root.Replace("'", "''")
            $wrappedCommand = "& { Set-Location -LiteralPath '$escapedRoot'; $CommandText }"
            & pwsh -NoProfile -Command $wrappedCommand | Out-Host
            $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
            if ($exitCode -eq 0) {
                $status = 'passed'
            }
        }
        catch {
            $exitCode = 1
            $errorMessage = $_.Exception.Message
        }
    }

    $finishedAt = Get-Date
    return [pscustomobject]@{
        name = $Name
        script = $CommandText
        status = $status
        exitCode = $exitCode
        startedAt = $startedAt.ToString('o')
        finishedAt = $finishedAt.ToString('o')
        durationMs = [int] ($finishedAt - $startedAt).TotalMilliseconds
        error = $errorMessage
        expectedOutcome = $ExpectedOutcome
    }
}

$resolvedRepoRoot = [System.IO.Path]::GetFullPath($RepoRoot)
$resolvedRunDirectory = [System.IO.Path]::GetFullPath($RunDirectory)
$resolvedRequestPath = [System.IO.Path]::GetFullPath($RequestPath)
$resolvedInputManifestPath = [System.IO.Path]::GetFullPath($InputArtifactManifestPath)
$resolvedOutputManifestPath = [System.IO.Path]::GetFullPath($OutputArtifactManifestPath)
$resolvedStageStatePath = if ([string]::IsNullOrWhiteSpace($StageStatePath)) { Join-Path $resolvedRunDirectory ('stages/{0}-state.json' -f $StageId) } else { [System.IO.Path]::GetFullPath($StageStatePath) }

$stageArtifactsDirectory = Join-Path $resolvedRunDirectory 'artifacts'
New-Item -ItemType Directory -Path $stageArtifactsDirectory -Force | Out-Null

$inputArtifactCount = 0
$artifactMap = @{}
$taskPlanData = $null
if (Test-Path -LiteralPath $resolvedInputManifestPath -PathType Leaf) {
    $inputManifest = Read-JsonFile -Path $resolvedInputManifestPath
    $inputArtifactCount = @($inputManifest.artifacts).Count
    $artifactMap = Convert-ArtifactManifestToMap -Manifest $inputManifest -Root $resolvedRepoRoot
    if ($artifactMap.ContainsKey('task-plan-data')) {
        $taskPlanDataPath = [string] $artifactMap['task-plan-data']
        if (Test-Path -LiteralPath $taskPlanDataPath -PathType Leaf) {
            $taskPlanData = Read-JsonFile -Path $taskPlanDataPath
        }
    }
}

$plannedChecks = New-Object System.Collections.Generic.List[object]
if ($null -ne $taskPlanData) {
    foreach ($workItem in @($taskPlanData.workItems)) {
        $taskId = [string] (Get-ObjectValue -Object $workItem -Name 'id')
        foreach ($commandEntry in @($workItem.commands)) {
            $commandText = if ($commandEntry -is [string]) { [string] $commandEntry } else { [string] (Get-ObjectValue -Object $commandEntry -Name 'command') }
            if ([string]::IsNullOrWhiteSpace($commandText)) {
                continue
            }

            $plannedChecks.Add([ordered]@{
                    name = ("planned-command::{0}::{1}" -f $taskId, ([string] (Get-ObjectValue -Object $commandEntry -Name 'purpose')))
                    command = $commandText
                    expectedOutcome = [string] (Get-ObjectValue -Object $commandEntry -Name 'expectedOutcome')
                }) | Out-Null
        }

        foreach ($checkpoint in @($workItem.checkpoints)) {
            $commandText = if ($checkpoint -is [string]) { [string] $checkpoint } else { [string] (Get-ObjectValue -Object $checkpoint -Name 'command') }
            if ([string]::IsNullOrWhiteSpace($commandText)) {
                continue
            }

            $plannedChecks.Add([ordered]@{
                    name = ("checkpoint::{0}::{1}" -f $taskId, ([string] (Get-ObjectValue -Object $checkpoint -Name 'name')))
                    command = $commandText
                    expectedOutcome = [string] (Get-ObjectValue -Object $checkpoint -Name 'expectedOutcome')
                }) | Out-Null
        }
    }
}

$validationScripts = @(
    [ordered]@{ Name = 'validate-instructions'; Path = (Join-Path $resolvedRepoRoot 'scripts/validation/validate-instructions.ps1') },
    [ordered]@{ Name = 'validate-policy'; Path = (Join-Path $resolvedRepoRoot 'scripts/validation/validate-policy.ps1') },
    [ordered]@{ Name = 'validate-agent-orchestration'; Path = (Join-Path $resolvedRepoRoot 'scripts/validation/validate-agent-orchestration.ps1') },
    [ordered]@{ Name = 'validate-planning-structure'; Path = (Join-Path $resolvedRepoRoot 'scripts/validation/validate-planning-structure.ps1') },
    [ordered]@{ Name = 'validate-release-governance'; Path = (Join-Path $resolvedRepoRoot 'scripts/validation/validate-release-governance.ps1') }
)

$results = New-Object System.Collections.Generic.List[object]
foreach ($plannedCheck in $plannedChecks) {
    $results.Add((Invoke-PlannedCommandCheck -Name ([string] $plannedCheck.name) -CommandText ([string] $plannedCheck.command) -ExpectedOutcome ([string] $plannedCheck.expectedOutcome) -Root $resolvedRepoRoot)) | Out-Null
}
foreach ($scriptEntry in $validationScripts) {
    if (-not (Test-Path -LiteralPath $scriptEntry.Path -PathType Leaf)) {
        $results.Add([pscustomobject]@{
            name = $scriptEntry.Name
            script = (Convert-ToRelativeRepoPath -Root $resolvedRepoRoot -Path $scriptEntry.Path)
            status = 'failed'
            exitCode = 1
            startedAt = (Get-Date).ToString('o')
            finishedAt = (Get-Date).ToString('o')
            durationMs = 0
            error = 'Validation script not found.'
        }) | Out-Null
        continue
    }

    $results.Add((Invoke-ValidationScript -Name $scriptEntry.Name -ScriptPath $scriptEntry.Path -Root $resolvedRepoRoot)) | Out-Null
}

$failedChecks = @($results | Where-Object { @('failed', 'blocked') -contains [string] $_.status }).Count
$inputArtifactCount = 0
if (Test-Path -LiteralPath $resolvedInputManifestPath -PathType Leaf) {
    $inputManifest = Get-Content -Raw -LiteralPath $resolvedInputManifestPath | ConvertFrom-Json -Depth 100
    $inputArtifactCount = @($inputManifest.artifacts).Count
}
$validationReportPath = Join-Path $stageArtifactsDirectory 'validation-report.json'

$validationReport = [ordered]@{
    traceId = $TraceId
    stageId = $StageId
    agentId = $AgentId
    generatedAt = (Get-Date).ToString('o')
    summary = [ordered]@{
        totalChecks = $results.Count
        failedChecks = $failedChecks
        overallStatus = if ($failedChecks -eq 0) { 'passed' } else { 'failed' }
    }
    inputs = [ordered]@{
        requestPath = Convert-ToRelativeRepoPath -Root $resolvedRepoRoot -Path $resolvedRequestPath
        inputArtifactManifestPath = Convert-ToRelativeRepoPath -Root $resolvedRepoRoot -Path $resolvedInputManifestPath
        inputArtifactCount = $inputArtifactCount
        plannedVerificationCount = $plannedChecks.Count
    }
    checks = $results
}
Write-JsonFile -Path $validationReportPath -Value $validationReport

$outputManifestDirectory = Split-Path -Parent $resolvedOutputManifestPath
if (-not [string]::IsNullOrWhiteSpace($outputManifestDirectory)) {
    New-Item -ItemType Directory -Path $outputManifestDirectory -Force | Out-Null
}

$outputManifest = [ordered]@{
    traceId = $TraceId
    stageId = $StageId
    agentId = $AgentId
    producedAt = (Get-Date).ToString('o')
    artifacts = @(
        (Get-ArtifactDescriptor -Name 'validation-report' -Path $validationReportPath -Root $resolvedRepoRoot)
    )
}
Write-JsonFile -Path $resolvedOutputManifestPath -Value $outputManifest

$stageState = [ordered]@{
    traceId = $TraceId
    stageId = $StageId
    agentId = $AgentId
    backend = 'scripted'
    dispatchCount = 0
    validationCount = $results.Count
    failedChecks = $failedChecks
}
Write-JsonFile -Path $resolvedStageStatePath -Value $stageState

Write-VerboseLog ("Stage artifacts written: {0}" -f $resolvedOutputManifestPath)

if ($failedChecks -gt 0) {
    exit 1
}

exit 0
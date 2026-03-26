<#
.SYNOPSIS
    Produces release-closeout artifacts for the orchestration pipeline.

.DESCRIPTION
    Consolidates release-facing outputs after review, including a commit-ready
    summary, changelog summary, and planning transition metadata.

.PARAMETER RepoRoot
    Repository root used to resolve manifests, prompts, schemas, and artifacts.

.PARAMETER RunDirectory
    Pipeline run directory where stage artifacts and metadata are persisted.

.PARAMETER TraceId
    Stable execution trace identifier for the current pipeline run.

.PARAMETER StageId
    Stage identifier from the pipeline manifest.

.PARAMETER AgentId
    Agent contract identifier used for this stage.

.PARAMETER RequestPath
    Path to the normalized request payload for the run.

.PARAMETER InputArtifactManifestPath
    Artifact manifest produced by the previous stage.

.PARAMETER OutputArtifactManifestPath
    Artifact manifest written by this stage.

.PARAMETER AgentsManifestPath
    Relative or absolute path to the orchestration agent manifest.

.PARAMETER DispatchMode
    Dispatch mode declared by the pipeline stage contract.

.PARAMETER PromptTemplatePath
    Closeout prompt template used when live dispatch is enabled.

.PARAMETER ResponseSchemaPath
    JSON schema used to validate live closeout output.

.PARAMETER DispatchCommand
    Local command used to invoke Codex dispatch.

.PARAMETER ExecutionBackend
    Selected backend for the run, such as `script-only` or `codex-exec`.

.PARAMETER EffectiveModel
    Optional resolved model override for live closeout dispatch.

.PARAMETER StageStatePath
    Optional override path for the persisted stage-state artifact.

.PARAMETER DetailedOutput
    Enables verbose diagnostics for stage execution.

.EXAMPLE
    pwsh -File scripts/orchestration/stages/closeout-stage.ps1 -RepoRoot . -RunDirectory .temp/runs/example -TraceId trace-1 -StageId closeout -AgentId release-engineer -RequestPath .temp/runs/example/request.md -InputArtifactManifestPath .temp/runs/example/review-output.json -OutputArtifactManifestPath .temp/runs/example/closeout-output.json

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
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
    [string] $AgentsManifestPath = '.codex/orchestration/agents.manifest.json',
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
# Builds one artifact descriptor with checksum metadata.
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

# Reads a JSON file and returns the parsed object.
function Read-JsonFile {
    param([string] $Path)

    return (Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -Depth 200)
}

# Writes JSON content without a trailing newline.
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

# Moves a file while preserving its original timestamp metadata.
function Move-ItemPreserveTimestamps {
    param(
        [string] $SourcePath,
        [string] $DestinationPath
    )

    $sourceItem = Get-Item -LiteralPath $SourcePath
    $creationTimeUtc = $sourceItem.CreationTimeUtc
    $lastWriteTimeUtc = $sourceItem.LastWriteTimeUtc
    $lastAccessTimeUtc = $sourceItem.LastAccessTimeUtc

    Move-Item -LiteralPath $SourcePath -Destination $DestinationPath -Force

    $destinationItem = Get-Item -LiteralPath $DestinationPath
    $destinationItem.CreationTimeUtc = $creationTimeUtc
    $destinationItem.LastWriteTimeUtc = $lastWriteTimeUtc
    $destinationItem.LastAccessTimeUtc = $lastAccessTimeUtc
}

# Replaces token placeholders in a prompt template.
function Expand-Template {
    param(
        [string] $TemplateText,
        [hashtable] $Tokens
    )

    $rendered = $TemplateText
    foreach ($key in $Tokens.Keys) {
        $rendered = $rendered.Replace(("{{{0}}}" -f $key), [string] $Tokens[$key])
    }

    return $rendered
}

# Loads one agent contract from the orchestration manifest.
function Get-AgentContract {
    param(
        [string] $ManifestPath,
        [string] $TargetAgentId
    )

    $manifest = Read-JsonFile -Path $ManifestPath
    return @($manifest.agents | Where-Object { $_.id -eq $TargetAgentId } | Select-Object -First 1)
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

# Resolves a repository-relative target path and blocks writes outside the repo root.
function Resolve-SafeRepoTargetPath {
    param(
        [string] $Root,
        [string] $RelativePath
    )

    if ([string]::IsNullOrWhiteSpace($RelativePath)) {
        throw 'Closeout update path cannot be empty.'
    }

    if ([System.IO.Path]::IsPathRooted($RelativePath)) {
        throw ("Closeout update path must be repository-relative: {0}" -f $RelativePath)
    }

    $resolvedRoot = [System.IO.Path]::GetFullPath($Root)
    $resolvedPath = [System.IO.Path]::GetFullPath((Join-Path $resolvedRoot $RelativePath))
    $rootPrefix = $resolvedRoot.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if (($resolvedPath -ne $resolvedRoot) -and (-not $resolvedPath.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase))) {
        throw ("Closeout update path escapes repository root: {0}" -f $RelativePath)
    }

    return $resolvedPath
}

# Returns a short JSON preview of a file for closeout prompting.
function Get-FilePreviewText {
    param(
        [string] $Path,
        [int] $MaxLines = 160
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return ''
    }

    return ((Get-Content -LiteralPath $Path | Select-Object -First $MaxLines) -join "`n")
}

# Builds a unique list of README candidates from changed files and route guidance.
function Get-ReadmeCandidatePaths {
    param(
        [string] $Root,
        [string[]] $ChangedFiles,
        [bool] $ReadmeImpact
    )

    $paths = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($changedFile in @($ChangedFiles)) {
        if ([string]::IsNullOrWhiteSpace($changedFile)) {
            continue
        }

        $resolvedCandidate = Resolve-FullPath -BasePath $Root -Candidate $changedFile
        $currentDirectory = if (Test-Path -LiteralPath $resolvedCandidate -PathType Container) {
            $resolvedCandidate
        }
        else {
            Split-Path -Path $resolvedCandidate -Parent
        }

        while (-not [string]::IsNullOrWhiteSpace($currentDirectory)) {
            $candidateReadmePath = Join-Path $currentDirectory 'README.md'
            if (Test-Path -LiteralPath $candidateReadmePath -PathType Leaf) {
                $paths.Add($candidateReadmePath) | Out-Null
                break
            }

            if ([System.StringComparer]::OrdinalIgnoreCase.Equals($currentDirectory, $Root)) {
                break
            }

            $parentDirectory = Split-Path -Path $currentDirectory -Parent
            if ([string]::IsNullOrWhiteSpace($parentDirectory) -or [System.StringComparer]::OrdinalIgnoreCase.Equals($parentDirectory, $currentDirectory)) {
                break
            }

            $currentDirectory = $parentDirectory
        }
    }

    if ($ReadmeImpact) {
        $rootReadmePath = Join-Path $Root 'README.md'
        if (Test-Path -LiteralPath $rootReadmePath -PathType Leaf) {
            $paths.Add($rootReadmePath) | Out-Null
        }
    }

    return @($paths)
}

# Builds a prompt-safe payload describing README candidates and current content.
function Get-ReadmeCandidatePayload {
    param(
        [string] $Root,
        [string[]] $Paths
    )

    return @(
        $Paths |
            Sort-Object |
            ForEach-Object {
                [ordered]@{
                    path = Convert-ToRelativeRepoPath -Root $Root -Path $_
                    currentContent = Get-Content -Raw -LiteralPath $_
                }
            }
    )
}

# Builds a prompt-safe payload describing the changelog candidate and current head content.
function Get-ChangelogCandidatePayload {
    param(
        [string] $Root,
        [bool] $ChangelogImpact
    )

    $defaultPath = Join-Path $Root 'CHANGELOG.md'
    return [ordered]@{
        path = Convert-ToRelativeRepoPath -Root $Root -Path $defaultPath
        shouldUpdate = $ChangelogImpact
        currentHead = Get-FilePreviewText -Path $defaultPath -MaxLines 160
    }
}

# Applies README updates returned by the closeout result.
function Set-ReadmeUpdates {
    param(
        [string] $Root,
        [object[]] $Updates
    )

    $applied = New-Object System.Collections.Generic.List[object]

    foreach ($update in @($Updates)) {
        $relativePath = [string] $update.path
        $targetPath = Resolve-SafeRepoTargetPath -Root $Root -RelativePath $relativePath
        if ([System.IO.Path]::GetFileName($targetPath) -ne 'README.md') {
            throw ("Closeout README update must target a README.md file: {0}" -f $relativePath)
        }

        if (-not (Test-Path -LiteralPath $targetPath -PathType Leaf)) {
            throw ("Closeout README target does not exist: {0}" -f $relativePath)
        }

        Set-Content -LiteralPath $targetPath -Value ([string] $update.content) -Encoding UTF8 -NoNewline
        $applied.Add([ordered]@{
                path = Convert-ToRelativeRepoPath -Root $Root -Path $targetPath
                summary = [string] $update.summary
                checksum = ("sha256:{0}" -f (Get-FileHash -LiteralPath $targetPath -Algorithm SHA256).Hash.ToLowerInvariant())
            }) | Out-Null
    }

    return @($applied.ToArray())
}

# Applies a changelog update returned by the closeout result.
function Update-ChangelogFile {
    param(
        [string] $Root,
        [object] $Update
    )

    $relativePath = [string] $Update.path
    $targetPath = Resolve-SafeRepoTargetPath -Root $Root -RelativePath $relativePath
    $fileName = [System.IO.Path]::GetFileName($targetPath)
    if ($fileName -notmatch '^(?i:CHANGELOG)(\..+)?$') {
        throw ("Closeout changelog update must target a CHANGELOG file: {0}" -f $relativePath)
    }

    $entry = (([string] $Update.entry) ?? '').Trim()
    $existingContent = if (Test-Path -LiteralPath $targetPath -PathType Leaf) {
        Get-Content -Raw -LiteralPath $targetPath
    }
    else {
        ''
    }

    $applied = $false
    if (-not [string]::IsNullOrWhiteSpace($entry)) {
        $normalizedExisting = $existingContent.TrimStart()
        if (-not $normalizedExisting.StartsWith($entry, [System.StringComparison]::Ordinal)) {
            $combinedContent = if ([string]::IsNullOrWhiteSpace($existingContent)) {
                $entry
            }
            else {
                $entry + "`n`n" + $existingContent.TrimStart()
            }
            Set-Content -LiteralPath $targetPath -Value $combinedContent -Encoding UTF8 -NoNewline
            $applied = $true
        }
    }

    return [ordered]@{
        path = Convert-ToRelativeRepoPath -Root $Root -Path $targetPath
        summary = [string] $Update.summary
        applied = $applied
        checksum = if (Test-Path -LiteralPath $targetPath -PathType Leaf) { ("sha256:{0}" -f (Get-FileHash -LiteralPath $targetPath -Algorithm SHA256).Hash.ToLowerInvariant()) } else { $null }
    }
}

# Produces the deterministic fallback closeout result when live dispatch is unavailable.
function New-FallbackCloseoutResult {
    param(
        [string] $ReviewDecision,
        [int] $FailedChecks
    )

    if ($ReviewDecision -eq 'blocked' -or $FailedChecks -gt 0) {
        return [ordered]@{
            status = 'blocked'
            summary = 'Closeout is blocked because review or validation did not pass cleanly.'
            readmeActions = @('Do not update release-facing documentation until the blocking issues are resolved.')
            readmeUpdates = @()
            commitMessage = 'fix: resolve blocking review findings before closeout'
            changelogSummary = 'Blocked closeout due to pending validation or review findings.'
            changelogUpdate = [ordered]@{
                apply = $false
                path = 'CHANGELOG.md'
                summary = 'Do not update the changelog while closeout is blocked.'
                entry = ''
            }
            followUps = @(
                'Resolve failed validation checks.',
                'Address reviewer follow-up items before closing the plan.'
            )
        }
    }

    return [ordered]@{
        status = 'ready-for-commit'
        summary = 'Closeout is ready for commit and plan completion.'
        readmeActions = @('Review whether README changes are required for the delivered scope and keep them aligned when applicable.')
        readmeUpdates = @()
        commitMessage = 'feat: finalize planned delivery with validated review closeout'
        changelogSummary = 'Finalize the validated delivery and close the active implementation plan.'
        changelogUpdate = [ordered]@{
            apply = $false
            path = 'CHANGELOG.md'
            summary = 'No deterministic changelog update was generated in fallback mode.'
            entry = ''
        }
        followUps = @()
    }
}

$resolvedRepoRoot = [System.IO.Path]::GetFullPath($RepoRoot)
$resolvedRunDirectory = [System.IO.Path]::GetFullPath($RunDirectory)
$resolvedRequestPath = [System.IO.Path]::GetFullPath($RequestPath)
$resolvedInputManifestPath = [System.IO.Path]::GetFullPath($InputArtifactManifestPath)
$resolvedOutputManifestPath = [System.IO.Path]::GetFullPath($OutputArtifactManifestPath)
$resolvedAgentsManifestPath = Resolve-FullPath -BasePath $resolvedRepoRoot -Candidate $AgentsManifestPath
$resolvedPromptTemplatePath = Resolve-FullPath -BasePath $resolvedRepoRoot -Candidate $PromptTemplatePath
$resolvedResponseSchemaPath = Resolve-FullPath -BasePath $resolvedRepoRoot -Candidate $ResponseSchemaPath
$resolvedStageStatePath = if ([string]::IsNullOrWhiteSpace($StageStatePath)) { Join-Path $resolvedRunDirectory ('stages/{0}-state.json' -f $StageId) } else { Resolve-FullPath -BasePath $resolvedRepoRoot -Candidate $StageStatePath }

$stageArtifactsDirectory = Join-Path $resolvedRunDirectory 'artifacts'
$stageMetadataDirectory = Join-Path $resolvedRunDirectory ('stages/{0}' -f $StageId)
New-Item -ItemType Directory -Path $stageArtifactsDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $stageMetadataDirectory -Force | Out-Null

$requestContent = if (Test-Path -LiteralPath $resolvedRequestPath -PathType Leaf) {
    (Get-Content -Raw -LiteralPath $resolvedRequestPath).Trim()
}
else {
    'No request content provided.'
}

$agent = Get-AgentContract -ManifestPath $resolvedAgentsManifestPath -TargetAgentId $AgentId
if ($null -eq $agent) {
    throw ("Agent contract not found for stage {0}: {1}" -f $StageId, $AgentId)
}

$inputManifest = Read-JsonFile -Path $resolvedInputManifestPath
$artifactMap = Convert-ArtifactManifestToMap -Manifest $inputManifest -Root $resolvedRepoRoot
$normalizedRequestPath = if ($artifactMap.ContainsKey('normalized-request')) { [string] $artifactMap['normalized-request'] } else { $null }
$specSummaryPath = if ($artifactMap.ContainsKey('spec-summary')) { [string] $artifactMap['spec-summary'] } else { $null }
$activeSpecPath = if ($artifactMap.ContainsKey('active-spec')) { [string] $artifactMap['active-spec'] } else { $null }
$routeSelectionPath = if ($artifactMap.ContainsKey('route-selection')) { [string] $artifactMap['route-selection'] } else { $null }
$changesetPath = if ($artifactMap.ContainsKey('changeset')) { [string] $artifactMap['changeset'] } else { $null }
$validationReportPath = if ($artifactMap.ContainsKey('validation-report')) { [string] $artifactMap['validation-report'] } else { $null }
$reviewReportPath = if ($artifactMap.ContainsKey('review-report')) { [string] $artifactMap['review-report'] } else { $null }
$decisionLogPath = if ($artifactMap.ContainsKey('decision-log')) { [string] $artifactMap['decision-log'] } else { $null }
$activePlanPath = if ($artifactMap.ContainsKey('active-plan')) { [string] $artifactMap['active-plan'] } else { $null }

if ($null -ne $normalizedRequestPath -and (Test-Path -LiteralPath $normalizedRequestPath -PathType Leaf)) {
    $normalizedRequestContent = (Get-Content -Raw -LiteralPath $normalizedRequestPath).Trim()
    if (-not [string]::IsNullOrWhiteSpace($normalizedRequestContent)) {
        $requestContent = $normalizedRequestContent
    }
}

$routeSelection = if ($null -ne $routeSelectionPath -and (Test-Path -LiteralPath $routeSelectionPath -PathType Leaf)) { Read-JsonFile -Path $routeSelectionPath } else { $null }
$routeSelectionJson = if ($null -ne $routeSelectionPath -and (Test-Path -LiteralPath $routeSelectionPath -PathType Leaf)) { Get-Content -Raw -LiteralPath $routeSelectionPath } else { '{}' }
$specSummaryJson = if ($null -ne $specSummaryPath -and (Test-Path -LiteralPath $specSummaryPath -PathType Leaf)) { Get-Content -Raw -LiteralPath $specSummaryPath } else { '{}' }
$changesetJson = if ($null -ne $changesetPath -and (Test-Path -LiteralPath $changesetPath -PathType Leaf)) { Get-Content -Raw -LiteralPath $changesetPath } else { '{}' }
$changeset = if ($null -ne $changesetPath -and (Test-Path -LiteralPath $changesetPath -PathType Leaf)) { Read-JsonFile -Path $changesetPath } else { $null }
$validationReport = if ($null -ne $validationReportPath -and (Test-Path -LiteralPath $validationReportPath -PathType Leaf)) { Read-JsonFile -Path $validationReportPath } else { $null }
$validationReportJson = if ($null -ne $validationReportPath -and (Test-Path -LiteralPath $validationReportPath -PathType Leaf)) { Get-Content -Raw -LiteralPath $validationReportPath } else { '{}' }
$reviewReportText = if ($null -ne $reviewReportPath -and (Test-Path -LiteralPath $reviewReportPath -PathType Leaf)) { Get-Content -Raw -LiteralPath $reviewReportPath } else { '' }
$decisionLogText = if ($null -ne $decisionLogPath -and (Test-Path -LiteralPath $decisionLogPath -PathType Leaf)) { Get-Content -Raw -LiteralPath $decisionLogPath } else { '' }

$changedFiles = if ($null -ne $changeset) { @($changeset.changedFiles | ForEach-Object { [string] $_ }) } else { @() }
$shouldUpdateReadmes = if ($null -ne $routeSelection) { [bool] $routeSelection.readmeImpact } else { $false }
$shouldUpdateChangelog = if ($null -ne $routeSelection) { [bool] $routeSelection.changelogImpact } else { $false }
$readmeCandidatePaths = Get-ReadmeCandidatePaths -Root $resolvedRepoRoot -ChangedFiles $changedFiles -ReadmeImpact $shouldUpdateReadmes
$readmeCandidatesJson = ((Get-ReadmeCandidatePayload -Root $resolvedRepoRoot -Paths $readmeCandidatePaths) | ConvertTo-Json -Depth 20)
$changelogCandidateJson = ((Get-ChangelogCandidatePayload -Root $resolvedRepoRoot -ChangelogImpact $shouldUpdateChangelog) | ConvertTo-Json -Depth 20)

$failedChecks = if ($null -ne $validationReport) { [int] $validationReport.summary.failedChecks } else { 1 }
$reviewDecision = if ($decisionLogText -match 'Decision:\s*(?<decision>[a-z-]+)') { $Matches['decision'] } else { 'blocked' }

$shouldUseCodexDispatch = ($ExecutionBackend -eq 'codex-exec') -and ($DispatchMode -eq 'codex-exec')
$backendUsed = if ($shouldUseCodexDispatch) { 'codex-exec' } else { 'scripted' }
$dispatchError = $null
$closeoutResult = $null
$dispatchRecordPath = Join-Path $stageMetadataDirectory 'closeout-dispatch.json'
$dispatchResultPath = Join-Path $stageMetadataDirectory 'closeout-result.json'
$dispatchPromptPath = Join-Path $stageMetadataDirectory 'closeout-prompt.md'

if ($shouldUseCodexDispatch) {
    try {
        $templateText = Get-Content -Raw -LiteralPath $resolvedPromptTemplatePath
        $renderedPrompt = Expand-Template -TemplateText $templateText -Tokens @{
            REQUEST_TEXT = $requestContent
            SPEC_SUMMARY_JSON = $specSummaryJson
            ROUTE_SELECTION_JSON = $routeSelectionJson
            CHANGESET_JSON = $changesetJson
            VALIDATION_REPORT_JSON = $validationReportJson
            REVIEW_REPORT_TEXT = $reviewReportText
            DECISION_LOG_TEXT = $decisionLogText
            README_CANDIDATES_JSON = $readmeCandidatesJson
            CHANGELOG_CANDIDATE_JSON = $changelogCandidateJson
        }
        Set-Content -LiteralPath $dispatchPromptPath -Value $renderedPrompt -Encoding UTF8 -NoNewline

        $dispatchScriptPath = Join-Path $resolvedRepoRoot 'scripts/orchestration/engine/invoke-codex-dispatch.ps1'
        $dispatchParams = @{
            RepoRoot = $resolvedRepoRoot
            WorkingDirectory = $resolvedRepoRoot
            TraceId = $TraceId
            StageId = $StageId
            AgentId = $AgentId
            PromptPath = $dispatchPromptPath
            ResponseSchemaPath = $resolvedResponseSchemaPath
            ResultPath = $dispatchResultPath
            DispatchRecordPath = $dispatchRecordPath
            CommandName = $DispatchCommand
            Model = if ([string]::IsNullOrWhiteSpace($EffectiveModel)) { [string] $agent.model } else { $EffectiveModel }
            DetailedOutput = [bool] $DetailedOutput
        }
        & $dispatchScriptPath @dispatchParams
        $closeoutResult = Read-JsonFile -Path $dispatchResultPath
    }
    catch {
        $dispatchError = $_.Exception.Message
        Write-StyledOutput ("[WARN] Closeout live dispatch failed. Falling back to scripted mode. {0}" -f $dispatchError)
        $backendUsed = 'scripted'
    }
}

if ($null -eq $closeoutResult) {
    $closeoutResult = New-FallbackCloseoutResult -ReviewDecision $reviewDecision -FailedChecks $failedChecks
}

$closeoutReportPath = Join-Path $stageArtifactsDirectory 'closeout-report.json'
$releaseSummaryPath = Join-Path $stageArtifactsDirectory 'release-summary.md'
$completedPlanMetadataPath = Join-Path $stageArtifactsDirectory 'completed-plan.json'
$readmeUpdatesReportPath = Join-Path $stageArtifactsDirectory 'readme-updates.json'
$changelogUpdateReportPath = Join-Path $stageArtifactsDirectory 'changelog-update.json'

$completedPlanPath = $null
$planMoved = $false
$completedSpecPath = $null
$specMoved = $false
$appliedReadmeUpdates = @()
$appliedChangelogUpdate = [ordered]@{
    path = 'CHANGELOG.md'
    summary = 'No changelog update was applied.'
    applied = $false
    checksum = $null
}
if ($closeoutResult.status -eq 'ready-for-commit') {
    $appliedReadmeUpdates = Set-ReadmeUpdates -Root $resolvedRepoRoot -Updates @($closeoutResult.readmeUpdates)
    if ($null -ne $closeoutResult.changelogUpdate -and [bool] $closeoutResult.changelogUpdate.apply) {
        $appliedChangelogUpdate = Update-ChangelogFile -Root $resolvedRepoRoot -Update $closeoutResult.changelogUpdate
    }
}
if ($closeoutResult.status -eq 'ready-for-commit' -and -not [string]::IsNullOrWhiteSpace($activePlanPath) -and (Test-Path -LiteralPath $activePlanPath -PathType Leaf)) {
    $completedPlansDirectory = Join-Path $resolvedRepoRoot 'planning/completed'
    New-Item -ItemType Directory -Path $completedPlansDirectory -Force | Out-Null
    $completedPlanPath = Join-Path $completedPlansDirectory ([System.IO.Path]::GetFileName($activePlanPath))
    Move-ItemPreserveTimestamps -SourcePath $activePlanPath -Destination $completedPlanPath
    $planMoved = $true
}
if ($closeoutResult.status -eq 'ready-for-commit' -and -not [string]::IsNullOrWhiteSpace($activeSpecPath) -and (Test-Path -LiteralPath $activeSpecPath -PathType Leaf)) {
    $activeSpecRelativePath = Convert-ToRelativeRepoPath -Root $resolvedRepoRoot -Path $activeSpecPath
    if ($activeSpecRelativePath -like 'planning/specs/active/*') {
        $completedSpecsDirectory = Join-Path $resolvedRepoRoot 'planning/specs/completed'
        New-Item -ItemType Directory -Path $completedSpecsDirectory -Force | Out-Null
        $completedSpecPath = Join-Path $completedSpecsDirectory ([System.IO.Path]::GetFileName($activeSpecPath))
        Move-ItemPreserveTimestamps -SourcePath $activeSpecPath -Destination $completedSpecPath
        $specMoved = $true
    }
}

Write-JsonFile -Path $closeoutReportPath -Value $closeoutResult
Write-JsonFile -Path $readmeUpdatesReportPath -Value ([ordered]@{
        updated = (@($appliedReadmeUpdates).Count -gt 0)
        updates = @($appliedReadmeUpdates)
    })
Write-JsonFile -Path $changelogUpdateReportPath -Value $appliedChangelogUpdate

$releaseSummary = @(
    ('# Release Summary ({0})' -f $TraceId),
    '',
    ('- Stage: {0}' -f $StageId),
    ('- Agent: {0}' -f $AgentId),
    ('- Backend: {0}' -f $backendUsed),
    ('- Status: {0}' -f [string] $closeoutResult.status),
    ('- GeneratedAt: {0}' -f (Get-Date).ToString('o')),
    ('- README candidates: {0}' -f @($readmeCandidatePaths).Count),
    '',
    '## Summary',
    ('- {0}' -f [string] $closeoutResult.summary),
    '',
    '## Commit Message',
    ('- `{0}`' -f [string] $closeoutResult.commitMessage),
    '',
    '## Changelog Summary',
    ('- {0}' -f [string] $closeoutResult.changelogSummary),
    '',
    '## README Actions'
)
$releaseSummary += @($closeoutResult.readmeActions | ForEach-Object { '- ' + [string] $_ })
$releaseSummary += @(
    '',
    '## README Updates Applied'
)
if (@($appliedReadmeUpdates).Count -gt 0) {
    $releaseSummary += @($appliedReadmeUpdates | ForEach-Object { '- ' + [string] $_.path + ': ' + [string] $_.summary })
}
else {
    $releaseSummary += '- none'
}
$releaseSummary += @(
    '',
    '## CHANGELOG Update Applied'
)
if ([bool] $appliedChangelogUpdate.applied) {
    $releaseSummary += ('- {0}: {1}' -f [string] $appliedChangelogUpdate.path, [string] $appliedChangelogUpdate.summary)
}
else {
    $releaseSummary += ('- {0}' -f [string] $appliedChangelogUpdate.summary)
}
$releaseSummary += @(
    '',
    '## Follow-Ups'
)
$releaseSummary += @($closeoutResult.followUps | ForEach-Object { '- ' + [string] $_ })
$releaseSummary += @(
    '',
    ('- Active plan moved: {0}' -f $planMoved),
    ('- Active spec moved: {0}' -f $specMoved)
)
Set-Content -LiteralPath $releaseSummaryPath -Value ($releaseSummary -join "`n") -Encoding UTF8 -NoNewline

$completedPlanMetadata = [ordered]@{
    traceId = $TraceId
    stageId = $StageId
    agentId = $AgentId
    moved = $planMoved
    sourcePlanPath = if (-not [string]::IsNullOrWhiteSpace($activePlanPath)) { Convert-ToRelativeRepoPath -Root $resolvedRepoRoot -Path $activePlanPath } else { $null }
    completedPlanPath = if (-not [string]::IsNullOrWhiteSpace($completedPlanPath)) { Convert-ToRelativeRepoPath -Root $resolvedRepoRoot -Path $completedPlanPath } else { $null }
    specMoved = $specMoved
    sourceSpecPath = if (-not [string]::IsNullOrWhiteSpace($activeSpecPath)) { Convert-ToRelativeRepoPath -Root $resolvedRepoRoot -Path $activeSpecPath } else { $null }
    completedSpecPath = if (-not [string]::IsNullOrWhiteSpace($completedSpecPath)) { Convert-ToRelativeRepoPath -Root $resolvedRepoRoot -Path $completedSpecPath } else { $null }
}
Write-JsonFile -Path $completedPlanMetadataPath -Value $completedPlanMetadata

$outputManifest = [ordered]@{
    traceId = $TraceId
    stageId = $StageId
    agentId = $AgentId
    producedAt = (Get-Date).ToString('o')
    artifacts = @(
        (Get-ArtifactDescriptor -Name 'closeout-report' -Path $closeoutReportPath -Root $resolvedRepoRoot),
        (Get-ArtifactDescriptor -Name 'release-summary' -Path $releaseSummaryPath -Root $resolvedRepoRoot),
        (Get-ArtifactDescriptor -Name 'completed-plan' -Path $completedPlanMetadataPath -Root $resolvedRepoRoot),
        (Get-ArtifactDescriptor -Name 'readme-updates' -Path $readmeUpdatesReportPath -Root $resolvedRepoRoot),
        (Get-ArtifactDescriptor -Name 'changelog-update' -Path $changelogUpdateReportPath -Root $resolvedRepoRoot)
    )
}
Write-JsonFile -Path $resolvedOutputManifestPath -Value $outputManifest

$stageState = [ordered]@{
    traceId = $TraceId
    stageId = $StageId
    agentId = $AgentId
    backend = $backendUsed
    dispatchCount = if ($backendUsed -eq 'codex-exec') { 1 } else { 0 }
    completedPlanMoved = $planMoved
    completedSpecMoved = $specMoved
    readmeUpdateCount = @($appliedReadmeUpdates).Count
    changelogUpdated = [bool] $appliedChangelogUpdate.applied
    promptTemplatePath = if ($backendUsed -eq 'codex-exec') { Convert-ToRelativeRepoPath -Root $resolvedRepoRoot -Path $resolvedPromptTemplatePath } else { $null }
    responseSchemaPath = if ($backendUsed -eq 'codex-exec') { Convert-ToRelativeRepoPath -Root $resolvedRepoRoot -Path $resolvedResponseSchemaPath } else { $null }
    dispatchRecordPath = if ((Test-Path -LiteralPath $dispatchRecordPath -PathType Leaf)) { Convert-ToRelativeRepoPath -Root $resolvedRepoRoot -Path $dispatchRecordPath } else { $null }
    warning = $dispatchError
}
Write-JsonFile -Path $resolvedStageStatePath -Value $stageState

Write-VerboseLog ("Stage artifacts written: {0}" -f $resolvedOutputManifestPath)

if ($closeoutResult.status -eq 'blocked') {
    exit 1
}

exit 0
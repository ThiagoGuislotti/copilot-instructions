<#
.SYNOPSIS
    Runtime tests for the multi-agent orchestration engine without external frameworks.

.DESCRIPTION
    Validates end-to-end scripted orchestration behavior, artifact generation,
    and closeout side effects for the repository-owned agent pipeline.

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.EXAMPLE
    pwsh -File scripts/tests/runtime/agent-orchestration-engine.tests.ps1

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
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
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('repository-paths')
# Fails the current runtime test when the supplied condition is false.
function Assert-True {
    param(
        [bool] $Condition,
        [string] $Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

# Fails the current test when the actual and expected values differ.
function Assert-Equal {
    param(
        $Actual,
        $Expected,
        [string] $Message
    )

    if ($Actual -ne $Expected) {
        throw ("{0}. Expected '{1}', got '{2}'." -f $Message, $Expected, $Actual)
    }
}

# Writes deterministic JSON test content to disk.
function Write-JsonFile {
    param(
        [string] $Path,
        [object] $Value
    )

    $parent = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    Set-Content -LiteralPath $Path -Value ($Value | ConvertTo-Json -Depth 100) -Encoding UTF8 -NoNewline
}

$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N'))
$repoSmokeRoot = Join-Path $resolvedRepoRoot '.temp/agent-orchestration-engine-smoke'
$repoSmokeReadmePath = Join-Path $repoSmokeRoot 'README.md'
$repoSmokeChangelogPath = Join-Path $repoSmokeRoot 'CHANGELOG.md'
$createdCompletedPlanPath = $null
$createdCompletedSpecPath = $null
$preservedPlanningArtifacts = [ordered]@{}
$planningArtifactPathsToPreserve = @(
    'planning/active/plan-approval-denied-test-implement-enterprise-orchestration-support.md',
    'planning/specs/active/spec-approval-denied-test-implement-enterprise-orchestration-support.md',
    'planning/completed/plan-approval-denied-test-implement-enterprise-orchestration-support.md',
    'planning/specs/completed/spec-approval-denied-test-implement-enterprise-orchestration-support.md',
    'planning/active/plan-approval-approved-test-implement-enterprise-orchestration-support.md',
    'planning/specs/active/spec-approval-approved-test-implement-enterprise-orchestration-support.md',
    'planning/completed/plan-approval-approved-test-implement-enterprise-orchestration-support.md',
    'planning/specs/completed/spec-approval-approved-test-implement-enterprise-orchestration-support.md',
    'planning/active/plan-resume-source-test-implement-closeout-smoke-orchestration-support.md',
    'planning/specs/active/spec-resume-source-test-implement-enterprise-orchestration-support.md',
    'planning/completed/plan-resume-source-test-implement-closeout-smoke-orchestration-support.md',
    'planning/specs/completed/spec-resume-source-test-implement-enterprise-orchestration-support.md',
    'planning/active/plan-run-test-implement-closeout-smoke-orchestration-support.md',
    'planning/specs/active/spec-run-test-implement-enterprise-orchestration-support.md',
    'planning/completed/plan-run-test-implement-closeout-smoke-orchestration-support.md',
    'planning/specs/completed/spec-run-test-implement-enterprise-orchestration-support.md',
    'planning/active/plan-implement-closeout-smoke-orchestration-support.md',
    'planning/specs/active/spec-implement-enterprise-orchestration-support.md',
    'planning/completed/plan-implement-closeout-smoke-orchestration-support.md',
    'planning/specs/completed/spec-implement-enterprise-orchestration-support.md'
)
$activePlanLastWriteTimeUtc = $null
$activeSpecLastWriteTimeUtc = $null
$testExitCode = 1

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $repoSmokeRoot -Force | Out-Null
    Set-Content -LiteralPath $repoSmokeReadmePath -Value '# Runtime Smoke README' -Encoding UTF8 -NoNewline
    Set-Content -LiteralPath $repoSmokeChangelogPath -Value '## [0.0.0] - 2026-03-20' -Encoding UTF8 -NoNewline
    foreach ($relativePath in $planningArtifactPathsToPreserve) {
        $absolutePath = Join-Path $resolvedRepoRoot $relativePath
        if (Test-Path -LiteralPath $absolutePath -PathType Leaf) {
            $preservedPlanningArtifacts[$absolutePath] = [ordered]@{
                bytes = [System.IO.File]::ReadAllBytes($absolutePath)
                lastWriteTimeUtc = (Get-Item -LiteralPath $absolutePath).LastWriteTimeUtc
            }
        }
    }
    $fakeCodexRunnerPath = Join-Path $tempRoot 'fake-codex-runner.ps1'
    $fakeCodexPath = Join-Path $tempRoot 'fake-codex.cmd'
    $fakeCodex = @'
param(
    [Parameter(ValueFromPipeline = $true)] [string] $IgnoredPipelineInput,
    [string] $RawArgs
)

begin {
    $allInput = ''
}
process {
    if ($null -ne $IgnoredPipelineInput) {
        $allInput += $IgnoredPipelineInput + "`n"
    }
}
end {
    if ([string]::IsNullOrWhiteSpace($allInput)) {
        $allInput = [Console]::In.ReadToEnd()
    }

    $RemainingArgs = @()
    if (-not [string]::IsNullOrWhiteSpace($RawArgs)) {
        $RemainingArgs = @($RawArgs.Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries))
    }

    $outputPath = $null
    for ($i = 0; $i -lt $RemainingArgs.Count; $i++) {
        if ($RemainingArgs[$i] -eq '-o' -and ($i + 1) -lt $RemainingArgs.Count) {
            $outputPath = $RemainingArgs[$i + 1]
        }
    }

    if ([string]::IsNullOrWhiteSpace($outputPath)) {
        throw 'Fake codex did not receive -o output path.'
    }

    if ($allInput -match '# Specification Stage Contract') {
        $payload = [ordered]@{
            stage = 'brainstorm-spec'
            status = 'required'
            specRequired = $true
            workstreamSlug = 'implement-enterprise-orchestration-support'
            specSummary = 'A versioned design checkpoint is required before planning.'
            designDecisions = @(
                'Keep a versioned spec separate from the execution plan.',
                'Lock the normalized request before creating work items.'
            )
            alternativesConsidered = @('Skipping the spec and planning directly from intake.')
            assumptions = @('Repository policy remains authoritative.')
            risks = @('Skipping the spec would blur design and execution intent.')
            acceptanceCriteria = @('A spec file exists.', 'Planning receives the spec summary.')
            planningReadiness = 'ready-for-plan'
            recommendedSpecialists = @('dev-dotnet-backend-engineer')
            notes = @('Mock spec agent prepared the workstream for planning.')
        }
    }
    elseif ($allInput -match '# Planner Stage Contract') {
        $payload = [ordered]@{
            objective = 'Deliver the requested change with deterministic validation.'
            scopeSummary = 'Planner produced two sequential work items for the request.'
            assumptions = @('Repository rules stay authoritative.')
            acceptanceCriteria = @('Changes are implemented.', 'Validation artifacts are ready.')
            workItems = @(
                [ordered]@{
                    id = 'task-one'
                    title = 'Prepare first change'
                    description = 'First planned task.'
                    dependsOn = @()
                    allowedPaths = @('scripts/**', '.github/**')
                    targetPaths = @('scripts/orchestration/stages/plan-stage.ps1')
                    commands = @(
                        [ordered]@{
                            purpose = 'targeted validation'
                            command = 'pwsh -File scripts/validation/validate-runtime-script-tests.ps1 -RepoRoot . -WarningOnly:$false'
                            expectedOutcome = 'Runtime tests pass after the first task.'
                        }
                    )
                    checkpoints = @(
                        [ordered]@{
                            name = 'first-task-baseline'
                            expectedOutcome = 'expected-verified'
                            evidence = 'Planner confirmed the first task scope and target file before implementation.'
                        },
                        [ordered]@{
                            name = 'first-task-green'
                            expectedOutcome = 'expected-pass'
                            command = 'pwsh -File scripts/validation/validate-runtime-script-tests.ps1 -RepoRoot . -WarningOnly:$false'
                            evidence = 'Runtime tests pass after the first task.'
                        }
                    )
                    commitCheckpoint = [ordered]@{
                        scope = 'task'
                        when = 'After the first task is validated.'
                        suggestedMessage = 'feat: complete first orchestration task checkpoint'
                    }
                    deliverables = @('First deliverable')
                    validationSteps = @('Run focused checks.')
                    successCriteria = @('First task completes cleanly.')
                },
                [ordered]@{
                    id = 'task-two'
                    title = 'Prepare second change'
                    description = 'Second planned task.'
                    dependsOn = @('task-one')
                    allowedPaths = @('scripts/**', '.github/**')
                    targetPaths = @('scripts/orchestration/stages/implement-stage.ps1')
                    commands = @(
                        [ordered]@{
                            purpose = 'targeted validation'
                            command = 'pwsh -File scripts/validation/validate-runtime-script-tests.ps1 -RepoRoot . -WarningOnly:$false'
                            expectedOutcome = 'Runtime tests pass after the second task.'
                        }
                    )
                    checkpoints = @(
                        [ordered]@{
                            name = 'second-task-baseline'
                            expectedOutcome = 'expected-verified'
                            evidence = 'Planner confirmed the second task scope and target file before implementation.'
                        },
                        [ordered]@{
                            name = 'second-task-green'
                            expectedOutcome = 'expected-pass'
                            command = 'pwsh -File scripts/validation/validate-runtime-script-tests.ps1 -RepoRoot . -WarningOnly:$false'
                            evidence = 'Runtime tests pass after the second task.'
                        }
                    )
                    commitCheckpoint = [ordered]@{
                        scope = 'slice'
                        when = 'After the second task is validated and the slice is stable.'
                        suggestedMessage = 'feat: complete second orchestration task checkpoint'
                    }
                    deliverables = @('Second deliverable')
                    validationSteps = @('Run focused checks.')
                    successCriteria = @('Second task completes cleanly.')
                }
            )
            contextPaths = @('.github/AGENTS.md', '.github/copilot-instructions.md')
            validations = @('Run repository validation stage.')
            risks = @('None in mock flow.')
            deliverySlices = @(
                [ordered]@{ name = 'phase-1'; goal = 'Plan and execute sequential tasks.' }
            )
        }
    }
    elseif ($allInput -match '# Router Stage Contract') {
        $payload = [ordered]@{
            summary = 'Router selected a backend-oriented specialist focus.'
            recommendedSpecialistSkill = 'dev-dotnet-backend-engineer'
            recommendedSpecialistFocus = '.NET backend implementation and validation.'
            contextPaths = @(
                '.github/AGENTS.md',
                '.github/copilot-instructions.md',
                '.github/instructions/subagent-planning-workflow.instructions.md'
            )
            tokenBudgetGuidance = @('Load only routed files.', 'Keep prompts focused on the current work item.')
            executionNotes = @('Apply the routed focus to all work items.')
            validationFocus = @('Run validation after implementation.')
            closeoutExpectations = @('Prepare commit and changelog summary.')
            shouldRunTester = $true
            readmeImpact = $true
            changelogImpact = $true
        }
    }
    elseif ($allInput -match '# Super Agent Intake Stage Contract') {
        $normalizedRequest = 'Implement enterprise orchestration support.'
        $workstreamSlug = 'implement-enterprise-orchestration-support'
        if ($allInput -match 'Implement closeout smoke orchestration support\.') {
            $normalizedRequest = 'Implement closeout smoke orchestration support.'
            $workstreamSlug = 'implement-closeout-smoke-orchestration-support'
        }

        $payload = [ordered]@{
            stage = 'super-agent-intake'
            normalizedRequest = $normalizedRequest
            changeBearing = $true
            planningRequired = $true
            clarificationRequired = $false
            canProceedSafely = $true
            workstreamSlug = $workstreamSlug
            explicitWorkItems = @('Normalize request', 'Plan execution')
            clarificationQuestions = @()
            clarificationReason = $null
            constraints = @('Preserve repository policy and validation gates.')
            risks = @('Skipping planning would violate the lifecycle.')
            notes = @('Use sequential execution unless the planner proves tasks are parallel-safe.')
        }
    }
    elseif ($allInput -match '# Executor Task Contract') {
        $taskId = 'task-generic'
        if ($allInput -match '"id"\s*:\s*"(?<taskId>[a-z0-9-]+)"') {
            $taskId = $Matches['taskId']
        }

        $payload = [ordered]@{
            taskId = $taskId
            status = 'completed'
            summary = "Completed $taskId in fake execution mode."
            changedFiles = @()
            validationsPerformed = @('Prepared downstream validation artifacts.')
            residualRisks = @()
            notes = @('Mock executor produced no file changes.')
            commitReady = $true
        }
    }
    elseif ($allInput -match '# Task Spec Review Contract') {
        $payload = [ordered]@{
            reviewType = 'spec-compliance'
            decision = 'approved'
            summary = 'Mock spec review approved the task.'
            findings = @()
            followUps = @()
        }
    }
    elseif ($allInput -match '# Task Code Quality Review Contract') {
        $payload = [ordered]@{
            reviewType = 'code-quality'
            decision = 'approved'
            summary = 'Mock code-quality review approved the task.'
            findings = @()
            followUps = @()
        }
    }
    elseif ($allInput -match '# Reviewer Stage Contract') {
        $payload = [ordered]@{
            decision = 'approved'
            summary = 'Mock reviewer approved the change set.'
            findings = @()
            requiredFollowUps = @()
            recommendation = 'Proceed with delivery.'
        }
    }
    elseif ($allInput -match '# Closeout Stage Contract') {
        $payload = [ordered]@{
            status = 'ready-for-commit'
            summary = 'Mock closeout produced commit-ready artifacts.'
            readmeActions = @('README already aligned for mock flow.')
            readmeUpdates = @(
                [ordered]@{
                    path = '.temp/agent-orchestration-engine-smoke/README.md'
                    summary = 'Refresh the temporary README from the closeout stage.'
                    content = "# Runtime Smoke README`n`nCloseout automation updated this README during the orchestration smoke test."
                }
            )
            commitMessage = 'feat: close orchestration smoke test'
            changelogSummary = 'Close the orchestration smoke test plan.'
            changelogUpdate = [ordered]@{
                apply = $true
                path = '.temp/agent-orchestration-engine-smoke/CHANGELOG.md'
                summary = 'Record closeout documentation automation coverage in the temporary changelog.'
                entry = "## [9.9.9] - 2026-03-20`n`n### Changed`n- Added smoke-test coverage for closeout-driven README and CHANGELOG updates."
            }
            followUps = @()
        }
    }
    else {
        throw 'Fake codex received an unknown prompt contract.'
    }

    Set-Content -LiteralPath $outputPath -Value ($payload | ConvertTo-Json -Depth 100) -Encoding UTF8 -NoNewline
}
'@
    Set-Content -LiteralPath $fakeCodexRunnerPath -Value $fakeCodex -Encoding UTF8 -NoNewline
    $fakeCodexCmd = "@echo off`r`nsetlocal`r`nset FAKE_CODEX_ARGS=%*`r`npwsh -NoProfile -File `"$fakeCodexRunnerPath`" -RawArgs `"%FAKE_CODEX_ARGS%`"`r`n"
    Set-Content -LiteralPath $fakeCodexPath -Value $fakeCodexCmd -Encoding ASCII -NoNewline

    $runDirectory = Join-Path $tempRoot 'run'
    New-Item -ItemType Directory -Path (Join-Path $runDirectory 'artifacts') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $runDirectory 'stages') -Force | Out-Null

    $requestPath = Join-Path $runDirectory 'artifacts/request.md'
    Set-Content -LiteralPath $requestPath -Value 'Implement closeout smoke orchestration support.' -Encoding UTF8 -NoNewline

    $intakeOutputManifestPath = Join-Path $runDirectory 'stages/intake-output.json'
    & (Join-Path $resolvedRepoRoot 'scripts/orchestration/stages/intake-stage.ps1') `
        -RepoRoot $resolvedRepoRoot `
        -RunDirectory $runDirectory `
        -TraceId 'run-test' `
        -StageId 'intake' `
        -AgentId 'super-agent' `
        -RequestPath $requestPath `
        -OutputArtifactManifestPath $intakeOutputManifestPath `
        -DispatchMode 'codex-exec' `
        -PromptTemplatePath '.codex/orchestration/prompts/super-agent-intake-stage.prompt.md' `
        -ResponseSchemaPath '.github/schemas/agent.stage-intake-result.schema.json' `
        -DispatchCommand $fakeCodexPath `
        -ExecutionBackend 'codex-exec' | Out-Null
    Assert-Equal -Actual ([int] $LASTEXITCODE) -Expected 0 -Message 'Intake stage should succeed with fake Codex.'

    $intakeManifest = Get-Content -Raw -LiteralPath $intakeOutputManifestPath | ConvertFrom-Json -Depth 100
    $intakeArtifacts = @{}
    foreach ($artifact in @($intakeManifest.artifacts)) {
        $intakeArtifacts[[string] $artifact.name] = Join-Path $resolvedRepoRoot ([string] $artifact.path)
    }
    $intakeReport = Get-Content -Raw -LiteralPath $intakeArtifacts['intake-report'] | ConvertFrom-Json -Depth 100
    Assert-True ([bool] $intakeReport.planningRequired) 'Intake stage should require planning in the fake flow.'

    $specOutputManifestPath = Join-Path $runDirectory 'stages/spec-output.json'
    & (Join-Path $resolvedRepoRoot 'scripts/orchestration/stages/spec-stage.ps1') `
        -RepoRoot $resolvedRepoRoot `
        -RunDirectory $runDirectory `
        -TraceId 'run-test' `
        -StageId 'spec' `
        -AgentId 'brainstormer' `
        -RequestPath $requestPath `
        -InputArtifactManifestPath $intakeOutputManifestPath `
        -OutputArtifactManifestPath $specOutputManifestPath `
        -DispatchMode 'codex-exec' `
        -PromptTemplatePath '.codex/orchestration/prompts/spec-stage.prompt.md' `
        -ResponseSchemaPath '.github/schemas/agent.stage-spec-result.schema.json' `
        -DispatchCommand $fakeCodexPath `
        -ExecutionBackend 'codex-exec' | Out-Null
    Assert-Equal -Actual ([int] $LASTEXITCODE) -Expected 0 -Message 'Spec stage should succeed with fake Codex.'

    $specManifest = Get-Content -Raw -LiteralPath $specOutputManifestPath | ConvertFrom-Json -Depth 100
    $specArtifacts = @{}
    foreach ($artifact in @($specManifest.artifacts)) {
        $specArtifacts[[string] $artifact.name] = Join-Path $resolvedRepoRoot ([string] $artifact.path)
    }
    $specSummary = Get-Content -Raw -LiteralPath $specArtifacts['spec-summary'] | ConvertFrom-Json -Depth 100
    Assert-True ([bool] $specSummary.specRequired) 'Spec stage should require a versioned spec in the fake flow.'
    Assert-True (Test-Path -LiteralPath $specArtifacts['active-spec'] -PathType Leaf) 'Spec stage should produce an active spec file.'
    $activeSpecContent = Get-Content -Raw -LiteralPath $specArtifacts['active-spec']
    Assert-True ($activeSpecContent -notmatch 'GeneratedAt:') 'Versioned active spec should not include volatile GeneratedAt metadata.'
    $activeSpecLastWriteTimeUtc = (Get-Item -LiteralPath $specArtifacts['active-spec']).LastWriteTimeUtc

    $planOutputManifestPath = Join-Path $runDirectory 'stages/plan-output.json'
    & (Join-Path $resolvedRepoRoot 'scripts/orchestration/stages/plan-stage.ps1') `
        -RepoRoot $resolvedRepoRoot `
        -RunDirectory $runDirectory `
        -TraceId 'run-test' `
        -StageId 'plan' `
        -AgentId 'planner' `
        -RequestPath $requestPath `
        -InputArtifactManifestPath $specOutputManifestPath `
        -OutputArtifactManifestPath $planOutputManifestPath `
        -DispatchMode 'codex-exec' `
        -PromptTemplatePath '.codex/orchestration/prompts/planner-stage.prompt.md' `
        -ResponseSchemaPath '.github/schemas/agent.stage-plan-result.schema.json' `
        -DispatchCommand $fakeCodexPath `
        -ExecutionBackend 'codex-exec' | Out-Null
    Assert-Equal -Actual ([int] $LASTEXITCODE) -Expected 0 -Message 'Plan stage should succeed with fake Codex.'

    $planManifest = Get-Content -Raw -LiteralPath $planOutputManifestPath | ConvertFrom-Json -Depth 100
    $planArtifacts = @{}
    foreach ($artifact in @($planManifest.artifacts)) {
        $planArtifacts[[string] $artifact.name] = Join-Path $resolvedRepoRoot ([string] $artifact.path)
    }
    $taskPlanData = Get-Content -Raw -LiteralPath $planArtifacts['task-plan-data'] | ConvertFrom-Json -Depth 100
    Assert-Equal -Actual @($taskPlanData.workItems).Count -Expected 2 -Message 'Plan stage should produce two work items in fake flow.'
    Assert-Equal -Actual @($taskPlanData.workItems[0].targetPaths).Count -Expected 1 -Message 'Plan stage should emit target paths per work item.'
    Assert-Equal -Actual @($taskPlanData.workItems[0].commands).Count -Expected 1 -Message 'Plan stage should emit explicit commands per work item.'
    Assert-Equal -Actual @($taskPlanData.workItems[0].checkpoints).Count -Expected 2 -Message 'Plan stage should emit checkpoints per work item.'
    Assert-Equal -Actual ([string] $taskPlanData.workItems[0].commitCheckpoint.scope) -Expected 'task' -Message 'Plan stage should emit commit checkpoints per work item.'
    Assert-True (Test-Path -LiteralPath $planArtifacts['active-plan'] -PathType Leaf) 'Plan stage should produce an active plan file.'
    $activePlanContent = Get-Content -Raw -LiteralPath $planArtifacts['active-plan']
    Assert-True ($activePlanContent -notmatch 'GeneratedAt:') 'Versioned active plan should not include volatile GeneratedAt metadata.'
    $activePlanLastWriteTimeUtc = (Get-Item -LiteralPath $planArtifacts['active-plan']).LastWriteTimeUtc

    Start-Sleep -Milliseconds 1200

    & (Join-Path $resolvedRepoRoot 'scripts/orchestration/stages/spec-stage.ps1') `
        -RepoRoot $resolvedRepoRoot `
        -RunDirectory $runDirectory `
        -TraceId 'run-test' `
        -StageId 'spec' `
        -AgentId 'brainstormer' `
        -RequestPath $requestPath `
        -InputArtifactManifestPath $intakeOutputManifestPath `
        -OutputArtifactManifestPath $specOutputManifestPath `
        -DispatchMode 'codex-exec' `
        -PromptTemplatePath '.codex/orchestration/prompts/spec-stage.prompt.md' `
        -ResponseSchemaPath '.github/schemas/agent.stage-spec-result.schema.json' `
        -DispatchCommand $fakeCodexPath `
        -ExecutionBackend 'codex-exec' | Out-Null
    Assert-Equal -Actual ([int] $LASTEXITCODE) -Expected 0 -Message 'Repeated spec stage should succeed with fake Codex.'
    $specManifest = Get-Content -Raw -LiteralPath $specOutputManifestPath | ConvertFrom-Json -Depth 100
    $specArtifacts = @{}
    foreach ($artifact in @($specManifest.artifacts)) {
        $specArtifacts[[string] $artifact.name] = Join-Path $resolvedRepoRoot ([string] $artifact.path)
    }
    Assert-Equal -Actual ((Get-Item -LiteralPath $specArtifacts['active-spec']).LastWriteTimeUtc) -Expected $activeSpecLastWriteTimeUtc -Message 'Repeated spec stage should not rewrite the versioned spec when content is unchanged.'

    & (Join-Path $resolvedRepoRoot 'scripts/orchestration/stages/plan-stage.ps1') `
        -RepoRoot $resolvedRepoRoot `
        -RunDirectory $runDirectory `
        -TraceId 'run-test' `
        -StageId 'plan' `
        -AgentId 'planner' `
        -RequestPath $requestPath `
        -InputArtifactManifestPath $specOutputManifestPath `
        -OutputArtifactManifestPath $planOutputManifestPath `
        -DispatchMode 'codex-exec' `
        -PromptTemplatePath '.codex/orchestration/prompts/planner-stage.prompt.md' `
        -ResponseSchemaPath '.github/schemas/agent.stage-plan-result.schema.json' `
        -DispatchCommand $fakeCodexPath `
        -ExecutionBackend 'codex-exec' | Out-Null
    Assert-Equal -Actual ([int] $LASTEXITCODE) -Expected 0 -Message 'Repeated plan stage should succeed with fake Codex.'
    $planManifest = Get-Content -Raw -LiteralPath $planOutputManifestPath | ConvertFrom-Json -Depth 100
    $planArtifacts = @{}
    foreach ($artifact in @($planManifest.artifacts)) {
        $planArtifacts[[string] $artifact.name] = Join-Path $resolvedRepoRoot ([string] $artifact.path)
    }
    Assert-Equal -Actual ((Get-Item -LiteralPath $planArtifacts['active-plan']).LastWriteTimeUtc) -Expected $activePlanLastWriteTimeUtc -Message 'Repeated plan stage should not rewrite the versioned plan when content is unchanged.'

    $routeInputManifestPath = Join-Path $runDirectory 'stages/route-input.json'
    Write-JsonFile -Path $routeInputManifestPath -Value ([ordered]@{
            traceId = 'run-test'
            stageId = 'route'
            agentId = 'router'
            producedAt = (Get-Date).ToString('o')
            artifacts = @($intakeManifest.artifacts + $specManifest.artifacts + $planManifest.artifacts)
        })
    $routeOutputManifestPath = Join-Path $runDirectory 'stages/route-output.json'
    & (Join-Path $resolvedRepoRoot 'scripts/orchestration/stages/route-stage.ps1') `
        -RepoRoot $resolvedRepoRoot `
        -RunDirectory $runDirectory `
        -TraceId 'run-test' `
        -StageId 'route' `
        -AgentId 'router' `
        -RequestPath $requestPath `
        -InputArtifactManifestPath $routeInputManifestPath `
        -OutputArtifactManifestPath $routeOutputManifestPath `
        -DispatchMode 'codex-exec' `
        -PromptTemplatePath '.codex/orchestration/prompts/router-stage.prompt.md' `
        -ResponseSchemaPath '.github/schemas/agent.stage-route-result.schema.json' `
        -DispatchCommand $fakeCodexPath `
        -ExecutionBackend 'codex-exec' | Out-Null
    Assert-Equal -Actual ([int] $LASTEXITCODE) -Expected 0 -Message 'Route stage should succeed with fake Codex.'

    $routeManifest = Get-Content -Raw -LiteralPath $routeOutputManifestPath | ConvertFrom-Json -Depth 100
    $routeArtifacts = @{}
    foreach ($artifact in @($routeManifest.artifacts)) {
        $routeArtifacts[[string] $artifact.name] = Join-Path $resolvedRepoRoot ([string] $artifact.path)
    }
    $routeSelection = Get-Content -Raw -LiteralPath $routeArtifacts['route-selection'] | ConvertFrom-Json -Depth 100
    Assert-Equal -Actual $routeSelection.recommendedSpecialistSkill -Expected 'dev-dotnet-backend-engineer' -Message 'Route stage should surface the routed specialist skill.'

    $implementInputManifestPath = Join-Path $runDirectory 'stages/implement-input.json'
    Write-JsonFile -Path $implementInputManifestPath -Value ([ordered]@{
            traceId = 'run-test'
            stageId = 'implement'
            agentId = 'specialist'
            producedAt = (Get-Date).ToString('o')
            artifacts = @($intakeManifest.artifacts + $specManifest.artifacts + $planManifest.artifacts + $routeManifest.artifacts)
        })
    $implementOutputManifestPath = Join-Path $runDirectory 'stages/implement-output.json'
    & (Join-Path $resolvedRepoRoot 'scripts/orchestration/stages/implement-stage.ps1') `
        -RepoRoot $resolvedRepoRoot `
        -RunDirectory $runDirectory `
        -TraceId 'run-test' `
        -StageId 'implement' `
        -AgentId 'specialist' `
        -RequestPath $requestPath `
        -InputArtifactManifestPath $implementInputManifestPath `
        -OutputArtifactManifestPath $implementOutputManifestPath `
        -DispatchMode 'codex-exec' `
        -PromptTemplatePath '.codex/orchestration/prompts/executor-task.prompt.md' `
        -ResponseSchemaPath '.github/schemas/agent.stage-implementation-result.schema.json' `
        -DispatchCommand $fakeCodexPath `
        -ExecutionBackend 'codex-exec' | Out-Null
    Assert-Equal -Actual ([int] $LASTEXITCODE) -Expected 0 -Message 'Implement stage should succeed with fake Codex.'

    $implementManifest = Get-Content -Raw -LiteralPath $implementOutputManifestPath | ConvertFrom-Json -Depth 100
    $implementArtifacts = @{}
    foreach ($artifact in @($implementManifest.artifacts)) {
        $implementArtifacts[[string] $artifact.name] = Join-Path $resolvedRepoRoot ([string] $artifact.path)
    }
    $dispatches = Get-Content -Raw -LiteralPath $implementArtifacts['implementation-dispatches'] | ConvertFrom-Json -Depth 100
    Assert-Equal -Actual @($dispatches.tasks).Count -Expected 2 -Message 'Implement stage should dispatch each planned work item.'
    Assert-True ($implementArtifacts.ContainsKey('task-review-report')) 'Implement stage should emit the task-review-report artifact.'

    $validateInputManifestPath = Join-Path $runDirectory 'stages/validate-input.json'
    Write-JsonFile -Path $validateInputManifestPath -Value ([ordered]@{
            traceId = 'run-test'
            stageId = 'validate'
            agentId = 'tester'
            producedAt = (Get-Date).ToString('o')
            artifacts = @($implementManifest.artifacts + $routeManifest.artifacts + $planManifest.artifacts)
        })
    $validateOutputManifestPath = Join-Path $runDirectory 'stages/validate-output.json'
    & (Join-Path $resolvedRepoRoot 'scripts/orchestration/stages/validate-stage.ps1') `
        -RepoRoot $resolvedRepoRoot `
        -RunDirectory $runDirectory `
        -TraceId 'run-test' `
        -StageId 'validate' `
        -AgentId 'tester' `
        -RequestPath $requestPath `
        -InputArtifactManifestPath $validateInputManifestPath `
        -OutputArtifactManifestPath $validateOutputManifestPath | Out-Null
    Assert-Equal -Actual ([int] $LASTEXITCODE) -Expected 0 -Message 'Validate stage should succeed.'

    $validateManifest = Get-Content -Raw -LiteralPath $validateOutputManifestPath | ConvertFrom-Json -Depth 100
    $validateArtifacts = @{}
    foreach ($artifact in @($validateManifest.artifacts)) {
        $validateArtifacts[[string] $artifact.name] = Join-Path $resolvedRepoRoot ([string] $artifact.path)
    }

    $reviewInputManifestPath = Join-Path $runDirectory 'stages/review-input.json'
    Write-JsonFile -Path $reviewInputManifestPath -Value ([ordered]@{
            traceId = 'run-test'
            stageId = 'review'
            agentId = 'reviewer'
            producedAt = (Get-Date).ToString('o')
            artifacts = @(
                [ordered]@{ name = 'spec-summary'; path = [System.IO.Path]::GetRelativePath($resolvedRepoRoot, $specArtifacts['spec-summary']) -replace '\\', '/' },
                [ordered]@{ name = 'active-spec'; path = [System.IO.Path]::GetRelativePath($resolvedRepoRoot, $specArtifacts['active-spec']) -replace '\\', '/' },
                [ordered]@{ name = 'changeset'; path = [System.IO.Path]::GetRelativePath($resolvedRepoRoot, $implementArtifacts['changeset']) -replace '\\', '/' },
                [ordered]@{ name = 'validation-report'; path = [System.IO.Path]::GetRelativePath($resolvedRepoRoot, $validateArtifacts['validation-report']) -replace '\\', '/' },
                [ordered]@{ name = 'route-selection'; path = [System.IO.Path]::GetRelativePath($resolvedRepoRoot, $routeArtifacts['route-selection']) -replace '\\', '/' },
                [ordered]@{ name = 'task-review-report'; path = [System.IO.Path]::GetRelativePath($resolvedRepoRoot, $implementArtifacts['task-review-report']) -replace '\\', '/' },
                [ordered]@{ name = 'active-plan'; path = [System.IO.Path]::GetRelativePath($resolvedRepoRoot, $planArtifacts['active-plan']) -replace '\\', '/' }
            )
        })
    $reviewOutputManifestPath = Join-Path $runDirectory 'stages/review-output.json'
    & (Join-Path $resolvedRepoRoot 'scripts/orchestration/stages/review-stage.ps1') `
        -RepoRoot $resolvedRepoRoot `
        -RunDirectory $runDirectory `
        -TraceId 'run-test' `
        -StageId 'review' `
        -AgentId 'reviewer' `
        -RequestPath $requestPath `
        -InputArtifactManifestPath $reviewInputManifestPath `
        -OutputArtifactManifestPath $reviewOutputManifestPath `
        -DispatchMode 'codex-exec' `
        -PromptTemplatePath '.codex/orchestration/prompts/reviewer-stage.prompt.md' `
        -ResponseSchemaPath '.github/schemas/agent.stage-review-result.schema.json' `
        -DispatchCommand $fakeCodexPath `
        -ExecutionBackend 'codex-exec' | Out-Null
    Assert-Equal -Actual ([int] $LASTEXITCODE) -Expected 0 -Message 'Review stage should succeed with fake Codex.'

    $reviewManifest = Get-Content -Raw -LiteralPath $reviewOutputManifestPath | ConvertFrom-Json -Depth 100
    $reviewArtifacts = @{}
    foreach ($artifact in @($reviewManifest.artifacts)) {
        $reviewArtifacts[[string] $artifact.name] = Join-Path $resolvedRepoRoot ([string] $artifact.path)
    }

    $closeoutInputManifestPath = Join-Path $runDirectory 'stages/closeout-input.json'
    Write-JsonFile -Path $closeoutInputManifestPath -Value ([ordered]@{
            traceId = 'run-test'
            stageId = 'closeout'
            agentId = 'release-engineer'
            producedAt = (Get-Date).ToString('o')
            artifacts = @(
                [ordered]@{ name = 'spec-summary'; path = [System.IO.Path]::GetRelativePath($resolvedRepoRoot, $specArtifacts['spec-summary']) -replace '\\', '/' },
                [ordered]@{ name = 'active-spec'; path = [System.IO.Path]::GetRelativePath($resolvedRepoRoot, $specArtifacts['active-spec']) -replace '\\', '/' },
                [ordered]@{ name = 'route-selection'; path = [System.IO.Path]::GetRelativePath($resolvedRepoRoot, $routeArtifacts['route-selection']) -replace '\\', '/' },
                [ordered]@{ name = 'changeset'; path = [System.IO.Path]::GetRelativePath($resolvedRepoRoot, $implementArtifacts['changeset']) -replace '\\', '/' },
                [ordered]@{ name = 'validation-report'; path = [System.IO.Path]::GetRelativePath($resolvedRepoRoot, $validateArtifacts['validation-report']) -replace '\\', '/' },
                [ordered]@{ name = 'task-review-report'; path = [System.IO.Path]::GetRelativePath($resolvedRepoRoot, $implementArtifacts['task-review-report']) -replace '\\', '/' },
                [ordered]@{ name = 'review-report'; path = [System.IO.Path]::GetRelativePath($resolvedRepoRoot, $reviewArtifacts['review-report']) -replace '\\', '/' },
                [ordered]@{ name = 'decision-log'; path = [System.IO.Path]::GetRelativePath($resolvedRepoRoot, $reviewArtifacts['decision-log']) -replace '\\', '/' },
                [ordered]@{ name = 'active-plan'; path = [System.IO.Path]::GetRelativePath($resolvedRepoRoot, $planArtifacts['active-plan']) -replace '\\', '/' }
            )
        })
    $closeoutOutputManifestPath = Join-Path $runDirectory 'stages/closeout-output.json'
    & (Join-Path $resolvedRepoRoot 'scripts/orchestration/stages/closeout-stage.ps1') `
        -RepoRoot $resolvedRepoRoot `
        -RunDirectory $runDirectory `
        -TraceId 'run-test' `
        -StageId 'closeout' `
        -AgentId 'release-engineer' `
        -RequestPath $requestPath `
        -InputArtifactManifestPath $closeoutInputManifestPath `
        -OutputArtifactManifestPath $closeoutOutputManifestPath `
        -DispatchMode 'codex-exec' `
        -PromptTemplatePath '.codex/orchestration/prompts/closeout-stage.prompt.md' `
        -ResponseSchemaPath '.github/schemas/agent.stage-closeout-result.schema.json' `
        -DispatchCommand $fakeCodexPath `
        -ExecutionBackend 'codex-exec' | Out-Null
    Assert-Equal -Actual ([int] $LASTEXITCODE) -Expected 0 -Message 'Closeout stage should succeed with fake Codex.'

    $closeoutManifest = Get-Content -Raw -LiteralPath $closeoutOutputManifestPath | ConvertFrom-Json -Depth 100
    $closeoutArtifacts = @{}
    foreach ($artifact in @($closeoutManifest.artifacts)) {
        $closeoutArtifacts[[string] $artifact.name] = Join-Path $resolvedRepoRoot ([string] $artifact.path)
    }
    $closeoutReport = Get-Content -Raw -LiteralPath $closeoutArtifacts['closeout-report'] | ConvertFrom-Json -Depth 100
    $readmeUpdatesReport = Get-Content -Raw -LiteralPath $closeoutArtifacts['readme-updates'] | ConvertFrom-Json -Depth 100
    $changelogUpdateReport = Get-Content -Raw -LiteralPath $closeoutArtifacts['changelog-update'] | ConvertFrom-Json -Depth 100
    $completedPlanMetadata = Get-Content -Raw -LiteralPath $closeoutArtifacts['completed-plan'] | ConvertFrom-Json -Depth 100
    $createdCompletedPlanPath = if (-not [string]::IsNullOrWhiteSpace([string] $completedPlanMetadata.completedPlanPath)) {
        Join-Path $resolvedRepoRoot ([string] $completedPlanMetadata.completedPlanPath)
    }
    else {
        Join-Path $resolvedRepoRoot ('planning/completed/{0}' -f [System.IO.Path]::GetFileName([string] $planArtifacts['active-plan']))
    }
    $createdCompletedSpecPath = if (-not [string]::IsNullOrWhiteSpace([string] $completedPlanMetadata.completedSpecPath)) {
        Join-Path $resolvedRepoRoot ([string] $completedPlanMetadata.completedSpecPath)
    }
    else {
        Join-Path $resolvedRepoRoot ('planning/specs/completed/{0}' -f [System.IO.Path]::GetFileName([string] $specArtifacts['active-spec']))
    }
    Assert-Equal -Actual $closeoutReport.status -Expected 'ready-for-commit' -Message 'Closeout stage should be commit-ready in fake flow.'
    Assert-True ([bool] $readmeUpdatesReport.updated) 'Closeout stage should report applied README updates in fake flow.'
    Assert-True ((Get-Content -Raw -LiteralPath $repoSmokeReadmePath) -match 'Closeout automation updated this README') 'Closeout stage should rewrite the temporary README in fake flow.'
    Assert-True ((Get-Content -Raw -LiteralPath $repoSmokeChangelogPath).StartsWith("## [9.9.9] - 2026-03-20", [System.StringComparison]::Ordinal)) 'Closeout stage should prepend the temporary changelog entry in fake flow.'
    Assert-True (([bool] $changelogUpdateReport.applied) -or ((Get-Content -Raw -LiteralPath $repoSmokeChangelogPath).StartsWith("## [9.9.9] - 2026-03-20", [System.StringComparison]::Ordinal))) 'Closeout stage should either apply the changelog update or keep the idempotent temporary changelog state already at the expected entry.'
    Assert-True (-not (Test-Path -LiteralPath $planArtifacts['active-plan'] -PathType Leaf)) 'Closeout stage should move the active plan out of planning/active.'
    Assert-True (-not (Test-Path -LiteralPath $specArtifacts['active-spec'] -PathType Leaf)) 'Closeout stage should move the active spec out of planning/specs/active.'
    Assert-Equal -Actual ((Get-Item -LiteralPath $createdCompletedPlanPath).LastWriteTimeUtc) -Expected $activePlanLastWriteTimeUtc -Message 'Closeout stage should preserve the plan LastWriteTime when moving to completed.'
    Assert-Equal -Actual ((Get-Item -LiteralPath $createdCompletedSpecPath).LastWriteTimeUtc) -Expected $activeSpecLastWriteTimeUtc -Message 'Closeout stage should preserve the spec LastWriteTime when moving to completed.'

    $pipelineRunRoot = Join-Path $tempRoot 'pipeline-runs'
    $pipelineScriptPath = Join-Path $resolvedRepoRoot 'scripts/runtime/run-agent-pipeline.ps1'

    & $pipelineScriptPath `
        -RepoRoot $resolvedRepoRoot `
        -RunRoot $pipelineRunRoot `
        -TraceId 'clarification-needed-test' `
        -RequestText 'Fix that.' `
        -ExecutionBackend 'script-only' `
        -WarningOnly:$false | Out-Null
    Assert-Equal -Actual ([int] $LASTEXITCODE) -Expected 0 -Message 'Pipeline should stop cleanly when clarification is required.'

    $clarificationRunArtifactPath = Join-Path $pipelineRunRoot 'clarification-needed-test\run-artifact.json'
    $clarificationRunArtifact = Get-Content -Raw -LiteralPath $clarificationRunArtifactPath | ConvertFrom-Json -Depth 100
    Assert-Equal -Actual ([string] $clarificationRunArtifact.status) -Expected 'partial' -Message 'Clarification-only pipeline should report partial status.'
    Assert-Equal -Actual @($clarificationRunArtifact.stages).Count -Expected 1 -Message 'Clarification-only pipeline should stop after the intake stage.'
    $clarificationStage = @($clarificationRunArtifact.stages | Select-Object -First 1)
    Assert-Equal -Actual ([string] $clarificationStage.stageId) -Expected 'intake' -Message 'Clarification-only pipeline should record only the intake stage.'
    Assert-Equal -Actual ([string] $clarificationStage.status) -Expected 'partial' -Message 'Intake stage should be marked partial when clarification is required.'
    Assert-True ([bool] $clarificationStage.execution.clarificationRequired) 'Intake stage should record clarificationRequired=true.'
    Assert-True (-not [bool] $clarificationStage.execution.canProceedSafely) 'Clarification-only pipeline should record canProceedSafely=false.'
    Assert-True (@($clarificationStage.execution.clarificationQuestions).Count -gt 0) 'Clarification-only pipeline should record clarification questions.'
    Assert-True ([int] $clarificationRunArtifact.summary.warningCount -gt 0) 'Clarification-only pipeline should emit warnings explaining the stop.'

    & $pipelineScriptPath `
        -RepoRoot $resolvedRepoRoot `
        -RunRoot $pipelineRunRoot `
        -TraceId 'approval-denied-test' `
        -RequestText 'Implement enterprise orchestration support.' `
        -ExecutionBackend 'codex-exec' `
        -DispatchCommand $fakeCodexPath `
        -WarningOnly:$false | Out-Null
    Assert-Equal -Actual ([int] $LASTEXITCODE) -Expected 1 -Message 'Pipeline should fail when sensitive stages do not have explicit approval.'

    $deniedRunArtifactPath = Join-Path $pipelineRunRoot 'approval-denied-test\run-artifact.json'
    $deniedRunArtifact = Get-Content -Raw -LiteralPath $deniedRunArtifactPath | ConvertFrom-Json -Depth 100
    Assert-Equal -Actual ([string] $deniedRunArtifact.status) -Expected 'failed' -Message 'Denied pipeline should report failed status.'
    $deniedImplementStage = @($deniedRunArtifact.stages | Where-Object { [string] $_.stageId -eq 'implement' } | Select-Object -First 1)
    Assert-True ($null -ne $deniedImplementStage) 'Denied pipeline should record the implement stage result.'
    Assert-True ([bool] $deniedImplementStage.execution.approvalRequired) 'Implement stage should be marked as approval-required.'
    Assert-True (-not [bool] $deniedImplementStage.execution.approvalSatisfied) 'Implement stage should record unsatisfied approval when denied.'

    & $pipelineScriptPath `
        -RepoRoot $resolvedRepoRoot `
        -RunRoot $pipelineRunRoot `
        -TraceId 'approval-approved-test' `
        -RequestText 'Implement enterprise orchestration support.' `
        -ExecutionBackend 'codex-exec' `
        -DispatchCommand $fakeCodexPath `
        -ApprovedAgentIds specialist,release-engineer `
        -ApprovedBy 'runtime-test' `
        -ApprovalJustification 'orchestration smoke test' `
        -WarningOnly:$false | Out-Null
    Assert-Equal -Actual ([int] $LASTEXITCODE) -Expected 0 -Message 'Pipeline should succeed when explicit approval is supplied for sensitive agents.'

    $approvedRunDirectory = Join-Path $pipelineRunRoot 'approval-approved-test'
    $approvedRunArtifact = Get-Content -Raw -LiteralPath (Join-Path $approvedRunDirectory 'run-artifact.json') | ConvertFrom-Json -Depth 100
    Assert-Equal -Actual ([string] $approvedRunArtifact.status) -Expected 'success' -Message 'Approved pipeline should report success.'
    Assert-Equal -Actual @($approvedRunArtifact.approvals).Count -Expected 2 -Message 'Approved pipeline should persist both approval entries.'
    $approvalRecord = Get-Content -Raw -LiteralPath (Join-Path $approvedRunDirectory 'artifacts\approval-record.json') | ConvertFrom-Json -Depth 100
    Assert-Equal -Actual @($approvalRecord.approvals).Count -Expected 2 -Message 'Approval record should be persisted as an artifact.'
    Assert-True (-not [string]::IsNullOrWhiteSpace([string] $approvedRunArtifact.traceRecordPath)) 'Approved pipeline should record traceRecordPath.'
    Assert-True (-not [string]::IsNullOrWhiteSpace([string] $approvedRunArtifact.policyEvaluationsPath)) 'Approved pipeline should record policyEvaluationsPath.'
    Assert-True (-not [string]::IsNullOrWhiteSpace([string] $approvedRunArtifact.checkpointStatePath)) 'Approved pipeline should record checkpointStatePath.'
    $traceRecordPath = Join-Path $resolvedRepoRoot ([string] $approvedRunArtifact.traceRecordPath)
    $policyEvaluationsPath = Join-Path $resolvedRepoRoot ([string] $approvedRunArtifact.policyEvaluationsPath)
    $checkpointStatePath = Join-Path $resolvedRepoRoot ([string] $approvedRunArtifact.checkpointStatePath)
    Assert-True (Test-Path -LiteralPath $traceRecordPath -PathType Leaf) 'Approved pipeline should write trace-record.json.'
    Assert-True (Test-Path -LiteralPath $policyEvaluationsPath -PathType Leaf) 'Approved pipeline should write policy-evaluations.json.'
    Assert-True (Test-Path -LiteralPath $checkpointStatePath -PathType Leaf) 'Approved pipeline should write checkpoint-state.json.'

    $traceRecord = Get-Content -Raw -LiteralPath $traceRecordPath | ConvertFrom-Json -Depth 100
    $policyEvaluations = Get-Content -Raw -LiteralPath $policyEvaluationsPath | ConvertFrom-Json -Depth 100
    $checkpointState = Get-Content -Raw -LiteralPath $checkpointStatePath | ConvertFrom-Json -Depth 100
    Assert-Equal -Actual ([int] $traceRecord.summary.stageCount) -Expected @($approvedRunArtifact.stages).Count -Message 'Trace record should mirror run artifact stage count.'
    Assert-Equal -Actual ([string] $checkpointState.status) -Expected 'success' -Message 'Checkpoint state should mirror final success.'
    Assert-Equal -Actual ([int] @($policyEvaluations.evaluations).Count) -Expected ([int] $approvedRunArtifact.summary.policyWarningCount + [int] $approvedRunArtifact.summary.policyBlockCount) -Message 'Policy evaluation artifact should mirror the recorded decision count for the mock run.'

    $replayScriptPath = Join-Path $resolvedRepoRoot 'scripts/runtime/replay-agent-run.ps1'
    $replayOutputPath = Join-Path $approvedRunDirectory 'replay-summary.json'
    & $replayScriptPath `
        -RepoRoot $resolvedRepoRoot `
        -RunDirectory $approvedRunDirectory `
        -OutputPath $replayOutputPath | Out-Null
    Assert-Equal -Actual ([int] $LASTEXITCODE) -Expected 0 -Message 'Replay script should summarize a completed run.'
    $replaySummary = Get-Content -Raw -LiteralPath $replayOutputPath | ConvertFrom-Json -Depth 100
    Assert-Equal -Actual ([string] $replaySummary.status) -Expected 'success' -Message 'Replay summary should report the completed run status.'
    Assert-Equal -Actual ([string] $replaySummary.traceId) -Expected 'approval-approved-test' -Message 'Replay summary should keep the original trace id.'

    $evalScriptPath = Join-Path $resolvedRepoRoot 'scripts/runtime/evaluate-agent-pipeline.ps1'
    $evalOutputPath = Join-Path $tempRoot 'pipeline-scorecard.json'
    & $evalScriptPath `
        -RepoRoot $resolvedRepoRoot `
        -OutputPath $evalOutputPath | Out-Null
    Assert-Equal -Actual ([int] $LASTEXITCODE) -Expected 0 -Message 'Pipeline eval script should succeed against the repository fixtures.'
    $evalScorecard = Get-Content -Raw -LiteralPath $evalOutputPath | ConvertFrom-Json -Depth 100
    Assert-True ([int] $evalScorecard.totalCases -gt 0) 'Pipeline eval scorecard should include at least one case.'
    Assert-Equal -Actual ([int] $evalScorecard.failedCases) -Expected 0 -Message 'Pipeline eval scorecard should not report failed cases.'

    & $pipelineScriptPath `
        -RepoRoot $resolvedRepoRoot `
        -RunRoot $pipelineRunRoot `
        -TraceId 'resume-source-test' `
        -RequestText 'Implement closeout smoke orchestration support.' `
        -ExecutionBackend 'codex-exec' `
        -DispatchCommand $fakeCodexPath `
        -ApprovedAgentIds specialist,release-engineer `
        -ApprovedBy 'runtime-test' `
        -ApprovalJustification 'resume smoke test' `
        -StopAfterStageId 'validate' `
        -WarningOnly:$false | Out-Null
    Assert-Equal -Actual ([int] $LASTEXITCODE) -Expected 0 -Message 'Partial pipeline run for resume smoke test should succeed.'

    $resumeSourceRunDirectory = Join-Path $pipelineRunRoot 'resume-source-test'
    $resumeSourceCheckpoint = Get-Content -Raw -LiteralPath (Join-Path $resumeSourceRunDirectory 'checkpoint-state.json') | ConvertFrom-Json -Depth 100
    Assert-Equal -Actual ([string] $resumeSourceCheckpoint.resumableFromStageId) -Expected 'review' -Message 'Checkpoint state should resume from review after stopping at validate.'

    $resumeScriptPath = Join-Path $resolvedRepoRoot 'scripts/runtime/resume-agent-pipeline.ps1'
    & $resumeScriptPath `
        -RepoRoot $resolvedRepoRoot `
        -RunDirectory $resumeSourceRunDirectory `
        -ExecutionBackend 'codex-exec' `
        -DispatchCommand $fakeCodexPath `
        -ApprovedAgentIds specialist,release-engineer `
        -ApprovedBy 'runtime-test' `
        -ApprovalJustification 'resume smoke test' | Out-Null
    Assert-Equal -Actual ([int] $LASTEXITCODE) -Expected 0 -Message 'Resume script should continue from the last successful checkpoint.'

    $resumedRunArtifact = Get-Content -Raw -LiteralPath (Join-Path $resumeSourceRunDirectory 'run-artifact.json') | ConvertFrom-Json -Depth 100
    Assert-Equal -Actual ([string] $resumedRunArtifact.status) -Expected 'success' -Message 'Resumed run should finish successfully.'
    Assert-True ([bool] $resumedRunArtifact.resume.resumed) 'Resumed run should mark resume metadata.'
    Assert-Equal -Actual ([string] $resumedRunArtifact.resume.startStageId) -Expected 'review' -Message 'Resumed run should record the resume start stage.'

    Write-Host '[OK] agent orchestration engine tests passed.'
    $testExitCode = 0
}
catch {
    $message = $_.Exception.Message
    $trace = $_.ScriptStackTrace
    if ([string]::IsNullOrWhiteSpace($trace)) {
        Write-Host ("[FAIL] agent orchestration engine tests failed: {0}" -f $message)
    }
    else {
        Write-Host ("[FAIL] agent orchestration engine tests failed: {0}`n{1}" -f $message, $trace)
    }
    $testExitCode = 1
}
finally {
    foreach ($relativePath in $planningArtifactPathsToPreserve) {
        $absolutePath = Join-Path $resolvedRepoRoot $relativePath
        if ($preservedPlanningArtifacts.Contains($absolutePath)) {
            $backup = $preservedPlanningArtifacts[$absolutePath]
            $parent = Split-Path -Parent $absolutePath
            if (-not [string]::IsNullOrWhiteSpace($parent)) {
                New-Item -ItemType Directory -Path $parent -Force | Out-Null
            }

            [System.IO.File]::WriteAllBytes($absolutePath, $backup.bytes)
            (Get-Item -LiteralPath $absolutePath).LastWriteTimeUtc = [datetime] $backup.lastWriteTimeUtc
        }
        elseif (Test-Path -LiteralPath $absolutePath -PathType Leaf) {
            Remove-Item -LiteralPath $absolutePath -Force -ErrorAction SilentlyContinue
        }
    }

    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $repoSmokeRoot) {
        Remove-Item -LiteralPath $repoSmokeRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

exit $testExitCode
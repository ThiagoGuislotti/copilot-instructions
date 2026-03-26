Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Reads the JSON payload emitted by the VS Code hook runtime from STDIN.
function Read-HookInput {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return [pscustomobject]@{}
    }

    return $raw | ConvertFrom-Json -Depth 50
}

# Resolves the workspace display name from a repository path.
function Get-WorkspaceName {
    param(
        [string] $WorkspacePath
    )

    if ([string]::IsNullOrWhiteSpace($WorkspacePath)) {
        return 'unknown-workspace'
    }

    return [System.IO.Path]::GetFileName($WorkspacePath.TrimEnd('\', '/'))
}

# Resolves the current Git branch for the workspace when Git is available.
function Get-GitBranchName {
    param(
        [string] $WorkspacePath
    )

    if ([string]::IsNullOrWhiteSpace($WorkspacePath)) {
        return $null
    }

    $gitCommand = Get-Command git -ErrorAction SilentlyContinue
    if ($null -eq $gitCommand) {
        return $null
    }

    try {
        $branch = (& git -C $WorkspacePath branch --show-current 2>$null)
        if ([string]::IsNullOrWhiteSpace($branch)) {
            return $null
        }

        return [string] $branch
    }
    catch {
        return $null
    }
}

# Checks whether a repository-relative path exists inside the current workspace.
function Test-WorkspacePath {
    param(
        [string] $WorkspacePath,
        [string] $RelativePath
    )

    if ([string]::IsNullOrWhiteSpace($WorkspacePath)) {
        return $false
    }

    $candidatePath = Join-Path $WorkspacePath $RelativePath
    return (Test-Path -LiteralPath $candidatePath)
}

# Safely reads an optional property from the hook payload object.
function Get-OptionalPayloadProperty {
    param(
        [object] $Payload,
        [string] $Name
    )

    if ($null -eq $Payload) {
        return $null
    }

    $property = $Payload.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

# Resolves the repository-owned hooks root from the current script location.
function Resolve-HooksRootPath {
    return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
}

# Resolves the repository default insert_final_newline policy from the workspace .editorconfig.
function Get-WorkspaceInsertFinalNewlinePolicy {
    param(
        [string] $WorkspacePath
    )

    if ([string]::IsNullOrWhiteSpace($WorkspacePath)) {
        return $null
    }

    $editorConfigPath = Join-Path $WorkspacePath '.editorconfig'
    if (-not (Test-Path -LiteralPath $editorConfigPath -PathType Leaf)) {
        return $null
    }

    foreach ($line in (Get-Content -LiteralPath $editorConfigPath)) {
        $trimmed = [string] $line
        $trimmed = $trimmed.Trim()

        if ([string]::IsNullOrWhiteSpace($trimmed)) {
            continue
        }

        if ($trimmed.StartsWith('#') -or $trimmed.StartsWith(';')) {
            continue
        }

        if ($trimmed -match '^insert_final_newline\s*=\s*(true|false)$') {
            return [System.Convert]::ToBoolean($Matches[1])
        }
    }

    return $null
}

# Detects whether the current workspace provides a local Super Agent adapter surface.
function Get-SuperAgentWorkspaceSurface {
    param(
        [string] $WorkspacePath
    )

    $hasWorkspaceAgents = Test-WorkspacePath -WorkspacePath $WorkspacePath -RelativePath '.github/AGENTS.md'
    $hasWorkspaceInstructions = Test-WorkspacePath -WorkspacePath $WorkspacePath -RelativePath '.github/copilot-instructions.md'
    $hasWorkspaceRouteCatalog = Test-WorkspacePath -WorkspacePath $WorkspacePath -RelativePath '.github/instruction-routing.catalog.yml'
    $hasWorkspaceRoutePrompt = Test-WorkspacePath -WorkspacePath $WorkspacePath -RelativePath '.github/prompts/route-instructions.prompt.md'
    $hasPlanningWorkspace = Test-WorkspacePath -WorkspacePath $WorkspacePath -RelativePath 'planning/README.md'
    $hasSpecWorkspace = Test-WorkspacePath -WorkspacePath $WorkspacePath -RelativePath 'planning/specs/README.md'

    $workspaceMode = if ($hasWorkspaceAgents -and $hasWorkspaceInstructions) {
        'workspace-adapter'
    }
    else {
        'global-runtime'
    }

    $planningActivePath = if ($hasPlanningWorkspace) { 'planning/active' } else { '.build/super-agent/planning/active' }
    $planningCompletedPath = if ($hasPlanningWorkspace) { 'planning/completed' } else { '.build/super-agent/planning/completed' }
    $specActivePath = if ($hasSpecWorkspace) { 'planning/specs/active' } else { '.build/super-agent/specs/active' }
    $specCompletedPath = if ($hasSpecWorkspace) { 'planning/specs/completed' } else { '.build/super-agent/specs/completed' }

    $instructionLoadMessage = if ($workspaceMode -eq 'workspace-adapter') {
        'Load workspace .github/AGENTS.md and .github/copilot-instructions.md first.'
    }
    else {
        'No local workspace adapter detected: load runtime AGENTS.md and copilot-instructions.md from ~/.github first.'
    }

    $routingMessage = if (($workspaceMode -eq 'workspace-adapter') -and $hasWorkspaceRouteCatalog -and $hasWorkspaceRoutePrompt) {
        'Routing mode: use workspace static routing with .github/instruction-routing.catalog.yml and .github/prompts/route-instructions.prompt.md.'
    }
    elseif ($workspaceMode -eq 'workspace-adapter') {
        'Routing mode: no local static routing surface detected; build a minimal context pack from the workspace files you are touching.'
    }
    else {
        'Routing mode: global-runtime. Do not assume the runtime repository routing catalog or repository-operating-model.instructions.md applies to this workspace; build a minimal local context pack from the target repo.'
    }

    $closeoutMessage = if ($workspaceMode -eq 'workspace-adapter') {
        'Closeout uses workspace conventions, including README and CHANGELOG updates when the local repo requires them.'
    }
    else {
        'Closeout stays generic in global-runtime mode: always prepare a commit message and only update README or CHANGELOG when the target repo already uses them.'
    }

    return [pscustomobject]@{
        WorkspaceMode          = $workspaceMode
        HasWorkspaceAdapter    = ($workspaceMode -eq 'workspace-adapter')
        HasWorkspaceRouteCatalog = $hasWorkspaceRouteCatalog
        HasWorkspaceRoutePrompt = $hasWorkspaceRoutePrompt
        HasPlanningWorkspace   = $hasPlanningWorkspace
        HasSpecWorkspace       = $hasSpecWorkspace
        PlanningActivePath     = $planningActivePath
        PlanningCompletedPath  = $planningCompletedPath
        SpecActivePath         = $specActivePath
        SpecCompletedPath      = $specCompletedPath
        InstructionLoadMessage = $instructionLoadMessage
        RoutingMessage         = $routingMessage
        CloseoutMessage        = $closeoutMessage
    }
}

# Resolves one workspace-relative artifact directory when it exists.
function Resolve-WorkspaceArtifactDirectory {
    param(
        [string] $WorkspacePath,
        [string] $RelativeDirectory
    )

    if ([string]::IsNullOrWhiteSpace($WorkspacePath) -or [string]::IsNullOrWhiteSpace($RelativeDirectory)) {
        return $null
    }

    $directoryPath = Join-Path $WorkspacePath $RelativeDirectory
    if (-not (Test-Path -LiteralPath $directoryPath -PathType Container)) {
        return $null
    }

    return $directoryPath
}

# Returns the most recently updated markdown artifact inside one workspace directory.
function Get-LatestWorkspaceMarkdownArtifact {
    param(
        [string] $WorkspacePath,
        [string] $RelativeDirectory
    )

    $directoryPath = Resolve-WorkspaceArtifactDirectory -WorkspacePath $WorkspacePath -RelativeDirectory $RelativeDirectory
    if ([string]::IsNullOrWhiteSpace($directoryPath)) {
        return $null
    }

    return @(Get-ChildItem -LiteralPath $directoryPath -File -Filter *.md -Force -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1)[0]
}

# Extracts the first markdown heading from a file body.
function Get-FirstMarkdownHeadingText {
    param(
        [string[]] $Lines
    )

    foreach ($line in @($Lines)) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        if ($line -match '^#\s+(.+?)\s*$') {
            return [string] $Matches[1]
        }
    }

    return $null
}

# Extracts the first matching status/value bullet from a markdown file.
function Get-MarkdownStatusValue {
    param(
        [string[]] $Lines,
        [string] $Label
    )

    if ([string]::IsNullOrWhiteSpace($Label)) {
        return $null
    }

    $escapedLabel = [regex]::Escape($Label)
    foreach ($line in @($Lines)) {
        if ($line -match ("^-\s+{0}:\s+(.+?)\s*$" -f $escapedLabel)) {
            return [string] $Matches[1]
        }
    }

    return $null
}

# Extracts the first short paragraph under one of the requested markdown headings.
function Get-MarkdownSectionExcerpt {
    param(
        [string[]] $Lines,
        [string[]] $HeadingCandidates
    )

    if (@($Lines).Count -eq 0 -or @($HeadingCandidates).Count -eq 0) {
        return $null
    }

    $normalizedCandidates = @($HeadingCandidates | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($normalizedCandidates.Count -eq 0) {
        return $null
    }

    for ($index = 0; $index -lt $Lines.Count; $index++) {
        $line = [string] $Lines[$index]
        if ($line -notmatch '^##\s+(.+?)\s*$') {
            continue
        }

        $headingText = [string] $Matches[1]
        if ($normalizedCandidates -notcontains $headingText) {
            continue
        }

        $excerptLines = New-Object System.Collections.Generic.List[string]
        for ($innerIndex = $index + 1; $innerIndex -lt $Lines.Count; $innerIndex++) {
            $innerLine = [string] $Lines[$innerIndex]
            if ($innerLine -match '^#') {
                break
            }

            if ([string]::IsNullOrWhiteSpace($innerLine)) {
                if ($excerptLines.Count -gt 0) {
                    break
                }

                continue
            }

            $excerptLines.Add($innerLine.Trim()) | Out-Null
        }

        if ($excerptLines.Count -gt 0) {
            return (($excerptLines.ToArray()) -join ' ')
        }
    }

    return $null
}

# Trims a long summary to a bounded sentence-length output.
function Compress-ContinuityText {
    param(
        [string] $Text,
        [int] $MaxLength = 220
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }

    $normalized = (($Text -replace '\s+', ' ').Trim())
    if ($normalized.Length -le $MaxLength) {
        return $normalized
    }

    return ($normalized.Substring(0, $MaxLength - 3).TrimEnd() + '...')
}

# Builds a short continuity summary anchored in the active plan/spec artifacts.
function New-WorkspaceContinuitySummary {
    param(
        [string] $WorkspacePath,
        [object] $WorkspaceSurface
    )

    if ([string]::IsNullOrWhiteSpace($WorkspacePath) -or $null -eq $WorkspaceSurface) {
        return 'Continuity summary: workspace path unavailable; when context is compacted, re-anchor on the active plan/spec before rereading large history.'
    }

    $planArtifact = Get-LatestWorkspaceMarkdownArtifact -WorkspacePath $WorkspacePath -RelativeDirectory ([string] $WorkspaceSurface.PlanningActivePath)
    $specArtifact = Get-LatestWorkspaceMarkdownArtifact -WorkspacePath $WorkspacePath -RelativeDirectory ([string] $WorkspaceSurface.SpecActivePath)

    if (($null -eq $planArtifact) -and ($null -eq $specArtifact)) {
        return 'Continuity summary: no active plan/spec detected. If prior context was compacted, create or update the active planning artifact before continuing non-trivial change-bearing work.'
    }

    $segments = New-Object System.Collections.Generic.List[string]

    if ($null -ne $planArtifact) {
        $planLines = @(Get-Content -LiteralPath $planArtifact.FullName -ErrorAction SilentlyContinue)
        $planHeading = Compress-ContinuityText -Text (Get-FirstMarkdownHeadingText -Lines $planLines) -MaxLength 100
        $planState = Compress-ContinuityText -Text (Get-MarkdownStatusValue -Lines $planLines -Label 'State') -MaxLength 60
        $currentSlice = Compress-ContinuityText -Text (Get-MarkdownStatusValue -Lines $planLines -Label 'Current urgent slice in progress') -MaxLength 180
        if ($null -eq $currentSlice) {
            $currentSlice = Compress-ContinuityText -Text (Get-MarkdownSectionExcerpt -Lines $planLines -HeadingCandidates @('Objective And Scope', 'Objective', 'Normalized Request Summary')) -MaxLength 180
        }

        $planSegment = "Active plan: $($WorkspaceSurface.PlanningActivePath)/$($planArtifact.Name)"
        if (-not [string]::IsNullOrWhiteSpace($planHeading)) {
            $planSegment += " ($planHeading)"
        }
        if (-not [string]::IsNullOrWhiteSpace($planState)) {
            $planSegment += ". State: $planState"
        }
        if (-not [string]::IsNullOrWhiteSpace($currentSlice)) {
            $planSegment += ". Resume point: $currentSlice"
        }

        $segments.Add($planSegment) | Out-Null
    }

    if ($null -ne $specArtifact) {
        $specLines = @(Get-Content -LiteralPath $specArtifact.FullName -ErrorAction SilentlyContinue)
        $specHeading = Compress-ContinuityText -Text (Get-FirstMarkdownHeadingText -Lines $specLines) -MaxLength 100
        $specObjective = Compress-ContinuityText -Text (Get-MarkdownSectionExcerpt -Lines $specLines -HeadingCandidates @('Objective', 'Design Summary', 'Normalized Request Summary')) -MaxLength 180

        $specSegment = "Active spec: $($WorkspaceSurface.SpecActivePath)/$($specArtifact.Name)"
        if (-not [string]::IsNullOrWhiteSpace($specHeading)) {
            $specSegment += " ($specHeading)"
        }
        if (-not [string]::IsNullOrWhiteSpace($specObjective)) {
            $specSegment += ". Focus: $specObjective"
        }

        $segments.Add($specSegment) | Out-Null
    }

    $segments.Add('If prior context was compacted, resume from these artifacts first instead of replaying large session history.') | Out-Null
    return ('Continuity summary: ' + (($segments.ToArray()) -join ' '))
}

# Builds a workspace-aware EOF policy guidance string for startup and edit hooks.
function Get-WorkspaceEofPolicyMessage {
    param(
        [string] $WorkspacePath
    )

    $insertFinalNewline = Get-WorkspaceInsertFinalNewlinePolicy -WorkspacePath $WorkspacePath
    if ($insertFinalNewline -eq $false) {
        return 'Workspace EOF policy: preserve exact file EOF, and do not append a terminal newline because .editorconfig uses insert_final_newline = false.'
    }

    if ($insertFinalNewline -eq $true) {
        return 'Workspace EOF policy: preserve exact file EOF and keep a terminal newline where .editorconfig uses insert_final_newline = true.'
    }

    return 'Workspace EOF policy: preserve the current EOF state of touched files and do not change terminal newline behavior unless the workspace defines a narrower rule.'
}

# Returns true when the supplied path resolves inside the current workspace.
function Test-WorkspaceManagedFilePath {
    param(
        [string] $WorkspacePath,
        [string] $FilePath
    )

    if ([string]::IsNullOrWhiteSpace($WorkspacePath) -or [string]::IsNullOrWhiteSpace($FilePath)) {
        return $false
    }

    try {
        $resolvedWorkspace = [System.IO.Path]::GetFullPath($WorkspacePath)
        $resolvedFile = if ([System.IO.Path]::IsPathRooted($FilePath)) {
            [System.IO.Path]::GetFullPath($FilePath)
        }
        else {
            [System.IO.Path]::GetFullPath((Join-Path $resolvedWorkspace $FilePath))
        }
    }
    catch {
        return $false
    }

    $separator = [System.IO.Path]::DirectorySeparatorChar
    $workspacePrefix = $resolvedWorkspace.TrimEnd('\', '/') + $separator
    $comparison = if ($IsWindows) { [System.StringComparison]::OrdinalIgnoreCase } else { [System.StringComparison]::Ordinal }

    return $resolvedFile.StartsWith($workspacePrefix, $comparison)
}

# Removes terminal newline sequences from a tool text payload while preserving internal line breaks.
function Remove-TerminalNewline {
    param(
        [AllowNull()]
        [string] $Text
    )

    if ($null -eq $Text) {
        return $null
    }

    return ($Text -replace '(\r\n|\n)+$','')
}

# Clones a hook tool input payload into a mutable object for normalization.
function Copy-ToolInputObject {
    param(
        [object] $ToolInput
    )

    if ($null -eq $ToolInput) {
        return $null
    }

    return ($ToolInput | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100)
}

# Normalizes supported edit-tool payloads to remove terminal newlines when the workspace policy forbids them.
function Get-EofNormalizedToolInput {
    param(
        [string] $WorkspacePath,
        [string] $ToolName,
        [object] $ToolInput
    )

    $insertFinalNewline = Get-WorkspaceInsertFinalNewlinePolicy -WorkspacePath $WorkspacePath
    if ($insertFinalNewline -ne $false) {
        return $null
    }

    $updatedInput = Copy-ToolInputObject -ToolInput $ToolInput
    if ($null -eq $updatedInput) {
        return $null
    }

    $changed = $false

    switch ($ToolName) {
        'createFile' {
            if (Test-WorkspaceManagedFilePath -WorkspacePath $WorkspacePath -FilePath ([string] $updatedInput.filePath)) {
                $normalizedContent = Remove-TerminalNewline -Text ([string] $updatedInput.content)
                if ($normalizedContent -cne [string] $updatedInput.content) {
                    $updatedInput.content = $normalizedContent
                    $changed = $true
                }
            }
        }
        'insertEdit' {
            if (Test-WorkspaceManagedFilePath -WorkspacePath $WorkspacePath -FilePath ([string] $updatedInput.filePath)) {
                $normalizedCode = Remove-TerminalNewline -Text ([string] $updatedInput.code)
                if ($normalizedCode -cne [string] $updatedInput.code) {
                    $updatedInput.code = $normalizedCode
                    $changed = $true
                }
            }
        }
        'replaceString' {
            if (Test-WorkspaceManagedFilePath -WorkspacePath $WorkspacePath -FilePath ([string] $updatedInput.filePath)) {
                $normalizedNewString = Remove-TerminalNewline -Text ([string] $updatedInput.newString)
                if ($normalizedNewString -cne [string] $updatedInput.newString) {
                    $updatedInput.newString = $normalizedNewString
                    $changed = $true
                }
            }
        }
        'multiReplaceString' {
            foreach ($replacement in @($updatedInput.replacements)) {
                if (-not (Test-WorkspaceManagedFilePath -WorkspacePath $WorkspacePath -FilePath ([string] $replacement.filePath))) {
                    continue
                }

                $normalizedNewString = Remove-TerminalNewline -Text ([string] $replacement.newString)
                if ($normalizedNewString -cne [string] $replacement.newString) {
                    $replacement.newString = $normalizedNewString
                    $changed = $true
                }
            }
        }
    }

    if (-not $changed) {
        return $null
    }

    return $updatedInput
}

# Returns true when the tool participates in repository file creation or editing.
function Test-EofSensitiveToolName {
    param(
        [string] $ToolName
    )

    return @('applyPatch', 'createFile', 'insertEdit', 'replaceString', 'multiReplaceString') -contains $ToolName
}

# Reads a JSON file when it exists and returns $null when absent.
function Read-OptionalJsonFile {
    param(
        [string] $Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }

    return (Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -Depth 50)
}

# Loads the shared Super Agent selector configuration from the repository hooks folder.
function Get-SuperAgentSelectorConfig {
    $hooksRoot = Resolve-HooksRootPath
    $selectorPath = Join-Path $hooksRoot 'super-agent.selector.json'
    $selector = Read-OptionalJsonFile -Path $selectorPath

    if ($null -eq $selector) {
        throw ("Missing or invalid selector configuration: {0}" -f $selectorPath)
    }

    return $selector
}

# Resolves the optional local override file path under the user ~/.github/hooks runtime.
function Resolve-SuperAgentSelectorOverridePath {
    param(
        [string] $RelativePath
    )

    if ([string]::IsNullOrWhiteSpace($RelativePath)) {
        return $null
    }

    $userProfile = $env:USERPROFILE
    if ([string]::IsNullOrWhiteSpace($userProfile)) {
        $userProfile = $HOME
    }

    if ([string]::IsNullOrWhiteSpace($userProfile)) {
        return $null
    }

    return (Join-Path (Join-Path $userProfile '.github\hooks') $RelativePath)
}

# Builds the normalized selected startup-controller record.
function New-SuperAgentSelection {
    param(
        [string] $SkillName,
        [string] $DisplayName,
        [string] $Source
    )

    if ([string]::IsNullOrWhiteSpace($SkillName)) {
        throw 'Startup controller skill name cannot be empty.'
    }

    if ([string]::IsNullOrWhiteSpace($DisplayName)) {
        $DisplayName = $SkillName
    }

    if ([string]::IsNullOrWhiteSpace($Source)) {
        $Source = 'default'
    }

    return [pscustomobject]@{
        SkillName   = [string] $SkillName
        DisplayName = [string] $DisplayName
        Source      = [string] $Source
    }
}

# Resolves the startup-controller selection using repo default, local override, then env override.
function Resolve-SuperAgentSelection {
    $selector = Get-SuperAgentSelectorConfig
    $selection = New-SuperAgentSelection `
        -SkillName ([string] $selector.defaultAgent.skillName) `
        -DisplayName ([string] $selector.defaultAgent.displayName) `
        -Source 'default'

    $overridePath = Resolve-SuperAgentSelectorOverridePath -RelativePath ([string] $selector.overrideSources.localOverrideFile)
    $localOverride = Read-OptionalJsonFile -Path $overridePath
    if (($null -ne $localOverride) -and -not [string]::IsNullOrWhiteSpace([string] $localOverride.skillName)) {
        $selection = New-SuperAgentSelection `
            -SkillName ([string] $localOverride.skillName) `
            -DisplayName ([string] $localOverride.displayName) `
            -Source 'local-override'
    }

    $envSkillVariable = [string] $selector.overrideSources.environment.skillVariable
    $envDisplayVariable = [string] $selector.overrideSources.environment.displayVariable
    $envSkillValue = if ([string]::IsNullOrWhiteSpace($envSkillVariable)) { $null } else { [Environment]::GetEnvironmentVariable($envSkillVariable) }
    $envDisplayValue = if ([string]::IsNullOrWhiteSpace($envDisplayVariable)) { $null } else { [Environment]::GetEnvironmentVariable($envDisplayVariable) }

    if (-not [string]::IsNullOrWhiteSpace($envSkillValue)) {
        $selection = New-SuperAgentSelection `
            -SkillName $envSkillValue `
            -DisplayName $envDisplayValue `
            -Source 'environment-override'
    }

    return $selection
}

# Formats the skill token consistently for bootstrap messages.
function Format-SkillToken {
    param(
        [string] $SkillName
    )

    if ([string]::IsNullOrWhiteSpace($SkillName)) {
        return '<unspecified-skill>'
    }

    return ('$' + $SkillName)
}

# Builds a short, user-visible activation banner for the current startup controller.
function New-SuperAgentVisibilityBanner {
    param(
        [string] $WorkspaceName,
        [object] $Selection,
        [object] $WorkspaceSurface
    )

    return ('[Super Agent: ACTIVE | controller={0} | skill={1} | mode={2} | workspace={3}]' -f $Selection.DisplayName, $Selection.SkillName, $WorkspaceSurface.WorkspaceMode, $WorkspaceName)
}

# Resolves the runtime housekeeping script path mirrored under ~/.github/scripts/runtime.
function Resolve-SuperAgentHousekeepingScriptPath {
    $hooksRoot = Resolve-HooksRootPath
    $candidateRoots = @(
        (Join-Path (Split-Path -Path $hooksRoot -Parent) 'scripts\runtime'),
        (Join-Path (Split-Path -Path (Split-Path -Path $hooksRoot -Parent) -Parent) 'scripts\runtime')
    )

    foreach ($runtimeRoot in $candidateRoots) {
        $scriptPath = Join-Path $runtimeRoot 'invoke-super-agent-housekeeping.ps1'
        if (Test-Path -LiteralPath $scriptPath -PathType Leaf) {
            return $scriptPath
        }
    }

    return $null
}

# Resolves the state file path for periodic Super Agent housekeeping.
function Resolve-SuperAgentHousekeepingStatePath {
    param(
        [string] $WorkspacePath
    )

    $overridePath = [Environment]::GetEnvironmentVariable('SUPER_AGENT_HOUSEKEEPING_STATE_PATH')
    if (-not [string]::IsNullOrWhiteSpace($overridePath)) {
        return [System.IO.Path]::GetFullPath($overridePath)
    }

    if ([string]::IsNullOrWhiteSpace($WorkspacePath)) {
        $userProfile = if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) { $env:USERPROFILE } else { $HOME }
        if ([string]::IsNullOrWhiteSpace($userProfile)) {
            return $null
        }

        return (Join-Path $userProfile '.github\hooks\super-agent-housekeeping.state.json')
    }

    return (Join-Path $WorkspacePath '.build/super-agent/runtime/housekeeping.state.json')
}

# Reads one optional JSON state file.
function Read-SuperAgentHousekeepingState {
    param(
        [string] $StateFilePath
    )

    if ([string]::IsNullOrWhiteSpace($StateFilePath)) {
        return $null
    }

    if (-not (Test-Path -LiteralPath $StateFilePath -PathType Leaf)) {
        return $null
    }

    try {
        return (Get-Content -Raw -LiteralPath $StateFilePath | ConvertFrom-Json -Depth 20)
    }
    catch {
        return $null
    }
}

# Writes one JSON state file for the housekeeping throttle.
function Save-SuperAgentHousekeepingState {
    param(
        [string] $StateFilePath,
        [hashtable] $State
    )

    if ([string]::IsNullOrWhiteSpace($StateFilePath)) {
        return
    }

    $parentPath = Split-Path -Path $StateFilePath -Parent
    if (-not [string]::IsNullOrWhiteSpace($parentPath)) {
        New-Item -ItemType Directory -Path $parentPath -Force | Out-Null
    }

    $State | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $StateFilePath
}

# Resolves the last housekeeping attempt or run timestamp from the state file.
function Get-SuperAgentHousekeepingActivityTimestamp {
    param(
        [AllowNull()]
        [object] $State
    )

    if ($null -eq $State) {
        return $null
    }

    foreach ($propertyName in @('lastAttemptAt', 'lastRunAt')) {
        $property = $State.PSObject.Properties[$propertyName]
        if ($null -eq $property -or [string]::IsNullOrWhiteSpace([string] $property.Value)) {
            continue
        }

        try {
            return [datetime] $property.Value
        }
        catch {
            continue
        }
    }

    return $null
}

# Returns the effective housekeeping interval in hours.
function Get-SuperAgentHousekeepingIntervalHours {
    $environmentValue = [Environment]::GetEnvironmentVariable('SUPER_AGENT_HOUSEKEEPING_INTERVAL_HOURS')
    if (-not [string]::IsNullOrWhiteSpace($environmentValue)) {
        $parsedValue = 0
        if ([int]::TryParse($environmentValue, [ref] $parsedValue) -and $parsedValue -ge 1) {
            return $parsedValue
        }
    }

    return 2
}

# Returns true when housekeeping dispatch should be skipped.
function Test-ShouldDispatchSuperAgentHousekeeping {
    param(
        [AllowNull()]
        [Nullable[datetime]] $LastActivityAt,
        [int] $IntervalHours
    )

    if ($null -eq $LastActivityAt) {
        return $true
    }

    $threshold = (Get-Date).AddHours(-1 * $IntervalHours)
    return ($LastActivityAt -le $threshold)
}

# Best-effort dispatch of safe periodic housekeeping for active sessions.
function Invoke-SuperAgentHousekeepingDispatch {
    param(
        [object] $Payload
    )

    $disabled = [Environment]::GetEnvironmentVariable('SUPER_AGENT_HOUSEKEEPING_DISABLE')
    if ($disabled -eq '1') {
        return
    }

    $workspacePath = [string] (Get-OptionalPayloadProperty -Payload $Payload -Name 'cwd')
    if ([string]::IsNullOrWhiteSpace($workspacePath) -or -not (Test-Path -LiteralPath $workspacePath -PathType Container)) {
        return
    }

    $housekeepingScriptPath = Resolve-SuperAgentHousekeepingScriptPath
    if ([string]::IsNullOrWhiteSpace($housekeepingScriptPath)) {
        return
    }

    $intervalHours = Get-SuperAgentHousekeepingIntervalHours
    $stateFilePath = Resolve-SuperAgentHousekeepingStatePath -WorkspacePath $workspacePath
    $existingState = Read-SuperAgentHousekeepingState -StateFilePath $stateFilePath
    $lastActivityAt = Get-SuperAgentHousekeepingActivityTimestamp -State $existingState
    if (-not (Test-ShouldDispatchSuperAgentHousekeeping -LastActivityAt $lastActivityAt -IntervalHours $intervalHours)) {
        return
    }

    Save-SuperAgentHousekeepingState -StateFilePath $stateFilePath -State ([ordered]@{
            workspacePath = $workspacePath
            lastAttemptAt = (Get-Date).ToString('o')
            lastRunAt = if ($null -ne $existingState -and $null -ne $existingState.PSObject.Properties['lastRunAt']) { [string] $existingState.lastRunAt } else { $null }
            lastStatus = 'dispatching'
        })

    $pwshCommand = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($null -eq $pwshCommand) {
        return
    }

    $argumentList = @(
        '-NoLogo',
        '-NoProfile',
        '-File',
        $housekeepingScriptPath,
        '-WorkspacePath',
        $workspacePath,
        '-RepoRoot',
        $workspacePath,
        '-IntervalHours',
        [string] $intervalHours,
        '-StateFilePath',
        $stateFilePath,
        '-BypassThrottle',
        '-Apply'
    )

    $recordOnlyPath = [Environment]::GetEnvironmentVariable('SUPER_AGENT_HOUSEKEEPING_RECORD_ONLY_PATH')
    if (-not [string]::IsNullOrWhiteSpace($recordOnlyPath)) {
        $argumentList += @('-RecordOnlyPath', $recordOnlyPath)
    }

    $foregroundMode = [Environment]::GetEnvironmentVariable('SUPER_AGENT_HOUSEKEEPING_FOREGROUND')
    try {
        if ($foregroundMode -eq '1') {
            & $pwshCommand.Source @argumentList | Out-Null
        }
        else {
            Start-Process -FilePath $pwshCommand.Source -ArgumentList $argumentList -WindowStyle Hidden | Out-Null
        }
    }
    catch {
        # best effort only: do not break the hook contract
    }
}

# Builds the SessionStart bootstrap context injected into VS Code agent sessions.
function New-SessionContextString {
    param(
        [object] $Payload
    )

    $selection = Resolve-SuperAgentSelection
    $workspacePath = [string] (Get-OptionalPayloadProperty -Payload $Payload -Name 'cwd')
    $workspaceName = Get-WorkspaceName -WorkspacePath $workspacePath
    $branchName = Get-GitBranchName -WorkspacePath $workspacePath
    $workspaceSurface = Get-SuperAgentWorkspaceSurface -WorkspacePath $workspacePath
    $eofMessage = Get-WorkspaceEofPolicyMessage -WorkspacePath $workspacePath
    $visibilityBanner = New-SuperAgentVisibilityBanner -WorkspaceName $workspaceName -Selection $selection -WorkspaceSurface $workspaceSurface
    $continuitySummary = New-WorkspaceContinuitySummary -WorkspacePath $workspacePath -WorkspaceSurface $workspaceSurface

    Invoke-SuperAgentHousekeepingDispatch -Payload $Payload

    $segments = New-Object System.Collections.Generic.List[string]
    $segments.Add(('Workspace: {0}' -f $workspaceName)) | Out-Null

    if (-not [string]::IsNullOrWhiteSpace($branchName)) {
        $segments.Add(('Branch: {0}' -f $branchName)) | Out-Null
    }

    $segments.Add(('Selected startup controller: {0} ({1}) via {2}.' -f $selection.DisplayName, (Format-SkillToken -SkillName $selection.SkillName), $selection.Source)) | Out-Null
    $segments.Add(('Visibility banner: {0}.' -f $visibilityBanner)) | Out-Null
    $segments.Add('Visibility contract: in the first substantive assistant reply of this session, echo the visibility banner exactly once near the start so the user can see that Super Agent is active.') | Out-Null
    $segments.Add(('Workspace mode: {0}.' -f $workspaceSurface.WorkspaceMode)) | Out-Null
    $segments.Add([string] $workspaceSurface.InstructionLoadMessage) | Out-Null
    $segments.Add([string] $workspaceSurface.RoutingMessage) | Out-Null
    $segments.Add(('Planning root: {0} -> {1}.' -f $workspaceSurface.PlanningActivePath, $workspaceSurface.PlanningCompletedPath)) | Out-Null
    $segments.Add(('Spec root: {0} -> {1}.' -f $workspaceSurface.SpecActivePath, $workspaceSurface.SpecCompletedPath)) | Out-Null
    $segments.Add($continuitySummary) | Out-Null
    $segments.Add([string] $workspaceSurface.CloseoutMessage) | Out-Null
    $segments.Add('Super Agent lifecycle is mandatory for change-bearing work: intake -> planning -> spec when needed -> specialist -> test -> review -> closeout -> planning update.') | Out-Null
    $segments.Add($eofMessage) | Out-Null
    $segments.Add('Use workspace context first and official docs second.') | Out-Null
    $segments.Add('Keep non-versioned build outputs under .build/ and deployment/runtime publish outputs under .deployment/.') | Out-Null

    return ($segments -join ' ')
}

# Builds the SubagentStart bootstrap context injected into worker sessions.
function New-SubagentContextString {
    param(
        [object] $Payload
    )

    $selection = Resolve-SuperAgentSelection
    $workspacePath = [string] (Get-OptionalPayloadProperty -Payload $Payload -Name 'cwd')
    $workspaceSurface = Get-SuperAgentWorkspaceSurface -WorkspacePath $workspacePath
    $eofMessage = Get-WorkspaceEofPolicyMessage -WorkspacePath $workspacePath
    $agentType = [string] (Get-OptionalPayloadProperty -Payload $Payload -Name 'agent_type')
    if ([string]::IsNullOrWhiteSpace($agentType)) {
        $agentType = 'subagent'
    }
    $workspaceName = Get-WorkspaceName -WorkspacePath $workspacePath
    $visibilityBanner = New-SuperAgentVisibilityBanner -WorkspaceName $workspaceName -Selection $selection -WorkspaceSurface $workspaceSurface
    $continuitySummary = New-WorkspaceContinuitySummary -WorkspacePath $workspacePath -WorkspaceSurface $workspaceSurface

    Invoke-SuperAgentHousekeepingDispatch -Payload $Payload

    return ('Startup controller: {0} ({1}) via {2}. Visibility banner: {3}. Workspace mode: {4}. {5} {6} Planning root: {7}. Spec root: {8}. {9} {10} Super Agent bootstrap is active. Current worker type: {11}. {12} Keep scope minimal, follow the active routing decision for this workspace, respect planning/spec artifacts, avoid write-scope conflicts, validate before completion, and return structured output only for the assigned slice.' -f $selection.DisplayName, (Format-SkillToken -SkillName $selection.SkillName), $selection.Source, $visibilityBanner, $workspaceSurface.WorkspaceMode, $workspaceSurface.InstructionLoadMessage, $workspaceSurface.RoutingMessage, $workspaceSurface.PlanningActivePath, $workspaceSurface.SpecActivePath, $continuitySummary, $workspaceSurface.CloseoutMessage, $agentType, $eofMessage)
}

# Builds the PreToolUse payload used to normalize repository edit tool inputs before disk writes occur.
function New-PreToolUseResult {
    param(
        [object] $Payload
    )

    $toolName = [string] (Get-OptionalPayloadProperty -Payload $Payload -Name 'tool_name')
    $toolInput = Get-OptionalPayloadProperty -Payload $Payload -Name 'tool_input'
    $workspacePath = [string] (Get-OptionalPayloadProperty -Payload $Payload -Name 'cwd')

    $hookSpecificOutput = [ordered]@{
        hookEventName = 'PreToolUse'
    }

    if (Test-EofSensitiveToolName -ToolName $toolName) {
        $hookSpecificOutput.additionalContext = Get-WorkspaceEofPolicyMessage -WorkspacePath $workspacePath

        $updatedInput = Get-EofNormalizedToolInput -WorkspacePath $workspacePath -ToolName $toolName -ToolInput $toolInput
        if ($null -ne $updatedInput) {
            $hookSpecificOutput.updatedInput = $updatedInput
        }
    }

    return [ordered]@{
        hookSpecificOutput = $hookSpecificOutput
    }
}
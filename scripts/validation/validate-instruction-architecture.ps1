<#
.SYNOPSIS
    Validates instruction architecture ownership and boundary rules.

.DESCRIPTION
    Ensures the repository keeps a clear separation between:
    - global core files
    - repository operating model
    - domain instructions
    - cross-cutting policy files
    - prompts
    - templates
    - Codex skills
    - runtime/orchestration assets

    The validator is intentionally conservative:
    - missing required ownership references fail
    - suspicious policy ownership markers in prompts/templates/skills warn

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.PARAMETER ManifestPath
    Relative path to the instruction ownership manifest.

.PARAMETER AgentsPath
    Relative path to AGENTS.md.

.PARAMETER GlobalInstructionsPath
    Relative path to copilot-instructions.md.

.PARAMETER RoutingCatalogPath
    Relative path to instruction-routing.catalog.yml.

.PARAMETER RoutePromptPath
    Relative path to the route-only prompt that enforces deterministic context selection.

.PARAMETER PromptRoot
    Relative or absolute prompt root to scan.

.PARAMETER TemplateRoot
    Relative or absolute template root to scan.

.PARAMETER SkillRoot
    Relative or absolute skill root to scan.

.PARAMETER WarningOnly
    When true (default), failures are emitted as warnings and execution exits with code 0.

.PARAMETER Verbose
    Shows detailed diagnostics.

.PARAMETER DetailedOutput
    Prints file-level warning details.

.EXAMPLE
    pwsh -File scripts/validation/validate-instruction-architecture.ps1

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $ManifestPath = '.github/governance/instruction-ownership.manifest.json',
    [string] $AgentsPath = '.github/AGENTS.md',
    [string] $GlobalInstructionsPath = '.github/copilot-instructions.md',
    [string] $RoutingCatalogPath = '.github/instruction-routing.catalog.yml',
    [string] $RoutePromptPath = '.github/prompts/route-instructions.prompt.md',
    [string] $PromptRoot = '.github/prompts',
    [string] $TemplateRoot = '.github/templates',
    [string] $SkillRoot = '.codex/skills',
    [bool] $WarningOnly = $true,
    [switch] $DetailedOutput,
    [switch] $Verbose
)

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
$script:IsWarningOnly = [bool] $WarningOnly
Initialize-ValidationState -WarningOnly $script:IsWarningOnly -VerboseEnabled $script:IsVerboseEnabled
$script:IsDetailedOutputEnabled = [bool] $DetailedOutput

# Resolves a path from repo root.

# Reads and parses JSON from file path.
function Read-JsonFile {
    param(
        [string] $Path,
        [string] $Label
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Add-ValidationFailure ("Missing {0}: {1}" -f $Label, $Path)
        return $null
    }

    try {
        return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -Depth 200
    }
    catch {
        Add-ValidationFailure ("Invalid JSON in {0}: {1}" -f $Label, $_.Exception.Message)
        return $null
    }
}

# Reads a required text file.
function Read-TextFile {
    param(
        [string] $Path,
        [string] $Label
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Add-ValidationFailure ("Missing {0}: {1}" -f $Label, $Path)
        return $null
    }

    return Get-Content -Raw -LiteralPath $Path
}

# Converts input to a string array.
function ConvertTo-StringArray {
    param(
        [object] $Value
    )

    if ($null -eq $Value) {
        return @()
    }

    if ($Value -is [string]) {
        return @([string] $Value)
    }

    return @($Value | ForEach-Object { [string] $_ })
}

# Reads an optional property value from a loose object.
function Get-OptionalPropertyValue {
    param(
        [object] $InputObject,
        [string] $Name
    )

    if ($null -eq $InputObject) {
        return $null
    }

    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

# Resolves one architecture layer by id.
function Get-ManifestLayerById {
    param(
        [object] $Manifest,
        [string] $LayerId
    )

    if ($null -eq $Manifest) {
        return $null
    }

    foreach ($layer in @($Manifest.layers)) {
        if ([string] $layer.id -eq $LayerId) {
            return $layer
        }
    }

    return $null
}

# Converts an absolute path to a normalized repository-relative path.
function Get-NormalizedRelativePath {
    param(
        [string] $Root,
        [string] $Path
    )

    return [System.IO.Path]::GetRelativePath($Root, $Path).Replace('\', '/')
}

# Matches a repository-relative path against a manifest pattern.
function Test-PathPatternMatch {
    param(
        [string] $RelativePath,
        [string] $Pattern
    )

    return $RelativePath.ToLowerInvariant() -like $Pattern.Replace('\', '/').ToLowerInvariant()
}

# Expands manifest patterns into the matching file set for one layer.
function Get-MatchingFilesForLayer {
    param(
        [string] $Root,
        [object] $Layer
    )

    $allFiles = Get-ChildItem -Path $Root -Recurse -File
    $matches = New-Object System.Collections.Generic.List[string]
    $pathPatterns = @(ConvertTo-StringArray -Value (Get-OptionalPropertyValue -InputObject $Layer -Name 'pathPatterns'))
    $excludePatterns = @(ConvertTo-StringArray -Value (Get-OptionalPropertyValue -InputObject $Layer -Name 'excludePatterns'))

    foreach ($file in $allFiles) {
        $relativePath = Get-NormalizedRelativePath -Root $Root -Path $file.FullName
        $isMatch = $false

        foreach ($pattern in $pathPatterns) {
            if (Test-PathPatternMatch -RelativePath $relativePath -Pattern $pattern) {
                $isMatch = $true
                break
            }
        }

        if (-not $isMatch) {
            continue
        }

        $isExcluded = $false
        foreach ($excludePattern in $excludePatterns) {
            if (Test-PathPatternMatch -RelativePath $relativePath -Pattern $excludePattern) {
                $isExcluded = $true
                break
            }
        }

        if (-not $isExcluded) {
            $matches.Add($file.FullName) | Out-Null
        }
    }

    return @($matches | Select-Object -Unique)
}

# Validates manifest version, required layers, and layer shape.
function Test-ManifestStructure {
    param(
        [object] $Manifest
    )

    if ($null -eq $Manifest) {
        return
    }

    if ([int] $Manifest.version -lt 1) {
        Add-ValidationFailure 'Instruction ownership manifest version must be >= 1.'
    }

    $exceptions = @((Get-OptionalPropertyValue -InputObject $Manifest -Name 'intentionalGlobalExceptions'))
    if ($exceptions.Count -eq 0) {
        Add-ValidationFailure 'Instruction ownership manifest must list intentional global exceptions.'
    }
    else {
        foreach ($exception in $exceptions) {
            $concern = [string] (Get-OptionalPropertyValue -InputObject $exception -Name 'concern')
            $ownedBy = [string] (Get-OptionalPropertyValue -InputObject $exception -Name 'ownedBy')
            if ([string]::IsNullOrWhiteSpace($concern) -or [string]::IsNullOrWhiteSpace($ownedBy)) {
                Add-ValidationFailure 'Each intentional global exception must define concern and ownedBy.'
            }
        }
    }

    $constraints = Get-OptionalPropertyValue -InputObject $Manifest -Name 'architectureConstraints'
    if ($null -eq $constraints) {
        Add-ValidationFailure 'Instruction ownership manifest must define architectureConstraints.'
    }
    else {
        $globalCoreMaxChars = Get-OptionalPropertyValue -InputObject $constraints -Name 'globalCoreMaxChars'
        if ($null -eq $globalCoreMaxChars) {
            Add-ValidationFailure 'architectureConstraints.globalCoreMaxChars is required.'
        }
        else {
            $agentsLimit = Get-OptionalPropertyValue -InputObject $globalCoreMaxChars -Name 'AGENTS.md'
            $globalLimit = Get-OptionalPropertyValue -InputObject $globalCoreMaxChars -Name 'copilot-instructions.md'
            if ($null -eq $agentsLimit -or $null -eq $globalLimit) {
                Add-ValidationFailure 'architectureConstraints.globalCoreMaxChars must define AGENTS.md and copilot-instructions.md.'
            }
        }

        $routingConstraints = Get-OptionalPropertyValue -InputObject $constraints -Name 'routing'
        if ($null -eq $routingConstraints) {
            Add-ValidationFailure 'architectureConstraints.routing is required.'
        }
        else {
            if ($null -eq (Get-OptionalPropertyValue -InputObject $routingConstraints -Name 'maxAlwaysFiles')) {
                Add-ValidationFailure 'architectureConstraints.routing.maxAlwaysFiles is required.'
            }

            if ($null -eq (Get-OptionalPropertyValue -InputObject $routingConstraints -Name 'maxSelectedFiles')) {
                Add-ValidationFailure 'architectureConstraints.routing.maxSelectedFiles is required.'
            }

            $requiredAlwaysPaths = @(ConvertTo-StringArray -Value (Get-OptionalPropertyValue -InputObject $routingConstraints -Name 'requiredAlwaysPaths'))
            if ($requiredAlwaysPaths.Count -eq 0) {
                Add-ValidationFailure 'architectureConstraints.routing.requiredAlwaysPaths must define at least one path.'
            }
        }
    }

    $layers = @($Manifest.layers)
    if ($layers.Count -eq 0) {
        Add-ValidationFailure 'Instruction ownership manifest must define at least one layer.'
        return
    }

    $requiredLayerIds = @(
        'global-core',
        'repository-operating-model',
        'cross-cutting-policies',
        'domain-instructions',
        'prompts',
        'templates',
        'codex-skills',
        'orchestration',
        'runtime-projection'
    )

    $seenIds = @{}
    foreach ($layer in $layers) {
        $layerId = [string] $layer.id
        if ([string]::IsNullOrWhiteSpace($layerId)) {
            Add-ValidationFailure 'Instruction ownership manifest contains a layer without id.'
            continue
        }

        if ($seenIds.ContainsKey($layerId)) {
            Add-ValidationFailure ("Instruction ownership manifest contains duplicate layer id: {0}" -f $layerId)
            continue
        }

        $seenIds[$layerId] = $true

        $patterns = @(ConvertTo-StringArray -Value (Get-OptionalPropertyValue -InputObject $layer -Name 'pathPatterns'))
        if ($patterns.Count -eq 0) {
            Add-ValidationFailure ("Layer '{0}' must define at least one path pattern." -f $layerId)
        }
    }

    foreach ($requiredLayerId in $requiredLayerIds) {
        if (-not $seenIds.ContainsKey($requiredLayerId)) {
            Add-ValidationFailure ("Instruction ownership manifest is missing required layer '{0}'." -f $requiredLayerId)
        }
    }
}

# Detects exact file ownership overlap across architecture layers.
function Test-LayerOverlap {
    param(
        [string] $Root,
        [object[]] $Layers
    )

    $ownership = @{}

    foreach ($layer in $Layers) {
        $layerId = [string] $layer.id
        $files = @(Get-MatchingFilesForLayer -Root $Root -Layer $layer)
        foreach ($file in $files) {
            $relativePath = Get-NormalizedRelativePath -Root $Root -Path $file
            if ($ownership.ContainsKey($relativePath)) {
                Add-ValidationFailure ("File is claimed by multiple architecture layers: {0} -> {1}, {2}" -f $relativePath, $ownership[$relativePath], $layerId)
            }
            else {
                $ownership[$relativePath] = $layerId
            }
        }
    }
}

# Validates that the global core references the required centralized files.
function Test-GlobalCoreReferences {
    param(
        [string] $AgentsContent,
        [string] $GlobalContent,
        [string] $RoutingContent
    )

    $requiredPatterns = @(
        'instructions/repository-operating-model\.instructions\.md',
        'instructions/authoritative-sources\.instructions\.md'
    )

    foreach ($pattern in $requiredPatterns) {
        if ($AgentsContent -notmatch $pattern) {
            Add-ValidationFailure ("AGENTS.md is missing required architecture reference: {0}" -f $pattern)
        }

        if ($GlobalContent -notmatch $pattern) {
            Add-ValidationFailure ("copilot-instructions.md is missing required architecture reference: {0}" -f $pattern)
        }

        if ($RoutingContent -notmatch $pattern) {
            Add-ValidationFailure ("instruction-routing.catalog.yml is missing required architecture reference: {0}" -f $pattern)
        }
    }
}

# Returns all files under an explicit scan root.
function Get-FilesFromScanRoot {
    param(
        [string] $TargetRoot,
        [string] $Label
    )

    if (-not (Test-Path -LiteralPath $TargetRoot)) {
        Add-ValidationFailure ("Missing {0} root: {1}" -f $Label, $TargetRoot)
        return @()
    }

    return @(Get-ChildItem -Path $TargetRoot -Recurse -File)
}

# Resolves files for ownership scanning from either a custom root or the manifest layer patterns.
function Get-OwnershipScanFiles {
    param(
        [string] $Root,
        [object] $Manifest,
        [string] $LayerId,
        [string] $ResolvedOverrideRoot,
        [string] $ResolvedDefaultRoot,
        [string] $Label
    )

    if ($ResolvedOverrideRoot -ne $ResolvedDefaultRoot) {
        return @(Get-FilesFromScanRoot -TargetRoot $ResolvedOverrideRoot -Label $Label)
    }

    $layer = Get-ManifestLayerById -Manifest $Manifest -LayerId $LayerId
    if ($null -eq $layer) {
        Add-ValidationFailure ("Instruction ownership manifest is missing layer '{0}'." -f $LayerId)
        return @()
    }

    return @(Get-MatchingFilesForLayer -Root $Root -Layer $layer | ForEach-Object { Get-Item -LiteralPath $_ })
}

# Scans prompts, templates, or skills for ownership markers that should stay elsewhere.
function Test-OwnershipMarkers {
    param(
        [string] $Root,
        [System.IO.FileInfo[]] $Files,
        [string[]] $ForbiddenMarkers,
        [string] $Label
    )

    if ($Files.Count -eq 0) {
        Add-ValidationFailure ("No files found for {0} ownership scan." -f $Label)
        return
    }

    foreach ($file in $Files) {
        $content = Get-Content -Raw -LiteralPath $file.FullName
        $relativePath = Get-NormalizedRelativePath -Root $Root -Path $file.FullName

        foreach ($marker in $ForbiddenMarkers) {
            if ($content -match [regex]::Escape($marker)) {
                Add-ValidationWarning ("{0} may be owning policy instead of behavior: {1} -> marker '{2}'" -f $Label, $relativePath, $marker)
            }
        }
    }
}

# Warns when global core files regrow past agreed architecture budgets.
function Test-GlobalCoreBudget {
    param(
        [object] $Manifest,
        [string] $AgentsContent,
        [string] $GlobalContent
    )

    $constraints = Get-OptionalPropertyValue -InputObject $Manifest -Name 'architectureConstraints'
    if ($null -eq $constraints) {
        return
    }

    $globalCoreMaxChars = Get-OptionalPropertyValue -InputObject $constraints -Name 'globalCoreMaxChars'
    if ($null -eq $globalCoreMaxChars) {
        return
    }

    $agentsLimit = [int] (Get-OptionalPropertyValue -InputObject $globalCoreMaxChars -Name 'AGENTS.md')
    $globalLimit = [int] (Get-OptionalPropertyValue -InputObject $globalCoreMaxChars -Name 'copilot-instructions.md')

    if ($AgentsContent.Length -gt $agentsLimit) {
        Add-ValidationWarning ("AGENTS.md exceeds global-core budget: {0} > {1} characters." -f $AgentsContent.Length, $agentsLimit)
    }

    if ($GlobalContent.Length -gt $globalLimit) {
        Add-ValidationWarning ("copilot-instructions.md exceeds global-core budget: {0} > {1} characters." -f $GlobalContent.Length, $globalLimit)
    }
}

# Extracts the mandatory always-path entries from the routing catalog text.
function Get-RoutingAlwaysPaths {
    param(
        [string] $RoutingCatalogContent
    )

    $lines = $RoutingCatalogContent -split "\r?\n"
    $alwaysPaths = New-Object System.Collections.Generic.List[string]
    $insideAlways = $false

    foreach ($line in $lines) {
        if (-not $insideAlways) {
            if ($line -match '^always:\s*$') {
                $insideAlways = $true
            }

            continue
        }

        if ($line -match '^[A-Za-z0-9_-]+:\s*$') {
            break
        }

        if ($line -match '^\s*-\s+path:\s*(.+?)\s*$') {
            $pathValue = $Matches[1].Trim().Trim("'`"")
            if (-not [string]::IsNullOrWhiteSpace($pathValue)) {
                $alwaysPaths.Add($pathValue) | Out-Null
            }
        }
    }

    return @($alwaysPaths)
}

# Validates routing stays deterministic and within the agreed context budget.
function Test-RoutingDiscipline {
    param(
        [object] $Manifest,
        [string] $RoutingCatalogContent,
        [string] $RoutePromptContent
    )

    $constraints = Get-OptionalPropertyValue -InputObject $Manifest -Name 'architectureConstraints'
    if ($null -eq $constraints) {
        return
    }

    $routingConstraints = Get-OptionalPropertyValue -InputObject $constraints -Name 'routing'
    if ($null -eq $routingConstraints) {
        return
    }

    $maxAlwaysFiles = [int] (Get-OptionalPropertyValue -InputObject $routingConstraints -Name 'maxAlwaysFiles')
    $maxSelectedFiles = [int] (Get-OptionalPropertyValue -InputObject $routingConstraints -Name 'maxSelectedFiles')
    $requiredAlwaysPaths = @(ConvertTo-StringArray -Value (Get-OptionalPropertyValue -InputObject $routingConstraints -Name 'requiredAlwaysPaths'))
    $alwaysPaths = @(Get-RoutingAlwaysPaths -RoutingCatalogContent $RoutingCatalogContent)

    if ($alwaysPaths.Count -gt $maxAlwaysFiles) {
        Add-ValidationWarning ("Routing catalog 'always' section exceeds budget: {0} > {1} paths." -f $alwaysPaths.Count, $maxAlwaysFiles)
    }

    foreach ($requiredPath in $requiredAlwaysPaths) {
        if ($alwaysPaths -notcontains $requiredPath) {
            Add-ValidationFailure ("Routing catalog 'always' section is missing required path: {0}" -f $requiredPath)
        }
    }

    $hardCapPattern = "Hard cap: at most {0} selected instruction files (excluding mandatory)." -f $maxSelectedFiles
    if ($RoutePromptContent -notmatch [regex]::Escape($hardCapPattern)) {
        Add-ValidationFailure ("Route prompt is missing deterministic hard-cap text: {0}" -f $hardCapPattern)
    }
}

# Ensures every repository-owned skill points to the canonical repository operating model.
function Test-SkillCanonicalReferences {
    param(
        [string] $Root,
        [string] $TargetRoot,
        [string] $RequiredPattern
    )

    if (-not (Test-Path -LiteralPath $TargetRoot)) {
        Add-ValidationFailure ("Missing skill root: {0}" -f $TargetRoot)
        return
    }

    $skillFiles = Get-ChildItem -Path $TargetRoot -Recurse -Filter 'SKILL.md' -File
    foreach ($skillFile in $skillFiles) {
        $content = Get-Content -Raw -LiteralPath $skillFile.FullName
        if ($content -notmatch $RequiredPattern) {
            $relativePath = Get-NormalizedRelativePath -Root $Root -Path $skillFile.FullName
            Add-ValidationFailure ("Skill is missing canonical repository-operating reference: {0}" -f $relativePath)
        }
    }
}

$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
Set-Location -Path $resolvedRepoRoot

$resolvedManifestPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $ManifestPath
$resolvedAgentsPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $AgentsPath
$resolvedGlobalInstructionsPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $GlobalInstructionsPath
$resolvedRoutingCatalogPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $RoutingCatalogPath
$resolvedRoutePromptPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $RoutePromptPath
$resolvedPromptRoot = Resolve-RepoPath -Root $resolvedRepoRoot -Path $PromptRoot
$resolvedTemplateRoot = Resolve-RepoPath -Root $resolvedRepoRoot -Path $TemplateRoot
$resolvedSkillRoot = Resolve-RepoPath -Root $resolvedRepoRoot -Path $SkillRoot

$manifest = Read-JsonFile -Path $resolvedManifestPath -Label 'instruction ownership manifest'
Test-ManifestStructure -Manifest $manifest

if ($null -ne $manifest) {
    Test-LayerOverlap -Root $resolvedRepoRoot -Layers @($manifest.layers)
}

$agentsContent = Read-TextFile -Path $resolvedAgentsPath -Label 'AGENTS.md'
$globalInstructionsContent = Read-TextFile -Path $resolvedGlobalInstructionsPath -Label 'copilot-instructions.md'
$routingCatalogContent = Read-TextFile -Path $resolvedRoutingCatalogPath -Label 'instruction routing catalog'
$routePromptContent = Read-TextFile -Path $resolvedRoutePromptPath -Label 'route instructions prompt'

if ($null -ne $agentsContent -and $null -ne $globalInstructionsContent -and $null -ne $routingCatalogContent) {
    Test-GlobalCoreReferences `
        -AgentsContent $agentsContent `
        -GlobalContent $globalInstructionsContent `
        -RoutingContent $routingCatalogContent
}

if ($null -ne $manifest -and $null -ne $agentsContent -and $null -ne $globalInstructionsContent) {
    Test-GlobalCoreBudget `
        -Manifest $manifest `
        -AgentsContent $agentsContent `
        -GlobalContent $globalInstructionsContent
}

if ($null -ne $manifest -and $null -ne $routingCatalogContent -and $null -ne $routePromptContent) {
    Test-RoutingDiscipline `
        -Manifest $manifest `
        -RoutingCatalogContent $routingCatalogContent `
        -RoutePromptContent $routePromptContent
}

if ($null -ne $manifest) {
    foreach ($layer in @($manifest.layers)) {
        $forbiddenMarkers = @(ConvertTo-StringArray -Value (Get-OptionalPropertyValue -InputObject $layer -Name 'forbiddenOwnershipMarkers'))
        if ($forbiddenMarkers.Count -eq 0) {
            continue
        }

        switch ([string] $layer.id) {
            'prompts' {
                $promptFiles = @(Get-OwnershipScanFiles `
                    -Root $resolvedRepoRoot `
                    -Manifest $manifest `
                    -LayerId 'prompts' `
                    -ResolvedOverrideRoot $resolvedPromptRoot `
                    -ResolvedDefaultRoot (Resolve-RepoPath -Root $resolvedRepoRoot -Path '.github/prompts') `
                    -Label 'prompt')
                Test-OwnershipMarkers -Root $resolvedRepoRoot -Files $promptFiles -ForbiddenMarkers $forbiddenMarkers -Label 'Prompt file'
            }
            'templates' {
                $templateFiles = @(Get-OwnershipScanFiles `
                    -Root $resolvedRepoRoot `
                    -Manifest $manifest `
                    -LayerId 'templates' `
                    -ResolvedOverrideRoot $resolvedTemplateRoot `
                    -ResolvedDefaultRoot (Resolve-RepoPath -Root $resolvedRepoRoot -Path '.github/templates') `
                    -Label 'template')
                Test-OwnershipMarkers -Root $resolvedRepoRoot -Files $templateFiles -ForbiddenMarkers $forbiddenMarkers -Label 'Template file'
            }
            'codex-skills' {
                $skillFiles = @(Get-OwnershipScanFiles `
                    -Root $resolvedRepoRoot `
                    -Manifest $manifest `
                    -LayerId 'codex-skills' `
                    -ResolvedOverrideRoot $resolvedSkillRoot `
                    -ResolvedDefaultRoot (Resolve-RepoPath -Root $resolvedRepoRoot -Path '.codex/skills') `
                    -Label 'skill')
                Test-OwnershipMarkers -Root $resolvedRepoRoot -Files $skillFiles -ForbiddenMarkers $forbiddenMarkers -Label 'Skill file'
            }
        }
    }
}

Test-SkillCanonicalReferences `
    -Root $resolvedRepoRoot `
    -TargetRoot $resolvedSkillRoot `
    -RequiredPattern 'repository-operating-model\.instructions\.md'

Write-ValidationOutput ''
Write-ValidationOutput 'Instruction architecture validation summary'
Write-ValidationOutput ("  Warning-only mode: {0}" -f $script:IsWarningOnly)
Write-ValidationOutput ("  Manifest path: {0}" -f $ManifestPath)
Write-ValidationOutput ("  Warnings: {0}" -f $script:Warnings.Count)
Write-ValidationOutput ("  Failures: {0}" -f $script:Failures.Count)

if ($script:Failures.Count -gt 0 -and -not $script:IsWarningOnly) {
    exit 1
}

exit 0
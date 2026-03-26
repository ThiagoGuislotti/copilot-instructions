<#
.SYNOPSIS
    Validates the centralized authoritative documentation policy and source map.

.DESCRIPTION
    Ensures the repository keeps one shared policy for authoritative external
    documentation lookup by validating:
    - `.github/instructions/authoritative-sources.instructions.md`
    - `.github/governance/authoritative-source-map.json`
    - required references from `AGENTS.md`, `copilot-instructions.md`, and
      `instruction-routing.catalog.yml`
    - warning-only detection of duplicated official documentation domains in
      other instruction files

    Exit code:
    - 0 when validation passes or only warnings are found
    - 1 when failures are found and WarningOnly is false

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.PARAMETER SourceMapPath
    Relative path to the authoritative source map JSON.

.PARAMETER InstructionPath
    Relative path to the centralized authoritative-sources instruction file.

.PARAMETER AgentsPath
    Relative path to AGENTS.md.

.PARAMETER GlobalInstructionsPath
    Relative path to copilot-instructions.md.

.PARAMETER RoutingCatalogPath
    Relative path to instruction-routing.catalog.yml.

.PARAMETER InstructionSearchRoot
    Relative or absolute path used to discover instruction files for duplication warnings.

.PARAMETER WarningOnly
    When true (default), failures are emitted as warnings and execution exits with code 0.

.PARAMETER DetailedOutput
    Prints file-level warning details.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/validation/validate-authoritative-source-policy.ps1

.EXAMPLE
    pwsh -File scripts/validation/validate-authoritative-source-policy.ps1 -WarningOnly:$false -DetailedOutput

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $SourceMapPath = '.github/governance/authoritative-source-map.json',
    [string] $InstructionPath = '.github/instructions/authoritative-sources.instructions.md',
    [string] $AgentsPath = '.github/AGENTS.md',
    [string] $GlobalInstructionsPath = '.github/copilot-instructions.md',
    [string] $RoutingCatalogPath = '.github/instruction-routing.catalog.yml',
    [string] $InstructionSearchRoot = '.github/instructions',
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

# Validates one stack rule entry from the source map.
function Test-StackRule {
    param(
        [object] $Rule,
        [hashtable] $SeenIds
    )

    $ruleId = [string] $Rule.id
    if ([string]::IsNullOrWhiteSpace($ruleId)) {
        Add-ValidationFailure 'Authoritative source map contains a stack rule without id.'
        return
    }

    $normalizedRuleId = $ruleId.ToLowerInvariant()
    if ($SeenIds.ContainsKey($normalizedRuleId)) {
        Add-ValidationFailure ("Authoritative source map contains duplicate stack id: {0}" -f $ruleId)
    }
    else {
        $SeenIds[$normalizedRuleId] = $true
    }

    if ([string]::IsNullOrWhiteSpace([string] $Rule.displayName)) {
        Add-ValidationFailure ("Stack rule '{0}' is missing displayName." -f $ruleId)
    }

    $keywords = @(ConvertTo-StringArray -Value $Rule.keywords)
    if ($keywords.Count -eq 0) {
        Add-ValidationFailure ("Stack rule '{0}' must define at least one keyword." -f $ruleId)
    }

    $domains = @(ConvertTo-StringArray -Value $Rule.officialDomains)
    if ($domains.Count -eq 0) {
        Add-ValidationFailure ("Stack rule '{0}' must define at least one official domain." -f $ruleId)
        return
    }

    $seenDomains = @{}
    foreach ($domain in $domains) {
        $normalizedDomain = $domain.Trim().ToLowerInvariant()
        if ([string]::IsNullOrWhiteSpace($normalizedDomain)) {
            Add-ValidationFailure ("Stack rule '{0}' contains an empty official domain." -f $ruleId)
            continue
        }

        if ($normalizedDomain -match '[:/\\\s]') {
            Add-ValidationFailure ("Stack rule '{0}' contains invalid official domain '{1}'. Use bare domains only." -f $ruleId, $domain)
            continue
        }

        if ($normalizedDomain -notmatch '^(?:[a-z0-9-]+\.)+[a-z]{2,}$') {
            Add-ValidationFailure ("Stack rule '{0}' contains malformed official domain '{1}'." -f $ruleId, $domain)
            continue
        }

        if ($seenDomains.ContainsKey($normalizedDomain)) {
            Add-ValidationFailure ("Stack rule '{0}' repeats official domain '{1}'." -f $ruleId, $domain)
            continue
        }

        $seenDomains[$normalizedDomain] = $true
    }
}

# Validates the source map contract.
function Test-SourceMapContract {
    param(
        [object] $SourceMap
    )

    if ($null -eq $SourceMap) {
        return
    }

    if ([int] $SourceMap.version -lt 1) {
        Add-ValidationFailure 'Authoritative source map version must be >= 1.'
    }

    if ($null -eq $SourceMap.defaultPolicy) {
        Add-ValidationFailure 'Authoritative source map must contain defaultPolicy.'
    }

    $stackRules = @($SourceMap.stackRules)
    if ($stackRules.Count -eq 0) {
        Add-ValidationFailure 'Authoritative source map must contain at least one stackRules entry.'
        return
    }

    $requiredStackIds = @(
        'dotnet',
        'github-copilot',
        'vscode',
        'rust',
        'vue',
        'quasar',
        'docker',
        'kubernetes',
        'postgresql',
        'openai'
    )

    $seenIds = @{}
    foreach ($rule in $stackRules) {
        Test-StackRule -Rule $rule -SeenIds $seenIds
    }

    foreach ($requiredStackId in $requiredStackIds) {
        if (-not $seenIds.ContainsKey($requiredStackId)) {
            Add-ValidationFailure ("Authoritative source map is missing required stack id '{0}'." -f $requiredStackId)
        }
    }
}

# Validates that a text file contains required policy fragments.
function Test-TextContainsPatterns {
    param(
        [string] $Text,
        [string] $Label,
        [string[]] $Patterns
    )

    foreach ($pattern in $Patterns) {
        if ($Text -notmatch $pattern) {
            Add-ValidationFailure ("{0} is missing required pattern: {1}" -f $Label, $pattern)
        }
    }
}

# Warns when instruction files duplicate official documentation domains.
function Test-InstructionDomainDuplication {
    param(
        [string] $Root,
        [string] $InstructionDirectoryPath,
        [string] $CentralInstructionPath,
        [string[]] $OfficialDomains
    )

    if (-not (Test-Path -LiteralPath $InstructionDirectoryPath -PathType Container)) {
        Add-ValidationFailure ("Instruction search root not found: {0}" -f $InstructionDirectoryPath)
        return
    }

    $centralInstructionFullPath = [System.IO.Path]::GetFullPath($CentralInstructionPath)
    $instructionFiles = @(
        Get-ChildItem -LiteralPath $InstructionDirectoryPath -Recurse -Filter '*.md' -File
    )

    foreach ($instructionFile in $instructionFiles) {
        $fullPath = [System.IO.Path]::GetFullPath($instructionFile.FullName)
        if ($fullPath -eq $centralInstructionFullPath) {
            continue
        }

        $content = Get-Content -Raw -LiteralPath $instructionFile.FullName
        $matchedDomains = New-Object System.Collections.Generic.List[string]
        foreach ($officialDomain in $OfficialDomains) {
            $escapedDomain = [regex]::Escape($officialDomain)
            $urlPattern = ('https?://{0}(?:/[^\s)>''"`]*)?' -f $escapedDomain)
            $bareDomainPattern = ('(?<![A-Za-z0-9.-]){0}(?=$|[\s`''"),.;:])' -f $escapedDomain)
            if ($content -match $urlPattern -or $content -match $bareDomainPattern) {
                $matchedDomains.Add($officialDomain) | Out-Null
            }
        }

        if ($matchedDomains.Count -gt 0) {
            $relativePath = [System.IO.Path]::GetRelativePath($Root, $instructionFile.FullName).Replace('\', '/')
            Add-ValidationWarning (
                "Instruction duplicates official documentation domains and should use the centralized source policy: {0} -> {1}" -f
                $relativePath,
                (@($matchedDomains) | Sort-Object -Unique) -join ', '
            )
        }
    }
}

$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
Set-Location -Path $resolvedRepoRoot

$sourceMapAbsolute = Resolve-RepoPath -Root $resolvedRepoRoot -Path $SourceMapPath
$instructionAbsolute = Resolve-RepoPath -Root $resolvedRepoRoot -Path $InstructionPath
$agentsAbsolute = Resolve-RepoPath -Root $resolvedRepoRoot -Path $AgentsPath
$globalInstructionsAbsolute = Resolve-RepoPath -Root $resolvedRepoRoot -Path $GlobalInstructionsPath
$routingCatalogAbsolute = Resolve-RepoPath -Root $resolvedRepoRoot -Path $RoutingCatalogPath
$instructionSearchAbsolute = Resolve-RepoPath -Root $resolvedRepoRoot -Path $InstructionSearchRoot

$sourceMap = Read-JsonFile -Path $sourceMapAbsolute -Label 'authoritative source map'
Test-SourceMapContract -SourceMap $sourceMap

$instructionText = Read-TextFile -Path $instructionAbsolute -Label 'authoritative sources instruction'
if ($null -ne $instructionText) {
    Test-TextContainsPatterns -Text $instructionText -Label 'authoritative sources instruction' -Patterns @(
        '\.github/governance/authoritative-source-map\.json',
        'repository context first',
        'official documentation',
        'community sources'
    )
}

$agentsText = Read-TextFile -Path $agentsAbsolute -Label 'AGENTS.md'
if ($null -ne $agentsText) {
    Test-TextContainsPatterns -Text $agentsText -Label 'AGENTS.md' -Patterns @(
        'instructions/authoritative-sources\.instructions\.md',
        '\.github/governance/authoritative-source-map\.json'
    )
}

$globalInstructionsText = Read-TextFile -Path $globalInstructionsAbsolute -Label 'copilot-instructions.md'
if ($null -ne $globalInstructionsText) {
    Test-TextContainsPatterns -Text $globalInstructionsText -Label 'copilot-instructions.md' -Patterns @(
        'instructions/authoritative-sources\.instructions\.md',
        '\.github/governance/authoritative-source-map\.json'
    )
}

$routingText = Read-TextFile -Path $routingCatalogAbsolute -Label 'instruction routing catalog'
if ($null -ne $routingText) {
    Test-TextContainsPatterns -Text $routingText -Label 'instruction routing catalog' -Patterns @(
        'path:\s*instructions/authoritative-sources\.instructions\.md'
    )
}

$officialDomains = @()
if ($null -ne $sourceMap -and $null -ne $sourceMap.stackRules) {
    $officialDomains = @(
        $sourceMap.stackRules |
            ForEach-Object { ConvertTo-StringArray -Value $_.officialDomains } |
            ForEach-Object { $_.Trim().ToLowerInvariant() } |
            Sort-Object -Unique
    )
}

if ($officialDomains.Count -gt 0) {
    Test-InstructionDomainDuplication `
        -Root $resolvedRepoRoot `
        -InstructionDirectoryPath $instructionSearchAbsolute `
        -CentralInstructionPath $instructionAbsolute `
        -OfficialDomains $officialDomains
}

Write-StyledOutput ''
Write-StyledOutput 'Authoritative source policy validation summary'
Write-StyledOutput ("  Warning-only mode: {0}" -f $script:IsWarningOnly)
Write-StyledOutput ("  Source map path: {0}" -f $SourceMapPath)
Write-StyledOutput ("  Instruction path: {0}" -f $InstructionPath)
Write-StyledOutput ("  Warnings: {0}" -f $script:Warnings.Count)
Write-StyledOutput ("  Failures: {0}" -f $script:Failures.Count)

if ($script:IsDetailedOutputEnabled -and $script:Warnings.Count -gt 0) {
    Write-StyledOutput ''
    Write-StyledOutput 'Warnings'
    foreach ($warning in $script:Warnings) {
        Write-StyledOutput ("  - {0}" -f $warning)
    }
}

if ($script:Failures.Count -gt 0 -and (-not $script:IsWarningOnly)) {
    exit 1
}

if ($script:Failures.Count -gt 0 -or $script:Warnings.Count -gt 0) {
    Write-StyledOutput 'Authoritative source policy validation completed with warnings.'
}
else {
    Write-StyledOutput 'Authoritative source policy validation passed.'
}

exit 0
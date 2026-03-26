<#
.SYNOPSIS
    Validates PowerShell script standards across repository scripts.

.DESCRIPTION
    Enforces baseline script quality for files under `scripts/**/*.ps1`.

    Checks include:
    - Comment-based help block and required help sections
    - Param block presence
    - ErrorActionPreference set to Stop
    - SuppressMessageAttribute usage
    - Function naming and approved verbs
    - Function-level description comments
    - Optional PSScriptAnalyzer pass when available

    Exit code:
    - 0 when required checks pass
    - 1 when any required check fails

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.PARAMETER ScriptsRoot
    Scripts directory root. Defaults to `scripts`.

.PARAMETER IncludeAllScripts
    Validates all scripts under ScriptsRoot. If omitted, validates governance-critical script folders only.

.PARAMETER Strict
    Treats warning-level style findings as failures.

.PARAMETER SkipScriptAnalyzer
    Skips optional PSScriptAnalyzer execution.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/validation/validate-powershell-standards.ps1

.EXAMPLE
    pwsh -File scripts/validation/validate-powershell-standards.ps1 -IncludeAllScripts -Strict

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $ScriptsRoot = 'scripts',
    [switch] $IncludeAllScripts,
    [switch] $Strict,
    [switch] $SkipScriptAnalyzer,
    [switch] $Verbose
)

$ErrorActionPreference = 'Stop'

$script:ConsoleStylePath = Join-Path $PSScriptRoot '..\common\console-style.ps1'
if (-not (Test-Path -LiteralPath $script:ConsoleStylePath -PathType Leaf)) {
    $script:ConsoleStylePath = Join-Path $PSScriptRoot '..\..\common\console-style.ps1'
}
if (Test-Path -LiteralPath $script:ConsoleStylePath -PathType Leaf) {
    . $script:ConsoleStylePath
}
$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
$script:IsVerboseEnabled = [bool] $Verbose
$script:IsStrictEnabled = [bool] $Strict
$script:Failures = New-Object System.Collections.Generic.List[string]
$script:Warnings = New-Object System.Collections.Generic.List[string]

# -------------------------------
# Helpers
# -------------------------------
# Writes verbose diagnostics.
function Write-VerboseLog {
    param(
        [string] $Message
    )

    if ($script:IsVerboseEnabled) {
        Write-StyledOutput ("[VERBOSE] {0}" -f $Message)
    }
}

# Registers a validation failure.
function Add-ValidationFailure {
    param(
        [string] $Message
    )

    $script:Failures.Add($Message) | Out-Null
    Write-StyledOutput ("[FAIL] {0}" -f $Message)
}

# Registers a validation warning.
function Add-ValidationWarning {
    param(
        [string] $Message
    )

    if ($script:IsStrictEnabled) {
        Add-ValidationFailure -Message ("[strict] {0}" -f $Message)
        return
    }

    $script:Warnings.Add($Message) | Out-Null
    Write-StyledOutput ("[WARN] {0}" -f $Message)
}

# Resolves a path from repo root.
function Resolve-RepoPath {
    param(
        [string] $Root,
        [string] $Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $Root $Path))
}

# Resolves repository root from input and fallbacks.
function Resolve-RepositoryRoot {
    param(
        [string] $RequestedRoot
    )

    $candidates = @()

    if (-not [string]::IsNullOrWhiteSpace($RequestedRoot)) {
        try {
            $candidates += (Resolve-Path -LiteralPath $RequestedRoot).Path
        }
        catch {
            throw "Invalid RepoRoot path: $RequestedRoot"
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($script:ScriptRoot)) {
        $candidates += (Resolve-Path -LiteralPath (Join-Path $script:ScriptRoot '..\..')).Path
    }

    $candidates += (Get-Location).Path

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        $current = $candidate
        for ($i = 0; $i -lt 6 -and -not [string]::IsNullOrWhiteSpace($current); $i++) {
            $hasLayout = (Test-Path -LiteralPath (Join-Path $current '.github')) -and (Test-Path -LiteralPath (Join-Path $current '.codex'))
            if ($hasLayout) {
                Write-VerboseLog ("Repository root detected: {0}" -f $current)
                return $current
            }

            $current = Split-Path -Path $current -Parent
        }
    }

    throw 'Could not detect repository root containing both .github and .codex.'
}

# Converts absolute path into a repository-relative path.
function Convert-ToRelativePath {
    param(
        [string] $Root,
        [string] $Path
    )

    return [System.IO.Path]::GetRelativePath($Root, $Path)
}

# Resolves script files targeted by validation.
function Get-TargetScriptFileList {
    param(
        [string] $Root,
        [string] $ScriptsDirectory,
        [switch] $AllScripts
    )

    $resolvedScriptsRoot = Resolve-RepoPath -Root $Root -Path $ScriptsDirectory
    if (-not (Test-Path -LiteralPath $resolvedScriptsRoot -PathType Container)) {
        Add-ValidationFailure ("Scripts root not found: {0}" -f $ScriptsDirectory)
        return @()
    }

    if ($AllScripts) {
        return @(Get-ChildItem -LiteralPath $resolvedScriptsRoot -Recurse -File -Filter '*.ps1' | Select-Object -ExpandProperty FullName | Sort-Object -Unique)
    }

    $criticalFolders = @(
        'scripts/validation',
        'scripts/runtime',
        'scripts/orchestration',
        'scripts/governance',
        'scripts/git-hooks'
    )

    $fileSet = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($criticalFolder in $criticalFolders) {
        $folderPath = Resolve-RepoPath -Root $Root -Path $criticalFolder
        if (-not (Test-Path -LiteralPath $folderPath -PathType Container)) {
            Add-ValidationWarning ("Critical script folder not found: {0}" -f $criticalFolder)
            continue
        }

        Get-ChildItem -LiteralPath $folderPath -Recurse -File -Filter '*.ps1' | ForEach-Object {
            $fileSet.Add($_.FullName) | Out-Null
        }
    }

    return @($fileSet | Sort-Object)
}

# Checks if script contains comment-based help block near top.
function Test-CommentBasedHelpBlock {
    param(
        [string] $RawContent,
        [string] $RelativePath
    )

    $hasHelpBlock = $RawContent -match '(?s)^\s*<#\s*.*?#>'
    if (-not $hasHelpBlock) {
        Add-ValidationWarning ("Missing comment-based help block: {0}" -f $RelativePath)
    }

    return $hasHelpBlock
}

# Checks required help sections inside comment-based help.
function Test-HelpSectionSet {
    param(
        [string] $RawContent,
        [string] $RelativePath
    )

    $requiredTokens = @('.SYNOPSIS', '.DESCRIPTION', '.PARAMETER', '.EXAMPLE', '.NOTES')
    foreach ($token in $requiredTokens) {
        if ($RawContent -notmatch [regex]::Escape($token)) {
            Add-ValidationWarning ("Help section missing {0}: {1}" -f $token, $RelativePath)
        }
    }
}

# Checks presence of param block.
function Test-ParamBlockPresence {
    param(
        [string] $RawContent,
        [string] $RelativePath
    )

    if ($RawContent -notmatch '(?im)^\s*param\s*\(') {
        Add-ValidationFailure ("Missing param() block: {0}" -f $RelativePath)
    }
}

# Checks ErrorActionPreference is set to Stop.
function Test-ErrorActionPreferenceSetting {
    param(
        [string] $RawContent,
        [string] $RelativePath
    )

    $hasStopSingle = $RawContent -match '(?im)^\s*\$ErrorActionPreference\s*=\s*''Stop''\s*$'
    $hasStopDouble = $RawContent -match '(?im)^\s*\$ErrorActionPreference\s*=\s*"Stop"\s*$'

    if (-not ($hasStopSingle -or $hasStopDouble)) {
        Add-ValidationWarning ("Missing '$ErrorActionPreference = Stop' assignment: {0}" -f $RelativePath)
    }
}

# Checks disallowed SuppressMessageAttribute usage.
function Test-SuppressAttributeUsage {
    param(
        [string] $RawContent,
        [string] $RelativePath
    )

    if ($RawContent -match '(?im)^\s*\[[^\]]*SuppressMessage(Attribute)?') {
        Add-ValidationFailure ("SuppressMessageAttribute is not allowed in scripts: {0}" -f $RelativePath)
    }
}

# Returns declared function names with line numbers.
function Get-FunctionDeclarationList {
    param(
        [string[]] $Lines
    )

    $result = New-Object System.Collections.Generic.List[object]
    for ($lineIndex = 0; $lineIndex -lt $Lines.Count; $lineIndex++) {
        $match = [regex]::Match($Lines[$lineIndex], '^\s*function\s+(?<name>[A-Za-z][A-Za-z0-9-]*)\b')
        if (-not $match.Success) {
            continue
        }

        $result.Add([pscustomobject]@{
            name = $match.Groups['name'].Value
            line = $lineIndex + 1
        }) | Out-Null
    }

    return $result
}

# Checks function names against approved PowerShell verbs.
function Test-FunctionVerbUsage {
    param(
        [object[]] $Functions,
        [string] $RelativePath
    )

    $approvedVerbs = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($verb in (Get-Verb | Select-Object -ExpandProperty Verb)) {
        $approvedVerbs.Add($verb) | Out-Null
    }

    foreach ($functionInfo in $Functions) {
        $functionName = [string] $functionInfo.name
        if ($functionName -notmatch '-') {
            Add-ValidationWarning ("Function name should use Verb-Noun format: {0}:{1} ({2})" -f $RelativePath, $functionInfo.line, $functionName)
            continue
        }

        $verb = $functionName.Split('-')[0]
        if (-not $approvedVerbs.Contains($verb)) {
            Add-ValidationWarning ("Function uses unapproved verb '{0}': {1}:{2} ({3})" -f $verb, $RelativePath, $functionInfo.line, $functionName)
        }
    }
}

# Checks each function has a comment line before its declaration.
function Test-FunctionCommentCoverage {
    param(
        [object[]] $Functions,
        [string[]] $Lines,
        [string] $RelativePath
    )

    foreach ($functionInfo in $Functions) {
        $index = [int] $functionInfo.line - 2
        while ($index -ge 0 -and [string]::IsNullOrWhiteSpace($Lines[$index])) {
            $index--
        }

        if ($index -lt 0 -or $Lines[$index].TrimStart() -notmatch '^#') {
            Add-ValidationFailure ("Function missing description comment above declaration: {0}:{1} ({2})" -f $RelativePath, $functionInfo.line, $functionInfo.name)
        }
    }
}

# Runs optional PSScriptAnalyzer and records findings.
function Invoke-PSScriptAnalyzerCheck {
    param(
        [string[]] $ScriptPaths,
        [string] $Root,
        [switch] $SkipAnalyzer
    )

    if ($ScriptPaths.Count -eq 0) {
        return
    }

    if ($SkipAnalyzer) {
        Write-VerboseLog 'Skipping PSScriptAnalyzer by parameter.'
        return
    }

    $analyzerCommand = Get-Command Invoke-ScriptAnalyzer -ErrorAction SilentlyContinue
    if ($null -eq $analyzerCommand) {
        Add-ValidationWarning 'PSScriptAnalyzer not available; analyzer checks skipped.'
        return
    }

    foreach ($scriptPath in $ScriptPaths) {
        $results = @()
        try {
            $results = @(Invoke-ScriptAnalyzer -Path $scriptPath -Severity @('Error', 'Warning'))
        }
        catch {
            $relativePath = Convert-ToRelativePath -Root $Root -Path $scriptPath
            Add-ValidationFailure ("PSScriptAnalyzer execution failed for {0}: {1}" -f $relativePath, $_.Exception.Message)
            continue
        }

        foreach ($result in $results) {
            $relativePath = Convert-ToRelativePath -Root $Root -Path $result.ScriptPath
            $ruleText = if ([string]::IsNullOrWhiteSpace([string] $result.RuleName)) { 'UnknownRule' } else { [string] $result.RuleName }
            $message = if ([string]::IsNullOrWhiteSpace([string] $result.Message)) { 'Analyzer finding without message.' } else { [string] $result.Message }
            $line = if ($result.Line) { [int] $result.Line } else { 0 }
            $entry = ("{0}:{1} [{2}] {3}" -f $relativePath, $line, $ruleText, $message)

            if ([string] $result.Severity -eq 'Error') {
                Add-ValidationFailure ("PSScriptAnalyzer error: {0}" -f $entry)
            }
            else {
                Add-ValidationWarning ("PSScriptAnalyzer warning: {0}" -f $entry)
            }
        }
    }
}

# -------------------------------
# Main execution
# -------------------------------
$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
Set-Location -Path $resolvedRepoRoot

$scriptPaths = Get-TargetScriptFileList -Root $resolvedRepoRoot -ScriptsDirectory $ScriptsRoot -AllScripts:$IncludeAllScripts
if ($scriptPaths.Count -eq 0) {
    if ($script:Failures.Count -eq 0) {
        Add-ValidationWarning 'No PowerShell scripts found for validation.'
    }
}

$filesChecked = 0
foreach ($scriptPath in $scriptPaths) {
    $relativePath = Convert-ToRelativePath -Root $resolvedRepoRoot -Path $scriptPath
    $rawContent = Get-Content -Raw -LiteralPath $scriptPath
    $lines = @(Get-Content -LiteralPath $scriptPath)

    $filesChecked++
    $hasHelpBlock = Test-CommentBasedHelpBlock -RawContent $rawContent -RelativePath $relativePath
    if ($hasHelpBlock) {
        Test-HelpSectionSet -RawContent $rawContent -RelativePath $relativePath
    }

    Test-ParamBlockPresence -RawContent $rawContent -RelativePath $relativePath
    Test-ErrorActionPreferenceSetting -RawContent $rawContent -RelativePath $relativePath
    Test-SuppressAttributeUsage -RawContent $rawContent -RelativePath $relativePath

    $functions = @(Get-FunctionDeclarationList -Lines $lines)
    Test-FunctionVerbUsage -Functions $functions -RelativePath $relativePath
    Test-FunctionCommentCoverage -Functions $functions -Lines $lines -RelativePath $relativePath

    Write-VerboseLog ("Validated script: {0}" -f $relativePath)
}

Invoke-PSScriptAnalyzerCheck -ScriptPaths $scriptPaths -Root $resolvedRepoRoot -SkipAnalyzer:$SkipScriptAnalyzer

Write-StyledOutput ''
Write-StyledOutput 'PowerShell standards validation summary'
Write-StyledOutput ("  Files checked: {0}" -f $filesChecked)
Write-StyledOutput ("  Warnings: {0}" -f $script:Warnings.Count)
Write-StyledOutput ("  Failures: {0}" -f $script:Failures.Count)

if ($script:Failures.Count -gt 0) {
    exit 1
}

Write-StyledOutput 'PowerShell standards validation passed.'
exit 0
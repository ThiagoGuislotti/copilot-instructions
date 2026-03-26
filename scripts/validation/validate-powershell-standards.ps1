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
    Legacy compatibility switch. All scripts under ScriptsRoot are validated by default.

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
Initialize-ValidationState -VerboseEnabled $script:IsVerboseEnabled
$script:IsStrictEnabled = [bool] $Strict

# -------------------------------
# Helpers
# -------------------------------

# Resolves a path from repo root.

# Resolves repository root from input and fallbacks.

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

    return @(Get-ChildItem -LiteralPath $resolvedScriptsRoot -Recurse -File -Filter '*.ps1' | Select-Object -ExpandProperty FullName | Sort-Object -Unique)
}

# Fails when tracked PowerShell scripts are stored with non-normalized line endings in Git.
function Test-TrackedScriptLineEndingNormalization {
    param(
        [string] $Root,
        [string[]] $ScriptPaths
    )

    $gitCommand = Get-Command -Name 'git' -ErrorAction SilentlyContinue
    if ($null -eq $gitCommand) {
        Add-ValidationWarning 'Git not found; tracked PowerShell line-ending normalization check skipped.'
        return
    }

    $relativeTrackedPaths = @()
    foreach ($scriptPath in $ScriptPaths) {
        $relativePath = Convert-ToRelativePath -Root $Root -Path $scriptPath
        $trackedPath = (& git -C $Root ls-files --error-unmatch -- $relativePath 2>$null)
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace(($trackedPath -join ''))) {
            $relativeTrackedPaths += $relativePath
        }
    }

    if ($relativeTrackedPaths.Count -eq 0) {
        return
    }

    $eolLines = @(& git -C $Root ls-files --eol -- $relativeTrackedPaths 2>$null)
    if ($LASTEXITCODE -ne 0) {
        Add-ValidationWarning 'Could not inspect tracked PowerShell line endings with git ls-files --eol.'
        return
    }

    foreach ($line in $eolLines) {
        $text = [string] $line
        if ([string]::IsNullOrWhiteSpace($text)) {
            continue
        }

        if ($text -match '^i/(mixed|crlf)\b') {
            Add-ValidationFailure ("Tracked PowerShell script is not normalized in Git index: {0}" -f $text.Trim())
        }
    }
}

# Checks if script contains comment-based help block near top.
function Test-CommentBasedHelpBlock {
    param(
        [string] $RawContent,
        [string] $RelativePath
    )

    $normalizedContent = $RawContent.TrimStart([char] 0xFEFF)
    $hasHelpBlock = $normalizedContent -match '(?s)^\s*<#\s*.*?#>'
    if (-not $hasHelpBlock) {
        Add-ValidationFailure ("Missing comment-based help block: {0}" -f $RelativePath)
    }

    return $hasHelpBlock
}

# Checks required help sections inside comment-based help.
function Test-HelpSectionSet {
    param(
        [string] $RawContent,
        [string] $RelativePath,
        [string[]] $ScriptParameters
    )

    $requiredTokens = @('.SYNOPSIS', '.DESCRIPTION', '.EXAMPLE', '.NOTES')
    foreach ($token in $requiredTokens) {
        if ($RawContent -notmatch [regex]::Escape($token)) {
            Add-ValidationFailure ("Help section missing {0}: {1}" -f $token, $RelativePath)
        }
    }

    if (@($ScriptParameters).Count -gt 0 -and $RawContent -notmatch [regex]::Escape('.PARAMETER')) {
        Add-ValidationFailure ("Help section missing .PARAMETER entries: {0}" -f $RelativePath)
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

# Returns script-level parameter names from the top-level param block.
function Get-ScriptParameterNameList {
    param(
        [System.Management.Automation.Language.ScriptBlockAst] $Ast
    )

    if ($null -eq $Ast -or $null -eq $Ast.ParamBlock) {
        return @()
    }

    return @($Ast.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })
}

# Ensures each script-level parameter has a matching .PARAMETER entry in the help block.
function Test-ScriptParameterHelpCoverage {
    param(
        [string] $RawContent,
        [string[]] $ScriptParameters,
        [string] $RelativePath
    )

    foreach ($parameterName in $ScriptParameters) {
        $parameterPattern = "(?im)^\s*\.PARAMETER\s+{0}\b" -f [regex]::Escape($parameterName)
        if ($RawContent -notmatch $parameterPattern) {
            Add-ValidationFailure ("Script help is missing .PARAMETER {0}: {1}" -f $parameterName, $RelativePath)
        }
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

Test-TrackedScriptLineEndingNormalization -Root $resolvedRepoRoot -ScriptPaths $scriptPaths

$filesChecked = 0
foreach ($scriptPath in $scriptPaths) {
    $relativePath = Convert-ToRelativePath -Root $resolvedRepoRoot -Path $scriptPath
    $rawContent = Get-Content -Raw -LiteralPath $scriptPath
    $lines = @(Get-Content -LiteralPath $scriptPath)
    $tokens = $null
    $errors = $null
    $scriptAst = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref] $tokens, [ref] $errors)
    $scriptParameters = @(Get-ScriptParameterNameList -Ast $scriptAst)

    $filesChecked++
    $hasHelpBlock = Test-CommentBasedHelpBlock -RawContent $rawContent -RelativePath $relativePath
    if ($hasHelpBlock) {
        Test-HelpSectionSet -RawContent $rawContent -RelativePath $relativePath -ScriptParameters $scriptParameters
        Test-ScriptParameterHelpCoverage -RawContent $rawContent -ScriptParameters $scriptParameters -RelativePath $relativePath
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
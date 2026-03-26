<#
.SYNOPSIS
    Validates repository governance policies declared in .github/policies/*.json.

.DESCRIPTION
    Loads policy files from `.github/policies` and enforces required/forbidden
    repository contracts such as:
    - required files and directories
    - required git hook scripts under `.githooks`
    - optional required local git config values

    Exit code:
    - 0 when all policies pass
    - 1 when any policy check fails

.PARAMETER RepoRoot
    Optional repository root. If omitted, the script auto-detects a root containing .github and .codex.

.PARAMETER PolicyDirectory
    Relative or absolute path to the policy directory. Defaults to `.github/policies`.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/validation/validate-policy.ps1

.EXAMPLE
    pwsh -File scripts/validation/validate-policy.ps1 -Verbose

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $PolicyDirectory = '.github/policies',
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

# -------------------------------
# Helpers
# -------------------------------
# Writes verbose diagnostics with a logical color label.

# Registers a validation failure and prints a standardized failure message.

# Registers a validation warning and prints a standardized warning message.

# Builds an absolute path from repository root and relative input path.

# Resolves the repository root using explicit and fallback location candidates.

# Converts input values to a string array while handling null and scalar values.
function Convert-ToStringArray {
    param(
        [object] $Value
    )

    if ($null -eq $Value) {
        return ,@()
    }

    if ($Value -is [string]) {
        return ,@([string] $Value)
    }

    return ,@($Value | ForEach-Object { [string] $_ })
}

# Reads an optional property value without triggering strict-mode property errors.
function Get-OptionalPropertyValue {
    param(
        [object] $InputObject,
        [string] $PropertyName
    )

    if ($null -eq $InputObject) {
        return $null
    }

    $property = $InputObject.PSObject.Properties[$PropertyName]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

# Validates a policy object against required repository governance contracts.
function Test-PolicyContract {
    param(
        [string] $Root,
        [string] $PolicyPath,
        [object] $PolicyObject
    )

    $policyId = [string] $PolicyObject.id
    if ([string]::IsNullOrWhiteSpace($policyId)) {
        $policyId = [System.IO.Path]::GetFileNameWithoutExtension($PolicyPath)
    }

    Write-StyledOutput ("[POLICY] {0}" -f $policyId)

    $allowedKeys = @(
        'id',
        'description',
        'requiredFiles',
        'requiredDirectories',
        'forbiddenFiles',
        'requiredGitHooks',
        'requiredGitConfig'
    )

    foreach ($property in $PolicyObject.PSObject.Properties.Name) {
        if ($property -notin $allowedKeys) {
            Add-ValidationWarning ("Policy has unknown key '{0}' in {1}" -f $property, $PolicyPath)
        }
    }

    $requiredFiles = Get-OptionalPropertyValue -InputObject $PolicyObject -PropertyName 'requiredFiles'
    foreach ($relativePath in (Convert-ToStringArray -Value $requiredFiles)) {
        $absolutePath = Resolve-RepoPath -Root $Root -Path $relativePath
        if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
            Add-ValidationFailure ("Missing required file '{0}' (policy: {1})" -f $relativePath, $policyId)
        }
        else {
            Write-VerboseColor ("[OK] required file: {0}" -f $relativePath) 'Green'
        }
    }

    $requiredDirectories = Get-OptionalPropertyValue -InputObject $PolicyObject -PropertyName 'requiredDirectories'
    foreach ($relativePath in (Convert-ToStringArray -Value $requiredDirectories)) {
        $absolutePath = Resolve-RepoPath -Root $Root -Path $relativePath
        if (-not (Test-Path -LiteralPath $absolutePath -PathType Container)) {
            Add-ValidationFailure ("Missing required directory '{0}' (policy: {1})" -f $relativePath, $policyId)
        }
        else {
            Write-VerboseColor ("[OK] required directory: {0}" -f $relativePath) 'Green'
        }
    }

    $forbiddenFiles = Get-OptionalPropertyValue -InputObject $PolicyObject -PropertyName 'forbiddenFiles'
    foreach ($relativePath in (Convert-ToStringArray -Value $forbiddenFiles)) {
        $absolutePath = Resolve-RepoPath -Root $Root -Path $relativePath
        if (Test-Path -LiteralPath $absolutePath -PathType Leaf) {
            Add-ValidationFailure ("Forbidden file present '{0}' (policy: {1})" -f $relativePath, $policyId)
        }
        else {
            Write-VerboseColor ("[OK] forbidden file absent: {0}" -f $relativePath) 'Green'
        }
    }

    $requiredGitHooks = Get-OptionalPropertyValue -InputObject $PolicyObject -PropertyName 'requiredGitHooks'
    foreach ($hookName in (Convert-ToStringArray -Value $requiredGitHooks)) {
        $hookPath = Resolve-RepoPath -Root $Root -Path (Join-Path '.githooks' $hookName)
        if (-not (Test-Path -LiteralPath $hookPath -PathType Leaf)) {
            Add-ValidationFailure ("Missing required git hook '.githooks/{0}' (policy: {1})" -f $hookName, $policyId)
        }
        else {
            Write-VerboseColor ("[OK] required git hook: {0}" -f $hookName) 'Green'
        }
    }

    $requiredGitConfig = Get-OptionalPropertyValue -InputObject $PolicyObject -PropertyName 'requiredGitConfig'
    if ($null -ne $requiredGitConfig) {
        $gitCommand = Get-Command git -ErrorAction SilentlyContinue
        if ($null -eq $gitCommand) {
            Add-ValidationWarning ("Git command not found; skipping requiredGitConfig checks (policy: {0})" -f $policyId)
        }
        else {
            foreach ($configEntry in $requiredGitConfig.PSObject.Properties) {
                $key = [string] $configEntry.Name
                $expectedValue = [string] $configEntry.Value
                $currentValue = (& git config --local --get $key 2>$null)
                if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($currentValue)) {
                    Add-ValidationFailure ("Missing required git config '{0}' (policy: {1})" -f $key, $policyId)
                    continue
                }

                if ($currentValue -ne $expectedValue) {
                    Add-ValidationFailure ("Git config '{0}' expected '{1}' but found '{2}' (policy: {3})" -f $key, $expectedValue, $currentValue, $policyId)
                    continue
                }

                Write-VerboseColor ("[OK] git config: {0}={1}" -f $key, $expectedValue) 'Green'
            }
        }
    }
}

# -------------------------------
# Main execution
# -------------------------------
$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
Set-Location -Path $resolvedRepoRoot
$resolvedPolicyDirectory = Resolve-RepoPath -Root $resolvedRepoRoot -Path $PolicyDirectory

if (-not (Test-Path -LiteralPath $resolvedPolicyDirectory -PathType Container)) {
    Add-ValidationFailure ("Policy directory not found: {0}" -f $PolicyDirectory)
}
else {
    $policyFiles = @(Get-ChildItem -LiteralPath $resolvedPolicyDirectory -File -Filter '*.json' | Sort-Object Name)
    if ($policyFiles.Count -eq 0) {
        Add-ValidationFailure ("No policy files found in: {0}" -f $PolicyDirectory)
    }
    else {
        foreach ($policyFile in $policyFiles) {
            $relativePolicyPath = [System.IO.Path]::GetRelativePath($resolvedRepoRoot, $policyFile.FullName)
            $policyObject = $null

            try {
                $policyObject = Get-Content -Raw -LiteralPath $policyFile.FullName | ConvertFrom-Json -Depth 100
                Write-StyledOutput ("[OK] Policy JSON parse: {0}" -f $relativePolicyPath)
            }
            catch {
                Add-ValidationFailure ("Invalid JSON in policy file {0} :: {1}" -f $relativePolicyPath, $_.Exception.Message)
                continue
            }

            Test-PolicyContract -Root $resolvedRepoRoot -PolicyPath $relativePolicyPath -PolicyObject $policyObject
        }
    }
}

Write-StyledOutput ''
Write-StyledOutput 'Policy validation summary'
Write-StyledOutput ("  Warnings: {0}" -f $script:Warnings.Count)
Write-StyledOutput ("  Failures: {0}" -f $script:Failures.Count)

if ($script:Failures.Count -gt 0) {
    exit 1
}

Write-StyledOutput 'All policy validations passed.'
exit 0
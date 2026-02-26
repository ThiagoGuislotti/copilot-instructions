<#
.SYNOPSIS
    Validates local supply-chain baseline and generates a lightweight SBOM report.

.DESCRIPTION
    Scans dependency manifests in repository scope and enforces contracts declared
    in `.github/governance/supply-chain.baseline.json`.

    Checks include:
    - dependency inventory extraction (Node, .NET, Rust)
    - blocked/sensitive dependency pattern checks
    - optional license evidence presence
    - SBOM JSON export for audit usage

    Exit code:
    - 0 in warning-only mode (default)
    - 1 when enforcing mode is enabled and failures are found

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.PARAMETER BaselinePath
    Supply-chain baseline JSON path relative to repository root.

.PARAMETER WarningOnly
    When true (default), findings are emitted as warnings and do not fail execution.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/validation/validate-supply-chain.ps1

.EXAMPLE
    pwsh -File scripts/validation/validate-supply-chain.ps1 -WarningOnly:$false

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $BaselinePath = '.github/governance/supply-chain.baseline.json',
    [bool] $WarningOnly = $true,
    [switch] $Verbose
)

$ErrorActionPreference = 'Stop'
$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
$script:IsVerboseEnabled = [bool] $Verbose
$script:IsWarningOnly = [bool] $WarningOnly
$script:Failures = New-Object System.Collections.Generic.List[string]
$script:Warnings = New-Object System.Collections.Generic.List[string]

# Writes verbose diagnostics.
function Write-VerboseLog {
    param(
        [string] $Message
    )

    if ($script:IsVerboseEnabled) {
        Write-Output ("[VERBOSE] {0}" -f $Message)
    }
}

# Registers a validation failure.
function Add-ValidationFailure {
    param(
        [string] $Message
    )

    if ($script:IsWarningOnly) {
        $script:Warnings.Add($Message) | Out-Null
        Write-Output ("[WARN] {0}" -f $Message)
        return
    }

    $script:Failures.Add($Message) | Out-Null
    Write-Output ("[FAIL] {0}" -f $Message)
}

# Registers a validation warning.
function Add-ValidationWarning {
    param(
        [string] $Message
    )

    $script:Warnings.Add($Message) | Out-Null
    Write-Output ("[WARN] {0}" -f $Message)
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

# Resolves repository root from input and fallback candidates.
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
        for ($index = 0; $index -lt 6 -and -not [string]::IsNullOrWhiteSpace($current); $index++) {
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

# Reads and parses a required JSON document.
function Get-RequiredJsonDocument {
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

# Converts glob syntax to a regex pattern.
function Convert-GlobToRegex {
    param(
        [string] $Glob
    )

    $normalized = $Glob.Replace('\', '/')
    $escaped = [System.Text.RegularExpressions.Regex]::Escape($normalized)
    $escaped = $escaped.Replace('\*\*', '.*')
    $escaped = $escaped.Replace('\*', '[^/]*')
    $escaped = $escaped.Replace('\?', '.')
    return "^{0}$" -f $escaped
}

# Matches path against one or more glob patterns.
function Test-PathGlobMatch {
    param(
        [string] $RelativePath,
        [string[]] $GlobPatterns
    )

    $normalizedPath = $RelativePath.Replace('\', '/')
    foreach ($globPattern in $GlobPatterns) {
        if ([string]::IsNullOrWhiteSpace($globPattern)) {
            continue
        }

        $regexPattern = Convert-GlobToRegex -Glob $globPattern
        if ($normalizedPath -match $regexPattern) {
            return $true
        }
    }

    return $false
}

# Converts null/scalar/arrays to string arrays.
function Convert-ToStringArray {
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

# Converts absolute path to repository-relative path.
function Convert-ToRelativePath {
    param(
        [string] $Root,
        [string] $Path
    )

    return ([System.IO.Path]::GetRelativePath($Root, $Path)).Replace('\', '/')
}

# Finds dependency manifest files by name and csproj patterns.
function Get-DependencyManifestFile {
    param(
        [string] $Root,
        [string[]] $ExcludedPathGlobs
    )

    $fileEntries = New-Object System.Collections.Generic.List[object]
    $knownNames = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($name in @('package.json', 'Cargo.toml', 'Directory.Packages.props')) {
        $knownNames.Add($name) | Out-Null
    }

    foreach ($fileInfo in @(Get-ChildItem -LiteralPath $Root -Recurse -File)) {
        $relativePath = Convert-ToRelativePath -Root $Root -Path $fileInfo.FullName
        if (Test-PathGlobMatch -RelativePath $relativePath -GlobPatterns $ExcludedPathGlobs) {
            continue
        }

        $isDependencyFile = $knownNames.Contains($fileInfo.Name) -or $fileInfo.Name.EndsWith('.csproj', [System.StringComparison]::OrdinalIgnoreCase)
        if (-not $isDependencyFile) {
            continue
        }

        $fileEntries.Add([pscustomobject]@{
            fullPath = $fileInfo.FullName
            relativePath = $relativePath
            fileName = $fileInfo.Name
        }) | Out-Null
    }

    return @($fileEntries.ToArray())
}

# Parses package.json dependencies.
function Get-NodeDependencyItem {
    param(
        [string] $FilePath,
        [string] $RelativePath
    )

    $result = New-Object System.Collections.Generic.List[object]
    try {
        $json = Get-Content -Raw -LiteralPath $FilePath | ConvertFrom-Json -Depth 100
        foreach ($propertyName in @('dependencies', 'devDependencies', 'peerDependencies', 'optionalDependencies')) {
            $bucket = $json.PSObject.Properties[$propertyName]
            if ($null -eq $bucket -or $null -eq $bucket.Value) {
                continue
            }

            foreach ($entry in $bucket.Value.PSObject.Properties) {
                $result.Add([pscustomobject]@{
                    ecosystem = 'npm'
                    name = [string] $entry.Name
                    version = [string] $entry.Value
                    source = $RelativePath
                    scope = $propertyName
                }) | Out-Null
            }
        }
    }
    catch {
        Add-ValidationWarning ("Skipping invalid package.json parse: {0}" -f $RelativePath)
    }

    return @($result.ToArray())
}

# Parses PackageReference entries from csproj/props files.
function Get-DotnetDependencyItem {
    param(
        [string] $FilePath,
        [string] $RelativePath
    )

    $result = New-Object System.Collections.Generic.List[object]
    try {
        [xml]$xml = Get-Content -Raw -LiteralPath $FilePath
        $packageNodes = @($xml.SelectNodes('//PackageReference'))
        foreach ($node in $packageNodes) {
            $name = [string] $node.Include
            if ([string]::IsNullOrWhiteSpace($name)) {
                $name = [string] $node.Update
            }

            if ([string]::IsNullOrWhiteSpace($name)) {
                continue
            }

            $version = [string] $node.Version
            if ([string]::IsNullOrWhiteSpace($version) -and $null -ne $node.Attributes['Version']) {
                $version = [string] $node.Attributes['Version'].Value
            }

            if ([string]::IsNullOrWhiteSpace($version)) {
                $version = 'unspecified'
            }

            $result.Add([pscustomobject]@{
                ecosystem = '.net'
                name = $name
                version = $version
                source = $RelativePath
                scope = 'PackageReference'
            }) | Out-Null
        }
    }
    catch {
        Add-ValidationWarning ("Skipping invalid XML parse: {0}" -f $RelativePath)
    }

    return @($result.ToArray())
}

# Parses dependencies section from Cargo.toml.
function Get-RustDependencyItem {
    param(
        [string] $FilePath,
        [string] $RelativePath
    )

    $result = New-Object System.Collections.Generic.List[object]
    $lines = @(Get-Content -LiteralPath $FilePath)
    $insideDependencies = $false

    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^\[dependencies\]\s*$') {
            $insideDependencies = $true
            continue
        }

        if ($insideDependencies -and $trimmed -match '^\[.+\]\s*$') {
            $insideDependencies = $false
            continue
        }

        if (-not $insideDependencies) {
            continue
        }

        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) {
            continue
        }

        $match = [regex]::Match($trimmed, '^(?<name>[A-Za-z0-9_.\-]+)\s*=\s*(?<value>.+)$')
        if (-not $match.Success) {
            continue
        }

        $name = $match.Groups['name'].Value
        $value = $match.Groups['value'].Value.Trim()
        $version = if ($value.StartsWith('{')) { 'table' } else { $value.Trim('"').Trim("'") }

        $result.Add([pscustomobject]@{
            ecosystem = 'cargo'
            name = $name
            version = $version
            source = $RelativePath
            scope = 'dependencies'
        }) | Out-Null
    }

    return @($result.ToArray())
}

# Returns regex objects from input pattern text list.
function Get-RegexPatternList {
    param(
        [string[]] $PatternList,
        [string] $Label
    )

    $regexList = New-Object System.Collections.Generic.List[System.Text.RegularExpressions.Regex]
    foreach ($patternText in $PatternList) {
        if ([string]::IsNullOrWhiteSpace($patternText)) {
            continue
        }

        try {
            $regexList.Add([System.Text.RegularExpressions.Regex]::new($patternText)) | Out-Null
        }
        catch {
            Add-ValidationFailure ("Invalid regex in {0}: {1}" -f $Label, $_.Exception.Message)
        }
    }

    return @($regexList.ToArray())
}

# Checks dependency names against blocked and sensitive patterns.
function Test-DependencyPatternSet {
    param(
        [object[]] $Dependencies,
        [System.Text.RegularExpressions.Regex[]] $BlockedPatternList,
        [System.Text.RegularExpressions.Regex[]] $SensitivePatternList
    )

    foreach ($dependency in $Dependencies) {
        foreach ($blockedPattern in $BlockedPatternList) {
            if ($blockedPattern.IsMatch([string] $dependency.name)) {
                Add-ValidationFailure ("Blocked dependency detected: {0} ({1}) in {2}" -f $dependency.name, $dependency.ecosystem, $dependency.source)
            }
        }

        foreach ($sensitivePattern in $SensitivePatternList) {
            if ($sensitivePattern.IsMatch([string] $dependency.name)) {
                Add-ValidationWarning ("Sensitive dependency pattern matched: {0} ({1}) in {2}" -f $dependency.name, $dependency.ecosystem, $dependency.source)
            }
        }
    }
}

# Writes a lightweight SBOM JSON artifact.
function Write-SbomReport {
    param(
        [string] $Path,
        [string] $RepoRootPath,
        [object[]] $Dependencies
    )

    $parent = Split-Path -Path $Path -Parent
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $sbom = [ordered]@{
        schemaVersion = 1
        generatedAt = (Get-Date).ToString('o')
        repoRoot = $RepoRootPath
        packageCount = $Dependencies.Count
        packages = $Dependencies
    }

    Set-Content -LiteralPath $Path -Value ($sbom | ConvertTo-Json -Depth 100)
}

# -------------------------------
# Main execution
# -------------------------------
$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
Set-Location -Path $resolvedRepoRoot

$resolvedBaselinePath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $BaselinePath
$baseline = Get-RequiredJsonDocument -Path $resolvedBaselinePath -Label 'supply-chain baseline'

if ($null -eq $baseline) {
    Write-Output ''
    Write-Output 'Supply-chain validation summary'
    Write-Output ("  Warning-only mode: {0}" -f $script:IsWarningOnly)
    Write-Output '  Dependency manifests: 0'
    Write-Output '  Packages discovered: 0'
    Write-Output ("  Warnings: {0}" -f $script:Warnings.Count)
    Write-Output ("  Failures: {0}" -f $script:Failures.Count)
    if ($script:Failures.Count -gt 0 -and -not $script:IsWarningOnly) { exit 1 }
    exit 0
}

$excludedPathGlobs = Convert-ToStringArray -Value $baseline.excludedPathGlobs
$blockedPatternList = Get-RegexPatternList -PatternList (Convert-ToStringArray -Value $baseline.blockedDependencyPatterns) -Label 'blockedDependencyPatterns'
$sensitivePatternList = Get-RegexPatternList -PatternList (Convert-ToStringArray -Value $baseline.sensitiveDependencyPatterns) -Label 'sensitiveDependencyPatterns'

$manifestFiles = Get-DependencyManifestFile -Root $resolvedRepoRoot -ExcludedPathGlobs $excludedPathGlobs
$dependencyList = New-Object System.Collections.Generic.List[object]

foreach ($manifestFile in $manifestFiles) {
    switch -Regex ($manifestFile.fileName) {
        '^package\.json$' {
            foreach ($dependency in (Get-NodeDependencyItem -FilePath $manifestFile.fullPath -RelativePath $manifestFile.relativePath)) {
                $dependencyList.Add($dependency) | Out-Null
            }
            break
        }
        '^Cargo\.toml$' {
            foreach ($dependency in (Get-RustDependencyItem -FilePath $manifestFile.fullPath -RelativePath $manifestFile.relativePath)) {
                $dependencyList.Add($dependency) | Out-Null
            }
            break
        }
        '^Directory\.Packages\.props$' {
            foreach ($dependency in (Get-DotnetDependencyItem -FilePath $manifestFile.fullPath -RelativePath $manifestFile.relativePath)) {
                $dependencyList.Add($dependency) | Out-Null
            }
            break
        }
        '\.csproj$' {
            foreach ($dependency in (Get-DotnetDependencyItem -FilePath $manifestFile.fullPath -RelativePath $manifestFile.relativePath)) {
                $dependencyList.Add($dependency) | Out-Null
            }
            break
        }
        default {
            continue
        }
    }
}

$dependencies = @($dependencyList.ToArray())
if ($dependencies.Count -eq 0) {
    Add-ValidationWarning 'No dependencies discovered in scanned manifests.'
}

Test-DependencyPatternSet -Dependencies $dependencies -BlockedPatternList $blockedPatternList -SensitivePatternList $sensitivePatternList

$resolvedSbomPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path ([string] $baseline.sbomOutputPath)
Write-SbomReport -Path $resolvedSbomPath -RepoRootPath $resolvedRepoRoot -Dependencies $dependencies
Write-VerboseLog ("SBOM report generated at: {0}" -f $resolvedSbomPath)

$requireLicenseEvidence = [bool] $baseline.requireLicenseEvidence
$licenseEvidencePath = Resolve-RepoPath -Root $resolvedRepoRoot -Path ([string] $baseline.licenseEvidencePath)
if ($requireLicenseEvidence -and -not (Test-Path -LiteralPath $licenseEvidencePath -PathType Leaf)) {
    Add-ValidationFailure ("License evidence file is required but missing: {0}" -f [string] $baseline.licenseEvidencePath)
}
elseif (-not (Test-Path -LiteralPath $licenseEvidencePath -PathType Leaf)) {
    Add-ValidationWarning ("License evidence file not found (optional): {0}" -f [string] $baseline.licenseEvidencePath)
}

Write-Output ''
Write-Output 'Supply-chain validation summary'
Write-Output ("  Warning-only mode: {0}" -f $script:IsWarningOnly)
Write-Output ("  Dependency manifests: {0}" -f $manifestFiles.Count)
Write-Output ("  Packages discovered: {0}" -f $dependencies.Count)
Write-Output ("  SBOM path: {0}" -f (Convert-ToRelativePath -Root $resolvedRepoRoot -Path $resolvedSbomPath))
Write-Output ("  Warnings: {0}" -f $script:Warnings.Count)
Write-Output ("  Failures: {0}" -f $script:Failures.Count)

if ($script:Failures.Count -gt 0 -and -not $script:IsWarningOnly) {
    exit 1
}

Write-Output 'Supply-chain validation passed.'
exit 0
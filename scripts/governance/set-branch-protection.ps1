<#
.SYNOPSIS
    Validates or applies GitHub branch protection from a versioned baseline file.

.DESCRIPTION
    Loads `.github/governance/branch-protection.baseline.json` and compares expected
    settings with current branch protection from GitHub API (`gh api`).

    Default mode validates drift only (no remote mutation).
    Use `-Apply` to update branch protection.

    Outputs a JSON report with normalized expected/current values.

.PARAMETER RepoRoot
    Optional repository root. If omitted, the script auto-detects a root containing .github and .codex.

.PARAMETER BaselinePath
    Baseline JSON path. Defaults to `.github/governance/branch-protection.baseline.json`.

.PARAMETER Repository
    GitHub repository in `owner/name` format. If omitted, tries baseline file value, then origin remote.

.PARAMETER Branch
    Target branch. If omitted, uses baseline value.

.PARAMETER Apply
    Applies baseline protection to the target branch. Without this flag, script only validates drift.

.PARAMETER OutputPath
    Path for JSON validation/apply report. Defaults to `.temp/branch-protection-report.json`.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/governance/set-branch-protection.ps1

.EXAMPLE
    pwsh -File scripts/governance/set-branch-protection.ps1 -Apply

.EXAMPLE
    pwsh -File scripts/governance/set-branch-protection.ps1 -Repository ThiagoGuislotti/copilot-instructions -Branch main -Apply

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+, GitHub CLI (`gh`) authenticated with branch admin permissions.
#>

param(
    [string] $RepoRoot,
    [string] $BaselinePath = '.github/governance/branch-protection.baseline.json',
    [string] $Repository,
    [string] $Branch,
    [switch] $Apply,
    [string] $OutputPath = '.temp/branch-protection-report.json',
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

# -------------------------------
# Helpers
# -------------------------------
# Writes verbose diagnostics with a logical color label.
function Write-VerboseColor {
    param(
        [string] $Message,
        [ConsoleColor] $Color = [ConsoleColor]::Gray
    )

    if ($script:IsVerboseEnabled) {
        Write-StyledOutput ("[VERBOSE:{0}] {1}" -f $Color, $Message)
    }
}

# Builds an absolute path from repository root and relative input path.
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

# Returns the parent directory for a given file path when available.
function Get-ParentDirectoryPath {
    param(
        [string] $Path
    )

    $parent = Split-Path -Path $Path -Parent
    if ([string]::IsNullOrWhiteSpace($parent)) { return $null }
    return $parent
}

# Resolves the repository root using explicit and fallback location candidates.
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
                Write-VerboseColor ("Repository root detected: {0}" -f $current) 'Green'
                return $current
            }

            $current = Split-Path -Path $current -Parent
        }
    }

    throw 'Could not detect repository root containing both .github and .codex.'
}

# Validates that a required command is available in the current environment.
function Assert-CommandAvailable {
    param(
        [string] $CommandName
    )

    if ($null -eq (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
        throw ("Required command not found: {0}" -f $CommandName)
    }
}

# Converts mixed values into a normalized sorted unique string array.
function ConvertTo-NormalizedStringArray {
    param(
        [object] $Value
    )

    if ($null -eq $Value) {
        return @()
    }

    return @(
        $Value |
        ForEach-Object { [string] $_ } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Sort-Object -Unique
    )
}

# Converts branch protection restriction objects to normalized arrays.
function ConvertTo-NormalizedRestrictionSet {
    param(
        [object] $Restrictions
    )

    if ($null -eq $Restrictions) {
        return $null
    }

    $users = @()
    $teams = @()
    $apps = @()

    foreach ($user in @($Restrictions.users)) {
        if ($user -is [string]) {
            $users += $user
        }
        elseif ($null -ne $user.login) {
            $users += [string] $user.login
        }
        elseif ($null -ne $user.name) {
            $users += [string] $user.name
        }
    }

    foreach ($team in @($Restrictions.teams)) {
        if ($team -is [string]) {
            $teams += $team
        }
        elseif ($null -ne $team.slug) {
            $teams += [string] $team.slug
        }
        elseif ($null -ne $team.name) {
            $teams += [string] $team.name
        }
    }

    foreach ($app in @($Restrictions.apps)) {
        if ($app -is [string]) {
            $apps += $app
        }
        elseif ($null -ne $app.slug) {
            $apps += [string] $app.slug
        }
        elseif ($null -ne $app.name) {
            $apps += [string] $app.name
        }
    }

    return [ordered]@{
        users = ConvertTo-NormalizedStringArray -Value $users
        teams = ConvertTo-NormalizedStringArray -Value $teams
        apps = ConvertTo-NormalizedStringArray -Value $apps
    }
}

# Normalizes branch protection payloads for deterministic comparison.
function ConvertTo-NormalizedProtection {
    param(
        [object] $Protection
    )

    $statusChecks = $Protection.required_status_checks
    $contexts = @()

    if ($null -ne $statusChecks) {
        if ($null -ne $statusChecks.contexts) {
            $contexts = ConvertTo-NormalizedStringArray -Value $statusChecks.contexts
        }
        elseif ($null -ne $statusChecks.checks) {
            $contexts = ConvertTo-NormalizedStringArray -Value (@($statusChecks.checks | ForEach-Object { [string] $_.context }))
        }
    }

    $enforceAdmins = $false
    if ($null -ne $Protection.enforce_admins) {
        if ($Protection.enforce_admins -is [bool]) {
            $enforceAdmins = [bool] $Protection.enforce_admins
        }
        elseif ($Protection.enforce_admins.PSObject.Properties.Name -contains 'enabled') {
            $enforceAdmins = [bool] $Protection.enforce_admins.enabled
        }
    }

    $reviews = $Protection.required_pull_request_reviews

    return [ordered]@{
        required_status_checks = [ordered]@{
            strict = [bool] $statusChecks.strict
            contexts = $contexts
        }
        enforce_admins = $enforceAdmins
        required_pull_request_reviews = [ordered]@{
            dismiss_stale_reviews = [bool] $reviews.dismiss_stale_reviews
            require_code_owner_reviews = [bool] $reviews.require_code_owner_reviews
            required_approving_review_count = [int] $reviews.required_approving_review_count
        }
        restrictions = ConvertTo-NormalizedRestrictionSet -Restrictions $Protection.restrictions
    }
}

# Infers owner/repository slug from the git origin remote URL.
function Resolve-RepositoryFromOrigin {
    param(
        [string] $Root
    )

    $remoteUrl = (& git -C $Root remote get-url origin 2>$null)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($remoteUrl)) {
        return $null
    }

    if ($remoteUrl -match '^git@github\.com:(?<owner>[^/]+)/(?<repo>.+?)(\.git)?$') {
        return "{0}/{1}" -f $Matches.owner, $Matches.repo
    }

    if ($remoteUrl -match '^https://github\.com/(?<owner>[^/]+)/(?<repo>.+?)(\.git)?$') {
        return "{0}/{1}" -f $Matches.owner, $Matches.repo
    }

    return $null
}

# Executes GitHub API requests through gh CLI with error normalization.
function Invoke-GitHubApi {
    param(
        [string] $Method,
        [string] $Route,
        [string] $InputPath
    )

    $arguments = @('api', '--method', $Method, '-H', 'Accept: application/vnd.github+json', $Route)
    if (-not [string]::IsNullOrWhiteSpace($InputPath)) {
        $arguments += @('--input', $InputPath)
    }

    $stderrPath = [System.IO.Path]::GetTempFileName()
    try {
        $output = (& gh @arguments 2> $stderrPath)
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        if ($exitCode -ne 0) {
            $errorText = ''
            if (Test-Path -LiteralPath $stderrPath) {
                $errorText = Get-Content -Raw -LiteralPath $stderrPath
            }
            throw ("gh api failed ({0} {1}): {2}" -f $Method, $Route, $errorText.Trim())
        }

        if ([string]::IsNullOrWhiteSpace(($output -join ''))) {
            return $null
        }

        return ($output -join "`n") | ConvertFrom-Json -Depth 100
    }
    finally {
        Remove-Item -LiteralPath $stderrPath -Force -ErrorAction SilentlyContinue
    }
}

# -------------------------------
# Main execution
# -------------------------------
$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
Set-Location -Path $resolvedRepoRoot
$resolvedBaselinePath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $BaselinePath
$resolvedOutputPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $OutputPath
$outputParent = Get-ParentDirectoryPath -Path $resolvedOutputPath
if (-not [string]::IsNullOrWhiteSpace($outputParent)) {
    New-Item -ItemType Directory -Path $outputParent -Force | Out-Null
}

if (-not (Test-Path -LiteralPath $resolvedBaselinePath -PathType Leaf)) {
    throw ("Baseline file not found: {0}" -f $resolvedBaselinePath)
}

Assert-CommandAvailable -CommandName 'git'
Assert-CommandAvailable -CommandName 'gh'

$baseline = Get-Content -Raw -LiteralPath $resolvedBaselinePath | ConvertFrom-Json -Depth 100

$effectiveRepository = $Repository
if ([string]::IsNullOrWhiteSpace($effectiveRepository)) {
    $effectiveRepository = [string] $baseline.repository
}
if ([string]::IsNullOrWhiteSpace($effectiveRepository)) {
    $effectiveRepository = Resolve-RepositoryFromOrigin -Root $resolvedRepoRoot
}
if ([string]::IsNullOrWhiteSpace($effectiveRepository)) {
    throw 'Could not resolve GitHub repository. Use -Repository owner/name.'
}
if ($effectiveRepository -notmatch '^[^/]+/[^/]+$') {
    throw ("Invalid repository format: {0}. Expected owner/name." -f $effectiveRepository)
}

$effectiveBranch = $Branch
if ([string]::IsNullOrWhiteSpace($effectiveBranch)) {
    $effectiveBranch = [string] $baseline.branch
}
if ([string]::IsNullOrWhiteSpace($effectiveBranch)) {
    throw 'Branch value not provided. Use -Branch or set branch in baseline.'
}

$expectedProtection = $baseline.protection
if ($null -eq $expectedProtection) {
    throw 'Baseline JSON must include a `protection` object.'
}

$expectedNormalized = ConvertTo-NormalizedProtection -Protection $expectedProtection
$apiRoute = "repos/{0}/branches/{1}/protection" -f $effectiveRepository, $effectiveBranch

Write-StyledOutput ("[INFO] Repository: {0}" -f $effectiveRepository)
Write-StyledOutput ("[INFO] Branch: {0}" -f $effectiveBranch)
Write-StyledOutput ("[INFO] Mode: {0}" -f ($(if ($Apply) { 'apply' } else { 'validate' })))

$currentProtection = Invoke-GitHubApi -Method 'GET' -Route $apiRoute
$currentNormalized = ConvertTo-NormalizedProtection -Protection $currentProtection

$expectedJson = ($expectedNormalized | ConvertTo-Json -Depth 100 -Compress)
$currentJson = ($currentNormalized | ConvertTo-Json -Depth 100 -Compress)
$isAlignedBeforeApply = ($expectedJson -eq $currentJson)

if (-not $Apply) {
    if ($isAlignedBeforeApply) {
        Write-StyledOutput 'Branch protection is aligned with baseline.'
    }
    else {
        Write-StyledOutput 'Branch protection drift detected.'
        Write-StyledOutput 'Run with -Apply to enforce baseline.'
    }
}
else {
    $payloadPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path '.temp/branch-protection-payload.json'
    $payloadParent = Get-ParentDirectoryPath -Path $payloadPath
    if (-not [string]::IsNullOrWhiteSpace($payloadParent)) {
        New-Item -ItemType Directory -Path $payloadParent -Force | Out-Null
    }
    Set-Content -LiteralPath $payloadPath -Value ($expectedProtection | ConvertTo-Json -Depth 100)
    Write-StyledOutput '[INFO] Applying baseline branch protection via GitHub API...'
    [void](Invoke-GitHubApi -Method 'PUT' -Route $apiRoute -InputPath $payloadPath)

    $currentProtection = Invoke-GitHubApi -Method 'GET' -Route $apiRoute
    $currentNormalized = ConvertTo-NormalizedProtection -Protection $currentProtection
    $currentJson = ($currentNormalized | ConvertTo-Json -Depth 100 -Compress)
    $isAlignedBeforeApply = ($expectedJson -eq $currentJson)

    if ($isAlignedBeforeApply) {
        Write-StyledOutput 'Branch protection applied and validated successfully.'
    }
    else {
        Write-StyledOutput 'Branch protection apply completed but baseline drift still exists.'
    }
}

$report = [ordered]@{
    schemaVersion = 1
    generatedAt = (Get-Date).ToString('o')
    repository = $effectiveRepository
    branch = $effectiveBranch
    mode = if ($Apply) { 'apply' } else { 'validate' }
    baselinePath = [System.IO.Path]::GetRelativePath($resolvedRepoRoot, $resolvedBaselinePath)
    outputPath = $resolvedOutputPath
    isAligned = $isAlignedBeforeApply
    expected = $expectedNormalized
    current = $currentNormalized
}

Set-Content -LiteralPath $resolvedOutputPath -Value ($report | ConvertTo-Json -Depth 100)
Write-StyledOutput ("Report generated: {0}" -f $resolvedOutputPath)

if (-not $isAlignedBeforeApply) {
    exit 1
}

exit 0
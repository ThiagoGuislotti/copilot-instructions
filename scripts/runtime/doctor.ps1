<#
.SYNOPSIS
    Diagnoses drift between repository source-of-truth assets and local runtime folders.

.DESCRIPTION
    Compares source and runtime file sets for:
    - .github -> ~/.github
    - .codex/skills -> ~/.codex/skills
    - .codex/mcp -> ~/.codex/shared-mcp
    - .codex/scripts -> ~/.codex/shared-scripts
    - .codex/orchestration -> ~/.codex/shared-orchestration

    For each mapping, reports:
    - missing files in runtime
    - extra files in runtime
    - hash drift for files present on both sides

    Exit codes:
    - 0: no drift detected (or drift fixed with -SyncOnDrift)
    - 1: drift remains

.PARAMETER RepoRoot
    Optional repository root. If omitted, detects from script location and current directory.

.PARAMETER TargetGithubPath
    Runtime target path for .github assets. Defaults to $env:USERPROFILE\.github.

.PARAMETER TargetCodexPath
    Runtime target path for .codex assets. Defaults to $env:USERPROFILE\.codex.

.PARAMETER Detailed
    Prints file-level entries for missing, extra, and drifted files.

.PARAMETER SyncOnDrift
    When provided, runs scripts/runtime/bootstrap.ps1 if drift is detected and re-checks.

.PARAMETER StrictExtras
    Treats extra runtime files as drift failures. By default, extra files are reported but do not fail health.

.EXAMPLE
    pwsh -File scripts/runtime/doctor.ps1

.EXAMPLE
    pwsh -File scripts/runtime/doctor.ps1 -Detailed

.EXAMPLE
    pwsh -File scripts/runtime/doctor.ps1 -SyncOnDrift

.NOTES
    Version: 1.1
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $TargetGithubPath = "$env:USERPROFILE\.github",
    [string] $TargetCodexPath = "$env:USERPROFILE\.codex",
    [switch] $Detailed,
    [switch] $SyncOnDrift,
    [switch] $StrictExtras
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
                return $current
            }
            $current = Split-Path -Path $current -Parent
        }
    }

    throw 'Could not detect repository root containing both .github and .codex.'
}

# Builds a file hash inventory for drift comparison operations.
function Get-FileInventory {
    param(
        [string] $RootPath
    )

    $inventory = @{}
    if (-not (Test-Path -LiteralPath $RootPath)) {
        return $inventory
    }

    Get-ChildItem -LiteralPath $RootPath -Recurse -File | ForEach-Object {
        $relativePath = [System.IO.Path]::GetRelativePath($RootPath, $_.FullName)
        $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        $inventory[$relativePath] = $hash
    }

    return $inventory
}

# Compares source and runtime inventories to detect missing, extra, and drifted files.
function Compare-Mapping {
    param(
        [string] $Name,
        [string] $SourcePath,
        [string] $TargetPath,
        [string[]] $IgnoreExtraPrefixes = @(),
        [switch] $IncludeExtraRuntimeDrift
    )

    $sourceInventory = Get-FileInventory -RootPath $SourcePath
    $targetInventory = Get-FileInventory -RootPath $TargetPath

    $sourceKeys = @($sourceInventory.Keys | Sort-Object)
    $targetKeys = @($targetInventory.Keys | Sort-Object)

    $sourceKeySet = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
    $targetKeySet = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($key in $sourceKeys) { $sourceKeySet.Add($key) | Out-Null }
    foreach ($key in $targetKeys) { $targetKeySet.Add($key) | Out-Null }

    $missingInRuntime = New-Object System.Collections.Generic.List[string]
    foreach ($key in $sourceKeys) {
        if (-not $targetKeySet.Contains($key)) {
            $missingInRuntime.Add($key) | Out-Null
        }
    }

    $extraInRuntime = New-Object System.Collections.Generic.List[string]
    foreach ($key in $targetKeys) {
        if (-not $sourceKeySet.Contains($key)) {
            $shouldIgnore = $false
            foreach ($prefix in $IgnoreExtraPrefixes) {
                if ($key.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $shouldIgnore = $true
                    break
                }
            }

            if ($shouldIgnore) {
                continue
            }

            $extraInRuntime.Add($key) | Out-Null
        }
    }

    $driftedFiles = New-Object System.Collections.Generic.List[string]
    foreach ($key in $sourceKeys) {
        if (-not $targetKeySet.Contains($key)) {
            continue
        }

        if ($sourceInventory[$key] -ne $targetInventory[$key]) {
            $driftedFiles.Add($key) | Out-Null
        }
    }

    return [pscustomobject]@{
        Name = $Name
        SourcePath = $SourcePath
        TargetPath = $TargetPath
        SourceCount = $sourceKeys.Count
        TargetCount = $targetKeys.Count
        MissingInRuntime = @($missingInRuntime)
        ExtraInRuntime = @($extraInRuntime)
        DriftedFiles = @($driftedFiles)
        IsHealthy = ($missingInRuntime.Count -eq 0 -and $driftedFiles.Count -eq 0 -and ((-not $IncludeExtraRuntimeDrift) -or $extraInRuntime.Count -eq 0))
    }
}

# Prints a standardized summary for a single runtime mapping comparison.
function Write-MappingReport {
    param(
        [object] $Report,
        [switch] $DetailedReport
    )

    $statusText = if ($Report.IsHealthy) { 'OK' } else { 'DRIFT' }

    Write-StyledOutput ("[{0}] {1}" -f $statusText, $Report.Name)
    Write-StyledOutput ("  source: {0}" -f $Report.SourcePath)
    Write-StyledOutput ("  target: {0}" -f $Report.TargetPath)
    Write-StyledOutput ("  files: source={0} target={1}" -f $Report.SourceCount, $Report.TargetCount)
    Write-StyledOutput ("  missing in runtime: {0}" -f $Report.MissingInRuntime.Count)
    Write-StyledOutput ("  extra in runtime: {0}" -f $Report.ExtraInRuntime.Count)
    Write-StyledOutput ("  drifted files: {0}" -f $Report.DriftedFiles.Count)

    if ($DetailedReport) {
        foreach ($path in $Report.MissingInRuntime) {
            Write-StyledOutput ("    [missing] {0}" -f $path)
        }
        foreach ($path in $Report.ExtraInRuntime) {
            Write-StyledOutput ("    [extra]   {0}" -f $path)
        }
        foreach ($path in $Report.DriftedFiles) {
            Write-StyledOutput ("    [drift]   {0}" -f $path)
        }
    }
}

# Executes all runtime mapping drift checks and returns detailed reports.
function Invoke-Doctor {
    param(
        [string] $ResolvedRepoRoot
    )

    $mappings = @(
        [pscustomobject]@{
            Name = '.github -> runtime'
            Source = Join-Path $ResolvedRepoRoot '.github'
            Target = $TargetGithubPath
            IgnoreExtraPrefixes = @()
        },
        [pscustomobject]@{
            Name = '.codex/skills -> runtime'
            Source = Join-Path $ResolvedRepoRoot '.codex\skills'
            Target = Join-Path $TargetCodexPath 'skills'
            IgnoreExtraPrefixes = @('.system\', '.system/')
        },
        [pscustomobject]@{
            Name = '.codex/mcp -> runtime'
            Source = Join-Path $ResolvedRepoRoot '.codex\mcp'
            Target = Join-Path $TargetCodexPath 'shared-mcp'
            IgnoreExtraPrefixes = @()
        },
        [pscustomobject]@{
            Name = '.codex/scripts -> runtime'
            Source = Join-Path $ResolvedRepoRoot '.codex\scripts'
            Target = Join-Path $TargetCodexPath 'shared-scripts'
            IgnoreExtraPrefixes = @()
        },
        [pscustomobject]@{
            Name = '.codex/orchestration -> runtime'
            Source = Join-Path $ResolvedRepoRoot '.codex\orchestration'
            Target = Join-Path $TargetCodexPath 'shared-orchestration'
            IgnoreExtraPrefixes = @()
        }
    )

    $reports = @()
    foreach ($mapping in $mappings) {
        $reports += Compare-Mapping -Name $mapping.Name -SourcePath $mapping.Source -TargetPath $mapping.Target -IgnoreExtraPrefixes $mapping.IgnoreExtraPrefixes -IncludeExtraRuntimeDrift:$StrictExtras
    }

    return $reports
}

# Checks whether runtime reports include any extra unmanaged files.
function Test-HasExtraRuntimeFile {
    param(
        [object[]] $Reports
    )

    return @($Reports | Where-Object { @($_.ExtraInRuntime).Count -gt 0 }).Count -gt 0
}

$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
Set-Location -Path $resolvedRepoRoot
Write-StyledOutput 'Runtime doctor report'
Write-StyledOutput ("  repo root: {0}" -f $resolvedRepoRoot)

$reports = Invoke-Doctor -ResolvedRepoRoot $resolvedRepoRoot
foreach ($report in $reports) {
    Write-MappingReport -Report $report -DetailedReport:$Detailed
}

$hasDrift = @($reports | Where-Object { -not $_.IsHealthy }).Count -gt 0
$hasExtras = Test-HasExtraRuntimeFile -Reports $reports

if ($hasDrift -and $SyncOnDrift) {
    Write-StyledOutput 'Drift detected. Running bootstrap sync...'
    $bootstrapScript = Join-Path $resolvedRepoRoot 'scripts\runtime\bootstrap.ps1'
    if (-not (Test-Path -LiteralPath $bootstrapScript)) {
        throw "Bootstrap script not found: $bootstrapScript"
    }

    & $bootstrapScript -RepoRoot $resolvedRepoRoot -TargetGithubPath $TargetGithubPath -TargetCodexPath $TargetCodexPath
    $reports = Invoke-Doctor -ResolvedRepoRoot $resolvedRepoRoot
    foreach ($report in $reports) {
        Write-MappingReport -Report $report -DetailedReport:$Detailed
    }
    $hasDrift = @($reports | Where-Object { -not $_.IsHealthy }).Count -gt 0
    $hasExtras = Test-HasExtraRuntimeFile -Reports $reports
}

Write-StyledOutput ''
$statusText = if ($hasDrift) {
    'detected'
}
elseif ($hasExtras) {
    'clean-with-extras'
}
else {
    'clean'
}

Write-StyledOutput ("Drift status: {0}" -f $statusText)

if ($hasExtras -and (-not $StrictExtras)) {
    Write-StyledOutput 'Runtime has extra files not tracked by source mappings.'
    Write-StyledOutput 'Use -Detailed to inspect extras and -StrictExtras to fail on extras.'
}

if ($hasDrift) {
    exit 1
}

exit 0
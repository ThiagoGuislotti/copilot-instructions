<#
.SYNOPSIS
    Diagnoses drift between repository source-of-truth assets and local runtime folders.

.DESCRIPTION
    Compares source and runtime file sets for:
    - .github -> ~/.github
    - .codex/skills -> ~/.codex/skills
    - .codex/mcp -> ~/.codex/shared-mcp
    - .codex/scripts -> ~/.codex/shared-scripts

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
    Version: 1.0
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
$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent

function Set-CorrectWorkingDirectory {
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
                Set-Location -Path $current
                return $current
            }
            $current = Split-Path -Path $current -Parent
        }
    }

    throw 'Could not detect repository root containing both .github and .codex.'
}

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

function Write-MappingReport {
    param(
        [object] $Report
    )

    $statusColor = if ($Report.IsHealthy) { 'Green' } else { 'Yellow' }
    $statusText = if ($Report.IsHealthy) { 'OK' } else { 'DRIFT' }

    Write-Host ("[{0}] {1}" -f $statusText, $Report.Name) -ForegroundColor $statusColor
    Write-Host ("  source: {0}" -f $Report.SourcePath)
    Write-Host ("  target: {0}" -f $Report.TargetPath)
    Write-Host ("  files: source={0} target={1}" -f $Report.SourceCount, $Report.TargetCount)
    Write-Host ("  missing in runtime: {0}" -f $Report.MissingInRuntime.Count)
    Write-Host ("  extra in runtime: {0}" -f $Report.ExtraInRuntime.Count)
    Write-Host ("  drifted files: {0}" -f $Report.DriftedFiles.Count)

    if ($Detailed) {
        foreach ($path in $Report.MissingInRuntime) {
            Write-Host ("    [missing] {0}" -f $path) -ForegroundColor Yellow
        }
        foreach ($path in $Report.ExtraInRuntime) {
            Write-Host ("    [extra]   {0}" -f $path) -ForegroundColor Yellow
        }
        foreach ($path in $Report.DriftedFiles) {
            Write-Host ("    [drift]   {0}" -f $path) -ForegroundColor Yellow
        }
    }
}

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
        }
    )

    $reports = @()
    foreach ($mapping in $mappings) {
        $reports += Compare-Mapping -Name $mapping.Name -SourcePath $mapping.Source -TargetPath $mapping.Target -IgnoreExtraPrefixes $mapping.IgnoreExtraPrefixes -IncludeExtraRuntimeDrift:$StrictExtras
    }

    return $reports
}

$resolvedRepoRoot = Set-CorrectWorkingDirectory -RequestedRoot $RepoRoot
Write-Host 'Runtime doctor report' -ForegroundColor Cyan
Write-Host ("  repo root: {0}" -f $resolvedRepoRoot)

$reports = Invoke-Doctor -ResolvedRepoRoot $resolvedRepoRoot
foreach ($report in $reports) {
    Write-MappingReport -Report $report
}

$hasDrift = @($reports | Where-Object { -not $_.IsHealthy }).Count -gt 0

if ($hasDrift -and $SyncOnDrift) {
    Write-Host 'Drift detected. Running bootstrap sync...' -ForegroundColor Yellow
    $bootstrapScript = Join-Path $resolvedRepoRoot 'scripts\runtime\bootstrap.ps1'
    if (-not (Test-Path -LiteralPath $bootstrapScript)) {
        throw "Bootstrap script not found: $bootstrapScript"
    }

    & $bootstrapScript -RepoRoot $resolvedRepoRoot -TargetGithubPath $TargetGithubPath -TargetCodexPath $TargetCodexPath
    $reports = Invoke-Doctor -ResolvedRepoRoot $resolvedRepoRoot
    foreach ($report in $reports) {
        Write-MappingReport -Report $report
    }
    $hasDrift = @($reports | Where-Object { -not $_.IsHealthy }).Count -gt 0
}

Write-Host ''
$statusText = if ($hasDrift) { 'detected' } else { 'clean' }
$statusColor = if ($hasDrift) { 'Yellow' } else { 'Green' }
Write-Host ("Drift status: {0}" -f $statusText) -ForegroundColor $statusColor

if ($hasDrift) {
    exit 1
}

exit 0
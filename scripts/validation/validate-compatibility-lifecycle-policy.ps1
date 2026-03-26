<#
.SYNOPSIS
    Validates COMPATIBILITY.md support lifecycle and EOL table semantics.

.DESCRIPTION
    Ensures the "Support Lifecycle and EOL" section contains a reference date
    and a support lifecycle table that follows required date ordering,
    EOL calculation, and status alignment with the reference date.

    Exit code:
    - 0 when validation passes
    - 1 when validation fails (unless WarningOnly is enabled)

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.PARAMETER CompatibilityPath
    Path to COMPATIBILITY.md relative to repo root (or absolute path).

.PARAMETER WarningOnly
    When true, validation failures are emitted as warnings and exit code is 0.

.PARAMETER DetailedOutput
    When true, emits per-row validation details.

.EXAMPLE
    pwsh -File scripts/validation/validate-compatibility-lifecycle-policy.ps1

.EXAMPLE
    pwsh -File scripts/validation/validate-compatibility-lifecycle-policy.ps1 -WarningOnly:$false

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $CompatibilityPath = 'COMPATIBILITY.md',
    [switch] $WarningOnly,
    [switch] $DetailedOutput
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
$script:IsWarningOnly = [bool] $WarningOnly
Initialize-ValidationState -WarningOnly $script:IsWarningOnly -VerboseEnabled $false
$script:IsDetailedOutput = [bool] $DetailedOutput

# -------------------------------
# Helpers
# -------------------------------
# Registers a validation warning without failing immediately.

# Registers a non-fatal validation warning.

# Writes per-row diagnostics when detailed output is enabled.
function Write-Detail {
    param(
        [string] $Message
    )

    if ($script:IsDetailedOutput) {
        Write-StyledOutput ("[DETAIL] {0}" -f $Message)
    }
}

# Resolves a path relative to repository root.

# Extracts the markdown section body for a specific heading.
function Get-SectionBody {
    param(
        [string] $Content,
        [string] $Heading
    )

    $escaped = [regex]::Escape($Heading.Trim())
    $pattern = "(?ims)^#{{1,6}}\s+{0}\s*$\r?\n(?<body>.*?)(?=^#{{1,6}}\s+|\z)" -f $escaped
    $match = [regex]::Match($Content, $pattern)
    if ($match.Success) {
        return $match.Groups['body'].Value
    }

    return $null
}

# Splits a markdown table row into normalized columns.
function Convert-TableRow {
    param(
        [string] $Line
    )

    if ([string]::IsNullOrWhiteSpace($Line)) {
        return $null
    }

    if ($Line.TrimStart() -notmatch '^\|') {
        return $null
    }

    $trimmed = $Line.Trim()
    if ($trimmed -notmatch '\|') {
        return $null
    }

    $raw = $trimmed.Trim('|')
    $parts = @($raw -split '\|')
    return @($parts | ForEach-Object { $_.Trim() })
}

# Detects markdown separator rows such as | --- | --- |.
function Test-SeparationRow {
    param(
        [string[]] $Columns
    )

    if ($Columns.Count -lt 6) {
        return $false
    }

    foreach ($column in $Columns) {
        $normalized = $column.Trim()
        if ($normalized -notmatch '^:?-{3,}:?$') {
            return $false
        }
    }

    return $true
}

# Parses a compatibility lifecycle date using English month formats.
function Convert-CompatibilityDate {
    param(
        [string] $Value,
        [ref] $Parsed
    )

    $formats = @('MMMM d, yyyy', 'MMMM dd, yyyy')
    $culture = [System.Globalization.CultureInfo]::GetCultureInfo('en-US')
    $parsedDate = [datetime]::MinValue
    $success = [datetime]::TryParseExact(
        $Value,
        $formats,
        $culture,
        [System.Globalization.DateTimeStyles]::None,
        [ref] $parsedDate
    )

    if (-not $success) {
        $success = [datetime]::TryParse(
            $Value,
            $culture,
            [System.Globalization.DateTimeStyles]::None,
            [ref] $parsedDate
        )
    }

    if ($success) {
        $Parsed.Value = $parsedDate.Date
    }

    return $success
}

# Normalizes status text for case-insensitive comparisons.
function Convert-StatusText {
    param(
        [string] $Value
    )

    return ($Value -replace '\s+', ' ').Trim()
}

# -------------------------------
# Main execution
# -------------------------------
$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
Set-Location -Path $resolvedRepoRoot

$resolvedCompatibilityPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $CompatibilityPath
if (-not (Test-Path -LiteralPath $resolvedCompatibilityPath -PathType Leaf)) {
    Add-ValidationFailure ("Compatibility file not found: {0}" -f $CompatibilityPath)
    Write-StyledOutput ''
    Write-StyledOutput 'Compatibility lifecycle validation summary'
    Write-StyledOutput ("  Warnings: {0}" -f $script:Warnings.Count)
    Write-StyledOutput ("  Failures: {0}" -f $script:Failures.Count)
    exit 1
}

$content = Get-Content -Raw -LiteralPath $resolvedCompatibilityPath
$sectionBody = Get-SectionBody -Content $content -Heading 'Support Lifecycle and EOL'
if ($null -eq $sectionBody) {
    Add-ValidationFailure 'Support Lifecycle and EOL section not found.'
}

$referenceDate = $null
if ($null -ne $sectionBody) {
    $referenceMatch = [regex]::Match(
        $sectionBody,
        'Reference date for status labels in this table:\s+\*\*(?<date>[^*]+)\*\*\.',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
    if (-not $referenceMatch.Success) {
        Add-ValidationFailure 'Reference date line not found in Support Lifecycle and EOL section.'
    }
    else {
        $referenceText = $referenceMatch.Groups['date'].Value.Trim()
        $parsedReference = $null
        if (-not (Convert-CompatibilityDate -Value $referenceText -Parsed ([ref] $parsedReference))) {
            Add-ValidationFailure ("Reference date is not in 'Month Day, Year' format: {0}" -f $referenceText)
        }
        else {
            $referenceDate = $parsedReference
            Write-Detail ("Reference date: {0}" -f $referenceDate.ToString('yyyy-MM-dd'))
        }
    }
}

$expectedHeader = @(
    'Minor',
    'GA date',
    'Active support until',
    'Maintenance support until',
    'EOL date',
    'Status'
)

$tableRows = @()
if ($null -ne $sectionBody) {
    $lines = @($sectionBody -split "`r?`n")
    $headerIndex = -1
    for ($index = 0; $index -lt $lines.Count; $index++) {
        $candidate = Convert-TableRow -Line $lines[$index]
        if ($null -eq $candidate) {
            continue
        }

        if ($candidate.Count -ge $expectedHeader.Count) {
            $candidateHeader = $candidate[0..($expectedHeader.Count - 1)]
            $matchHeader = $true
            for ($colIndex = 0; $colIndex -lt $expectedHeader.Count; $colIndex++) {
                if ($candidateHeader[$colIndex] -ne $expectedHeader[$colIndex]) {
                    $matchHeader = $false
                    break
                }
            }

            if ($matchHeader) {
                $headerIndex = $index
                break
            }
        }
    }

    if ($headerIndex -lt 0) {
        Add-ValidationFailure 'Support lifecycle table header not found or mismatched.'
    }
    elseif ($headerIndex + 1 -ge $lines.Count) {
        Add-ValidationFailure 'Support lifecycle table separator row not found.'
    }
    else {
        $separatorRow = Convert-TableRow -Line $lines[$headerIndex + 1]
        if ($null -eq $separatorRow -or -not (Test-SeparationRow -Columns $separatorRow)) {
            Add-ValidationFailure 'Support lifecycle table separator row invalid.'
        }
        else {
            for ($rowIndex = $headerIndex + 2; $rowIndex -lt $lines.Count; $rowIndex++) {
                $line = $lines[$rowIndex]
                if ([string]::IsNullOrWhiteSpace($line)) {
                    break
                }

                if ($line -match '^\s*#{1,6}\s+') {
                    break
                }

                $row = Convert-TableRow -Line $line
                if ($null -eq $row) {
                    break
                }

                if ($row.Count -ne $expectedHeader.Count) {
                    Add-ValidationFailure ("Support lifecycle table row must have {0} columns: {1}" -f $expectedHeader.Count, $line.Trim())
                    continue
                }

                if ($row -notcontains $null) {
                    $tableRows += ,$row
                }
            }
        }
    }
}

$rowCount = 0
foreach ($row in $tableRows) {
    $rowCount++
    $minor = $row[0]
    $gaText = $row[1]
    $activeText = $row[2]
    $maintenanceText = $row[3]
    $eolText = $row[4]
    $statusText = Convert-StatusText -Value $row[5]

    if ([string]::IsNullOrWhiteSpace($minor)) {
        Add-ValidationFailure ("Row {0}: Minor value is required." -f $rowCount)
    }

    $dateTexts = @($gaText, $activeText, $maintenanceText, $eolText)
    $hasAnyNa = $false
    $hasAnyDate = $false
    foreach ($dateText in $dateTexts) {
        if ($dateText -match '^(?i)N/A$') {
            $hasAnyNa = $true
        }
        elseif (-not [string]::IsNullOrWhiteSpace($dateText)) {
            $hasAnyDate = $true
        }
    }

    if ($hasAnyNa) {
        if ($hasAnyDate) {
            Add-ValidationFailure ("Row {0}: N/A values cannot be mixed with dates." -f $rowCount)
        }

        foreach ($dateText in $dateTexts) {
            if ($dateText -notmatch '^(?i)N/A$') {
                Add-ValidationFailure ("Row {0}: All date columns must be N/A when legacy row uses N/A." -f $rowCount)
                break
            }
        }

        if ($statusText -ne 'Unsupported') {
            Add-ValidationFailure ("Row {0}: Status must be Unsupported when dates are N/A." -f $rowCount)
        }

        Write-Detail ("Row {0}: legacy N/A row" -f $rowCount)
        continue
    }

    $gaDate = $null
    $activeDate = $null
    $maintenanceDate = $null
    $eolDate = $null

    if (-not (Convert-CompatibilityDate -Value $gaText -Parsed ([ref] $gaDate))) {
        Add-ValidationFailure ("Row {0}: GA date invalid format: {1}" -f $rowCount, $gaText)
        continue
    }
    if (-not (Convert-CompatibilityDate -Value $activeText -Parsed ([ref] $activeDate))) {
        Add-ValidationFailure ("Row {0}: Active support date invalid format: {1}" -f $rowCount, $activeText)
        continue
    }
    if (-not (Convert-CompatibilityDate -Value $maintenanceText -Parsed ([ref] $maintenanceDate))) {
        Add-ValidationFailure ("Row {0}: Maintenance support date invalid format: {1}" -f $rowCount, $maintenanceText)
        continue
    }
    if (-not (Convert-CompatibilityDate -Value $eolText -Parsed ([ref] $eolDate))) {
        Add-ValidationFailure ("Row {0}: EOL date invalid format: {1}" -f $rowCount, $eolText)
        continue
    }

    if ($gaDate -gt $activeDate) {
        Add-ValidationFailure ("Row {0}: GA date must be <= Active support date." -f $rowCount)
    }
    if ($activeDate -gt $maintenanceDate) {
        Add-ValidationFailure ("Row {0}: Active support date must be <= Maintenance support date." -f $rowCount)
    }

    $expectedEol = $maintenanceDate.AddDays(1)
    if ($expectedEol.Date -ne $eolDate.Date) {
        Add-ValidationFailure ("Row {0}: EOL date must be Maintenance date + 1 day." -f $rowCount)
    }

    $expectedStatus = $null
    if ($null -ne $referenceDate) {
        if ($referenceDate -le $activeDate) {
            $expectedStatus = 'Active'
        }
        elseif ($referenceDate -le $maintenanceDate) {
            $expectedStatus = 'Maintenance'
        }
        else {
            $expectedStatus = 'Unsupported'
        }

        if ($statusText -ne $expectedStatus) {
            Add-ValidationFailure ("Row {0}: Status '{1}' does not match reference date ({2}). Expected '{3}'." -f $rowCount, $statusText, $referenceDate.ToString('yyyy-MM-dd'), $expectedStatus)
        }
    }

    Write-Detail ("Row {0}: GA {1} Active {2} Maintenance {3} EOL {4} Status {5}" -f $rowCount, $gaDate.ToString('yyyy-MM-dd'), $activeDate.ToString('yyyy-MM-dd'), $maintenanceDate.ToString('yyyy-MM-dd'), $eolDate.ToString('yyyy-MM-dd'), $statusText)
}

Write-StyledOutput ''
Write-StyledOutput 'Compatibility lifecycle validation summary'
Write-StyledOutput ("  Rows checked: {0}" -f $rowCount)
Write-StyledOutput ("  Warning-only mode: {0}" -f $script:IsWarningOnly)
Write-StyledOutput ("  Warnings: {0}" -f $script:Warnings.Count)
Write-StyledOutput ("  Failures: {0}" -f $script:Failures.Count)

if ($script:Failures.Count -gt 0 -and (-not $script:IsWarningOnly)) {
    exit 1
}

if ($script:Failures.Count -gt 0 -or $script:Warnings.Count -gt 0) {
    Write-StyledOutput 'Compatibility lifecycle validation completed with warnings.'
}
else {
    Write-StyledOutput 'Compatibility lifecycle validation passed.'
}

exit 0
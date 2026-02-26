<#
.SYNOPSIS
    Normalizes PackageReference version ranges in .csproj files.

.DESCRIPTION
    Scans one or more .csproj files and enforces upper-bound ranges for selected packages.
    Rules applied during processing:

        1. Fixed version lower than the package limit → converted to range [current, limit).
        2. Existing range [A,B) where B < limit → rewritten to [A, limit).

    The list of package limits is maintained in the $limits hashtable inside the script.
    When -Verbose is used, every change is printed to the console.

.PARAMETER ProjectFile
    Optional. Path to a single .csproj file. When omitted, all .csproj files under the current
    directory are processed recursively.

.PARAMETER Verbose
    Prints detailed logs for each change that is applied.

.EXAMPLE
    Processes every .csproj file found below the current directory.
    pwsh -File scripts/maintenance/fix-version-ranges.ps1

.EXAMPLE
    Processes only the specified project and prints each normalized range.
    pwsh -File scripts/maintenance/fix-version-ranges.ps1 -ProjectFile src/Api/Api.csproj -Verbose

.EXAMPLE
    Processes a single project without verbose logging.
    pwsh -File scripts/maintenance/fix-version-ranges.ps1 -ProjectFile src/Api/Api.csproj

.EXAMPLE
    Invokes the script for each project discovered under src via PowerShell pipeline.
    Get-ChildItem src -Filter '*.csproj' -Recurse | ForEach-Object {
        pwsh -File scripts/maintenance/fix-version-ranges.ps1 -ProjectFile $_.FullName
    }

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+, read/write access to the target .csproj files.
#>

param(
  [string] $ProjectFile,
  [switch] $Verbose
)

$ErrorActionPreference = 'Stop'

# Writes verbose diagnostics with a logical color label.
function Write-VerboseColor {
  param(
    [string] $Message,
    [ConsoleColor] $Color = [ConsoleColor]::Gray
  )

  if ($Verbose) {
    Write-Host $Message -ForegroundColor $Color
  }
}

Write-Host ("===== Start fix-version-ranges {0} =====" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))

# 1) Define the max version limit per package (match exact Include name)
$limits = @{
  'MassTransit.RabbitMQ'   = '9.0.0'
  'MassTransit.Newtonsoft' = '9.0.0'
  'AutoMapper'             = '14.0.0'
  'MediatR'                = '13.0.0'
  'FluentValidation'       = '12.0.0'
  'FluentAssertions'       = '8.0.0'
}

# 2) Decide which files to process
$csprojs = @()
if ($ProjectFile) {
  $projPath = $ProjectFile.Trim('"')
  if (-not (Test-Path -LiteralPath $projPath -PathType Leaf)) {
    Write-Error ("File not found for -ProjectFile:`n  '{0}'" -f $projPath)
    exit 1
  }
  $csprojs = @((Resolve-Path -LiteralPath $projPath).Path)
}
else {
  $csprojs = Get-ChildItem -Recurse -Filter *.csproj | ForEach-Object { $_.FullName }
}

# 3) Process each .csproj
foreach ($file in $csprojs) {
  $projName = Split-Path $file -Leaf
  Write-Host ("→ Processing project: {0}" -f $projName)
  $adjustments = @()

  try {
    $content = Get-Content -LiteralPath $file -Raw -ErrorAction Stop
  }
  catch {
    Write-Warning ("    ! Could not read file: {0}" -f $projName)
    continue
  }

  $updated = $content

  foreach ($pkg in $limits.Keys) {
    $maxVersion = [version] $limits[$pkg]

    # a) Explicit version: <PackageReference Include="Pkg" Version="X.Y.Z" />
    #    -> Replace with range [X.Y.Z,MAX) when X.Y.Z < MAX
    $patternExp = "(?i)<PackageReference\s+Include\s*=\s*`"$([regex]::Escape($pkg))`"\s+Version\s*=\s*`"(\d+\.\d+\.\d+)`"\s*/>"
    $matchesExp = [regex]::Matches($updated, $patternExp)

    foreach ($m in $matchesExp) {
      $currentVersion = [version] $m.Groups[1].Value
      if ($currentVersion -lt $maxVersion) {
        $oldText = $m.Value
        $newInterval = "[{0},{1})" -f $m.Groups[1].Value, $limits[$pkg]
        $newText = "<PackageReference Include=`"$pkg`" Version=`"$newInterval`" />"
        $adjustments += ("{0} -> {1}" -f $pkg, $newInterval)
        $escapedOld = [regex]::Escape($oldText)
        $updated = [regex]::Replace(
          $updated,
          $escapedOld,
          [System.Text.RegularExpressions.MatchEvaluator] { param($x) $newText }
        )
      }
    }

    # b) Range version: <PackageReference Include="Pkg" Version="[A.B.C,D.E.F)" />
    #    -> Replace the upper bound D.E.F with MAX if D.E.F < MAX
    $patternRange = "(?i)<PackageReference\s+Include\s*=\s*`"$([regex]::Escape($pkg))`"\s+Version\s*=\s*`"\[(\d+\.\d+\.\d+),\s*(\d+\.\d+\.\d+)\)`"\s*/>"
    $matchesRange = [regex]::Matches($updated, $patternRange)

    foreach ($m in $matchesRange) {
      $lowerVersion = [version] $m.Groups[1].Value
      $upperVersion = [version] $m.Groups[2].Value
      if ($upperVersion -lt $maxVersion) {
        $oldText = $m.Value
        $newInterval = "[{0},{1})" -f $m.Groups[1].Value, $limits[$pkg]
        $newText = "<PackageReference Include=`"$pkg`" Version=`"$newInterval`" />"
        $adjustments += ("{0} -> {1}" -f $pkg, $newInterval)
        $escapedOld = [regex]::Escape($oldText)
        $updated = [regex]::Replace(
          $updated,
          $escapedOld,
          [System.Text.RegularExpressions.MatchEvaluator] { param($x) $newText }
        )
      }
    }
  }

  if ($adjustments.Count -gt 0) {
    try {
      [System.IO.File]::WriteAllText($file, $updated, [System.Text.Encoding]::UTF8)
      Write-Host "  ✔ Applied adjustments:"
      foreach ($a in $adjustments) { Write-Host ("    - {0}" -f $a) }
    }
    catch {
      Write-Warning ("    ! Failed to write project: {0}`n      {1}" -f $projName, $_)
    }
  }
  else {
    Write-Host "  (no changes)"
  }

  Write-Host ""
}

Write-Host ("===== End fix-version-ranges {0} =====" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))Write-Host ("===== End fix-version-ranges {0} =====" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
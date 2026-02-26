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

$script:ConsoleStylePath = Join-Path $PSScriptRoot '..\common\console-style.ps1'
if (-not (Test-Path -LiteralPath $script:ConsoleStylePath -PathType Leaf)) {
    $script:ConsoleStylePath = Join-Path $PSScriptRoot '..\..\common\console-style.ps1'
}
if (Test-Path -LiteralPath $script:ConsoleStylePath -PathType Leaf) {
    . $script:ConsoleStylePath
}
$script:IsVerboseEnabled = [bool] $Verbose

# Writes output text using ANSI color sequences when available.
function Write-ColorLine {
  param(
    [string] $Message,
    [ConsoleColor] $Color = [ConsoleColor]::Gray
  )

  if ($null -eq $PSStyle) {
    Microsoft.PowerShell.Utility\Write-Output $Message
    return
  }

  $ansiColor = switch ($Color) {
    ([ConsoleColor]::Blue) { $PSStyle.Foreground.Blue; break }
    ([ConsoleColor]::Cyan) { $PSStyle.Foreground.Cyan; break }
    ([ConsoleColor]::Green) { $PSStyle.Foreground.Green; break }
    ([ConsoleColor]::Yellow) { $PSStyle.Foreground.Yellow; break }
    ([ConsoleColor]::Red) { $PSStyle.Foreground.Red; break }
    ([ConsoleColor]::DarkGray) { $PSStyle.Foreground.BrightBlack; break }
    default { $PSStyle.Foreground.White }
  }

  Microsoft.PowerShell.Utility\Write-Output ("{0}{1}{2}" -f $ansiColor, $Message, $PSStyle.Reset)
}

# Writes verbose diagnostics with a logical color label.
function Write-VerboseColor {
  param(
    [string] $Message,
    [ConsoleColor] $Color = [ConsoleColor]::Gray
  )

  if ($script:IsVerboseEnabled) {
    Write-ColorLine -Message ("[VERBOSE:{0}] {1}" -f $Color, $Message) -Color $Color
  }
}

Write-ColorLine -Message ("===== Start fix-version-ranges {0} =====" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) -Color Cyan

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
  Write-ColorLine -Message ("→ Processing project: {0}" -f $projName) -Color Blue
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
          [System.Text.RegularExpressions.MatchEvaluator] {
            param($matchToken)
            [void] $matchToken
            $newText
          }
        )
      }
    }

    # b) Range version: <PackageReference Include="Pkg" Version="[A.B.C,D.E.F)" />
    #    -> Replace the upper bound D.E.F with MAX if D.E.F < MAX
    $patternRange = "(?i)<PackageReference\s+Include\s*=\s*`"$([regex]::Escape($pkg))`"\s+Version\s*=\s*`"\[(\d+\.\d+\.\d+),\s*(\d+\.\d+\.\d+)\)`"\s*/>"
    $matchesRange = [regex]::Matches($updated, $patternRange)

    foreach ($m in $matchesRange) {
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
          [System.Text.RegularExpressions.MatchEvaluator] {
            param($matchToken)
            [void] $matchToken
            $newText
          }
        )
      }
    }
  }

  if ($adjustments.Count -gt 0) {
    try {
      [System.IO.File]::WriteAllText($file, $updated, [System.Text.Encoding]::UTF8)
      Write-ColorLine -Message '  ✔ Applied adjustments:' -Color Green
      foreach ($a in $adjustments) { Write-StyledOutput ("    - {0}" -f $a) }
    }
    catch {
      Write-Warning ("    ! Failed to write project: {0}`n      {1}" -f $projName, $_)
    }
  }
  else {
    Write-StyledOutput "  (no changes)"
  }

  Write-StyledOutput ""
}

Write-ColorLine -Message ("===== End fix-version-ranges {0} =====" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) -Color Cyan
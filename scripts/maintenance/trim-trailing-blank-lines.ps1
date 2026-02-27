<#
.SYNOPSIS
    Removes trailing blank lines and trailing whitespace from text files.

.DESCRIPTION
    Scans text files (skipping binaries and excluded folders) and normalizes the end-of-file:
        • Removes trailing spaces/tabs at the end of the file.
        • Removes every blank line after the last line of content.
        • Keeps the file without an extra newline, matching repository conventions.

    When executed inside a Git repository, it prefers `git ls-files` to respect ignore rules.
    Otherwise it falls back to a filesystem scan starting from -Path (or the current directory)
    while skipping common build/tooling folders.

.PARAMETER Path
    Root folder to scan or a single file path. Defaults to the current directory when omitted.

.PARAMETER CheckOnly
    Only checks and lists files that would be fixed. Returns exit code 1 when changes are required.

.PARAMETER Verbose
    Prints detailed logs of processed files, decisions and errors.

.EXAMPLE
    Normalizes all supported files under the current directory.
    pwsh -File scripts/maintenance/trim-trailing-blank-lines.ps1

.EXAMPLE
    Lists files requiring adjustments without modifying them.
    pwsh -File scripts/maintenance/trim-trailing-blank-lines.ps1 -Path "C:\repo" -CheckOnly

.EXAMPLE
    Runs with verbose logging so you can audit which files changed.
    pwsh -File scripts/maintenance/trim-trailing-blank-lines.ps1 -Path "C:\repo" -Verbose

.EXAMPLE
    Targets a single file and trims trailing whitespace/blank lines in-place.
    pwsh -File scripts/maintenance/trim-trailing-blank-lines.ps1 -Path "scripts/README.md"

.NOTES
    Version: 1.1
    Requirements: PowerShell 7+, Git CLI (optional, for faster discovery).
#>

param (
    [string] $Path,
    [switch] $Verbose,
    [switch] $CheckOnly
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

# -------------------------------
# Helpers
# -------------------------------
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
    param (
        [string] $Message,
        [ConsoleColor] $Color = [ConsoleColor]::Gray
    )

    if ($script:IsVerboseEnabled) {
        Write-ColorLine -Message ("[VERBOSE:{0}] {1}" -f $Color, $Message) -Color $Color
    }
}

# Resolves the repository root by searching for known repository markers.
function Get-RepoRoot ([string] $startPath) {
    try {
        $resolved = if ([string]::IsNullOrWhiteSpace($startPath)) {
            (Get-Location).Path
        } else {
            (Resolve-Path -LiteralPath $startPath).Path
        }

        $gitRoot = (git -C "$resolved" rev-parse --show-toplevel 2>$null)
        if ($LASTEXITCODE -eq 0 -and $gitRoot) {
            return $gitRoot
        }

        return $resolved
    }
    catch {
        return (Get-Location).Path
    }
}

# Checks whether a path is located under any configured excluded directory.
function Test-IsUnderExcludedDir ([string] $fullPath, [string[]] $excludeDirs, [string] $root) {
    $norm = [IO.Path]::GetFullPath($fullPath).TrimEnd('\', '/')

    foreach ($d in $excludeDirs) {
        try {
            $exp = [IO.Path]::GetFullPath((Join-Path -Path $root -ChildPath $d)).TrimEnd('\', '/')
            $expWithSlash = $exp + '\'
            $expWithAltSlash = $exp + '/'

            if (
                $norm.Equals($exp, [System.StringComparison]::OrdinalIgnoreCase) -or
                $norm.StartsWith($expWithSlash, [System.StringComparison]::OrdinalIgnoreCase) -or
                $norm.StartsWith($expWithAltSlash, [System.StringComparison]::OrdinalIgnoreCase)
            ) {
                return $true
            }
        }
        catch {
            Write-VerboseColor ("Skipping excluded directory candidate due path resolution failure: {0}" -f $d) 'Yellow'
        }
    }

    return $false
}

# Checks whether a file should be processed based on directory and extension filters.
function Test-IsProcessableFile ([string] $fullPath, [string[]] $excludedExtensions, [string[]] $excludeDirs, [string] $root) {
    if (Test-IsUnderExcludedDir -fullPath $fullPath -excludeDirs $excludeDirs -root $root) {
        return $false
    }

    $extension = [IO.Path]::GetExtension($fullPath)
    if ([string]::IsNullOrWhiteSpace($extension)) {
        return $true
    }

    return ($excludedExtensions -notcontains $extension.ToLowerInvariant())
}

# -------------------------------
# Configuration (extensions and exclusions)
# -------------------------------
$BinaryExtensions = @(
    '.dll', '.exe', '.pdb', '.png', '.jpg', '.jpeg', '.gif', '.ico',
    '.zip', '.7z', '.rar', '.pdf', '.mp4', '.mp3', '.wav', '.ogg', '.webp', '.bmp',
    '.ttf', '.otf', '.woff', '.woff2', '.snk', '.nupkg', '.sln', '.rs'
)

$ExcludeDirs = @(
    'bin', 'obj', '.git', 'node_modules', '.vs', '.idea',
    '.build', '.deployment', 'artifacts', 'target'
)

# -------------------------------
# Discover files (single-file mode or repo scanning)
# -------------------------------
$files = @()

if ($Path -and (Test-Path -LiteralPath $Path -PathType Leaf)) {
    # Single file mode
    $fullFile = (Resolve-Path -LiteralPath $Path).Path
    $root     = [System.IO.Path]::GetDirectoryName($fullFile)

    Write-ColorLine -Message ("Root: {0}" -f $root) -Color Blue

    $files = @($fullFile)
}
else {
    # Repository or directory mode
    $root = Get-RepoRoot -startPath $Path

    Write-ColorLine -Message ("Root: {0}" -f $root) -Color Blue

    try {
        # Git method: tracked + untracked (non-ignored)
        $gitFiles = git -C "$root" ls-files -z --cached -o --exclude-standard 2>$null
        if ($LASTEXITCODE -eq 0 -and $gitFiles) {
            $files = ($gitFiles -split "`0") |
                Where-Object { $_ -ne '' } |
                ForEach-Object { Join-Path -Path $root -ChildPath $_ }

            # Apply directory and extension exclusions to git list as well.
            $files = $files |
                Where-Object {
                    Test-IsProcessableFile -fullPath $_ -excludedExtensions $BinaryExtensions -excludeDirs $ExcludeDirs -root $root
                }
        }
    }
    catch {
        Write-VerboseColor 'Git file discovery failed; falling back to filesystem scan.' 'Yellow'
    }

    if (-not $files) {
        # Filesystem method
        $files = Get-ChildItem -Path $root -Recurse -File |
            Where-Object {
                Test-IsProcessableFile -fullPath $_.FullName -excludedExtensions $BinaryExtensions -excludeDirs $ExcludeDirs -root $root
            } |
            ForEach-Object { $_.FullName }
    }
}

Write-ColorLine -Message ("Files found: {0}" -f $files.Count) -Color Yellow

# -------------------------------
# Processing
# -------------------------------
$changed = New-Object System.Collections.Generic.List[string]

# Regex patterns to clean EOF regardless of line ending type; \z ensures true end-of-string
$trailNlPattern = '([ \t]*(?:\r\n|\n|\r))+\z'
$trailWsPattern = '[ \t]+\z'

foreach ($fullPath in $files) {
    try {
        $relative = [IO.Path]::GetRelativePath($root, $fullPath)

        $text = Get-Content -Raw -LiteralPath $fullPath -ErrorAction Stop
        if ($null -eq $text) {
            continue
        }

        $updated = $text -replace $trailNlPattern, ''
        $updated = $updated -replace $trailWsPattern, ''

        if ($updated -ne $text) {
            if (-not $CheckOnly) {
                # Write exactly the computed content; do not add extra newline; UTF-8
                Set-Content -LiteralPath $fullPath -Value $updated -NoNewline -Encoding UTF8
            }

            $changed.Add($fullPath) | Out-Null
            Write-VerboseColor ("Fixed EOF for: {0}" -f $relative) 'Green'
        }
        else {
            Write-VerboseColor ("OK: {0}" -f $relative) 'Green'
        }
    }
    catch {
        Write-VerboseColor ("ERROR: {0} [{1}]" -f $_.Exception.Message, $fullPath) 'Red'
    }
}

# -------------------------------
# Summary and exit code
# -------------------------------
Write-StyledOutput ("Changed files: {0}" -f $changed.Count)

if ($Verbose -and $changed.Count -gt 0) {
    $changed | ForEach-Object { Write-StyledOutput $_ }
}

if ($CheckOnly) {
    if ($changed.Count -gt 0) {
        exit 1
    }
    else {
        exit 0
    }
}
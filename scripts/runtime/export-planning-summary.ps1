<#
.SYNOPSIS
    Exports a context handoff summary from active planning artifacts.

.DESCRIPTION
    Reads active plans and active specs from the workspace planning surface and
    generates a structured "Context Handoff" document showing where work
    stopped. Supports both repository-owned planning under `planning/` and the
    global-runtime fallback under `.build/super-agent/`. Designed to be called
    before context cleanup or at context-limit events so sessions can resume
    from a known stable state.

.PARAMETER RepoRoot
    Repository root path. Defaults to auto-detection from script location
    (two levels up from scripts/runtime/).

.PARAMETER OutputPath
    Output file path for the handoff document. When omitted, writes to
    .temp/context-handoff-<timestamp>.md under the repo root.

.PARAMETER PrintOnly
    Writes the summary to the console only. Does not create a file.

.PARAMETER Verbose
    Shows verbose execution metadata.

.EXAMPLE
    pwsh -File scripts/runtime/export-planning-summary.ps1

.EXAMPLE
    pwsh -File scripts/runtime/export-planning-summary.ps1 -PrintOnly

.EXAMPLE
    pwsh -File scripts/runtime/export-planning-summary.ps1 -RepoRoot C:\projects\my-repo

.NOTES
    Version: 1.1
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $OutputPath,
    [switch] $PrintOnly,
    [switch] $Verbose
)

$ErrorActionPreference = 'Stop'

$script:CommonBootstrapPath = Join-Path $PSScriptRoot '../common/common-bootstrap.ps1'
if (-not (Test-Path -LiteralPath $script:CommonBootstrapPath -PathType Leaf)) {
    $script:CommonBootstrapPath = Join-Path $PSScriptRoot '../../common/common-bootstrap.ps1'
}
if (-not (Test-Path -LiteralPath $script:CommonBootstrapPath -PathType Leaf)) {
    $script:CommonBootstrapPath = Join-Path $PSScriptRoot '../../shared-scripts/common/common-bootstrap.ps1'
}
if (-not (Test-Path -LiteralPath $script:CommonBootstrapPath -PathType Leaf)) {
    throw "Missing shared common bootstrap helper: $script:CommonBootstrapPath"
}
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('local-context-index')

# Resolves one planning/spec surface pair for the current workspace.
function Resolve-PlanningSurface {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ResolvedRepoRoot
    )

    $workspacePlanningPath = Join-Path $ResolvedRepoRoot 'planning'
    $workspaceSpecsPath = Join-Path $workspacePlanningPath 'specs'
    if ((Test-Path -LiteralPath (Join-Path $workspacePlanningPath 'active') -PathType Container) -or
        (Test-Path -LiteralPath (Join-Path $workspaceSpecsPath 'active') -PathType Container)) {
        return [pscustomobject]@{
            PlanRoot = 'planning/active'
            SpecRoot = 'planning/specs/active'
        }
    }

    return [pscustomobject]@{
        PlanRoot = '.build/super-agent/planning/active'
        SpecRoot = '.build/super-agent/specs/active'
    }
}

# Resolves the repository or workspace root from the script location or cwd.
function Resolve-PlanningSummaryRepoRoot {
    param(
        [string] $RequestedRoot
    )

    if (-not [string]::IsNullOrWhiteSpace($RequestedRoot)) {
        if (-not (Test-Path -LiteralPath $RequestedRoot -PathType Container)) {
            throw "RepoRoot not found: $RequestedRoot"
        }

        return (Resolve-Path -LiteralPath $RequestedRoot).Path
    }

    $candidateRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    if (Test-Path -LiteralPath (Join-Path $candidateRoot '.github') -PathType Container) {
        return (Resolve-Path -LiteralPath $candidateRoot).Path
    }

    if (-not (Test-Path -LiteralPath $PWD.Path -PathType Container)) {
        throw "RepoRoot not found: $($PWD.Path)"
    }

    return (Resolve-Path -LiteralPath $PWD.Path).Path
}

$RepoRoot = Resolve-PlanningSummaryRepoRoot -RequestedRoot $RepoRoot
$planningSurface = Resolve-PlanningSurface -ResolvedRepoRoot $RepoRoot

# Reads the title, status, and a concise focus excerpt from one planning markdown file.
function Get-PlanFileMeta {
    param([string] $FilePath)

    $raw = Get-Content -LiteralPath $FilePath -Raw -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }

    $lines = $raw -split "`n"
    $title = ($lines | Where-Object { $_ -match '^#\s+' } | Select-Object -First 1) -replace '^#\s+', ''
    $statusLine = ($lines | Where-Object { $_ -match 'State:|state:|Status:|status:' } | Select-Object -First 1)
    $status = if (-not [string]::IsNullOrWhiteSpace($statusLine)) {
        ($statusLine -replace '.*(?:State|Status):\s*', '').Trim()
    } else { '' }
    $focusLine = ($lines | Where-Object {
            $_ -match '^\s*(?:[-*]\s+)?(Current urgent slice in progress|Current focus|Objective|Next step|Summary):'
        } | Select-Object -First 1)
    $focus = if (-not [string]::IsNullOrWhiteSpace($focusLine)) {
        ($focusLine -replace '^\s*(?:[-*]\s+)?(Current urgent slice in progress|Current focus|Objective|Next step|Summary):\s*', '').Trim()
    }
    else {
        $firstBodyLine = ($lines |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace($_) -and
                $_ -notmatch '^\s*#' -and
                $_ -notmatch '^\s*[-*]\s+' -and
                $_ -notmatch '^\s*(State|Status):'
            } |
            Select-Object -First 1)
        if ($null -eq $firstBodyLine) {
            ''
        }
        else {
            ([string] $firstBodyLine).Trim()
        }
    }

    return [pscustomobject]@{
        FileName = Split-Path $FilePath -Leaf
        Title    = if ([string]::IsNullOrWhiteSpace($title)) { Split-Path $FilePath -Leaf } else { $title.Trim() }
        Status   = $status
        Focus    = $focus
    }
}

# Converts one workspace file path into a repository-relative path.
function Get-PlanningSummaryRelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ResolvedRepoRoot,
        [Parameter(Mandatory = $true)]
        [string] $FilePath
    )

    return ([System.IO.Path]::GetRelativePath($ResolvedRepoRoot, $FilePath) -replace '\\', '/')
}

# Returns one concise suggested-reference section from the local context index.
function Get-PlanningSummaryLocalReferences {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ResolvedRepoRoot,
        [Parameter(Mandatory = $true)]
        [object[]] $PlanArtifacts,
        [Parameter(Mandatory = $true)]
        [object[]] $SpecArtifacts
    )

    $querySegments = New-Object System.Collections.Generic.List[string]
    $excludePaths = New-Object System.Collections.Generic.List[string]

    foreach ($artifact in @($PlanArtifacts + $SpecArtifacts)) {
        if ($null -eq $artifact) {
            continue
        }

        foreach ($segment in @($artifact.Title, $artifact.Status, $artifact.Focus)) {
            if ([string]::IsNullOrWhiteSpace([string] $segment)) {
                continue
            }

            [void] $querySegments.Add((([string] $segment) -replace '\s+', ' ').Trim())
        }

        if (-not [string]::IsNullOrWhiteSpace([string] $artifact.RelativePath)) {
            [void] $excludePaths.Add([string] $artifact.RelativePath)
        }
    }

    if ($querySegments.Count -eq 0) {
        return @()
    }

    $queryText = (($querySegments.ToArray() | Select-Object -Unique) -join ' ').Trim()
    $hits = @(Get-LocalContextIndexHits -RepoRoot $ResolvedRepoRoot -QueryText $queryText -Top 6 -ExcludePaths $excludePaths.ToArray())
    if ($hits.Count -eq 0) {
        return @()
    }

    $references = New-Object System.Collections.Generic.List[string]
    $seenPaths = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($hit in $hits) {
        $normalizedPath = ([string] $hit.path -replace '\\', '/')
        if ($normalizedPath.StartsWith('planning/', [System.StringComparison]::OrdinalIgnoreCase) -or
            $normalizedPath.StartsWith('.build/super-agent/', [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }

        if (-not $seenPaths.Add($normalizedPath)) {
            continue
        }

        $referenceLine = "- `"$normalizedPath`""
        if (-not [string]::IsNullOrWhiteSpace([string] $hit.heading)) {
            $referenceLine += " - $([string] $hit.heading)"
        }

        $references.Add($referenceLine) | Out-Null
        if ($references.Count -ge 5) {
            break
        }
    }

    if ($references.Count -eq 0) {
        return @()
    }

    return @(
        '## Suggested Local References',
        '',
        'Use these indexed repository paths first if you need more detail than the active plan/spec summary already provides.',
        ''
    ) + $references.ToArray() + @('', '---', '')
}

# Collect active plans
$activePlansPath = Join-Path $RepoRoot $planningSurface.PlanRoot
$activePlans = @()
if (Test-Path -LiteralPath $activePlansPath -PathType Container) {
    $activePlans = @(
        Get-ChildItem -LiteralPath $activePlansPath -Filter '*.md' -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch '^README' } |
            Sort-Object LastWriteTime -Descending
    )
}

# Collect active specs
$activeSpecsPath = Join-Path $RepoRoot $planningSurface.SpecRoot
$activeSpecs = @()
if (Test-Path -LiteralPath $activeSpecsPath -PathType Container) {
    $activeSpecs = @(
        Get-ChildItem -LiteralPath $activeSpecsPath -Filter '*.md' -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch '^README' } |
            Sort-Object LastWriteTime -Descending
    )
}

$activePlanMetas = @()
foreach ($planFile in $activePlans) {
    $meta = Get-PlanFileMeta -FilePath $planFile.FullName
    if ($null -eq $meta) {
        continue
    }

    $meta | Add-Member -NotePropertyName RelativePath -NotePropertyValue (Get-PlanningSummaryRelativePath -ResolvedRepoRoot $RepoRoot -FilePath $planFile.FullName)
    $activePlanMetas += $meta
}

$activeSpecMetas = @()
foreach ($specFile in $activeSpecs) {
    $meta = Get-PlanFileMeta -FilePath $specFile.FullName
    if ($null -eq $meta) {
        continue
    }

    $meta | Add-Member -NotePropertyName RelativePath -NotePropertyValue (Get-PlanningSummaryRelativePath -ResolvedRepoRoot $RepoRoot -FilePath $specFile.FullName)
    $activeSpecMetas += $meta
}

# Get recent git log
$recentCommits = @()
try {
    $gitOut = & git -C $RepoRoot log --oneline -8 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitOut)) {
        $recentCommits = @($gitOut -split "`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }
} catch { }

# Build document
$ts = Get-Date -Format 'yyyy-MM-dd HH:mm'
$out = [System.Collections.Generic.List[string]]::new()

$out.Add('# Context Handoff Summary')
$out.Add('')
$out.Add("> Generated: $ts")
$out.Add("> Repo: $RepoRoot")
$out.Add('')
$out.Add('---')
$out.Add('')

# Active plans
$out.Add('## Active Plans')
$out.Add('')
if ($activePlans.Count -eq 0) {
    $out.Add('_No active plans._')
    $out.Add('')
} else {
    foreach ($meta in $activePlanMetas) {
        $out.Add("### $($meta.Title)")
        $out.Add('')
        $out.Add('- **File:** `' + $planningSurface.PlanRoot + '/' + $meta.FileName + '`')
        if (-not [string]::IsNullOrWhiteSpace($meta.Status)) {
            $out.Add("- **Status:** $($meta.Status)")
        }
        if (-not [string]::IsNullOrWhiteSpace($meta.Focus)) {
            $out.Add("- **Current focus:** $($meta.Focus)")
        }
        $out.Add('')
    }
}

$out.Add('---')
$out.Add('')

# Active specs
$out.Add('## Active Specs')
$out.Add('')
if ($activeSpecs.Count -eq 0) {
    $out.Add('_No active specs._')
    $out.Add('')
} else {
    foreach ($meta in $activeSpecMetas) {
        $out.Add("### $($meta.Title)")
        $out.Add('')
        $out.Add('- **File:** `' + $planningSurface.SpecRoot + '/' + $meta.FileName + '`')
        if (-not [string]::IsNullOrWhiteSpace($meta.Status)) {
            $out.Add("- **Status:** $($meta.Status)")
        }
        if (-not [string]::IsNullOrWhiteSpace($meta.Focus)) {
            $out.Add("- **Focus:** $($meta.Focus)")
        }
        $out.Add('')
    }
}

$out.Add('---')
$out.Add('')

foreach ($localReferenceLine in @(Get-PlanningSummaryLocalReferences -ResolvedRepoRoot $RepoRoot -PlanArtifacts $activePlanMetas -SpecArtifacts $activeSpecMetas)) {
    $out.Add([string] $localReferenceLine)
}

# Recent commits
$out.Add('## Recent Commits')
$out.Add('')
if ($recentCommits.Count -eq 0) {
    $out.Add('_Could not retrieve git log._')
} else {
    foreach ($c in $recentCommits) {
        $out.Add("- $c")
    }
}
$out.Add('')
$out.Add('---')
$out.Add('')

# Resume instructions
$out.Add('## Resume Instructions')
$out.Add('')
$out.Add('To resume work after context reset:')
$out.Add('')
$out.Add('1. Load `.github/AGENTS.md` and `.github/copilot-instructions.md`')
$out.Add('2. Load `.github/instructions/super-agent.instructions.md`')
$out.Add('3. Read the active plan(s) listed above from `' + $planningSurface.PlanRoot + '/`')
$out.Add('4. Read the active spec(s) from `' + $planningSurface.SpecRoot + '/` if present')
$out.Add('5. Resume from the last completed task in the active plan')

$document = $out -join "`n"

if ($PrintOnly) {
    Write-Output $document
    exit 0
}

# Resolve output path
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $tempDir = Join-Path $RepoRoot '.temp'
    if (-not (Test-Path -LiteralPath $tempDir -PathType Container)) {
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    }
    $OutputPath = Join-Path $tempDir ("context-handoff-{0}.md" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
}

$document | Set-Content -LiteralPath $OutputPath -Encoding UTF8 -NoNewline
Write-Output "Context handoff summary written to: $OutputPath"
exit 0
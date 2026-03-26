<#
.SYNOPSIS
    Adds a project/workspace prefix to persisted GitHub Copilot chat titles.

.DESCRIPTION
    Scans VS Code Copilot chat session files stored under the global VS Code
    user profile and normalizes each title to the format:

    `<project-prefix> - <task summary>`

    The project prefix is derived from the owning workspace or folder recorded
    in each `workspaceStorage/<workspace-id>/workspace.json` file.

    Supported session formats:
    - `workspaceStorage/<workspace-id>/chatSessions/*.json`
    - `workspaceStorage/<workspace-id>/chatSessions/*.jsonl`
    - optional `globalStorage/emptyWindowChatSessions/*.json*`

    The script updates only session title metadata (`customTitle`) and does not
    modify request content, messages, or other runtime state.

.PARAMETER RepoRoot
    Optional repository root. If omitted, the script auto-detects a root
    containing both `.github` and `.codex`.

.PARAMETER WorkspaceStorageRoot
    Optional VS Code `workspaceStorage` root. Defaults to the detected global
    VS Code user profile path.

.PARAMETER EmptyWindowChatRoot
    Optional path to VS Code `globalStorage/emptyWindowChatSessions`.

.PARAMETER PrefixSeparator
    Separator inserted between the project prefix and the session title.
    Default: ` - `

.PARAMETER IncludeEmptyWindowSessions
    Also normalizes empty-window sessions under `globalStorage`.
    Empty-window sessions are skipped when a project prefix cannot be derived.

.PARAMETER CreateBackup
    Creates a timestamped `.bak` file beside each changed session file.

.PARAMETER Apply
    Persists the computed title changes. Without this switch the script runs
    in preview mode and reports what would change.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/runtime/update-copilot-chat-titles.ps1

.EXAMPLE
    pwsh -File scripts/runtime/update-copilot-chat-titles.ps1 -Apply -CreateBackup

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $WorkspaceStorageRoot,
    [string] $EmptyWindowChatRoot,
    [string] $PrefixSeparator = ' - ',
    [switch] $IncludeEmptyWindowSessions,
    [switch] $CreateBackup,
    [switch] $Apply,
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
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('console-style', 'repository-paths', 'runtime-paths')
$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
$script:IsVerboseEnabled = [bool] $Verbose
$script:Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
# Resolves VS Code global user folder path with OS-aware defaults.
function Resolve-GlobalVscodeUserPath {
    param(
        [string] $RequestedPath
    )

    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        if (Test-Path -LiteralPath $RequestedPath -PathType Container) {
            return (Resolve-Path -LiteralPath $RequestedPath).Path
        }

        return [System.IO.Path]::GetFullPath($RequestedPath)
    }

    $homePath = Resolve-UserHomePath
    $candidates = @()

    if ($IsWindows) {
        if (-not [string]::IsNullOrWhiteSpace($env:APPDATA)) {
            $candidates += (Join-Path $env:APPDATA 'Code\User')
        }
        $candidates += (Join-Path $homePath 'AppData\Roaming\Code\User')
    }
    elseif ($IsMacOS) {
        $candidates += (Join-Path $homePath 'Library/Application Support/Code/User')
    }
    else {
        if (-not [string]::IsNullOrWhiteSpace($env:XDG_CONFIG_HOME)) {
            $candidates += (Join-Path $env:XDG_CONFIG_HOME 'Code/User')
        }
        $candidates += (Join-Path $homePath '.config/Code/User')
    }

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if (Test-Path -LiteralPath $candidate -PathType Container) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    if ($candidates.Count -gt 0) {
        return [System.IO.Path]::GetFullPath($candidates[0])
    }

    throw 'Could not resolve VS Code global user path.'
}

# Decodes a file URI into a local path.
function Convert-FileUriToPath {
    param(
        [string] $UriValue
    )

    if ([string]::IsNullOrWhiteSpace($UriValue)) {
        return $null
    }

    try {
        $uri = [System.Uri] $UriValue
        if (-not $uri.IsFile) {
            return $null
        }

        $localPath = [System.Uri]::UnescapeDataString($uri.LocalPath)
        if ($IsWindows -and $localPath -match '^/[A-Za-z]:/') {
            return $localPath.TrimStart('/').Replace('/', '\')
        }

        return $localPath
    }
    catch {
        return $null
    }
}

# Collapses whitespace and trims a candidate title.
function Get-NormalizedTitleText {
    param(
        [string] $Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    $normalized = ($Value -replace '\s+', ' ').Trim()
    if ([string]::IsNullOrWhiteSpace($normalized)) {
        return $null
    }

    if ($normalized.Length -gt 110) {
        return ('{0}...' -f $normalized.Substring(0, 107).TrimEnd())
    }

    return $normalized
}

# Builds a prefixed title while avoiding duplicate prefixes.
function Get-PrefixedTitle {
    param(
        [string] $Prefix,
        [string] $Title,
        [string] $Separator
    )

    $normalizedPrefix = Get-NormalizedTitleText -Value $Prefix
    $normalizedTitle = Get-NormalizedTitleText -Value $Title

    if ([string]::IsNullOrWhiteSpace($normalizedPrefix) -or [string]::IsNullOrWhiteSpace($normalizedTitle)) {
        return $null
    }

    $prefixWithSeparator = '{0}{1}' -f $normalizedPrefix, $Separator
    if ($normalizedTitle.StartsWith($prefixWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $normalizedTitle
    }

    return ('{0}{1}{2}' -f $normalizedPrefix, $Separator, $normalizedTitle)
}

# Extracts the most useful title candidate from a single request payload.
function Get-RequestTitleCandidate {
    param(
        [object] $Request
    )

    if ($null -eq $Request) {
        return $null
    }

    if ($Request.PSObject.Properties.Name -contains 'generatedTitle') {
        $generatedTitle = Get-NormalizedTitleText -Value ([string] $Request.generatedTitle)
        if (-not [string]::IsNullOrWhiteSpace($generatedTitle)) {
            return $generatedTitle
        }
    }

    if ($Request.PSObject.Properties.Name -contains 'message') {
        $message = $Request.message
        if ($null -ne $message) {
            if ($message.PSObject.Properties.Name -contains 'text') {
                $messageTitle = Get-NormalizedTitleText -Value ([string] $message.text)
                if (-not [string]::IsNullOrWhiteSpace($messageTitle)) {
                    return $messageTitle
                }
            }

            if ($message.PSObject.Properties.Name -contains 'parts') {
                foreach ($part in @($message.parts)) {
                    if ($null -eq $part) {
                        continue
                    }

                    if ($part.PSObject.Properties.Name -contains 'text') {
                        $partTitle = Get-NormalizedTitleText -Value ([string] $part.text)
                        if (-not [string]::IsNullOrWhiteSpace($partTitle)) {
                            return $partTitle
                        }
                    }
                }
            }
        }
    }

    if ($Request.PSObject.Properties.Name -contains 'response') {
        foreach ($responseEntry in @($Request.response)) {
            if ($null -eq $responseEntry) {
                continue
            }

            if ($responseEntry.PSObject.Properties.Name -contains 'generatedTitle') {
                $responseTitle = Get-NormalizedTitleText -Value ([string] $responseEntry.generatedTitle)
                if (-not [string]::IsNullOrWhiteSpace($responseTitle)) {
                    return $responseTitle
                }
            }
        }
    }

    return $null
}

# Extracts a session title candidate from a JSON session object.
function Get-JsonSessionBaseTitle {
    param(
        [object] $Session
    )

    if ($null -eq $Session) {
        return $null
    }

    foreach ($propertyName in @('customTitle', 'generatedTitle', 'title')) {
        if ($Session.PSObject.Properties.Name -contains $propertyName) {
            $title = Get-NormalizedTitleText -Value ([string] $Session.$propertyName)
            if (-not [string]::IsNullOrWhiteSpace($title)) {
                return $title
            }
        }
    }

    foreach ($request in @($Session.requests)) {
        $candidate = Get-RequestTitleCandidate -Request $request
        if (-not [string]::IsNullOrWhiteSpace($candidate)) {
            return $candidate
        }
    }

    return $null
}

# Tests whether the JSONL patch key addresses the session custom title.
function Test-IsCustomTitlePatch {
    param(
        [object] $KeyPath
    )

    $segments = @($KeyPath)
    if ($segments.Count -ne 1) {
        return $false
    }

    return [string]::Equals([string] $segments[0], 'customTitle', [System.StringComparison]::Ordinal)
}

# Extracts a session title candidate from JSONL patch entries.
function Get-JsonlSessionBaseTitle {
    param(
        [object[]] $Entries
    )

    foreach ($entry in @($Entries)) {
        if ($null -eq $entry) {
            continue
        }

        if ($entry.PSObject.Properties.Name -contains 'kind' -and [int] $entry.kind -eq 1 -and (Test-IsCustomTitlePatch -KeyPath $entry.k)) {
            $patchTitle = Get-NormalizedTitleText -Value ([string] $entry.v)
            if (-not [string]::IsNullOrWhiteSpace($patchTitle)) {
                return $patchTitle
            }
        }
    }

    foreach ($entry in @($Entries)) {
        if ($null -eq $entry) {
            continue
        }

        if ($entry.PSObject.Properties.Name -contains 'kind' -and [int] $entry.kind -eq 0) {
            $rootTitle = Get-JsonSessionBaseTitle -Session $entry.v
            if (-not [string]::IsNullOrWhiteSpace($rootTitle)) {
                return $rootTitle
            }
        }
    }

    foreach ($entry in @($Entries)) {
        if ($null -eq $entry) {
            continue
        }

        if ($entry.PSObject.Properties.Name -contains 'kind' -and [int] $entry.kind -eq 2) {
            $segments = @($entry.k)
            if ($segments.Count -gt 0 -and [string]::Equals([string] $segments[0], 'requests', [System.StringComparison]::Ordinal)) {
                foreach ($request in @($entry.v)) {
                    $candidate = Get-RequestTitleCandidate -Request $request
                    if (-not [string]::IsNullOrWhiteSpace($candidate)) {
                        return $candidate
                    }
                }
            }
        }
    }

    return $null
}

# Creates a timestamped backup beside the target session file.
function New-SessionBackup {
    param(
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }

    $backupPath = '{0}.{1}.bak' -f $Path, $script:Timestamp
    Copy-Item -LiteralPath $Path -Destination $backupPath -Force
    return $backupPath
}

# Replaces or inserts the `customTitle` property in a JSON session file.
function Update-JsonContentCustomTitle {
    param(
        [string] $Content,
        [string] $NewTitle
    )

    $jsonString = $NewTitle | ConvertTo-Json -Compress
    $existingTitlePattern = '"customTitle"\s*:\s*"([^"\\]|\\.)*"'
    if ([regex]::IsMatch($Content, $existingTitlePattern)) {
        return [regex]::Replace($Content, $existingTitlePattern, ('"customTitle": {0}' -f $jsonString), 1)
    }

    foreach ($anchor in @('"lastMessageDate"\s*:\s*\d+', '"creationDate"\s*:\s*\d+', '"sessionId"\s*:\s*"([^"\\]|\\.)*"')) {
        if ([regex]::IsMatch($Content, $anchor)) {
            return [regex]::Replace($Content, $anchor, ('$0,' + [Environment]::NewLine + '  "customTitle": ' + $jsonString), 1)
        }
    }

    throw 'Could not locate an insertion anchor for customTitle.'
}

# Resolves the project prefix from a workspaceStorage directory.
function Resolve-WorkspacePrefix {
    param(
        [string] $WorkspaceStorageDirectory
    )

    $metadataPath = Join-Path $WorkspaceStorageDirectory 'workspace.json'
    if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
        return $null
    }

    try {
        $metadata = Get-Content -Raw -LiteralPath $metadataPath | ConvertFrom-Json
    }
    catch {
        Write-VerboseLog ("Skipping workspace metadata parse failure: {0}" -f $metadataPath)
        return $null
    }

    $locationValue = $null
    if ($metadata.PSObject.Properties.Name -contains 'workspace') {
        $locationValue = [string] $metadata.workspace
    }
    elseif ($metadata.PSObject.Properties.Name -contains 'folder') {
        $locationValue = [string] $metadata.folder
    }

    $resolvedPath = Convert-FileUriToPath -UriValue $locationValue
    if ([string]::IsNullOrWhiteSpace($resolvedPath)) {
        return $null
    }

    if ($resolvedPath.EndsWith('.code-workspace', [System.StringComparison]::OrdinalIgnoreCase)) {
        return [System.IO.Path]::GetFileNameWithoutExtension($resolvedPath)
    }

    return Split-Path -Path $resolvedPath -Leaf
}

# Updates one JSON chat session file and returns a result object.
function Update-JsonSessionFile {
    param(
        [string] $Path,
        [string] $Prefix,
        [string] $Separator,
        [bool] $ShouldApply,
        [bool] $ShouldCreateBackup
    )

    $session = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
    $baseTitle = Get-JsonSessionBaseTitle -Session $session
    if ([string]::IsNullOrWhiteSpace($baseTitle)) {
        return [PSCustomObject]@{
            Path = $Path
            Status = 'Skipped'
            Reason = 'No title candidate found'
            OriginalTitle = $null
            UpdatedTitle = $null
        }
    }

    $newTitle = Get-PrefixedTitle -Prefix $Prefix -Title $baseTitle -Separator $Separator
    if ([string]::IsNullOrWhiteSpace($newTitle)) {
        return [PSCustomObject]@{
            Path = $Path
            Status = 'Skipped'
            Reason = 'Could not build prefixed title'
            OriginalTitle = $baseTitle
            UpdatedTitle = $null
        }
    }

    $existingCustomTitle = $null
    if ($session.PSObject.Properties.Name -contains 'customTitle') {
        $existingCustomTitle = Get-NormalizedTitleText -Value ([string] $session.customTitle)
    }
    $rawContent = Get-Content -Raw -LiteralPath $Path
    if ([string]::Equals($existingCustomTitle, $newTitle, [System.StringComparison]::Ordinal)) {
        return [PSCustomObject]@{
            Path = $Path
            Status = 'Unchanged'
            Reason = 'Already normalized'
            OriginalTitle = $existingCustomTitle
            UpdatedTitle = $newTitle
        }
    }

    if ($ShouldApply) {
        if ($ShouldCreateBackup) {
            New-SessionBackup -Path $Path | Out-Null
        }

        $updatedContent = Update-JsonContentCustomTitle -Content $rawContent -NewTitle $newTitle
        Set-Content -LiteralPath $Path -Value $updatedContent
    }

    return [PSCustomObject]@{
        Path = $Path
        Status = if ($ShouldApply) { 'Updated' } else { 'Preview' }
        Reason = $null
        OriginalTitle = $baseTitle
        UpdatedTitle = $newTitle
    }
}

# Updates one JSONL chat session file and returns a result object.
function Update-JsonlSessionFile {
    param(
        [string] $Path,
        [string] $Prefix,
        [string] $Separator,
        [bool] $ShouldApply,
        [bool] $ShouldCreateBackup
    )

    $entries = New-Object System.Collections.Generic.List[object]
    foreach ($line in (Get-Content -LiteralPath $Path)) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        $entries.Add(($line | ConvertFrom-Json)) | Out-Null
    }

    $baseTitle = Get-JsonlSessionBaseTitle -Entries $entries.ToArray()
    if ([string]::IsNullOrWhiteSpace($baseTitle)) {
        return [PSCustomObject]@{
            Path = $Path
            Status = 'Skipped'
            Reason = 'No title candidate found'
            OriginalTitle = $null
            UpdatedTitle = $null
        }
    }

    $newTitle = Get-PrefixedTitle -Prefix $Prefix -Title $baseTitle -Separator $Separator
    if ([string]::IsNullOrWhiteSpace($newTitle)) {
        return [PSCustomObject]@{
            Path = $Path
            Status = 'Skipped'
            Reason = 'Could not build prefixed title'
            OriginalTitle = $baseTitle
            UpdatedTitle = $null
        }
    }

    $alreadyNormalized = $false
    foreach ($entry in $entries) {
        if ($entry.PSObject.Properties.Name -contains 'kind' -and [int] $entry.kind -eq 1 -and (Test-IsCustomTitlePatch -KeyPath $entry.k)) {
            $patchTitle = Get-NormalizedTitleText -Value ([string] $entry.v)
            if ([string]::Equals($patchTitle, $newTitle, [System.StringComparison]::Ordinal)) {
                $alreadyNormalized = $true
                break
            }
        }
    }

    if (-not $alreadyNormalized) {
        $rootEntry = $entries | Where-Object {
            $_.PSObject.Properties.Name -contains 'kind' -and [int] $_.kind -eq 0
        } | Select-Object -First 1

        if ($null -ne $rootEntry) {
            if ($rootEntry.v.PSObject.Properties.Name -notcontains 'customTitle') {
                $rootEntry.v | Add-Member -MemberType NoteProperty -Name 'customTitle' -Value $newTitle
            }
            else {
                $rootEntry.v.customTitle = $newTitle
            }
        }

        foreach ($entry in $entries) {
            if ($entry.PSObject.Properties.Name -contains 'kind' -and [int] $entry.kind -eq 1 -and (Test-IsCustomTitlePatch -KeyPath $entry.k)) {
                $entry.v = $newTitle
            }
        }
    }

    if ($alreadyNormalized) {
        return [PSCustomObject]@{
            Path = $Path
            Status = 'Unchanged'
            Reason = 'Already normalized'
            OriginalTitle = $newTitle
            UpdatedTitle = $newTitle
        }
    }

    if ($ShouldApply) {
        if ($ShouldCreateBackup) {
            New-SessionBackup -Path $Path | Out-Null
        }

        $serializedLines = foreach ($entry in $entries) {
            $entry | ConvertTo-Json -Depth 100 -Compress
        }
        Set-Content -LiteralPath $Path -Value $serializedLines
    }

    return [PSCustomObject]@{
        Path = $Path
        Status = if ($ShouldApply) { 'Updated' } else { 'Preview' }
        Reason = $null
        OriginalTitle = $baseTitle
        UpdatedTitle = $newTitle
    }
}

# Processes all session files under a workspaceStorage directory.
function Update-WorkspaceSessionFiles {
    param(
        [string] $WorkspaceStorageDirectory,
        [string] $Separator,
        [bool] $ShouldApply,
        [bool] $ShouldCreateBackup
    )

    $prefix = Resolve-WorkspacePrefix -WorkspaceStorageDirectory $WorkspaceStorageDirectory
    if ([string]::IsNullOrWhiteSpace($prefix)) {
        return @()
    }

    $chatSessionsPath = Join-Path $WorkspaceStorageDirectory 'chatSessions'
    if (-not (Test-Path -LiteralPath $chatSessionsPath -PathType Container)) {
        return @()
    }

    $results = New-Object System.Collections.Generic.List[object]
    $sessionFiles = Get-ChildItem -LiteralPath $chatSessionsPath -File -Include *.json,*.jsonl
    foreach ($sessionFile in $sessionFiles) {
        Write-VerboseLog ("Processing Copilot session file: {0}" -f $sessionFile.FullName)

        if ([string]::Equals($sessionFile.Extension, '.jsonl', [System.StringComparison]::OrdinalIgnoreCase)) {
            $result = Update-JsonlSessionFile -Path $sessionFile.FullName -Prefix $prefix -Separator $Separator -ShouldApply $ShouldApply -ShouldCreateBackup $ShouldCreateBackup
        }
        else {
            $result = Update-JsonSessionFile -Path $sessionFile.FullName -Prefix $prefix -Separator $Separator -ShouldApply $ShouldApply -ShouldCreateBackup $ShouldCreateBackup
        }

        $results.Add($result) | Out-Null
    }

    return $results.ToArray()
}

# Processes optional empty-window Copilot session files.
function Update-EmptyWindowSessionFiles {
    param(
        [string] $RootPath,
        [string] $Separator,
        [bool] $ShouldApply,
        [bool] $ShouldCreateBackup
    )

    if (-not (Test-Path -LiteralPath $RootPath -PathType Container)) {
        return @()
    }

    $results = New-Object System.Collections.Generic.List[object]
    foreach ($sessionFile in (Get-ChildItem -LiteralPath $RootPath -File -Include *.json,*.jsonl)) {
        $result = [PSCustomObject]@{
            Path = $sessionFile.FullName
            Status = 'Skipped'
            Reason = 'Empty-window sessions do not have a stable project prefix'
            OriginalTitle = $null
            UpdatedTitle = $null
        }

        $results.Add($result) | Out-Null
    }

    return $results.ToArray()
}

$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
Set-Location -Path $resolvedRepoRoot

$resolvedGlobalUserPath = Resolve-GlobalVscodeUserPath
$resolvedWorkspaceStorageRoot = if (-not [string]::IsNullOrWhiteSpace($WorkspaceStorageRoot)) {
    if (Test-Path -LiteralPath $WorkspaceStorageRoot -PathType Container) {
        (Resolve-Path -LiteralPath $WorkspaceStorageRoot).Path
    }
    else {
        [System.IO.Path]::GetFullPath($WorkspaceStorageRoot)
    }
}
else {
    Join-Path $resolvedGlobalUserPath 'workspaceStorage'
}
$resolvedEmptyWindowChatRoot = if (-not [string]::IsNullOrWhiteSpace($EmptyWindowChatRoot)) {
    if (Test-Path -LiteralPath $EmptyWindowChatRoot -PathType Container) {
        (Resolve-Path -LiteralPath $EmptyWindowChatRoot).Path
    }
    else {
        [System.IO.Path]::GetFullPath($EmptyWindowChatRoot)
    }
}
else {
    Join-Path $resolvedGlobalUserPath 'globalStorage\emptyWindowChatSessions'
}

if (-not (Test-Path -LiteralPath $resolvedWorkspaceStorageRoot -PathType Container)) {
    throw "Workspace storage root not found: $resolvedWorkspaceStorageRoot"
}

$results = New-Object System.Collections.Generic.List[object]
foreach ($workspaceDirectory in (Get-ChildItem -LiteralPath $resolvedWorkspaceStorageRoot -Directory | Sort-Object Name)) {
    foreach ($result in (Update-WorkspaceSessionFiles -WorkspaceStorageDirectory $workspaceDirectory.FullName -Separator $PrefixSeparator -ShouldApply ([bool] $Apply) -ShouldCreateBackup ([bool] $CreateBackup))) {
        $results.Add($result) | Out-Null
    }
}

if ($IncludeEmptyWindowSessions) {
    foreach ($result in (Update-EmptyWindowSessionFiles -RootPath $resolvedEmptyWindowChatRoot -Separator $PrefixSeparator -ShouldApply ([bool] $Apply) -ShouldCreateBackup ([bool] $CreateBackup))) {
        $results.Add($result) | Out-Null
    }
}

$updatedCount = @($results | Where-Object { $_.Status -eq 'Updated' }).Count
$previewCount = @($results | Where-Object { $_.Status -eq 'Preview' }).Count
$unchangedCount = @($results | Where-Object { $_.Status -eq 'Unchanged' }).Count
$skippedCount = @($results | Where-Object { $_.Status -eq 'Skipped' }).Count

foreach ($result in $results) {
    if ($result.Status -in @('Updated', 'Preview')) {
        Write-StyledOutput ("[INFO] {0}: {1} -> {2}" -f $result.Status, $result.OriginalTitle, $result.UpdatedTitle)
    }
    elseif ($script:IsVerboseEnabled) {
        Write-StyledOutput ("[WARN] {0}: {1}" -f $result.Path, $result.Reason)
    }
}

Write-StyledOutput ''
Write-StyledOutput 'Copilot chat title update summary'
Write-StyledOutput ("  Repo root: {0}" -f $resolvedRepoRoot)
Write-StyledOutput ("  Workspace storage root: {0}" -f $resolvedWorkspaceStorageRoot)
Write-StyledOutput ("  Empty-window root: {0}" -f $resolvedEmptyWindowChatRoot)
Write-StyledOutput ("  Apply mode: {0}" -f ([bool] $Apply))
Write-StyledOutput ("  Create backup: {0}" -f ([bool] $CreateBackup))
Write-StyledOutput ("  Updated: {0}" -f $updatedCount)
Write-StyledOutput ("  Preview: {0}" -f $previewCount)
Write-StyledOutput ("  Unchanged: {0}" -f $unchangedCount)
Write-StyledOutput ("  Skipped: {0}" -f $skippedCount)

if (-not $Apply) {
    Write-StyledOutput 'Run again with -Apply to persist the normalized Copilot titles.'
}
else {
    Write-StyledOutput 'Copilot chat title update completed.'
}

exit 0
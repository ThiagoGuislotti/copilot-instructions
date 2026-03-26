<#
.SYNOPSIS
    Applies generated MCP server configuration to the target Codex config.toml.

.DESCRIPTION
    Reads either the canonical MCP runtime catalog or an explicit generated
    Codex MCP manifest, rewrites the `mcp_servers` sections in the target
    `config.toml`, and optionally creates a timestamped backup before writing.

.PARAMETER RepoRoot
    Optional repository root. Auto-detected when omitted.

.PARAMETER CatalogPath
    Optional path to the canonical MCP runtime catalog used when `ManifestPath`
    is not supplied.

.PARAMETER ManifestPath
    Optional path to a generated Codex MCP manifest. When supplied, the script
    applies this manifest directly instead of rendering from the catalog.

.PARAMETER TargetConfigPath
    Optional target Codex `config.toml` path. Defaults to the effective machine
    Codex runtime root resolved by `scripts/common/runtime-paths.ps1`.

.PARAMETER CreateBackup
    Creates a timestamped backup of the target config before overwriting it.

.PARAMETER DryRun
    Prints the would-be updated `config.toml` content without writing changes.

.EXAMPLE
    pwsh -File .\scripts\runtime\sync-codex-mcp-config.ps1 -RepoRoot . -CreateBackup

.EXAMPLE
    pwsh -File .\scripts\runtime\sync-codex-mcp-config.ps1 -RepoRoot . -DryRun

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

[CmdletBinding()]
param(
    [string] $RepoRoot,
    [string] $CatalogPath,
    [string] $ManifestPath,
    [string] $TargetConfigPath,
    [switch] $CreateBackup,
    [switch] $DryRun
)

$ErrorActionPreference = "Stop"

$script:CommonBootstrapPath = Join-Path $PSScriptRoot '../../scripts/common/common-bootstrap.ps1'
if (-not (Test-Path -LiteralPath $script:CommonBootstrapPath -PathType Leaf)) {
    $script:CommonBootstrapPath = Join-Path $PSScriptRoot '../../shared-scripts/common/common-bootstrap.ps1'
}
if (-not (Test-Path -LiteralPath $script:CommonBootstrapPath -PathType Leaf)) {
    throw "Missing shared common bootstrap helper: $script:CommonBootstrapPath"
}
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('runtime-paths', 'repository-paths', 'mcp-runtime-catalog')

# Escapes one string value for safe TOML output.
function Escape-TomlString {
    param([Parameter(Mandatory = $true)][string]$Value)
    return ($Value -replace '\\', '\\\\' -replace '"', '\"')
}

# Formats a string array as a TOML array literal.
function Format-TomlArray {
    param([Parameter(Mandatory = $true)][string[]]$Values)
    $escaped = $Values | ForEach-Object { '"' + (Escape-TomlString $_) + '"' }
    return "[" + ($escaped -join ", ") + "]"
}

# Reads one optional property from dictionary-like or PSCustomObject values.
function Get-OptionalPropertyValue {
    param(
        [Parameter(Mandatory = $true)] $Object,
        [Parameter(Mandatory = $true)][string]$PropertyName
    )

    if ($null -eq $Object) {
        return $null
    }

    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($PropertyName)) {
            return $Object[$PropertyName]
        }

        return $null
    }

    $property = $Object.PSObject.Properties[$PropertyName]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

# Loads a generated Codex MCP manifest file.
function Read-McpManifestFile {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Manifest not found: $Path"
    }

    $manifest = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -Depth 100
    $servers = @($manifest.servers)
    if ($servers.Count -eq 0) {
        throw "Manifest has no servers: $Path"
    }

    return $servers
}

# Removes existing `mcp_servers` sections from a config.toml file.
function Remove-McpSections {
    param([string[]]$Lines)

    if ($null -eq $Lines) {
        $Lines = @()
    }

    $result = New-Object System.Collections.Generic.List[string]
    $i = 0
    while ($i -lt $Lines.Count) {
        $line = $Lines[$i]
        $trimmed = $line.Trim()

        if ($trimmed -match '^\[mcp_servers(\.|])') {
            $i++
            while ($i -lt $Lines.Count) {
                $probe = $Lines[$i].Trim()
                if ($probe -match '^\[' -and $probe -notmatch '^\[mcp_servers(\.|])') {
                    break
                }
                $i++
            }
            continue
        }

        $result.Add($line)
        $i++
    }

    while ($result.Count -gt 0 -and [string]::IsNullOrWhiteSpace($result[$result.Count - 1])) {
        $result.RemoveAt($result.Count - 1)
    }

    return $result
}

# Renders MCP server entries into TOML lines for config.toml insertion.
function Render-McpToml {
    param([Parameter(Mandatory = $true)]$Servers)

    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($server in $Servers) {
        $nameValue = Get-OptionalPropertyValue -Object $server -PropertyName 'name'
        if ([string]::IsNullOrWhiteSpace([string]$nameValue)) {
            throw "Each server must include a non-empty 'name'."
        }

        $name = [string]$nameValue
        $lines.Add("[mcp_servers.$name]")

        $commandValue = Get-OptionalPropertyValue -Object $server -PropertyName 'command'
        if ($null -ne $commandValue -and -not [string]::IsNullOrWhiteSpace([string]$commandValue)) {
            $lines.Add("command = ""$(Escape-TomlString ([string]$commandValue))""")
        }

        $argsValue = Get-OptionalPropertyValue -Object $server -PropertyName 'args'
        if ($null -ne $argsValue) {
            $args = @($argsValue | ForEach-Object { [string]$_ })
            if ($args.Count -gt 0) {
                $lines.Add("args = $(Format-TomlArray -Values $args)")
            }
        }

        $urlValue = Get-OptionalPropertyValue -Object $server -PropertyName 'url'
        if ($null -ne $urlValue -and -not [string]::IsNullOrWhiteSpace([string]$urlValue)) {
            $lines.Add("url = ""$(Escape-TomlString ([string]$urlValue))""")
        }

        $headersValue = Get-OptionalPropertyValue -Object $server -PropertyName 'headers'
        if ($null -ne $headersValue) {
            $headerProps = $headersValue.PSObject.Properties
            if ($headerProps.Count -gt 0) {
                $lines.Add("[mcp_servers.$name.headers]")
                foreach ($prop in $headerProps) {
                    $k = Escape-TomlString ([string]$prop.Name)
                    $v = Escape-TomlString ([string]$prop.Value)
                    $lines.Add("""$k"" = ""$v""")
                }
            }
        }

        $envValue = Get-OptionalPropertyValue -Object $server -PropertyName 'env'
        if ($null -ne $envValue) {
            $envProps = $envValue.PSObject.Properties
            if ($envProps.Count -gt 0) {
                $lines.Add("[mcp_servers.$name.env]")
                foreach ($prop in $envProps) {
                    $k = Escape-TomlString ([string]$prop.Name)
                    $v = Escape-TomlString ([string]$prop.Value)
                    $lines.Add("""$k"" = ""$v""")
                }
            }
        }

        $lines.Add("")
    }

    while ($lines.Count -gt 0 -and [string]::IsNullOrWhiteSpace($lines[$lines.Count - 1])) {
        $lines.RemoveAt($lines.Count - 1)
    }

    return $lines
}

if ([string]::IsNullOrWhiteSpace($TargetConfigPath)) {
    $TargetConfigPath = Join-Path (Resolve-CodexRuntimePath) 'config.toml'
}

if (!(Test-Path $TargetConfigPath)) {
    throw "Target config not found: $TargetConfigPath"
}

$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
$servers = if (-not [string]::IsNullOrWhiteSpace($ManifestPath)) {
    $resolvedManifestPath = if ([System.IO.Path]::IsPathRooted($ManifestPath)) {
        [System.IO.Path]::GetFullPath($ManifestPath)
    }
    else {
        [System.IO.Path]::GetFullPath((Join-Path $resolvedRepoRoot $ManifestPath))
    }
    Read-McpManifestFile -Path $resolvedManifestPath
}
else {
    $catalogInfo = Read-McpRuntimeCatalog -RepoRoot $resolvedRepoRoot -CatalogPath $CatalogPath
    @((Convert-McpRuntimeCatalogToCodexManifest -Catalog $catalogInfo.Catalog).servers)
}

$originalLines = Get-Content $TargetConfigPath
$baseLines = Remove-McpSections -Lines $originalLines
$mcpLines = Render-McpToml -Servers $servers

$output = New-Object System.Collections.Generic.List[string]
$baseLines | ForEach-Object { $output.Add($_) }
$output.Add("")
$mcpLines | ForEach-Object { $output.Add($_) }

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
if ($CreateBackup) {
    $backup = "$TargetConfigPath.bak.$timestamp"
    Copy-Item $TargetConfigPath $backup -Force
    Write-Host "Backup: $backup"
}

if ($DryRun) {
    Write-Host ($output -join [Environment]::NewLine)
    Write-Host ""
    Write-Host "Dry-run only. No file changes were written."
    exit 0
}

Set-Content -Path $TargetConfigPath -Value $output
Write-Host "Updated: $TargetConfigPath"
Write-Host "Servers applied: $($servers.Count)"
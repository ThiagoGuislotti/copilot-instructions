[CmdletBinding()]
param(
    [string]$ManifestPath = (Join-Path $PSScriptRoot "..\mcp\servers.manifest.json"),
    [string]$TargetConfigPath = "$env:USERPROFILE\.codex\config.toml",
    [switch]$CreateBackup,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Escape-TomlString {
    param([Parameter(Mandatory = $true)][string]$Value)
    return ($Value -replace '\\', '\\\\' -replace '"', '\"')
}

function Format-TomlArray {
    param([Parameter(Mandatory = $true)][string[]]$Values)
    $escaped = $Values | ForEach-Object { '"' + (Escape-TomlString $_) + '"' }
    return "[" + ($escaped -join ", ") + "]"
}

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

function Render-McpToml {
    param([Parameter(Mandatory = $true)]$Servers)

    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($server in $Servers) {
        if ([string]::IsNullOrWhiteSpace($server.name)) {
            throw "Each server must include a non-empty 'name'."
        }

        $name = [string]$server.name
        $lines.Add("[mcp_servers.$name]")

        if ($null -ne $server.command -and -not [string]::IsNullOrWhiteSpace([string]$server.command)) {
            $lines.Add("command = ""$(Escape-TomlString ([string]$server.command))""")
        }

        if ($null -ne $server.args) {
            $args = @($server.args | ForEach-Object { [string]$_ })
            if ($args.Count -gt 0) {
                $lines.Add("args = $(Format-TomlArray -Values $args)")
            }
        }

        if ($null -ne $server.url -and -not [string]::IsNullOrWhiteSpace([string]$server.url)) {
            $lines.Add("url = ""$(Escape-TomlString ([string]$server.url))""")
        }

        if ($null -ne $server.headers) {
            $headerProps = $server.headers.PSObject.Properties
            if ($headerProps.Count -gt 0) {
                $lines.Add("[mcp_servers.$name.headers]")
                foreach ($prop in $headerProps) {
                    $k = Escape-TomlString ([string]$prop.Name)
                    $v = Escape-TomlString ([string]$prop.Value)
                    $lines.Add("""$k"" = ""$v""")
                }
            }
        }

        if ($null -ne $server.env) {
            $envProps = $server.env.PSObject.Properties
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

if (!(Test-Path $ManifestPath)) {
    throw "Manifest not found: $ManifestPath"
}

if (!(Test-Path $TargetConfigPath)) {
    throw "Target config not found: $TargetConfigPath"
}

$manifest = Get-Content -Raw $ManifestPath | ConvertFrom-Json -Depth 100
$servers = @($manifest.servers)
if ($servers.Count -eq 0) {
    throw "Manifest has no servers: $ManifestPath"
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

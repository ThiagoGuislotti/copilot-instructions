[CmdletBinding()]
param(
    [string]$ManifestPath = (Join-Path $PSScriptRoot "..\mcp\servers.manifest.json"),
    [string]$OutputPath = (Join-Path $PSScriptRoot "..\mcp\vscode.mcp.generated.json")
)

$ErrorActionPreference = "Stop"

if (!(Test-Path $ManifestPath)) {
    throw "Manifest not found: $ManifestPath"
}

$manifest = Get-Content -Raw $ManifestPath | ConvertFrom-Json -Depth 100
$servers = @($manifest.servers)
if ($servers.Count -eq 0) {
    throw "Manifest has no servers: $ManifestPath"
}

$serverMap = [ordered]@{}
foreach ($server in $servers) {
    if ([string]::IsNullOrWhiteSpace([string]$server.name)) {
        throw "Each server must include a non-empty 'name'."
    }

    $entry = [ordered]@{}
    if ($null -ne $server.type) { $entry.type = [string]$server.type }
    if ($null -ne $server.command) { $entry.command = [string]$server.command }
    if ($null -ne $server.args) { $entry.args = @($server.args | ForEach-Object { [string]$_ }) }
    if ($null -ne $server.url) { $entry.url = [string]$server.url }
    if ($null -ne $server.headers) {
        $headers = [ordered]@{}
        foreach ($prop in $server.headers.PSObject.Properties) {
            $headers[$prop.Name] = [string]$prop.Value
        }
        if ($headers.Count -gt 0) { $entry.headers = $headers }
    }

    $serverMap[[string]$server.name] = $entry
}

$result = [ordered]@{
    servers = $serverMap
}

$json = $result | ConvertTo-Json -Depth 100
Set-Content -Path $OutputPath -Value $json

Write-Host "Generated: $OutputPath"
Write-Host "Servers rendered: $($servers.Count)"
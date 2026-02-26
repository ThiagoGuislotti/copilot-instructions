<#
.SYNOPSIS
    Generates a REST Client .http file from an OpenAPI document using the NetToolsKit.OpenApi.Readers tool.

.DESCRIPTION
    This script invokes the CLI in tools/NetToolsKit.OpenApi.Readers to parse an OpenAPI spec and emit a .http file.
    By default it targets the OpenAPI endpoint (preferred). You can opt-in to the Swagger UI JSON if needed.

.PARAMETER Source
    Base URL for your API (e.g., http://localhost:5000). The script will append the default spec path accordingly.

.PARAMETER UseSwaggerJson
    When specified, uses '/swagger/v1/swagger.json' instead of the OpenAPI endpoint.

.PARAMETER Output
    Output .http file path. Defaults to '.build/generated/api.http'.

.EXAMPLE
    Generate from OpenAPI endpoint (default):
    pwsh -File scripts/maintenance/generate-http-from-openapi.ps1 -Source http://localhost:5000

.EXAMPLE
    Generate from Swagger JSON explicitly:
    pwsh -File scripts/maintenance/generate-http-from-openapi.ps1 -Source http://localhost:5000 -UseSwaggerJson

.NOTES
    Requires: PowerShell 7+, .NET SDK; builds the CLI if missing.
#>

param (
    [Parameter(Mandatory = $true)]
    [string] $Source,

    [switch] $UseSwaggerJson,

    [string] $Output = ".build/generated/api.http"
)

$ErrorActionPreference = 'Stop'

$script:ConsoleStylePath = Join-Path $PSScriptRoot '..\common\console-style.ps1'
if (-not (Test-Path -LiteralPath $script:ConsoleStylePath -PathType Leaf)) {
    $script:ConsoleStylePath = Join-Path $PSScriptRoot '..\..\common\console-style.ps1'
}
if (Test-Path -LiteralPath $script:ConsoleStylePath -PathType Leaf) {
    . $script:ConsoleStylePath
}

# Resolves the repository root by searching for known repository markers.
function Get-RepoRoot {
    try {
        $gitRoot = (git rev-parse --show-toplevel 2>$null)
        if ($LASTEXITCODE -eq 0 -and $gitRoot) { return $gitRoot }
    } catch {
        Write-StyledOutput "[WARN] Could not resolve git repository root. Using current directory."
    }
    return (Get-Location).Path
}

$root = Get-RepoRoot
Write-StyledOutput ("Root: {0}" -f $root)

$cliProj = Join-Path $root 'tools/NetToolsKit.OpenApi.Readers/NetToolsKit.OpenApi.Readers.csproj'
if (-not (Test-Path $cliProj)) {
    throw "CLI project not found: $cliProj"
}

# Build CLI (Release) if output not present
dotnet build "$cliProj" -c Release --nologo | Out-Null

# Compute spec URL
$specPath = if ($UseSwaggerJson) { '/swagger/v1/swagger.json' } else { '/openapi/v1.json' }
if ($Source.EndsWith('/')) { $Source = $Source.TrimEnd('/') }
$inputUrl = "$Source$specPath"

# Resolve CLI path
$cliDll = Join-Path $root '.deployment/release/NetToolsKit.OpenApi.Readers/net8.0/NetToolsKit.OpenApi.Readers.dll'
if (-not (Test-Path $cliDll)) {
    # try net9.0 fallback
    $cliDll = Join-Path $root '.deployment/release/NetToolsKit.OpenApi.Readers/net9.0/NetToolsKit.OpenApi.Readers.dll'
}
if (-not (Test-Path $cliDll)) {
    throw "CLI assembly not found under .deployment/release. Build may have failed."
}

$outPath = if ([IO.Path]::IsPathRooted($Output)) { $Output } else { Join-Path $root $Output }
[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($outPath)) | Out-Null

Write-StyledOutput ("Generating .http from: {0}" -f $inputUrl)

& dotnet "$cliDll" --input "$inputUrl" --output "$outPath" --group-by-tag true

Write-StyledOutput ("HTTP file generated: {0}" -f $outPath)
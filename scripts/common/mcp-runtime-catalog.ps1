<#
.SYNOPSIS
    Resolves the canonical MCP runtime catalog and derived runtime documents.

.DESCRIPTION
    Provides shared helper functions for the repository-owned MCP configuration
    model. The catalog is the single source of truth for MCP server definitions,
    per-runtime projections, and VS Code auth input declarations. Derived
    artifacts such as `.vscode/mcp.tamplate.jsonc` and
    `.codex/mcp/servers.manifest.json` are rendered from this catalog.

.EXAMPLE
    . .\scripts\common\mcp-runtime-catalog.ps1
    $catalog = Read-McpRuntimeCatalog -RepoRoot (Get-Location)

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Returns one direct property value or a fallback default.
function Get-McpCatalogOptionalValue {
    param(
        [object] $Object,
        [string] $PropertyName,
        [object] $DefaultValue = $null
    )

    if ($null -eq $Object -or [string]::IsNullOrWhiteSpace($PropertyName)) {
        return $DefaultValue
    }

    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($PropertyName)) {
            return $Object[$PropertyName]
        }

        return $DefaultValue
    }

    $property = $Object.PSObject.Properties[$PropertyName]
    if ($null -eq $property) {
        return $DefaultValue
    }

    return $property.Value
}

# Resolves the canonical MCP runtime catalog path.
function Resolve-McpRuntimeCatalogPath {
    param(
        [Parameter(Mandatory = $true)]
        [string] $RepoRoot,
        [string] $CatalogPath
    )

    if ([string]::IsNullOrWhiteSpace($CatalogPath)) {
        return Join-Path $RepoRoot '.github\governance\mcp-runtime.catalog.json'
    }

    if ([System.IO.Path]::IsPathRooted($CatalogPath)) {
        return [System.IO.Path]::GetFullPath($CatalogPath)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $CatalogPath))
}

# Reads the canonical MCP runtime catalog.
function Read-McpRuntimeCatalog {
    param(
        [Parameter(Mandatory = $true)]
        [string] $RepoRoot,
        [string] $CatalogPath
    )

    $resolvedCatalogPath = Resolve-McpRuntimeCatalogPath -RepoRoot $RepoRoot -CatalogPath $CatalogPath
    if (-not (Test-Path -LiteralPath $resolvedCatalogPath -PathType Leaf)) {
        throw "MCP runtime catalog not found: $resolvedCatalogPath"
    }

    try {
        $catalog = Get-Content -Raw -LiteralPath $resolvedCatalogPath | ConvertFrom-Json -Depth 200
    }
    catch {
        throw ("Invalid MCP runtime catalog '{0}': {1}" -f $resolvedCatalogPath, $_.Exception.Message)
    }

    $servers = @($catalog.servers)
    if ($servers.Count -eq 0) {
        throw "MCP runtime catalog has no servers: $resolvedCatalogPath"
    }

    return [pscustomobject]@{
        Path = $resolvedCatalogPath
        Catalog = $catalog
    }
}

# Returns one server target block (vscode/codex/claude) when present.
function Get-McpCatalogTarget {
    param(
        [Parameter(Mandatory = $true)]
        [object] $Server,
        [Parameter(Mandatory = $true)]
        [string] $TargetName
    )

    $targets = Get-McpCatalogOptionalValue -Object $Server -PropertyName 'targets'
    if ($null -eq $targets) {
        return $null
    }

    return Get-McpCatalogOptionalValue -Object $targets -PropertyName $TargetName
}

# Returns true when one runtime target should include the server.
function Test-McpCatalogTargetIncluded {
    param(
        [Parameter(Mandatory = $true)]
        [object] $Server,
        [Parameter(Mandatory = $true)]
        [string] $TargetName
    )

    $target = Get-McpCatalogTarget -Server $Server -TargetName $TargetName
    if ($null -eq $target) {
        return $false
    }

    return [bool] (Get-McpCatalogOptionalValue -Object $target -PropertyName 'include' -DefaultValue $false)
}

# Copies shared MCP server definition fields into an ordered hashtable.
function Convert-McpServerDefinition {
    param(
        [Parameter(Mandatory = $true)]
        [object] $Definition,
        [string[]] $AllowedFields = @('type', 'command', 'args', 'url', 'headers', 'env', 'gallery', 'version')
    )

    $entry = [ordered]@{}
    foreach ($fieldName in @($AllowedFields)) {
        $fieldValue = Get-McpCatalogOptionalValue -Object $Definition -PropertyName $fieldName
        if ($null -eq $fieldValue) {
            continue
        }

        switch ($fieldName) {
            'args' {
                $entry.args = @($fieldValue | ForEach-Object { [string] $_ })
            }
            'headers' {
                $headers = [ordered]@{}
                foreach ($property in $fieldValue.PSObject.Properties) {
                    $headers[[string] $property.Name] = [string] $property.Value
                }
                if ($headers.Count -gt 0) {
                    $entry.headers = $headers
                }
            }
            'env' {
                $envMap = [ordered]@{}
                foreach ($property in $fieldValue.PSObject.Properties) {
                    $envMap[[string] $property.Name] = [string] $property.Value
                }
                if ($envMap.Count -gt 0) {
                    $entry.env = $envMap
                }
            }
            default {
                $entry[$fieldName] = if ($fieldValue -is [string]) { [string] $fieldValue } else { $fieldValue }
            }
        }
    }

    return $entry
}

# Builds the full-fidelity VS Code MCP document from the canonical catalog.
function Convert-McpRuntimeCatalogToVscodeDocument {
    param(
        [Parameter(Mandatory = $true)]
        [object] $Catalog
    )

    $result = [ordered]@{
        inputs = @()
        servers = [ordered]@{}
    }

    foreach ($input in @($Catalog.inputs)) {
        $result.inputs += [ordered]@{
            id = [string] (Get-McpCatalogOptionalValue -Object $input -PropertyName 'id' -DefaultValue '')
            type = [string] (Get-McpCatalogOptionalValue -Object $input -PropertyName 'type' -DefaultValue 'promptString')
            description = [string] (Get-McpCatalogOptionalValue -Object $input -PropertyName 'description' -DefaultValue '')
            password = [bool] (Get-McpCatalogOptionalValue -Object $input -PropertyName 'password' -DefaultValue $false)
        }
    }

    foreach ($server in @($Catalog.servers)) {
        if (-not (Test-McpCatalogTargetIncluded -Server $server -TargetName 'vscode')) {
            continue
        }

        $serverId = [string] (Get-McpCatalogOptionalValue -Object $server -PropertyName 'id' -DefaultValue '')
        if ([string]::IsNullOrWhiteSpace($serverId)) {
            throw 'Each MCP runtime catalog server must declare an id.'
        }

        $target = Get-McpCatalogTarget -Server $server -TargetName 'vscode'
        $definition = Convert-McpServerDefinition -Definition (Get-McpCatalogOptionalValue -Object $server -PropertyName 'definition')
        $enabledByDefault = [bool] (Get-McpCatalogOptionalValue -Object $target -PropertyName 'enabledByDefault' -DefaultValue $false)
        if (-not $enabledByDefault) {
            $definition.disabled = $true
        }

        $result.servers[$serverId] = $definition
    }

    return $result
}

# Builds the Codex MCP manifest subset from the canonical catalog.
function Convert-McpRuntimeCatalogToCodexManifest {
    param(
        [Parameter(Mandatory = $true)]
        [object] $Catalog
    )

    $manifest = [ordered]@{
        version = 1
        servers = @()
    }

    foreach ($server in @($Catalog.servers)) {
        if (-not (Test-McpCatalogTargetIncluded -Server $server -TargetName 'codex')) {
            continue
        }

        $codexName = [string] (Get-McpCatalogOptionalValue -Object $server -PropertyName 'codexName' -DefaultValue '')
        if ([string]::IsNullOrWhiteSpace($codexName)) {
            throw ("MCP runtime catalog server '{0}' is missing codexName." -f [string] (Get-McpCatalogOptionalValue -Object $server -PropertyName 'id' -DefaultValue 'unknown'))
        }

        $definition = Convert-McpServerDefinition -Definition (Get-McpCatalogOptionalValue -Object $server -PropertyName 'definition') -AllowedFields @('type', 'command', 'args', 'url', 'headers', 'env')
        $entry = [ordered]@{
            name = $codexName
        }
        foreach ($property in $definition.Keys) {
            $entry[$property] = $definition[$property]
        }

        $manifest.servers += $entry
    }

    return $manifest
}

# Applies one VS Code profile enable/disable map over the rendered document.
function Merge-McpProfileSelection {
    param(
        [Parameter(Mandatory = $true)]
        [object] $TemplateDocument,
        [string] $ResolvedProfilePath
    )

    if ([string]::IsNullOrWhiteSpace($ResolvedProfilePath)) {
        return $TemplateDocument
    }

    if (-not (Test-Path -LiteralPath $ResolvedProfilePath -PathType Leaf)) {
        throw "MCP profile not found: $ResolvedProfilePath"
    }

    try {
        $profileDocument = Get-Content -Raw -LiteralPath $ResolvedProfilePath | ConvertFrom-Json -Depth 100
    }
    catch {
        throw ("Invalid MCP profile '{0}': {1}" -f $ResolvedProfilePath, $_.Exception.Message)
    }

    $serverSelection = Get-McpCatalogOptionalValue -Object (Get-McpCatalogOptionalValue -Object $profileDocument -PropertyName 'mcp') -PropertyName 'servers'
    if ($null -eq $serverSelection) {
        return $TemplateDocument
    }

    foreach ($selectionProperty in $serverSelection.PSObject.Properties) {
        $serverName = [string] $selectionProperty.Name
        $selectionValue = $selectionProperty.Value
        if ($null -eq $selectionValue -or -not ($selectionValue.PSObject.Properties.Name -contains 'enabled')) {
            continue
        }

        $serversDocument = $TemplateDocument.servers
        $serverObject = $null
        if ($serversDocument -is [System.Collections.IDictionary]) {
            if ($serversDocument.Contains($serverName)) {
                $serverObject = $serversDocument[$serverName]
            }
        }
        else {
            $targetServer = $serversDocument.PSObject.Properties[$serverName]
            if ($null -ne $targetServer) {
                $serverObject = $targetServer.Value
            }
        }

        if ($null -eq $serverObject) {
            continue
        }

        $enabled = [bool] $selectionValue.enabled
        if ($enabled) {
            if ($serverObject -is [System.Collections.IDictionary]) {
                if ($serverObject.Contains('disabled')) {
                    $serverObject.Remove('disabled')
                }
            }
            else {
                $disabledProperty = $serverObject.PSObject.Properties['disabled']
                if ($null -ne $disabledProperty) {
                    $serverObject.PSObject.Properties.Remove('disabled')
                }
            }
        }
        else {
            if ($serverObject -is [System.Collections.IDictionary]) {
                $serverObject['disabled'] = $true
            }
            else {
                $disabledProperty = $serverObject.PSObject.Properties['disabled']
                if ($null -eq $disabledProperty) {
                    $serverObject | Add-Member -NotePropertyName 'disabled' -NotePropertyValue $true
                }
                else {
                    $disabledProperty.Value = $true
                }
            }
        }
    }

    return $TemplateDocument
}
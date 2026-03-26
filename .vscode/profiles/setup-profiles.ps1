<#
.SYNOPSIS
    Creates repository-managed VS Code profiles and can apply the matching MCP selection.

.DESCRIPTION
    Reads `profile-*.json` files from `.vscode/profiles/`, lists them, and creates
    the selected VS Code profiles through the local `code` command.

    When one profile is selected, the script can also apply the profile MCP
    enable/disable map on top of the canonical
    `.github/governance/mcp-runtime.catalog.json` renderer by delegating to
    `scripts/runtime/sync-vscode-global-mcp.ps1`.

.PARAMETER DryRun
    Prints planned profile creation actions without launching VS Code.

.PARAMETER ListProfiles
    Lists all available versioned profile definitions.

.PARAMETER ProfileName
    One or more profile names, file stems, or file names to create.
    Accepts comma-separated values.

.PARAMETER SkipMcpSync
    Skips MCP synchronization after profile creation.

.PARAMETER McpProfileName
    Optional explicit profile name to use for MCP synchronization when multiple
    profiles are selected. When omitted, MCP sync runs automatically only when
    exactly one profile is selected.

.PARAMETER GlobalVscodeUserPath
    Optional VS Code global user folder used by the delegated MCP sync.

.PARAMETER CreateMcpBackup
    Creates a timestamped backup of the global VS Code `mcp.json` before overwriting it.

.EXAMPLE
    pwsh -File .\.vscode\profiles\setup-profiles.ps1 -ListProfiles

.EXAMPLE
    pwsh -File .\.vscode\profiles\setup-profiles.ps1 -ProfileName Base

.EXAMPLE
    pwsh -File .\.vscode\profiles\setup-profiles.ps1 -ProfileName Base,Frontend -McpProfileName Frontend -CreateMcpBackup

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+ and VS Code.
#>

param(
    [switch] $DryRun,
    [switch] $ListProfiles,
    [string[]] $ProfileName,
    [switch] $SkipMcpSync,
    [string] $McpProfileName,
    [string] $GlobalVscodeUserPath,
    [switch] $CreateMcpBackup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Resolves the VS Code CLI path.
function Get-CodeCommandPath {
    $codeCommand = Get-Command 'code' -ErrorAction SilentlyContinue
    if ($null -ne $codeCommand) {
        return $codeCommand.Source
    }

    $fallbackPath = Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code\bin\code.cmd'
    if (Test-Path -LiteralPath $fallbackPath -PathType Leaf) {
        return $fallbackPath
    }

    throw 'VS Code não encontrado. Adicione o comando `code` ao PATH ou ajuste o script.'
}

# Resolves the repository root from the profiles folder.
function Resolve-RepoRoot {
    $profilesRoot = Split-Path -Path $PSCommandPath -Parent
    return [System.IO.Path]::GetFullPath((Join-Path $profilesRoot '..\..'))
}

# Loads profile definition files.
function Get-ProfileDefinitions {
    param(
        [string] $ProfilesRoot
    )

    $profileFiles = Get-ChildItem -LiteralPath $ProfilesRoot -Filter 'profile-*.json' -File | Sort-Object Name
    $definitions = foreach ($file in $profileFiles) {
        $content = Get-Content -Raw -LiteralPath $file.FullName | ConvertFrom-Json -Depth 20
        $extendsValue = if ($content.PSObject.Properties.Name -contains 'extends') {
            [string] $content.extends
        }
        else {
            ''
        }
        [pscustomobject]@{
            FileName = $file.Name
            FileStem = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
            Name = [string] $content.name
            Description = [string] $content.description
            Extends = $extendsValue
            Path = $file.FullName
        }
    }

    return @($definitions)
}

# Selects one or more requested profile definitions.
function Select-ProfileDefinitions {
    param(
        [object[]] $Definitions,
        [string[]] $RequestedNames
    )

    $normalizedRequestedNames = @(
        foreach ($requestedName in $RequestedNames) {
            if ([string]::IsNullOrWhiteSpace($requestedName)) {
                continue
            }

            foreach ($segment in ($requestedName -split ',')) {
                $trimmedSegment = $segment.Trim()
                if (-not [string]::IsNullOrWhiteSpace($trimmedSegment)) {
                    $trimmedSegment
                }
            }
        }
    )

    if ($normalizedRequestedNames.Count -eq 0) {
        return @($Definitions)
    }

    $selection = New-Object System.Collections.Generic.List[object]
    foreach ($requestedName in $normalizedRequestedNames) {
        $match = $Definitions | Where-Object {
            $_.Name -eq $requestedName -or
            $_.FileStem -eq $requestedName -or
            $_.FileName -eq $requestedName
        } | Select-Object -First 1

        if ($null -eq $match) {
            throw ("Profile não encontrado: {0}" -f $requestedName)
        }

        $selection.Add($match) | Out-Null
    }

    return @($selection.ToArray())
}

# Resolves the single profile to use for MCP sync.
function Resolve-McpSyncProfile {
    param(
        [object[]] $SelectedDefinitions,
        [string] $RequestedProfileName
    )

    if (-not [string]::IsNullOrWhiteSpace($RequestedProfileName)) {
        return (Select-ProfileDefinitions -Definitions $SelectedDefinitions -RequestedNames @($RequestedProfileName) | Select-Object -First 1)
    }

    if ($SelectedDefinitions.Count -eq 1) {
        return $SelectedDefinitions[0]
    }

    return $null
}

# Applies MCP sync using one selected profile.
function Invoke-McpProfileSync {
    param(
        [Parameter(Mandatory = $true)]
        [string] $RepoRoot,
        [Parameter(Mandatory = $true)]
        [string] $ProfilePath,
        [string] $GlobalVscodeUserPath,
        [switch] $CreateMcpBackup
    )

    $syncScriptPath = Join-Path $RepoRoot 'scripts\runtime\sync-vscode-global-mcp.ps1'
    if (-not (Test-Path -LiteralPath $syncScriptPath -PathType Leaf)) {
        throw "Script de sync MCP não encontrado: $syncScriptPath"
    }

    $syncArguments = @{
        RepoRoot = $RepoRoot
        ProfilePath = $ProfilePath
    }
    if (-not [string]::IsNullOrWhiteSpace($GlobalVscodeUserPath)) {
        $syncArguments.GlobalVscodeUserPath = $GlobalVscodeUserPath
    }
    if ($CreateMcpBackup) {
        $syncArguments.CreateBackup = $true
    }

    & $syncScriptPath @syncArguments | Out-Null
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
    if ($exitCode -ne 0) {
        throw ("Falha ao sincronizar MCP global para o profile selecionado. ExitCode={0}" -f $exitCode)
    }
}

$profilesRoot = Split-Path -Path $PSCommandPath -Parent
$repoRoot = Resolve-RepoRoot
$definitions = Get-ProfileDefinitions -ProfilesRoot $profilesRoot

if ($definitions.Count -eq 0) {
    throw ("Nenhum arquivo profile-*.json encontrado em {0}" -f $profilesRoot)
}

if ($ListProfiles) {
    $definitions |
        Select-Object Name, FileName, Extends, Description |
        Format-Table -AutoSize |
        Out-Host
    exit 0
}

$selectedDefinitions = Select-ProfileDefinitions -Definitions $definitions -RequestedNames @($ProfileName)
$resolvedCodePath = if ($DryRun) { $null } else { Get-CodeCommandPath }

Write-Host ''
Write-Host '=== VS Code Profile Setup ===' -ForegroundColor Cyan
Write-Host ''

foreach ($definition in $selectedDefinitions) {
    if ($DryRun) {
        Write-Host ("[DRY-RUN] Criaria profile: '{0}' ({1})" -f $definition.Name, $definition.FileName) -ForegroundColor Yellow
        continue
    }

    Write-Host ("Criando profile: '{0}'..." -f $definition.Name) -ForegroundColor Green
    & $resolvedCodePath --profile $definition.Name --new-window --wait 2>$null | Out-Null
    Start-Sleep -Milliseconds 500
}

$mcpSyncProfile = $null
if (-not $SkipMcpSync) {
    $mcpSyncProfile = Resolve-McpSyncProfile -SelectedDefinitions $selectedDefinitions -RequestedProfileName $McpProfileName
}

if ($DryRun) {
    if ($SkipMcpSync) {
        Write-Host '[DRY-RUN] MCP global não será sincronizado porque -SkipMcpSync foi informado.' -ForegroundColor DarkYellow
    }
    elseif ($null -ne $mcpSyncProfile) {
        Write-Host ("[DRY-RUN] Sincronizaria o MCP global com o profile '{0}'." -f $mcpSyncProfile.Name) -ForegroundColor Yellow
    }
    else {
        Write-Host '[DRY-RUN] MCP global não será sincronizado automaticamente porque a seleção de profile está ambígua. Use -McpProfileName para escolher um profile.' -ForegroundColor DarkYellow
    }
}
elseif (-not $SkipMcpSync) {
    if ($null -ne $mcpSyncProfile) {
        Write-Host ("Sincronizando MCP global com o profile: '{0}'..." -f $mcpSyncProfile.Name) -ForegroundColor Green
        Invoke-McpProfileSync -RepoRoot $repoRoot -ProfilePath $mcpSyncProfile.Path -GlobalVscodeUserPath $GlobalVscodeUserPath -CreateMcpBackup:$CreateMcpBackup
    }
    else {
        Write-Host 'MCP global não foi sincronizado automaticamente porque há múltiplos profiles selecionados. Use -McpProfileName para escolher qual profile controla os MCPs.' -ForegroundColor Yellow
    }
}

Write-Host ''
Write-Host 'Feito! Profiles processados.' -ForegroundColor Green
Write-Host 'Para alternar:' -ForegroundColor White
Write-Host "  Ctrl+Shift+P -> 'Profiles: Switch Profile'" -ForegroundColor White
Write-Host 'Para listar profiles disponíveis:' -ForegroundColor White
Write-Host '  .\setup-profiles.ps1 -ListProfiles' -ForegroundColor White
Write-Host 'Para criar só alguns profiles:' -ForegroundColor White
Write-Host '  .\setup-profiles.ps1 -ProfileName Base,Frontend' -ForegroundColor White
Write-Host 'Para criar um profile e sincronizar o MCP global com ele:' -ForegroundColor White
Write-Host '  .\setup-profiles.ps1 -ProfileName Frontend -CreateMcpBackup' -ForegroundColor White
Write-Host 'Para usar outro profile como fonte do MCP global:' -ForegroundColor White
Write-Host '  .\setup-profiles.ps1 -ProfileName Base,Frontend -McpProfileName Frontend' -ForegroundColor White
<#
.SYNOPSIS
    Interactive Docker deployment helper for .NET backends targeting VPS hosts (e.g., Contabo).
.DESCRIPTION
    Guides the operator through seven interactive stages:
        1. Optionally rebuild the Docker image locally.
        2. Export the image to a compressed .tar.gz bundle.
        3. Optionally clean the remote stack (`docker compose down -v`).
        4. Sync the local docker/ directory (compose files, configs, env files, etc.).
        5. Transfer the exported bundle to the VPS via SCP.
        6. Load the image into the remote Docker engine.
        7. Start the stack with `docker compose up -d`, display container status and helpful URLs.

    The script is generic; create environment-specific wrappers to avoid retyping secrets or
    parameters. When -VpsPassword is omitted, the script prompts once and reuses the answer.

.PARAMETER VpsIp
    Public IP or hostname of the target VPS.
.PARAMETER VpsUser
    SSH user employed for all remote operations (e.g., root, deploy).
.PARAMETER VpsBasePath
    Base directory on the VPS where compose files and artifacts are stored.
.PARAMETER ImageName
    Name assigned to the Docker image bundle.
.PARAMETER ImageTag
    Optional Docker tag. Default: latest.
.PARAMETER ApiPort
.PARAMETER ApiPortHttps
.PARAMETER SeqPort
    Ports surfaced in the final summary (HTTP endpoint, HTTPS endpoint, Seq dashboard).
.PARAMETER ProjectRoot
    Local project root that contains docker/ assets and the Dockerfile.
.PARAMETER DockerfilePath
    Path to the Dockerfile used during the build stage.
.PARAMETER VpsPassword
    Optional SSH password value (compatible with sshpass if installed). Prompted when omitted.

.EXAMPLE
    Recommended usage: call the generic script through a project-specific wrapper.
    $params = @{
        VpsIp          = "38.242.232.14"
        VpsUser        = "root"
        VpsBasePath    = "/root/my-app"
        ImageName      = "my-app-api"
        ApiPort        = "5000"
        ApiPortHttps   = "5001"
        SeqPort        = "8082"
        ProjectRoot    = $PSScriptRoot
        DockerfilePath = ".\src\API\Dockerfile"
    }
    & .\deploy-backend-to-vps.ps1 @params

.EXAMPLE
    Ad-hoc invocation where all parameters are passed explicitly.
    .\deploy-backend-to-vps.ps1 `
        -VpsIp "38.242.232.14" `
        -VpsUser "root" `
        -VpsBasePath "/root/prod-app" `
        -ImageName "prod-api" `
        -ApiPort "5000" `
        -ApiPortHttps "5001" `
        -SeqPort "8082" `
        -ProjectRoot "C:\Projects\Prod" `
        -DockerfilePath ".\src\Api\Dockerfile"

.EXAMPLE
    Wrapper snippet demonstrating password capture and reuse.
    $pwd = Read-Host 'VPS password' -AsSecureString
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($pwd))
    & .\deploy-backend-to-vps.ps1 -VpsIp "10.0.0.5" -VpsUser "deploy" -VpsBasePath "/srv/app" -ImageName "app-api" -ApiPort 5000 -ApiPortHttps 5001 -SeqPort 8082 -ProjectRoot "$PSScriptRoot" -DockerfilePath ".\Dockerfile" -VpsPassword $plain

.NOTES
    Requirements: Docker CLI, SSH/SCP tools, PowerShell 7+, network access to the VPS.
    Recommendation: keep environment-specific wrappers (deploy-staging.ps1, deploy-prod.ps1, etc.).
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$VpsIp,

    [Parameter(Mandatory=$true)]
    [string]$VpsUser,

    [Parameter(Mandatory=$true)]
    [string]$VpsBasePath,

    [Parameter(Mandatory=$true)]
    [string]$ImageName,

    [string]$ImageTag = "latest",

    [Parameter(Mandatory=$true)]
    [string]$ApiPort,

    [Parameter(Mandatory=$true)]
    [string]$ApiPortHttps,

    [Parameter(Mandatory=$true)]
    [string]$SeqPort,

    [Parameter(Mandatory=$true)]
    [string]$ProjectRoot,

    [Parameter(Mandatory=$true)]
    [string]$DockerfilePath,

    [string]$VpsPassword = ""
)

$ErrorActionPreference = "Stop"

# ============================================================================
# Configure SSH authentication (prompt password once)
# ============================================================================
if (-not $VpsPassword) {
    Write-Host ""
    Write-Host "🔐 SSH Authentication" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    $securePassword = Read-Host "   VPS password (${VpsUser}@${VpsIp})" -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    $VpsPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
}

# Configure sshpass environment variable when available
$env:SSHPASS = $VpsPassword

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Deploy Backend para VPS Contabo" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration:" -ForegroundColor Gray
Write-Host "  • VPS: ${VpsUser}@${VpsIp}" -ForegroundColor White
Write-Host "  • Base path: ${VpsBasePath}" -ForegroundColor White
Write-Host "  • Image: ${ImageName}:${ImageTag}" -ForegroundColor White
Write-Host "  • API ports: ${ApiPort} (HTTP) | ${ApiPortHttps} (HTTPS)" -ForegroundColor White
Write-Host ""

# Define paths
$exportPath = Join-Path $PSScriptRoot "${ImageName}.tar.gz"
$fullImageName = "${ImageName}:${ImageTag}"
$dockerPath = Join-Path $ProjectRoot "docker"
$vpsDockerPath = "${VpsBasePath}/docker"

# ============================================================================
# STEP 1: Build local Docker image
# ============================================================================
Write-Host "[1/7] Build Docker image" -ForegroundColor Cyan
Write-Host ""

$buildNewImage = $false
if (docker images -q $fullImageName 2>$null) {
    Write-Host "✅ Local Docker image found: $fullImageName" -ForegroundColor Green
    Write-Host ""
    $response = Read-Host "Rebuild image from scratch? (y/N)"
    $buildNewImage = $response -match '^[yY]'
} else {
    Write-Host "⚠️  Local Docker image not found: $fullImageName" -ForegroundColor Yellow
    Write-Host "   A fresh image will be created automatically." -ForegroundColor Gray
    $buildNewImage = $true
}

Write-Host ""

if ($buildNewImage) {
    Write-Host "   Building Docker image..." -ForegroundColor Yellow

    try {
        Push-Location $ProjectRoot

        # Build image (without cache to guarantee full rebuild)
        docker rmi $fullImageName -f 2>$null
        docker build --no-cache -t $fullImageName -f $DockerfilePath . 2>&1 | Out-Null

        if ($LASTEXITCODE -ne 0) {
            throw "Docker image build failed"
        }

        Write-Host "   ✅ Build completed!" -ForegroundColor Green
        Write-Host ""
    }
    finally {
        Pop-Location
    }
} else {
    Write-Host "   Using existing image" -ForegroundColor Gray
    Write-Host ""
}

# ============================================================================
# STEP 2: Export Docker image
# ============================================================================
Write-Host "[2/7] Export Docker image" -ForegroundColor Cyan
Write-Host ""

# Remove previous bundle if present
if (Test-Path $exportPath) {
    Remove-Item $exportPath -Force
}

# Export to .tar first
$tarPath = $exportPath -replace '\.gz$', ''
docker save -o $tarPath $fullImageName 2>&1 | Out-Null

if ($LASTEXITCODE -ne 0) {
    throw "Failed to export Docker image"
}

# Compress with PowerShell
$tarFileStream = [System.IO.File]::OpenRead($tarPath)
$gzipFileStream = [System.IO.File]::Create($exportPath)
$gzipStream = New-Object System.IO.Compression.GZipStream($gzipFileStream, [System.IO.Compression.CompressionMode]::Compress)
$tarFileStream.CopyTo($gzipStream)
$gzipStream.Close()
$tarFileStream.Close()
$gzipFileStream.Close()

# Remove intermediate .tar
Remove-Item $tarPath -Force

$fileSize = (Get-Item $exportPath).Length / 1MB
Write-Host "   ✅ Exported bundle size: $([math]::Round($fileSize, 2)) MB" -ForegroundColor Green
Write-Host ""

# ============================================================================
# STEP 3: Clean VPS (optional)
# ============================================================================
Write-Host "[3/7] Clean VPS" -ForegroundColor Cyan
Write-Host ""
Write-Host "   This step will:" -ForegroundColor Yellow
Write-Host "   • Stop all containers (docker compose down)" -ForegroundColor Yellow
Write-Host "   • Remove volumes/data (-v)" -ForegroundColor Yellow
Write-Host ""
$cleanVps = $false
$response = Read-Host "   Do you want to CLEAN the VPS? (y/N)"
$cleanVps = $response -match '^[yY]'
Write-Host ""

if ($cleanVps) {
    Write-Host "   Cleaning VPS..." -ForegroundColor Yellow

    $cleanCmd = "cd ${vpsDockerPath} && docker compose down -v 2>&1 && echo '✅ VPS cleaned'"

    $sshArgsClean = @(
        "-o", "StrictHostKeyChecking=no",
        "${VpsUser}@${VpsIp}",
        $cleanCmd
    )

    & ssh @sshArgsClean 2>&1 | Select-String -Pattern "✅" -SimpleMatch

    if ($LASTEXITCODE -ne 0) {
        Write-Host "   ⚠️ Warning: VPS folder may not exist yet" -ForegroundColor Yellow
    } else {
        Write-Host "   ✅ VPS cleaned!" -ForegroundColor Green
    }
    Write-Host ""
} else {
    Write-Host "   Skipping cleanup" -ForegroundColor Gray
    Write-Host ""
}

# ============================================================================
# STEP 4: Re-upload docker folder
# ============================================================================
Write-Host "[4/7] Re-upload docker/ folder" -ForegroundColor Cyan
Write-Host ""

$resendDockerFolder = $false

if ($cleanVps) {
    # If the VPS was cleaned we must upload docker/ again (no prompt)
    Write-Host "   ⚠️  VPS was cleaned – docker/ will be uploaded automatically" -ForegroundColor Yellow
    Write-Host ""
    $resendDockerFolder = $true
} else {
    # Otherwise, ask if we should re-upload configuration assets
    Write-Host "   This step will:" -ForegroundColor Yellow
    Write-Host "   • Recreate ${vpsDockerPath}/ on the VPS" -ForegroundColor Yellow
    Write-Host "   • Upload ALL configuration files" -ForegroundColor Yellow
    Write-Host "   • Include: docker-compose*.yaml, .env, env/, otel-collector/, rabbitmq/, etc." -ForegroundColor Yellow
    Write-Host ""
    $response = Read-Host "   Re-upload docker/ folder? (y/N)"
    $resendDockerFolder = $response -match '^[yY]'
    Write-Host ""
}

if ($resendDockerFolder) {
    Write-Host "   Uploading docker/ folder..." -ForegroundColor Yellow

    if (-not (Test-Path $dockerPath)) {
        throw "docker/ folder not found: $dockerPath"
    }

    # Preview everything that will be uploaded
    Write-Host ""
    Write-Host "   📦 docker/ content scheduled for upload:" -ForegroundColor Cyan
    Write-Host "   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray

    # Enumerate files and folders
    $allItems = Get-ChildItem -Path $dockerPath -Recurse -Force | Sort-Object FullName
    $files = $allItems | Where-Object { -not $_.PSIsContainer }
    $folders = $allItems | Where-Object { $_.PSIsContainer }

    Write-Host "   📁 Folders ($($folders.Count)):" -ForegroundColor Yellow
    foreach ($folder in $folders) {
        $relativePath = $folder.FullName.Substring($dockerPath.Length).TrimStart('\')
        Write-Host "      └─ $relativePath" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "   📄 Files ($($files.Count)):" -ForegroundColor Yellow
    foreach ($file in $files) {
        $relativePath = $file.FullName.Substring($dockerPath.Length).TrimStart('\')
        $sizeKB = [math]::Round($file.Length / 1KB, 2)
        $sizeDisplay = if ($sizeKB -lt 1) { "$($file.Length) bytes" } else { "$sizeKB KB" }

        # Highlight critical files (skip root .env for security)
        $icon = "   "
        $color = "Gray"

        # Skip root .env from logs for security reasons
        if ($relativePath -eq ".env") {
            continue
        }

        if ($relativePath -like "*.env") {
            $icon = "🔑 "
            $color = "Gray"
        } elseif ($relativePath -like "docker-compose*.yaml") {
            $icon = "🐳 "
            $color = "Cyan"
        } elseif ($relativePath -like "*.json") {
            $icon = "⚙️  "
            $color = "Yellow"
        }

        Write-Host "      $icon$relativePath" -ForegroundColor $color -NoNewline
        Write-Host " ($sizeDisplay)" -ForegroundColor DarkGray
    }

    Write-Host "   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    Write-Host ""

    # Check critical files
    $criticalFiles = @(".env", "docker-compose.yaml", "docker-compose.deploy.yaml")
    $missingCritical = @()
    foreach ($criticalFile in $criticalFiles) {
        $fullPath = Join-Path $dockerPath $criticalFile
        if (-not (Test-Path $fullPath)) {
            $missingCritical += $criticalFile
        }
    }

    if ($missingCritical.Count -gt 0) {
        Write-Host "   ⚠️  WARNING: Critical files missing:" -ForegroundColor Red
        foreach ($missing in $missingCritical) {
            Write-Host "      ❌ $missing" -ForegroundColor Red
        }
        Write-Host ""
        $response = Read-Host "   Continue anyway? (y/N)"
        if ($response -notmatch '^[yY]') {
            throw "Deployment cancelled by user (critical files missing)"
        }
    }

    Write-Host ""

    # Criar estrutura no VPS
    $createDirsCmd = "mkdir -p ${VpsBasePath} && rm -rf ${vpsDockerPath} && mkdir -p ${vpsDockerPath}"

    $sshArgsDirs = @(
        "-o", "StrictHostKeyChecking=no",
        "${VpsUser}@${VpsIp}",
        $createDirsCmd
    )

    & ssh @sshArgsDirs 2>&1 | Out-Null

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to prepare directory structure on VPS"
    }

    # Use recursive SCP to transfer everything (including hidden files)
    Push-Location $dockerPath

    $scpArgsRecursive = @(
        "-o", "StrictHostKeyChecking=no",
        "-r",
        ".",
        "${VpsUser}@${VpsIp}:${vpsDockerPath}/"
    )

    & scp @scpArgsRecursive 2>&1 | Out-Null

    Pop-Location

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to upload docker/ folder"
    }

    # Verificar se .env foi enviado
    $checkEnvCmd = "[ -f ${vpsDockerPath}/.env ] && echo '✅ .env OK' || echo '❌ .env MISSING'"

    $sshArgsCheckEnv = @(
        "-o", "StrictHostKeyChecking=no",
        "${VpsUser}@${VpsIp}",
        $checkEnvCmd
    )

    $envCheck = & ssh @sshArgsCheckEnv 2>&1
    Write-Host "   $envCheck" -ForegroundColor $(if($envCheck -match '✅'){'Green'}else{'Red'})

    # Renomear docker-compose.deploy.yaml para docker-compose.yaml
    $renameCmd = "cd ${vpsDockerPath} && [ -f docker-compose.deploy.yaml ] && cp docker-compose.deploy.yaml docker-compose.yaml"

    $sshArgsRename = @(
        "-o", "StrictHostKeyChecking=no",
        "${VpsUser}@${VpsIp}",
        $renameCmd
    )

    & ssh @sshArgsRename 2>&1 | Out-Null

    Write-Host "   ✅ docker/ folder uploaded!" -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host "   Skipping docker/ upload" -ForegroundColor Gray
    Write-Host ""
}

# ============================================================================
# STEP 5: Upload image bundle to VPS
# ============================================================================
Write-Host "[5/7] Upload image to VPS" -ForegroundColor Cyan
Write-Host ""

$scpArgs = @(
    "-o", "StrictHostKeyChecking=no",
    $exportPath,
    "${VpsUser}@${VpsIp}:${VpsBasePath}/${ImageName}.tar.gz"
)

& scp @scpArgs 2>&1 | Out-Null

if ($LASTEXITCODE -ne 0) {
    throw "Failed to transfer image bundle to VPS"
}

Write-Host "   ✅ Image bundle uploaded!" -ForegroundColor Green
Write-Host ""

# ============================================================================
# STEP 6: Load image into remote Docker engine
# ============================================================================
Write-Host "[6/7] Load image into Docker" -ForegroundColor Cyan
Write-Host ""

$loadCmd = "gunzip -c ${VpsBasePath}/${ImageName}.tar.gz | docker load && rm ${VpsBasePath}/${ImageName}.tar.gz"

$sshArgs = @(
    "-o", "StrictHostKeyChecking=no",
    "${VpsUser}@${VpsIp}",
    $loadCmd
)

& ssh @sshArgs 2>&1 | Select-String -Pattern "Loaded image" -SimpleMatch

if ($LASTEXITCODE -ne 0) {
    throw "Failed to load Docker image on VPS"
}

Write-Host "   ✅ Image loaded!" -ForegroundColor Green
Write-Host ""

# ============================================================================
# STEP 7: Run docker compose deployment
# ============================================================================
Write-Host "[7/7] Execute deployment" -ForegroundColor Cyan
Write-Host ""

$deployCmd = @"
cd ${vpsDockerPath} && \
docker compose down 2>&1 && \
docker compose up -d 2>&1 && \
echo '' && \
echo '========================================' && \
echo '  Container Status' && \
echo '========================================' && \
docker compose ps && \
echo '' && \
echo '========================================' && \
echo '  Access URLs' && \
echo '========================================' && \
echo 'API (HTTP): http://${VpsIp}:${ApiPort}' && \
echo 'API (HTTPS): https://${VpsIp}:${ApiPortHttps}/swagger/index.html' && \
echo 'Health: http://${VpsIp}:${ApiPort}/health' && \
echo 'Seq (Logs): http://${VpsIp}:${SeqPort}' && \
echo '========================================' && \
echo '' && \
echo 'Latest API logs (tail 10):' && \
docker compose logs --tail=10 api
"@

$sshArgs4 = @(
    "-o", "StrictHostKeyChecking=no",
    "${VpsUser}@${VpsIp}",
    $deployCmd
)

& ssh @sshArgs4

if ($LASTEXITCODE -ne 0) {
    throw "Failed to execute docker compose on VPS"
}

# ============================================================================
# Local cleanup
# ============================================================================
Write-Host ""
Write-Host "Removing temporary artifacts..." -ForegroundColor Gray
if (Test-Path $exportPath) {
    Remove-Item $exportPath -Force
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  ✅ DEPLOYMENT COMPLETED SUCCESSFULLY!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Access URLs:" -ForegroundColor Cyan
Write-Host "  • API (HTTP): http://${VpsIp}:${ApiPort}" -ForegroundColor White
Write-Host "  • API (HTTPS): https://${VpsIp}:${ApiPortHttps}/swagger/index.html" -ForegroundColor White
Write-Host "  • Health: http://${VpsIp}:${ApiPort}/health" -ForegroundColor White
Write-Host "  • Seq (Logs): http://${VpsIp}:${SeqPort}" -ForegroundColor White
Write-Host ""
Write-Host "Useful SSH commands:" -ForegroundColor Cyan
Write-Host "  • ssh ${VpsUser}@${VpsIp}" -ForegroundColor White
Write-Host "  • ssh ${VpsUser}@${VpsIp} 'cd ${vpsDockerPath} && docker compose logs -f api'" -ForegroundColor White
Write-Host "  • ssh ${VpsUser}@${VpsIp} 'cd ${vpsDockerPath} && docker compose restart api'" -ForegroundColor White
Write-Host ""
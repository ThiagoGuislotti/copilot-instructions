<#
.SYNOPSIS
    Deploys a .NET backend container image to a Contabo VPS over SSH/SCP.

.DESCRIPTION
    Provides an interactive, reusable deployment workflow with explicit parameters
    and step-by-step confirmations. The script is designed to be generic so it can
    be wrapped by project-specific deploy scripts.

    Main capabilities:
    - Required deployment parameters (no hardcoded infrastructure values).
    - One-time SSH password prompt reused across SSH/SCP calls.
    - Optional local image rebuild.
    - Docker image export to `.tar.gz`.
    - Optional VPS cleanup (`docker compose down -v`).
    - Optional/full resend of the `docker/` configuration folder.
    - Image transfer, load, and `docker compose up -d` execution.
    - Final access URLs and useful SSH commands summary.

    Deployment process (7 steps):
    1. Build Docker image (optional rebuild prompt).
    2. Export image as `.tar.gz`.
    3. Clean VPS (optional).
    4. Resend `docker/` folder (optional, mandatory after cleanup).
    5. Send image to VPS with SCP.
    6. Load image into Docker on VPS.
    7. Execute deployment with `docker compose up -d`.

.PARAMETER VpsIp
    Target VPS IP address.

.PARAMETER VpsUser
    SSH user for the target VPS.

.PARAMETER VpsBasePath
    Base path on VPS where deployment assets are stored.

.PARAMETER ImageName
    Docker image name to deploy.

.PARAMETER ImageTag
    Docker image tag. Defaults to `latest`.

.PARAMETER ApiPort
    Public HTTP port exposed by the API on VPS.

.PARAMETER ApiPortHttps
    Public HTTPS port exposed by the API on VPS.

.PARAMETER SeqPort
    Public port used by Seq logs UI on VPS.

.PARAMETER ProjectRoot
    Local project root path containing `docker/` and source context for build.

.PARAMETER DockerfilePath
    Local Dockerfile path used for image build.

.PARAMETER VpsPassword
    Optional secure password. If omitted, the script prompts interactively.

.EXAMPLE
    $params = @{
        VpsIp = "38.242.232.14"
        VpsUser = "root"
        VpsBasePath = "/root/my-app"
        ImageName = "my-app-api"
        ApiPort = "5000"
        ApiPortHttps = "5001"
        SeqPort = "8082"
        ProjectRoot = $PSScriptRoot
        DockerfilePath = ".\src\API\Dockerfile"
    }
    & .\deploy-backend-to-vps.ps1 @params

.EXAMPLE
    .\deploy-backend-to-vps.ps1 `
        -VpsIp "38.242.232.14" `
        -VpsUser "root" `
        -VpsBasePath "/root/my-app" `
        -ImageName "my-app-api" `
        -ApiPort "5000" `
        -ApiPortHttps "5001" `
        -SeqPort "8082" `
        -ProjectRoot "C:\Projects\MyApp" `
        -DockerfilePath "C:\Projects\MyApp\src\API\Dockerfile"

.NOTES
    Version: 1.0
    Requirements:
    - Docker Desktop installed and running locally.
    - SSH/SCP available in PATH.
    - SSH access configured for the VPS.
    - `docker/` structure and valid Dockerfile in the project.

    Recommendation:
    Create and use a project-specific wrapper script to avoid repeatedly typing
    all infrastructure parameters.
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
    
    [SecureString]$VpsPassword
)

$ErrorActionPreference = "Stop"

$script:ConsoleStylePath = Join-Path $PSScriptRoot '..\common\console-style.ps1'
if (-not (Test-Path -LiteralPath $script:ConsoleStylePath -PathType Leaf)) {
    $script:ConsoleStylePath = Join-Path $PSScriptRoot '..\..\common\console-style.ps1'
}
if (Test-Path -LiteralPath $script:ConsoleStylePath -PathType Leaf) {
    . $script:ConsoleStylePath
}

# ============================================================================
# Configure SSH authentication (prompt password only once)
# ============================================================================
$plainPassword = $null

if ($VpsPassword) {
    # Convert SecureString to plain text
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($VpsPassword)
    $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
} else {
    # Prompt password interactively
    Write-StyledOutput ""
    Write-StyledOutput "🔐 SSH Authentication"
    Write-StyledOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    $securePassword = Read-Host "   VPS password (${VpsUser}@${VpsIp})" -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
}

# Configure environment variable for sshpass (if available)
$env:SSHPASS = $plainPassword

Write-StyledOutput ""
Write-StyledOutput "========================================"
Write-StyledOutput "  Backend Deploy to Contabo VPS"
Write-StyledOutput "========================================"
Write-StyledOutput ""
Write-StyledOutput "Settings:"
Write-StyledOutput "  • VPS: ${VpsUser}@${VpsIp}"
Write-StyledOutput "  • Base Path: ${VpsBasePath}"
Write-StyledOutput "  • Image: ${ImageName}:${ImageTag}"
Write-StyledOutput "  • API Port: ${ApiPort} (HTTP) | ${ApiPortHttps} (HTTPS)"
Write-StyledOutput ""

# Define paths
$exportPath = Join-Path $PSScriptRoot "${ImageName}.tar.gz"
$fullImageName = "${ImageName}:${ImageTag}"
$dockerPath = Join-Path $ProjectRoot "docker"
$vpsDockerPath = "${VpsBasePath}/docker"

# ============================================================================
# STEP 1: Build Docker image locally
# ============================================================================
Write-StyledOutput "[1/7] Build Docker image"
Write-StyledOutput ""

$buildNewImage = $false
$imageExists = docker images -q $fullImageName 2>$null
if ($imageExists) {
    Write-StyledOutput "✅ Local Docker image found: $fullImageName"
    Write-StyledOutput ""
    $response = Read-Host "Do you want to build a NEW image? (y/N)"
    $buildNewImage = $response -match '^[yY]'
} else {
    Write-StyledOutput "⚠️  Local Docker image NOT found: $fullImageName"
    Write-StyledOutput "   A new image will be created automatically."
    $buildNewImage = $true
}

Write-StyledOutput ""

if ($buildNewImage) {
    Write-StyledOutput "   Building image..."

    try {
        Push-Location $ProjectRoot
        
        # Build image (no cache to guarantee full rebuild)
        Write-StyledOutput "   🛠️  Removing old image (if any)..."
        docker rmi $fullImageName -f 2>$null
        
        Write-StyledOutput "   👷 Building Docker image..."
        Write-StyledOutput "   (Please wait, this may take a few minutes)"
        
        docker build --no-cache -t $fullImageName -f $DockerfilePath . 2>&1 | ForEach-Object {
            if ($_ -match "Step \d+/\d+|Successfully built|Successfully tagged") {
                Write-StyledOutput "   $_"
            }
        }
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to build Docker image"
        }
        
        Write-StyledOutput "   ✅ Build completed!"
        Write-StyledOutput ""
    }
    finally {
        Pop-Location
    }
} else {
    Write-StyledOutput "   Using existing image"
    Write-StyledOutput ""
}

# ============================================================================
# STEP 2: Export image to file
# ============================================================================
Write-StyledOutput "[2/7] Export Docker image"
Write-StyledOutput ""

# Remove old file if it exists
if (Test-Path $exportPath) {
    Remove-Item $exportPath -Force
}

# Export to .tar first
$tarPath = $exportPath -replace '\.gz$', ''
Write-StyledOutput "   📦 Exporting Docker image to .tar..."
Write-StyledOutput "   (Please wait, this may take a few seconds)"

$saveOutput = docker save -o $tarPath $fullImageName 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-StyledOutput "   ❌ Error: $saveOutput"
    throw "Failed to export Docker image"
}

# Compress with PowerShell
Write-StyledOutput "   🗜️  Compressing .tar file to .tar.gz..."
$tarFileStream = [System.IO.File]::OpenRead($tarPath)
$gzipFileStream = [System.IO.File]::Create($exportPath)
$gzipStream = New-Object System.IO.Compression.GZipStream($gzipFileStream, [System.IO.Compression.CompressionMode]::Compress)
$tarFileStream.CopyTo($gzipStream)
$gzipStream.Close()
$tarFileStream.Close()
$gzipFileStream.Close()

# Remove original .tar
Remove-Item $tarPath -Force

$fileSize = (Get-Item $exportPath).Length / 1MB
Write-StyledOutput "   ✅ Exported: $([math]::Round($fileSize, 2)) MB"
Write-StyledOutput ""

# ============================================================================
# STEP 3: Clean VPS
# ============================================================================
Write-StyledOutput "[3/7] Clean VPS"
Write-StyledOutput ""
Write-StyledOutput "   This operation will:"
Write-StyledOutput "   • Stop all containers (docker compose down)"
Write-StyledOutput "   • Remove volumes and data (-v)"
Write-StyledOutput ""
$cleanVps = $false
$response = Read-Host "   Do you want to CLEAN the VPS? (y/N)"
$cleanVps = $response -match '^[yY]'
Write-StyledOutput ""

if ($cleanVps) {
    Write-StyledOutput "   Cleaning VPS..."
    
    $cleanCmd = "cd ${vpsDockerPath} && docker compose down -v 2>&1 && echo '✅ VPS cleaned'"
    
    $sshArgsClean = @(
        "-o", "StrictHostKeyChecking=no",
        "${VpsUser}@${VpsIp}",
        $cleanCmd
    )
    
    Write-StyledOutput "   🧹 Running docker compose down -v..."
    
    $cleanOutput = & ssh @sshArgsClean 2>&1
    $cleanOutput | ForEach-Object {
        if ($_ -match "Stopping|Removing|✅") {
            Write-StyledOutput "   $_"
        }
    }
    
    if ($LASTEXITCODE -ne 0) {
        Write-StyledOutput "   ⚠️ Warning: VPS may not exist or an error occurred"
    } else {
        Write-StyledOutput "   ✅ VPS cleaned!"
    }
    Write-StyledOutput ""
} else {
    Write-StyledOutput "   Skipping cleanup"
    Write-StyledOutput ""
}

# ============================================================================
# STEP 4: Resend docker folder
# ============================================================================
Write-StyledOutput "[4/7] Resend docker/ folder"
Write-StyledOutput ""

$resendDockerFolder = $false

if ($cleanVps) {
    # If VPS was cleaned, MUST resend docker folder (no prompt)
    Write-StyledOutput "   ⚠️  VPS was cleaned - docker/ folder WILL be resent automatically"
    Write-StyledOutput ""
    $resendDockerFolder = $true
} else {
    # If not cleaned, ask whether to resend
    Write-StyledOutput "   This operation will:"
    Write-StyledOutput "   • Recreate ${vpsDockerPath}/ folder on the VPS"
    Write-StyledOutput "   • Send ALL configuration files"
    Write-StyledOutput "   • Include: docker-compose*.yaml, .env, env/, otel-collector/, rabbitmq/, etc"
    Write-StyledOutput ""
    $response = Read-Host "   Do you want to RESEND docker/ folder? (y/N)"
    $resendDockerFolder = $response -match '^[yY]'
    Write-StyledOutput ""
}

if ($resendDockerFolder) {
    Write-StyledOutput "   Resending docker/ folder..."
    
    if (-not (Test-Path $dockerPath)) {
        throw "docker/ folder not found: $dockerPath"
    }
    
    # List everything that will be sent
    Write-StyledOutput ""
    Write-StyledOutput "   📦 Content to be sent from docker/:"
    Write-StyledOutput "   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # List files and folders recursively
    $allItems = Get-ChildItem -Path $dockerPath -Recurse -Force | Sort-Object FullName
    $files = $allItems | Where-Object { -not $_.PSIsContainer }
    $folders = $allItems | Where-Object { $_.PSIsContainer }
    
    Write-StyledOutput "   📁 Folders ($($folders.Count)):"
    foreach ($folder in $folders) {
        $relativePath = $folder.FullName.Substring($dockerPath.Length).TrimStart('\')
        Write-StyledOutput "      └─ $relativePath"
    }
    
    Write-StyledOutput ""
    Write-StyledOutput "   📄 Files ($($files.Count)):"
    foreach ($file in $files) {
        $relativePath = $file.FullName.Substring($dockerPath.Length).TrimStart('\')
        $sizeKB = [math]::Round($file.Length / 1KB, 2)
        $sizeDisplay = if ($sizeKB -lt 1) { "$($file.Length) bytes" } else { "$sizeKB KB" }
        
        # Highlight critical files (except .env - do not print for security)
        $icon = "   "
        
        # Do not print .env in logs for security
        if ($relativePath -eq ".env") {
            continue
        }
        
        if ($relativePath -like "*.env") {
            $icon = "🔑 "
        } elseif ($relativePath -like "docker-compose*.yaml") {
            $icon = "🐳 "
        } elseif ($relativePath -like "*.json") {
            $icon = "⚙️  "
        }
        
        Write-StyledOutput "      $icon$relativePath"
        Write-StyledOutput " ($sizeDisplay)"
    }
    
    Write-StyledOutput "   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Write-StyledOutput ""
    
    # Verify critical files
    $criticalFiles = @(".env", "docker-compose.yaml", "docker-compose.deploy.yaml")
    $missingCritical = @()
    foreach ($criticalFile in $criticalFiles) {
        $fullPath = Join-Path $dockerPath $criticalFile
        if (-not (Test-Path $fullPath)) {
            $missingCritical += $criticalFile
        }
    }
    
    if ($missingCritical.Count -gt 0) {
        Write-StyledOutput "   ⚠️  WARNING: Missing critical files:"
        foreach ($missing in $missingCritical) {
            Write-StyledOutput "      ❌ $missing"
        }
        Write-StyledOutput ""
        $response = Read-Host "   Continue anyway? (y/N)"
        if ($response -notmatch '^[yY]') {
            throw "Deploy canceled by user (missing critical files)"
        }
    }
    
    Write-StyledOutput ""
    
    # Create structure on VPS
    $createDirsCmd = "mkdir -p ${VpsBasePath} && rm -rf ${vpsDockerPath} && mkdir -p ${vpsDockerPath}"
    
    $sshArgsDirs = @(
        "-o", "StrictHostKeyChecking=no",
        "${VpsUser}@${VpsIp}",
        $createDirsCmd
    )
    
    Write-StyledOutput "   📁 Creating directory structure on VPS..."
    $dirOutput = & ssh @sshArgsDirs 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-StyledOutput "   ❌ Error: $dirOutput"
        throw "Failed to create directory structure on VPS"
    } else {
        Write-StyledOutput "   ✅ Directories created!"
    }
    
    # Use recursive SCP to send EVERYTHING (including hidden files)
    Push-Location $dockerPath
    
    $scpArgsRecursive = @(
        "-o", "StrictHostKeyChecking=no",
        "-r",
        ".",
        "${VpsUser}@${VpsIp}:${vpsDockerPath}/"
    )
    
    Write-StyledOutput "   📤 Sending files from docker/ folder..."
    Write-StyledOutput "   (Enter password when prompted)"
    Write-StyledOutput ""
    
    $scpStartTime = Get-Date
    & scp @scpArgsRecursive 2>&1 | ForEach-Object {
        $currentLine = $_
        if ($currentLine -match "Authenticated|Sending|100%") {
            Write-StyledOutput "   $currentLine"
        }
    }
    
    Pop-Location
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to send docker/ folder"
    }
    
    $scpEndTime = Get-Date
    $scpDuration = ($scpEndTime - $scpStartTime).TotalSeconds
    Write-StyledOutput ""
    Write-StyledOutput "   ⏱️  Transfer time: $([math]::Round($scpDuration, 1))s"
    
    # Verify whether .env was sent
    $checkEnvCmd = "[ -f ${vpsDockerPath}/.env ] && echo '✅ .env OK' || echo '❌ .env MISSING'"
    
    $sshArgsCheckEnv = @(
        "-o", "StrictHostKeyChecking=no",
        "${VpsUser}@${VpsIp}",
        $checkEnvCmd
    )
    
    $envCheck = & ssh @sshArgsCheckEnv 2>&1
    Write-StyledOutput "   $envCheck"
    
    # Rename docker-compose.deploy.yaml to docker-compose.yaml
    $renameCmd = "cd ${vpsDockerPath} && [ -f docker-compose.deploy.yaml ] && cp docker-compose.deploy.yaml docker-compose.yaml"
    
    $sshArgsRename = @(
        "-o", "StrictHostKeyChecking=no",
        "${VpsUser}@${VpsIp}",
        $renameCmd
    )
    
    $renameOutput = & ssh @sshArgsRename 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-StyledOutput "   ⚠️  Warning while renaming docker-compose: $renameOutput"
    }
    
    Write-StyledOutput "   ✅ docker/ folder sent!"
    Write-StyledOutput ""
} else {
    Write-StyledOutput "   Skipping resend"
    Write-StyledOutput ""
}

# ============================================================================
# STEP 5: Send image to VPS
# ============================================================================
Write-StyledOutput "[5/7] Send image to VPS"
Write-StyledOutput ""

$scpArgs = @(
    "-o", "StrictHostKeyChecking=no",
    $exportPath,
    "${VpsUser}@${VpsIp}:${VpsBasePath}/${ImageName}.tar.gz"
)

Write-StyledOutput "   📤 Sending Docker image (${ImageName}.tar.gz)..."
$imageSize = (Get-Item $exportPath).Length / 1MB
Write-StyledOutput "   Size: $([math]::Round($imageSize, 2)) MB"
Write-StyledOutput "   (Enter password when prompted)"
Write-StyledOutput ""

$scpStartTime = Get-Date
& scp @scpArgs 2>&1 | ForEach-Object {
    $currentLine = $_
    # Show feedback after authentication
    if ($currentLine -match "Authenticated|Sending|100%|ETA") {
        Write-StyledOutput "   $currentLine"
    }
}

if ($LASTEXITCODE -ne 0) {
    throw "Failed to send file to VPS"
}

$scpEndTime = Get-Date
$scpDuration = ($scpEndTime - $scpStartTime).TotalSeconds
Write-StyledOutput ""
Write-StyledOutput "   ⏱️  Transfer time: $([math]::Round($scpDuration, 1))s"

Write-StyledOutput "   ✅ Image sent!"
Write-StyledOutput ""

# ============================================================================
# STEP 6: Load image into VPS Docker
# ============================================================================
Write-StyledOutput "[6/7] Load image into Docker"
Write-StyledOutput ""

$loadCmd = "gunzip -c ${VpsBasePath}/${ImageName}.tar.gz | docker load && rm ${VpsBasePath}/${ImageName}.tar.gz"

$sshArgs = @(
    "-o", "StrictHostKeyChecking=no",
    "${VpsUser}@${VpsIp}",
    $loadCmd
)

Write-StyledOutput "   🐋 Decompressing and loading image into Docker..."
Write-StyledOutput "   (Please wait, this may take a few seconds)"

$loadOutput = & ssh @sshArgs 2>&1
$loadOutput | Where-Object { $_ -match "Loaded image" } | ForEach-Object {
    Write-StyledOutput "   $_"
}

if ($LASTEXITCODE -ne 0) {
    Write-StyledOutput "   ❌ Error: $loadOutput"
    throw "Failed to load image on VPS"
}

Write-StyledOutput "   ✅ Image loaded!"
Write-StyledOutput ""

# ============================================================================
# STEP 7: Execute deploy
# ============================================================================
Write-StyledOutput "[7/7] Execute deploy"
Write-StyledOutput ""

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
echo 'API logs (last 10 lines):' && \
docker compose logs --tail=10 api
"@

$sshArgs4 = @(
    "-o", "StrictHostKeyChecking=no",
    "${VpsUser}@${VpsIp}",
    $deployCmd
)

Write-StyledOutput "   🚀 Running docker compose up -d..."
Write-StyledOutput ""

$deployOutput = & ssh @sshArgs4 2>&1
$deployOutput | ForEach-Object {
    Write-StyledOutput $_
}

if ($LASTEXITCODE -ne 0) {
    Write-StyledOutput ""
    Write-StyledOutput "   ❌ Failed to execute deploy on VPS"
    throw "Failed to execute deploy on VPS"
}

# ============================================================================
# Local cleanup
# ============================================================================
Write-StyledOutput ""
Write-StyledOutput "Cleaning temporary file..."
if (Test-Path $exportPath) {
    Remove-Item $exportPath -Force
}

Write-StyledOutput ""
Write-StyledOutput "========================================"
Write-StyledOutput "  ✅ DEPLOY COMPLETED SUCCESSFULLY!"
Write-StyledOutput "========================================"
Write-StyledOutput ""
Write-StyledOutput "Access URLs:"
Write-StyledOutput "  • API (HTTP): http://${VpsIp}:${ApiPort}"
Write-StyledOutput "  • API (HTTPS): https://${VpsIp}:${ApiPortHttps}/swagger/index.html"
Write-StyledOutput "  • Health: http://${VpsIp}:${ApiPort}/health"
Write-StyledOutput "  • Seq (Logs): http://${VpsIp}:${SeqPort}"
Write-StyledOutput ""
Write-StyledOutput "Useful SSH commands:"
Write-StyledOutput "  • ssh ${VpsUser}@${VpsIp}"
Write-StyledOutput "  • ssh ${VpsUser}@${VpsIp} 'cd ${vpsDockerPath} && docker compose logs -f api'"
Write-StyledOutput "  • ssh ${VpsUser}@${VpsIp} 'cd ${vpsDockerPath} && docker compose restart api'"
Write-StyledOutput ""
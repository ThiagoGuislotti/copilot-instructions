################################################################################
# Deploy Backend para VPS Contabo
# 
# Script GENÉRICO para deploy de aplicações backend .NET em VPS Contabo
# 
# ⚙️ CARACTERÍSTICAS:
# • Parâmetros obrigatórios (não hardcoded)
# • Perguntas contextuais em cada etapa
# • Deploy interativo com confirmações
# • Suporte a múltiplos projetos/ambientes
# • Cópia recursiva de configurações Docker
# 
# 🔄 PROCESSO (7 ETAPAS):
# [1/7] Build da imagem Docker (pergunta se quer rebuild)
# [2/7] Exportar imagem como .tar.gz (compressão automática)
# [3/7] Limpar VPS (pergunta se quer docker compose down -v)
# [4/7] Reenviar pasta docker/ (pergunta se quer reenviar configs)
# [5/7] Enviar imagem para VPS (via SCP)
# [6/7] Carregar imagem no Docker (importação)
# [7/7] Executar deploy (docker compose up -d)
#
# 📋 REQUISITOS:
# • Docker Desktop instalado e rodando
# • SSH/SCP disponíveis no PATH
# • Acesso SSH configurado ao VPS
# • Estrutura docker/ no projeto
# • Dockerfile válido no projeto
#
# 🚀 USO:
#
# Este script NÃO deve ser chamado diretamente.
# Crie um wrapper script para seu projeto específico.
#
# EXEMPLO DE WRAPPER (deploy-meu-app.ps1):
# -----------------------------------------------
# $params = @{
#     VpsIp = "38.242.232.14"
#     VpsUser = "root"
#     VpsBasePath = "/root/meu-app"
#     ImageName = "meu-app-api"
#     ApiPort = "5000"
#     ApiPortHttps = "5001"
#     SeqPort = "8082"
#     ProjectRoot = $PSScriptRoot
#     DockerfilePath = ".\src\API\Dockerfile"
# }
# & .\deploy-backend-to-vps.ps1 @params
# -----------------------------------------------
#
# Ou chame diretamente (não recomendado):
# .\deploy-backend-to-vps.ps1 `
#     -VpsIp "38.242.232.14" `
#     -VpsUser "root" `
#     -VpsBasePath "/root/meu-app" `
#     -ImageName "meu-app-api" `
#     -ApiPort "5000" `
#     -ApiPortHttps "5001" `
#     -SeqPort "8082" `
#     -ProjectRoot "C:\Projetos\MeuApp" `
#     -DockerfilePath "C:\Projetos\MeuApp\src\API\Dockerfile"
#
# 💡 RECOMENDAÇÃO:
# Use o wrapper específico do seu projeto (ex: deploy-muralha.ps1)
# para evitar digitar todos os parâmetros manualmente.
#
# 📖 MAIS INFORMAÇÕES:
# Consulte README.md e REFACTORING-SUMMARY.md para detalhes
################################################################################

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

# ============================================================================
# Configurar autenticação SSH (pedir senha uma única vez)
# ============================================================================
$plainPassword = $null

if ($VpsPassword) {
    # Converter SecureString para string plana
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($VpsPassword)
    $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
} else {
    # Pedir senha interativamente
    Write-Host ""
    Write-Host "🔐 Autenticação SSH" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    $securePassword = Read-Host "   Senha do VPS (${VpsUser}@${VpsIp})" -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
}

# Configurar variável de ambiente para sshpass (se disponível)
$env:SSHPASS = $plainPassword

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Deploy Backend para VPS Contabo" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configurações:" -ForegroundColor Gray
Write-Host "  • VPS: ${VpsUser}@${VpsIp}" -ForegroundColor White
Write-Host "  • Base Path: ${VpsBasePath}" -ForegroundColor White
Write-Host "  • Imagem: ${ImageName}:${ImageTag}" -ForegroundColor White
Write-Host "  • API Port: ${ApiPort} (HTTP) | ${ApiPortHttps} (HTTPS)" -ForegroundColor White
Write-Host ""

# Definir caminhos
$exportPath = Join-Path $PSScriptRoot "${ImageName}.tar.gz"
$fullImageName = "${ImageName}:${ImageTag}"
$dockerPath = Join-Path $ProjectRoot "docker"
$vpsDockerPath = "${VpsBasePath}/docker"

# ============================================================================
# ETAPA 1: Build da imagem Docker localmente
# ============================================================================
Write-Host "[1/7] Build da imagem Docker" -ForegroundColor Cyan
Write-Host ""

$buildNewImage = $false
$imageExists = docker images -q $fullImageName 2>$null
if ($imageExists) {
    Write-Host "✅ Imagem Docker local encontrada: $fullImageName" -ForegroundColor Green
    Write-Host ""
    $response = Read-Host "Deseja fazer BUILD de uma NOVA imagem? (s/N)"
    $buildNewImage = $response -match '^[sS]'
} else {
    Write-Host "⚠️  Imagem Docker local NÃO encontrada: $fullImageName" -ForegroundColor Yellow
    Write-Host "   Uma nova imagem será criada automaticamente." -ForegroundColor Gray
    $buildNewImage = $true
}

Write-Host ""

if ($buildNewImage) {
    Write-Host "   Fazendo build da imagem..." -ForegroundColor Yellow

    try {
        Push-Location $ProjectRoot
        
        # Build da imagem (sem cache para garantir rebuild completo)
        Write-Host "   🛠️  Removendo imagem antiga (se existir)..." -ForegroundColor Gray
        docker rmi $fullImageName -f 2>$null
        
        Write-Host "   👷 Construindo imagem Docker..." -ForegroundColor Yellow
        Write-Host "   (Aguarde, isso pode levar alguns minutos)" -ForegroundColor Gray
        
        docker build --no-cache -t $fullImageName -f $DockerfilePath . 2>&1 | ForEach-Object {
            if ($_ -match "Step \d+/\d+|Successfully built|Successfully tagged") {
                Write-Host "   $_" -ForegroundColor DarkGray
            }
        }
        
        if ($LASTEXITCODE -ne 0) {
            throw "Falha no build da imagem Docker"
        }
        
        Write-Host "   ✅ Build concluído!" -ForegroundColor Green
        Write-Host ""
    }
    finally {
        Pop-Location
    }
} else {
    Write-Host "   Usando imagem existente" -ForegroundColor Gray
    Write-Host ""
}

# ============================================================================
# ETAPA 2: Exportar imagem como arquivo
# ============================================================================
Write-Host "[2/7] Exportar imagem Docker" -ForegroundColor Cyan
Write-Host ""

# Remover arquivo antigo se existir
if (Test-Path $exportPath) {
    Remove-Item $exportPath -Force
}

# Exportar para .tar primeiro
$tarPath = $exportPath -replace '\.gz$', ''
Write-Host "   📦 Exportando imagem Docker para .tar..." -ForegroundColor Yellow
Write-Host "   (Aguarde, isso pode levar alguns segundos)" -ForegroundColor Gray

$saveOutput = docker save -o $tarPath $fullImageName 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "   ❌ Erro: $saveOutput" -ForegroundColor Red
    throw "Falha ao exportar imagem Docker"
}

# Comprimir com PowerShell
Write-Host "   🗜️  Comprimindo arquivo .tar para .tar.gz..." -ForegroundColor Yellow
$tarFileStream = [System.IO.File]::OpenRead($tarPath)
$gzipFileStream = [System.IO.File]::Create($exportPath)
$gzipStream = New-Object System.IO.Compression.GZipStream($gzipFileStream, [System.IO.Compression.CompressionMode]::Compress)
$tarFileStream.CopyTo($gzipStream)
$gzipStream.Close()
$tarFileStream.Close()
$gzipFileStream.Close()

# Remover .tar original
Remove-Item $tarPath -Force

$fileSize = (Get-Item $exportPath).Length / 1MB
Write-Host "   ✅ Exportado: $([math]::Round($fileSize, 2)) MB" -ForegroundColor Green
Write-Host ""

# ============================================================================
# ETAPA 3: Limpar VPS
# ============================================================================
Write-Host "[3/7] Limpar VPS" -ForegroundColor Cyan
Write-Host ""
Write-Host "   Esta operação irá:" -ForegroundColor Yellow
Write-Host "   • Parar todos os containers (docker compose down)" -ForegroundColor Yellow
Write-Host "   • Remover volumes e dados (-v)" -ForegroundColor Yellow
Write-Host ""
$cleanVps = $false
$response = Read-Host "   Deseja LIMPAR o VPS? (s/N)"
$cleanVps = $response -match '^[sS]'
Write-Host ""

if ($cleanVps) {
    Write-Host "   Limpando VPS..." -ForegroundColor Yellow
    
    $cleanCmd = "cd ${vpsDockerPath} && docker compose down -v 2>&1 && echo '✅ VPS limpo'"
    
    $sshArgsClean = @(
        "-o", "StrictHostKeyChecking=no",
        "${VpsUser}@${VpsIp}",
        $cleanCmd
    )
    
    Write-Host "   🧹 Executando docker compose down -v..." -ForegroundColor Yellow
    
    $cleanOutput = & ssh @sshArgsClean 2>&1
    $cleanOutput | ForEach-Object {
        if ($_ -match "Stopping|Removing|✅") {
            Write-Host "   $_" -ForegroundColor Gray
        }
    }
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "   ⚠️ Aviso: VPS pode não existir ou ocorreu um erro" -ForegroundColor Yellow
    } else {
        Write-Host "   ✅ VPS limpo!" -ForegroundColor Green
    }
    Write-Host ""
} else {
    Write-Host "   Pulando limpeza" -ForegroundColor Gray
    Write-Host ""
}

# ============================================================================
# ETAPA 4: Reenviar pasta docker
# ============================================================================
Write-Host "[4/7] Reenviar pasta docker/" -ForegroundColor Cyan
Write-Host ""

$resendDockerFolder = $false

if ($cleanVps) {
    # Se limpou o VPS, DEVE reenviar a pasta docker (sem perguntar)
    Write-Host "   ⚠️  VPS foi limpo - pasta docker/ SERÁ reenviada automaticamente" -ForegroundColor Yellow
    Write-Host ""
    $resendDockerFolder = $true
} else {
    # Se não limpou, pergunta se quer reenviar
    Write-Host "   Esta operação irá:" -ForegroundColor Yellow
    Write-Host "   • Recriar a pasta ${vpsDockerPath}/ no VPS" -ForegroundColor Yellow
    Write-Host "   • Enviar TODOS os arquivos de configuração" -ForegroundColor Yellow
    Write-Host "   • Incluir: docker-compose*.yaml, .env, env/, otel-collector/, rabbitmq/, etc" -ForegroundColor Yellow
    Write-Host ""
    $response = Read-Host "   Deseja REENVIAR a pasta docker/? (s/N)"
    $resendDockerFolder = $response -match '^[sS]'
    Write-Host ""
}

if ($resendDockerFolder) {
    Write-Host "   Reenviando pasta docker/..." -ForegroundColor Yellow
    
    if (-not (Test-Path $dockerPath)) {
        throw "Pasta docker/ não encontrada: $dockerPath"
    }
    
    # Listar tudo que será enviado
    Write-Host ""
    Write-Host "   📦 Conteúdo que será enviado de docker/:" -ForegroundColor Cyan
    Write-Host "   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    
    # Listar arquivos e pastas recursivamente
    $allItems = Get-ChildItem -Path $dockerPath -Recurse -Force | Sort-Object FullName
    $files = $allItems | Where-Object { -not $_.PSIsContainer }
    $folders = $allItems | Where-Object { $_.PSIsContainer }
    
    Write-Host "   📁 Pastas ($($folders.Count)):" -ForegroundColor Yellow
    foreach ($folder in $folders) {
        $relativePath = $folder.FullName.Substring($dockerPath.Length).TrimStart('\')
        Write-Host "      └─ $relativePath" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "   📄 Arquivos ($($files.Count)):" -ForegroundColor Yellow
    foreach ($file in $files) {
        $relativePath = $file.FullName.Substring($dockerPath.Length).TrimStart('\')
        $sizeKB = [math]::Round($file.Length / 1KB, 2)
        $sizeDisplay = if ($sizeKB -lt 1) { "$($file.Length) bytes" } else { "$sizeKB KB" }
        
        # Destacar arquivos críticos (exceto .env - não mostrar para não expor)
        $icon = "   "
        $color = "Gray"
        
        # Não mostrar .env no log por segurança
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
    
    # Verificar arquivos críticos
    $criticalFiles = @(".env", "docker-compose.yaml", "docker-compose.deploy.yaml")
    $missingCritical = @()
    foreach ($criticalFile in $criticalFiles) {
        $fullPath = Join-Path $dockerPath $criticalFile
        if (-not (Test-Path $fullPath)) {
            $missingCritical += $criticalFile
        }
    }
    
    if ($missingCritical.Count -gt 0) {
        Write-Host "   ⚠️  AVISO: Arquivos críticos ausentes:" -ForegroundColor Red
        foreach ($missing in $missingCritical) {
            Write-Host "      ❌ $missing" -ForegroundColor Red
        }
        Write-Host ""
        $response = Read-Host "   Continuar mesmo assim? (s/N)"
        if ($response -notmatch '^[sS]') {
            throw "Deploy cancelado pelo usuário (arquivos críticos ausentes)"
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
    
    Write-Host "   📁 Criando estrutura de diretórios no VPS..." -ForegroundColor Yellow
    $dirOutput = & ssh @sshArgsDirs 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "   ❌ Erro: $dirOutput" -ForegroundColor Red
        throw "Falha ao criar estrutura de diretórios no VPS"
    } else {
        Write-Host "   ✅ Diretórios criados!" -ForegroundColor Green
    }
    
    # Usar SCP com recursão para enviar TUDO (incluindo arquivos ocultos)
    Push-Location $dockerPath
    
    $scpArgsRecursive = @(
        "-o", "StrictHostKeyChecking=no",
        "-r",
        ".",
        "${VpsUser}@${VpsIp}:${vpsDockerPath}/"
    )
    
    Write-Host "   📤 Enviando arquivos da pasta docker/..." -ForegroundColor Yellow
    Write-Host "   (Digite a senha quando solicitado)" -ForegroundColor Gray
    Write-Host ""
    
    $scpStartTime = Get-Date
    & scp @scpArgsRecursive 2>&1 | ForEach-Object {
        $currentLine = $_
        if ($currentLine -match "Authenticated|Sending|100%") {
            Write-Host "   $currentLine" -ForegroundColor DarkGray
        }
    }
    
    Pop-Location
    
    if ($LASTEXITCODE -ne 0) {
        throw "Falha ao enviar pasta docker/"
    }
    
    $scpEndTime = Get-Date
    $scpDuration = ($scpEndTime - $scpStartTime).TotalSeconds
    Write-Host ""
    Write-Host "   ⏱️  Tempo de transferência: $([math]::Round($scpDuration, 1))s" -ForegroundColor Gray
    
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
    
    $renameOutput = & ssh @sshArgsRename 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "   ⚠️  Aviso ao renomear docker-compose: $renameOutput" -ForegroundColor Yellow
    }
    
    Write-Host "   ✅ Pasta docker/ enviada!" -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host "   Pulando reenvio" -ForegroundColor Gray
    Write-Host ""
}

# ============================================================================
# ETAPA 5: Enviar imagem para VPS
# ============================================================================
Write-Host "[5/7] Enviar imagem para VPS" -ForegroundColor Cyan
Write-Host ""

$scpArgs = @(
    "-o", "StrictHostKeyChecking=no",
    $exportPath,
    "${VpsUser}@${VpsIp}:${VpsBasePath}/${ImageName}.tar.gz"
)

Write-Host "   📤 Enviando imagem Docker (${ImageName}.tar.gz)..." -ForegroundColor Yellow
$imageSize = (Get-Item $exportPath).Length / 1MB
Write-Host "   Tamanho: $([math]::Round($imageSize, 2)) MB" -ForegroundColor Gray
Write-Host "   (Digite a senha quando solicitado)" -ForegroundColor Gray
Write-Host ""

$scpStartTime = Get-Date
& scp @scpArgs 2>&1 | ForEach-Object {
    $currentLine = $_
    # Mostrar feedback após autenticação
    if ($currentLine -match "Authenticated|Sending|100%|ETA") {
        Write-Host "   $currentLine" -ForegroundColor DarkGray
    }
}

if ($LASTEXITCODE -ne 0) {
    throw "Falha ao enviar arquivo para VPS"
}

$scpEndTime = Get-Date
$scpDuration = ($scpEndTime - $scpStartTime).TotalSeconds
Write-Host ""
Write-Host "   ⏱️  Tempo de transferência: $([math]::Round($scpDuration, 1))s" -ForegroundColor Gray

Write-Host "   ✅ Imagem enviada!" -ForegroundColor Green
Write-Host ""

# ============================================================================
# ETAPA 6: Carregar imagem no Docker do VPS
# ============================================================================
Write-Host "[6/7] Carregar imagem no Docker" -ForegroundColor Cyan
Write-Host ""

$loadCmd = "gunzip -c ${VpsBasePath}/${ImageName}.tar.gz | docker load && rm ${VpsBasePath}/${ImageName}.tar.gz"

$sshArgs = @(
    "-o", "StrictHostKeyChecking=no",
    "${VpsUser}@${VpsIp}",
    $loadCmd
)

Write-Host "   🐋 Descomprimindo e carregando imagem no Docker..." -ForegroundColor Yellow
Write-Host "   (Aguarde, isso pode levar alguns segundos)" -ForegroundColor Gray

$loadOutput = & ssh @sshArgs 2>&1
$loadOutput | Where-Object { $_ -match "Loaded image" } | ForEach-Object {
    Write-Host "   $_" -ForegroundColor Green
}

if ($LASTEXITCODE -ne 0) {
    Write-Host "   ❌ Erro: $loadOutput" -ForegroundColor Red
    throw "Falha ao carregar imagem no VPS"
}

Write-Host "   ✅ Imagem carregada!" -ForegroundColor Green
Write-Host ""

# ============================================================================
# ETAPA 7: Executar deploy
# ============================================================================
Write-Host "[7/7] Executar deploy" -ForegroundColor Cyan
Write-Host ""

$deployCmd = @"
cd ${vpsDockerPath} && \
docker compose down 2>&1 && \
docker compose up -d 2>&1 && \
echo '' && \
echo '========================================' && \
echo '  Status dos Containers' && \
echo '========================================' && \
docker compose ps && \
echo '' && \
echo '========================================' && \
echo '  URLs de Acesso' && \
echo '========================================' && \
echo 'API (HTTP): http://${VpsIp}:${ApiPort}' && \
echo 'API (HTTPS): https://${VpsIp}:${ApiPortHttps}/swagger/index.html' && \
echo 'Health: http://${VpsIp}:${ApiPort}/health' && \
echo 'Seq (Logs): http://${VpsIp}:${SeqPort}' && \
echo '========================================' && \
echo '' && \
echo 'Logs da API (últimas 10 linhas):' && \
docker compose logs --tail=10 api
"@

$sshArgs4 = @(
    "-o", "StrictHostKeyChecking=no",
    "${VpsUser}@${VpsIp}",
    $deployCmd
)

Write-Host "   🚀 Executando docker compose up -d..." -ForegroundColor Yellow
Write-Host ""

$deployOutput = & ssh @sshArgs4 2>&1
$deployOutput | ForEach-Object {
    Write-Host $_
}

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "   ❌ Falha ao executar deploy no VPS" -ForegroundColor Red
    throw "Falha ao executar deploy no VPS"
}

# ============================================================================
# Limpeza local
# ============================================================================
Write-Host ""
Write-Host "Limpando arquivo temporário..." -ForegroundColor Gray
if (Test-Path $exportPath) {
    Remove-Item $exportPath -Force
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  ✅ DEPLOY CONCLUÍDO COM SUCESSO!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "URLs de Acesso:" -ForegroundColor Cyan
Write-Host "  • API (HTTP): http://${VpsIp}:${ApiPort}" -ForegroundColor White
Write-Host "  • API (HTTPS): https://${VpsIp}:${ApiPortHttps}/swagger/index.html" -ForegroundColor White
Write-Host "  • Health: http://${VpsIp}:${ApiPort}/health" -ForegroundColor White
Write-Host "  • Seq (Logs): http://${VpsIp}:${SeqPort}" -ForegroundColor White
Write-Host ""
Write-Host "Comandos SSH úteis:" -ForegroundColor Cyan
Write-Host "  • ssh ${VpsUser}@${VpsIp}" -ForegroundColor White
Write-Host "  • ssh ${VpsUser}@${VpsIp} 'cd ${vpsDockerPath} && docker compose logs -f api'" -ForegroundColor White
Write-Host "  • ssh ${VpsUser}@${VpsIp} 'cd ${vpsDockerPath} && docker compose restart api'" -ForegroundColor White
Write-Host ""
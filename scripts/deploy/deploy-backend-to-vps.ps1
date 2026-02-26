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

$script:ConsoleStylePath = Join-Path $PSScriptRoot '..\common\console-style.ps1'
if (-not (Test-Path -LiteralPath $script:ConsoleStylePath -PathType Leaf)) {
    $script:ConsoleStylePath = Join-Path $PSScriptRoot '..\..\common\console-style.ps1'
}
if (Test-Path -LiteralPath $script:ConsoleStylePath -PathType Leaf) {
    . $script:ConsoleStylePath
}

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
    Write-StyledOutput ""
    Write-StyledOutput "🔐 Autenticação SSH"
    Write-StyledOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    $securePassword = Read-Host "   Senha do VPS (${VpsUser}@${VpsIp})" -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
}

# Configurar variável de ambiente para sshpass (se disponível)
$env:SSHPASS = $plainPassword

Write-StyledOutput ""
Write-StyledOutput "========================================"
Write-StyledOutput "  Deploy Backend para VPS Contabo"
Write-StyledOutput "========================================"
Write-StyledOutput ""
Write-StyledOutput "Configurações:"
Write-StyledOutput "  • VPS: ${VpsUser}@${VpsIp}"
Write-StyledOutput "  • Base Path: ${VpsBasePath}"
Write-StyledOutput "  • Imagem: ${ImageName}:${ImageTag}"
Write-StyledOutput "  • API Port: ${ApiPort} (HTTP) | ${ApiPortHttps} (HTTPS)"
Write-StyledOutput ""

# Definir caminhos
$exportPath = Join-Path $PSScriptRoot "${ImageName}.tar.gz"
$fullImageName = "${ImageName}:${ImageTag}"
$dockerPath = Join-Path $ProjectRoot "docker"
$vpsDockerPath = "${VpsBasePath}/docker"

# ============================================================================
# ETAPA 1: Build da imagem Docker localmente
# ============================================================================
Write-StyledOutput "[1/7] Build da imagem Docker"
Write-StyledOutput ""

$buildNewImage = $false
$imageExists = docker images -q $fullImageName 2>$null
if ($imageExists) {
    Write-StyledOutput "✅ Imagem Docker local encontrada: $fullImageName"
    Write-StyledOutput ""
    $response = Read-Host "Deseja fazer BUILD de uma NOVA imagem? (s/N)"
    $buildNewImage = $response -match '^[sS]'
} else {
    Write-StyledOutput "⚠️  Imagem Docker local NÃO encontrada: $fullImageName"
    Write-StyledOutput "   Uma nova imagem será criada automaticamente."
    $buildNewImage = $true
}

Write-StyledOutput ""

if ($buildNewImage) {
    Write-StyledOutput "   Fazendo build da imagem..."

    try {
        Push-Location $ProjectRoot
        
        # Build da imagem (sem cache para garantir rebuild completo)
        Write-StyledOutput "   🛠️  Removendo imagem antiga (se existir)..."
        docker rmi $fullImageName -f 2>$null
        
        Write-StyledOutput "   👷 Construindo imagem Docker..."
        Write-StyledOutput "   (Aguarde, isso pode levar alguns minutos)"
        
        docker build --no-cache -t $fullImageName -f $DockerfilePath . 2>&1 | ForEach-Object {
            if ($_ -match "Step \d+/\d+|Successfully built|Successfully tagged") {
                Write-StyledOutput "   $_"
            }
        }
        
        if ($LASTEXITCODE -ne 0) {
            throw "Falha no build da imagem Docker"
        }
        
        Write-StyledOutput "   ✅ Build concluído!"
        Write-StyledOutput ""
    }
    finally {
        Pop-Location
    }
} else {
    Write-StyledOutput "   Usando imagem existente"
    Write-StyledOutput ""
}

# ============================================================================
# ETAPA 2: Exportar imagem como arquivo
# ============================================================================
Write-StyledOutput "[2/7] Exportar imagem Docker"
Write-StyledOutput ""

# Remover arquivo antigo se existir
if (Test-Path $exportPath) {
    Remove-Item $exportPath -Force
}

# Exportar para .tar primeiro
$tarPath = $exportPath -replace '\.gz$', ''
Write-StyledOutput "   📦 Exportando imagem Docker para .tar..."
Write-StyledOutput "   (Aguarde, isso pode levar alguns segundos)"

$saveOutput = docker save -o $tarPath $fullImageName 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-StyledOutput "   ❌ Erro: $saveOutput"
    throw "Falha ao exportar imagem Docker"
}

# Comprimir com PowerShell
Write-StyledOutput "   🗜️  Comprimindo arquivo .tar para .tar.gz..."
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
Write-StyledOutput "   ✅ Exportado: $([math]::Round($fileSize, 2)) MB"
Write-StyledOutput ""

# ============================================================================
# ETAPA 3: Limpar VPS
# ============================================================================
Write-StyledOutput "[3/7] Limpar VPS"
Write-StyledOutput ""
Write-StyledOutput "   Esta operação irá:"
Write-StyledOutput "   • Parar todos os containers (docker compose down)"
Write-StyledOutput "   • Remover volumes e dados (-v)"
Write-StyledOutput ""
$cleanVps = $false
$response = Read-Host "   Deseja LIMPAR o VPS? (s/N)"
$cleanVps = $response -match '^[sS]'
Write-StyledOutput ""

if ($cleanVps) {
    Write-StyledOutput "   Limpando VPS..."
    
    $cleanCmd = "cd ${vpsDockerPath} && docker compose down -v 2>&1 && echo '✅ VPS limpo'"
    
    $sshArgsClean = @(
        "-o", "StrictHostKeyChecking=no",
        "${VpsUser}@${VpsIp}",
        $cleanCmd
    )
    
    Write-StyledOutput "   🧹 Executando docker compose down -v..."
    
    $cleanOutput = & ssh @sshArgsClean 2>&1
    $cleanOutput | ForEach-Object {
        if ($_ -match "Stopping|Removing|✅") {
            Write-StyledOutput "   $_"
        }
    }
    
    if ($LASTEXITCODE -ne 0) {
        Write-StyledOutput "   ⚠️ Aviso: VPS pode não existir ou ocorreu um erro"
    } else {
        Write-StyledOutput "   ✅ VPS limpo!"
    }
    Write-StyledOutput ""
} else {
    Write-StyledOutput "   Pulando limpeza"
    Write-StyledOutput ""
}

# ============================================================================
# ETAPA 4: Reenviar pasta docker
# ============================================================================
Write-StyledOutput "[4/7] Reenviar pasta docker/"
Write-StyledOutput ""

$resendDockerFolder = $false

if ($cleanVps) {
    # Se limpou o VPS, DEVE reenviar a pasta docker (sem perguntar)
    Write-StyledOutput "   ⚠️  VPS foi limpo - pasta docker/ SERÁ reenviada automaticamente"
    Write-StyledOutput ""
    $resendDockerFolder = $true
} else {
    # Se não limpou, pergunta se quer reenviar
    Write-StyledOutput "   Esta operação irá:"
    Write-StyledOutput "   • Recriar a pasta ${vpsDockerPath}/ no VPS"
    Write-StyledOutput "   • Enviar TODOS os arquivos de configuração"
    Write-StyledOutput "   • Incluir: docker-compose*.yaml, .env, env/, otel-collector/, rabbitmq/, etc"
    Write-StyledOutput ""
    $response = Read-Host "   Deseja REENVIAR a pasta docker/? (s/N)"
    $resendDockerFolder = $response -match '^[sS]'
    Write-StyledOutput ""
}

if ($resendDockerFolder) {
    Write-StyledOutput "   Reenviando pasta docker/..."
    
    if (-not (Test-Path $dockerPath)) {
        throw "Pasta docker/ não encontrada: $dockerPath"
    }
    
    # Listar tudo que será enviado
    Write-StyledOutput ""
    Write-StyledOutput "   📦 Conteúdo que será enviado de docker/:"
    Write-StyledOutput "   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Listar arquivos e pastas recursivamente
    $allItems = Get-ChildItem -Path $dockerPath -Recurse -Force | Sort-Object FullName
    $files = $allItems | Where-Object { -not $_.PSIsContainer }
    $folders = $allItems | Where-Object { $_.PSIsContainer }
    
    Write-StyledOutput "   📁 Pastas ($($folders.Count)):"
    foreach ($folder in $folders) {
        $relativePath = $folder.FullName.Substring($dockerPath.Length).TrimStart('\')
        Write-StyledOutput "      └─ $relativePath"
    }
    
    Write-StyledOutput ""
    Write-StyledOutput "   📄 Arquivos ($($files.Count)):"
    foreach ($file in $files) {
        $relativePath = $file.FullName.Substring($dockerPath.Length).TrimStart('\')
        $sizeKB = [math]::Round($file.Length / 1KB, 2)
        $sizeDisplay = if ($sizeKB -lt 1) { "$($file.Length) bytes" } else { "$sizeKB KB" }
        
        # Destacar arquivos críticos (exceto .env - não mostrar para não expor)
        $icon = "   "
        
        # Não mostrar .env no log por segurança
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
        Write-StyledOutput "   ⚠️  AVISO: Arquivos críticos ausentes:"
        foreach ($missing in $missingCritical) {
            Write-StyledOutput "      ❌ $missing"
        }
        Write-StyledOutput ""
        $response = Read-Host "   Continuar mesmo assim? (s/N)"
        if ($response -notmatch '^[sS]') {
            throw "Deploy cancelado pelo usuário (arquivos críticos ausentes)"
        }
    }
    
    Write-StyledOutput ""
    
    # Criar estrutura no VPS
    $createDirsCmd = "mkdir -p ${VpsBasePath} && rm -rf ${vpsDockerPath} && mkdir -p ${vpsDockerPath}"
    
    $sshArgsDirs = @(
        "-o", "StrictHostKeyChecking=no",
        "${VpsUser}@${VpsIp}",
        $createDirsCmd
    )
    
    Write-StyledOutput "   📁 Criando estrutura de diretórios no VPS..."
    $dirOutput = & ssh @sshArgsDirs 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-StyledOutput "   ❌ Erro: $dirOutput"
        throw "Falha ao criar estrutura de diretórios no VPS"
    } else {
        Write-StyledOutput "   ✅ Diretórios criados!"
    }
    
    # Usar SCP com recursão para enviar TUDO (incluindo arquivos ocultos)
    Push-Location $dockerPath
    
    $scpArgsRecursive = @(
        "-o", "StrictHostKeyChecking=no",
        "-r",
        ".",
        "${VpsUser}@${VpsIp}:${vpsDockerPath}/"
    )
    
    Write-StyledOutput "   📤 Enviando arquivos da pasta docker/..."
    Write-StyledOutput "   (Digite a senha quando solicitado)"
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
        throw "Falha ao enviar pasta docker/"
    }
    
    $scpEndTime = Get-Date
    $scpDuration = ($scpEndTime - $scpStartTime).TotalSeconds
    Write-StyledOutput ""
    Write-StyledOutput "   ⏱️  Tempo de transferência: $([math]::Round($scpDuration, 1))s"
    
    # Verificar se .env foi enviado
    $checkEnvCmd = "[ -f ${vpsDockerPath}/.env ] && echo '✅ .env OK' || echo '❌ .env MISSING'"
    
    $sshArgsCheckEnv = @(
        "-o", "StrictHostKeyChecking=no",
        "${VpsUser}@${VpsIp}",
        $checkEnvCmd
    )
    
    $envCheck = & ssh @sshArgsCheckEnv 2>&1
    Write-StyledOutput "   $envCheck"
    
    # Renomear docker-compose.deploy.yaml para docker-compose.yaml
    $renameCmd = "cd ${vpsDockerPath} && [ -f docker-compose.deploy.yaml ] && cp docker-compose.deploy.yaml docker-compose.yaml"
    
    $sshArgsRename = @(
        "-o", "StrictHostKeyChecking=no",
        "${VpsUser}@${VpsIp}",
        $renameCmd
    )
    
    $renameOutput = & ssh @sshArgsRename 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-StyledOutput "   ⚠️  Aviso ao renomear docker-compose: $renameOutput"
    }
    
    Write-StyledOutput "   ✅ Pasta docker/ enviada!"
    Write-StyledOutput ""
} else {
    Write-StyledOutput "   Pulando reenvio"
    Write-StyledOutput ""
}

# ============================================================================
# ETAPA 5: Enviar imagem para VPS
# ============================================================================
Write-StyledOutput "[5/7] Enviar imagem para VPS"
Write-StyledOutput ""

$scpArgs = @(
    "-o", "StrictHostKeyChecking=no",
    $exportPath,
    "${VpsUser}@${VpsIp}:${VpsBasePath}/${ImageName}.tar.gz"
)

Write-StyledOutput "   📤 Enviando imagem Docker (${ImageName}.tar.gz)..."
$imageSize = (Get-Item $exportPath).Length / 1MB
Write-StyledOutput "   Tamanho: $([math]::Round($imageSize, 2)) MB"
Write-StyledOutput "   (Digite a senha quando solicitado)"
Write-StyledOutput ""

$scpStartTime = Get-Date
& scp @scpArgs 2>&1 | ForEach-Object {
    $currentLine = $_
    # Mostrar feedback após autenticação
    if ($currentLine -match "Authenticated|Sending|100%|ETA") {
        Write-StyledOutput "   $currentLine"
    }
}

if ($LASTEXITCODE -ne 0) {
    throw "Falha ao enviar arquivo para VPS"
}

$scpEndTime = Get-Date
$scpDuration = ($scpEndTime - $scpStartTime).TotalSeconds
Write-StyledOutput ""
Write-StyledOutput "   ⏱️  Tempo de transferência: $([math]::Round($scpDuration, 1))s"

Write-StyledOutput "   ✅ Imagem enviada!"
Write-StyledOutput ""

# ============================================================================
# ETAPA 6: Carregar imagem no Docker do VPS
# ============================================================================
Write-StyledOutput "[6/7] Carregar imagem no Docker"
Write-StyledOutput ""

$loadCmd = "gunzip -c ${VpsBasePath}/${ImageName}.tar.gz | docker load && rm ${VpsBasePath}/${ImageName}.tar.gz"

$sshArgs = @(
    "-o", "StrictHostKeyChecking=no",
    "${VpsUser}@${VpsIp}",
    $loadCmd
)

Write-StyledOutput "   🐋 Descomprimindo e carregando imagem no Docker..."
Write-StyledOutput "   (Aguarde, isso pode levar alguns segundos)"

$loadOutput = & ssh @sshArgs 2>&1
$loadOutput | Where-Object { $_ -match "Loaded image" } | ForEach-Object {
    Write-StyledOutput "   $_"
}

if ($LASTEXITCODE -ne 0) {
    Write-StyledOutput "   ❌ Erro: $loadOutput"
    throw "Falha ao carregar imagem no VPS"
}

Write-StyledOutput "   ✅ Imagem carregada!"
Write-StyledOutput ""

# ============================================================================
# ETAPA 7: Executar deploy
# ============================================================================
Write-StyledOutput "[7/7] Executar deploy"
Write-StyledOutput ""

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

Write-StyledOutput "   🚀 Executando docker compose up -d..."
Write-StyledOutput ""

$deployOutput = & ssh @sshArgs4 2>&1
$deployOutput | ForEach-Object {
    Write-StyledOutput $_
}

if ($LASTEXITCODE -ne 0) {
    Write-StyledOutput ""
    Write-StyledOutput "   ❌ Falha ao executar deploy no VPS"
    throw "Falha ao executar deploy no VPS"
}

# ============================================================================
# Limpeza local
# ============================================================================
Write-StyledOutput ""
Write-StyledOutput "Limpando arquivo temporário..."
if (Test-Path $exportPath) {
    Remove-Item $exportPath -Force
}

Write-StyledOutput ""
Write-StyledOutput "========================================"
Write-StyledOutput "  ✅ DEPLOY CONCLUÍDO COM SUCESSO!"
Write-StyledOutput "========================================"
Write-StyledOutput ""
Write-StyledOutput "URLs de Acesso:"
Write-StyledOutput "  • API (HTTP): http://${VpsIp}:${ApiPort}"
Write-StyledOutput "  • API (HTTPS): https://${VpsIp}:${ApiPortHttps}/swagger/index.html"
Write-StyledOutput "  • Health: http://${VpsIp}:${ApiPort}/health"
Write-StyledOutput "  • Seq (Logs): http://${VpsIp}:${SeqPort}"
Write-StyledOutput ""
Write-StyledOutput "Comandos SSH úteis:"
Write-StyledOutput "  • ssh ${VpsUser}@${VpsIp}"
Write-StyledOutput "  • ssh ${VpsUser}@${VpsIp} 'cd ${vpsDockerPath} && docker compose logs -f api'"
Write-StyledOutput "  • ssh ${VpsUser}@${VpsIp} 'cd ${vpsDockerPath} && docker compose restart api'"
Write-StyledOutput ""
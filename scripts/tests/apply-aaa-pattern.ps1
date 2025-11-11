# Script para aplicar comentários AAA nos arquivos de teste pendentes
# Conforme .docs/frontend/aaa-compliance-plan.md

$files = @(
    "frontend/src/shared/tests/unit/adapters/QuasarNotificationAdapter.spec.ts",
    "frontend/src/shared/tests/unit/composables/data/useFilters.spec.ts",
    "frontend/src/shared/tests/unit/composables/services/useNotification.spec.ts",
    "frontend/src/shared/tests/unit/composables/utils/useAsync.spec.ts",
    "frontend/src/shared/tests/unit/services/FilterService.spec.ts",
    "frontend/src/shared/tests/unit/services/NotificationService.spec.ts",
    "frontend/src/shared/tests/unit/utils/async.spec.ts",
    "frontend/src/shared/tests/unit/utils/validators.spec.ts"
)

Write-Host "=== AAA Pattern Application Tool ===" -ForegroundColor Cyan
Write-Host "Este script irá adicionar comentários AAA aos testes pendentes" -ForegroundColor Yellow
Write-Host ""

# Função para processar um arquivo
function Add-AAAComments {
    param (
        [string]$FilePath
    )
    
    if (-not (Test-Path $FilePath)) {
        Write-Host "❌ Arquivo não encontrado: $FilePath" -ForegroundColor Red
        return
    }
    
    Write-Host "📝 Processando: $FilePath" -ForegroundColor Green
    
    $content = Get-Content $FilePath -Raw
    $modified = $false
    
    # Padrão regex para identificar testes sem AAA
    # Procura por it('...', () => { sem comentários AAA logo após
    $pattern = "(?m)(    it\('.*?', \(\) => \{)\s*\n(?!      \/\/ Arrange)"
    
    if ($content -match $pattern) {
        $modified = $true
        
        # Para cada teste encontrado, adiciona comentários AAA
        $content = $content -replace $pattern, "`$1`n      // Arrange`n      // Setup: prepare test data and preconditions`n`n      // Act`n      // Execute: operation being tested`n`n      // Assert`n      // Verify: expected outcome`n"
    }
    
    if ($modified) {
        Set-Content -Path $FilePath -Value $content -NoNewline
        Write-Host "   ✅ Comentários AAA adicionados com sucesso" -ForegroundColor Green
    } else {
        Write-Host "   ℹ️  Nenhuma modificação necessária (AAA já aplicado ou estrutura diferente)" -ForegroundColor Yellow
    }
}

# Processar cada arquivo
foreach ($file in $files) {
    $fullPath = Join-Path $PSScriptRoot ".." $file
    Add-AAAComments -FilePath $fullPath
    Write-Host ""
}

Write-Host "=== Processamento Concluído ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "⚠️ ATENÇÃO: Este script aplicou comentários AAA genéricos." -ForegroundColor Yellow
Write-Host "É necessário revisar manualmente cada teste para:" -ForegroundColor Yellow
Write-Host "  1. Ajustar os comentários para refletir o contexto específico" -ForegroundColor White
Write-Host "  2. Garantir que Arrange/Act/Assert estão corretamente posicionados" -ForegroundColor White
Write-Host "  3. Adicionar notas explicativas para lógica crítica/complexa" -ForegroundColor White
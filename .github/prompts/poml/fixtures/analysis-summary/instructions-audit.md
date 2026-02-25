# Auditoria de Instruções (24-09-2025)

## Resumo Executivo
- Identificadas inconsistências principais entre instruções globais e ferramentas disponíveis.
- Mapeadas referências inexistentes a templates.
- Propostas ações corretivas imediatas e follow-ups.

## Detalhes por Achado

### 1. Obrigatoriedade de Codex CLI
- **Origem:** `prompts/route-instructions.prompt.md` e `instruction-routing.catalog.yml`
- **Problema:** quando regras de execução e roteamento ficam acopladas em um único documento, é comum surgirem instruções inexequíveis (ex.: exigir um runner/CLI não disponível) que conflitam com o ambiente real.
- **Impacto:** conflito operacional recorrente, baixa previsibilidade.
- **Ação sugerida:** manter execução (tools/runner) fora do roteamento; roteador só escolhe contexto mínimo e, quando o ambiente não suportar um fluxo, registrar a decisão no checklist/saída.

### 2. Template inexistente referenciado
- **Origem:** `.github/instructions/dotnet-csharp.instructions.md` (seções Background Services e XML docs)
- **Problema:** referencia `.github/templates/background-service-template.cs`, porém arquivo não existe em `templates/`.
- **Impacto:** gera erros de documentação e quebra fluxo "usar template".
- **Ação sugerida:** criar template correspondente ou ajustar instrução removendo referência/indicando alternativa.

### 3. Sobreposição de regras de estilo POML
- **Origem:** `prompts/poml/prompt-engineering-poml.md` e estilo `prompts/poml/styles/enterprise.poml`
- **Problema:** guia exige separação de responsabilidades e metadados versionados, mas stylesheet atual não declara `meta` nem garante writerOptions JSON válido (usa placeholders `#quot`).
- **Impacto:** incoerência entre guideline e implementação inicial.
- **Ação sugerida:** atualizar stylesheet para JSON apropriado, adicionar metadados e alinhamento com governança de estilos.

## Recomendações Gerais
1. Manter o roteamento determinístico (pontuação + cap) e documentado.
2. Publicar template de background service ou ajustar instrução.
3. Revisar assets POML para aderir ao guia (metadados, guardrails centralizados, JSON válido).

## Ações Realizadas Nesta Iteração
- Adicionado template `.github/templates/background-service-template.cs` eliminando referência órfã.
- Revisado `styles/pt-br-enterprise.poml` com metadados, JSON consistente e guardrails expandidos.

## Pendências
- Confirmar se existem outras referências cruzadas aos templates ausentes após correções.
- Avaliar necessidade de CHANGELOG após ajustes.

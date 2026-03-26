# Auditoria de Instruções (24-09-2025)

## Resumo Executivo
- Identificadas inconsistências principais entre instruções globais e ferramentas disponíveis.
- Mapeadas referências inexistentes a templates.
- Propostas ações corretivas imediatas e follow-ups.

## Detalhes por Achado

### 1. Obrigatoriedade de Codex CLI
- **Origem:** `.github/instructions/ai-orchestration.instructions.md`
- **Problema:** determina uso exclusivo do Codex CLI para toda execução ("Always use Codex CLI"), incluindo comando exemplo com `--dangerously-bypass-approvals-and-sandbox`. Ambiente atual de automação não possui integração nem autorização para esse fluxo e demais instruções (ex.: workflow optimization) assumem edição direta via ferramentas padrão.
- **Impacto:** instrução inexequível → conflito operacional em todas as tarefas.
- **Ação sugerida:** substituir regra por diretriz compatível (e.g., priorizar Codex quando disponível, caso contrário usar ferramentas padrão) ou mover para anexo opcional.

### 2. Template inexistente referenciado
- **Origem:** `.github/instructions/dotnet-csharp.instructions.md` (seções Background Services e XML docs)
- **Problema:** referencia `.github/templates/background-service-template.cs`, porém arquivo não existe em `templates/`.
- **Impacto:** gera erros de documentação e quebra fluxo "usar template".
- **Ação sugerida:** criar template correspondente ou ajustar instrução removendo referência/indicando alternativa.

### 3. Sobreposição de regras de estilo POML
- **Origem:** `.github/prompt-engineering-poml.md` e estilo `styles/pt-br-enterprise.poml`
- **Problema:** guia exige separação de responsabilidades e metadados versionados, mas stylesheet atual não declara `meta` nem garante writerOptions JSON válido (usa placeholders `#quot`).
- **Impacto:** incoerência entre guideline e implementação inicial.
- **Ação sugerida:** atualizar stylesheet para JSON apropriado, adicionar metadados e alinhamento com governança de estilos.

## Recomendações Gerais
1. Revisar `ai-orchestration` para documentar fallback quando Codex não estiver habilitado.
2. Publicar template de background service ou ajustar instrução.
3. Revisar assets POML para aderir ao guia (metadados, guardrails centralizados, JSON válido).

## Ações Realizadas Nesta Iteração
- Atualizada `ai-orchestration.instructions.md` com fallback explícito para ferramentas padrão.
- Adicionado template `.github/templates/background-service-template.cs` eliminando referência órfã.
- Revisado `styles/pt-br-enterprise.poml` com metadados, JSON consistente e guardrails expandidos.

## Pendências
- Confirmar se existem outras referências cruzadas aos templates ausentes após correções.
- Avaliar necessidade de CHANGELOG após ajustes.

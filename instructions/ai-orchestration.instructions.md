---
applyTo: "**/*.*"
---

# AI Orchestration
Codex CLI preferencial quando disponível; mantenha compatibilidade com ferramentas padrão.

# Tool Selection Matrix
Tente Codex CLI primeiro; se não estiver habilitado ou aprovado, utilize ferramentas padrão do workspace mantendo a mesma qualidade.

# Task Analysis
- Possible categories: refactoring|generation|analysis|documentation|bugfix
- Complexity: simple|moderate|complex|very_complex

# Codex CLI Configuration
Quando autorizado, use `codex "task" --dangerously-bypass-approvals-and-sandbox --sandbox workspace-write ;exit`.
Não aguarde input humano; limite máximo de 10 minutos.
Se Codex não estiver acessível, execute as tarefas diretamente (apply_patch, create_file, run in terminal etc.).
Quality requirements baseline: namespace matches folder structure; target frameworks net8.0;net9.0 when applicable; sealed classes when appropriate; full XML docs; clean using statements; no BOM; no trailing empty lines.

# Execution Templates
```bash
# Infra pipeline step (usar Codex quando disponível)
codex "Create Azure DevOps pipeline YAML step for dotnet build and test; matrix net8.0 net9.0; publish test results; fail on low coverage; file path .azure/pipelines/build-test.yml; concise and production-ready" --dangerously-bypass-approvals-and-sandbox --sandbox workspace-write ;exit

# Simple class creation (fallback manual se Codex indisponível)
codex "Create sealed class Utils in NetToolsKit.Core.Utilities namespace; file path src/NetToolsKit.Core/Utilities/Utils.cs; XML docs summary param returns; expression-bodied methods for simple implementations; follow NetToolsKit coding standards; no trailing empty lines" --dangerously-bypass-approvals-and-sandbox --sandbox workspace-write ;exit
```

# Validation Checklist
- Namespace matches folder structure exactly
- No trailing empty lines
- Sealed classes when appropriate
- Complete XML documentation
- Clean and minimal using statements
- NetToolsKit coding standards followed
- Target frameworks net8.0;net9.0 when applicable
- No BOM (UTF-8 without BOM)

# Auto-Correction Protocol
Caso Codex falhe ou não esteja disponível, corrija manualmente usando as ferramentas padrão e atualize instruções se necessário para evitar recorrência.

# Response Template
- TOOL SELECTION Codex CLI (ou ferramentas padrão quando Codex indisponível)
- REASONING descrever por que a ferramenta foi escolhida
- CODEX COMMAND codex "[task]" --dangerously-bypass-approvals-and-sandbox --sandbox workspace-write ;exit (omita quando não usado)
- VALIDATION executar checklist independentemente da ferramenta

# Error Handling
Codex commands must always end with ;exit.
On timeout or invalid output, fix manually and log the failure cause.

# Session Tracking
Format: project|file|component/method|action
```
NetToolsKit.DynamicQuery|QueryBuilder.cs|BuildExpression()|add LINQ optimization
```
---
applyTo: "**/*.*"
---

# AI Orchestration
Single execution via Codex CLI; global instructions.

# Tool Selection Matrix
Always use Codex CLI to execute tasks, regardless of category or complexity.

# Task Analysis
- Possible categories: refactoring|generation|analysis|documentation|bugfix
- Complexity: simple|moderate|complex|very_complex

# Codex CLI Configuration
Command format codex "task description with context and quality requirements" --dangerously-bypass-approvals-and-sandbox --sandbox workspace-write ;exit
Never wait for user input; maximum timeout 10 minutes.
Quality requirements baseline: namespace matches folder structure; target frameworks net8.0;net9.0 when applicable; sealed classes when appropriate; full XML docs; clean using statements; no BOM; no trailing empty lines.

# Execution Templates
```bash
# Infra pipeline step
codex "Create Azure DevOps pipeline YAML step for dotnet build and test; matrix net8.0 net9.0; publish test results; fail on low coverage; file path .azure/pipelines/build-test.yml; concise and production-ready" --dangerously-bypass-approvals-and-sandbox --sandbox workspace-write ;exit

# Simple class creation
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
If Codex output fails validation, fix manually and update instructions to prevent recurrence.

# Response Template
- TOOL SELECTION Codex CLI
- REASONING always Codex CLI
- CODEX COMMAND codex "[task]" --dangerously-bypass-approvals-and-sandbox --sandbox workspace-write ;exit
- VALIDATION run checklist

# Error Handling
Codex commands must always end with ;exit.
On timeout or invalid output, fix manually and log the failure cause.

# Session Tracking
Format: project|file|component/method|action
```
NetToolsKit.DynamicQuery|QueryBuilder.cs|BuildExpression()|add LINQ optimization
```
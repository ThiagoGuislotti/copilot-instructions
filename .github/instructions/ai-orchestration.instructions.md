---
applyTo: "**/*.*"
---
AI Orchestration: intelligent selection between GitHub Copilot current session and Codex CLI; optimized execution by task type; orchestrator-level instruction with global scope justified.

Tool Selection Matrix: 
Copilot when workspace context needed; refactoring across multiple files; understanding project patterns; simple or moderate complexity; real-time interaction required.
Codex CLI when isolated code generation; complex algorithm or data-structure; well-defined requirements; deterministic single-file output.

Task Analysis: 
Categories refactoring|generation|analysis|documentation|bugfix
Complexity simple|moderate|complex|very_complex
Keywords: simple|basic|quick|small → simple; medium|standard|normal → moderate; advanced|sophisticated → complex; architecture|design-pattern|multi-layer → very_complex

Selection Logic: 
IF category=refactoring OR workspace_context_needed THEN TOOL=Copilot confidence=95%
ELSE IF category=generation AND complexity=moderate THEN TOOL=Copilot confidence=85%
ELSE IF category=generation AND complexity=complex AND focused_task AND single_file THEN TOOL=CodexCLI confidence=90% EXECUTE codex with quality requirements ;exit
ELSE TOOL=Copilot confidence=80%
Default TOOL=Copilot confidence=70%

Codex CLI Configuration: 
Command format codex "task description with context and quality requirements" ;exit
Include flags --dangerously-bypass-approvals-and-sandbox and --sandbox workspace-write only when approvals=never AND sandbox=danger-full-access; otherwise omit flags
Flags placement: append flags after the quoted task and before ;exit (e.g., codex "..." --dangerously-bypass-approvals-and-sandbox --sandbox workspace-write ;exit)
Never wait for user input; timeout max 10 minutes
Quality requirements baseline: namespace matches folder structure; target frameworks net8.0;net9.0 when applicable; sealed classes when appropriate; full XML docs; clean using statements; no BOM; no trailing empty lines

Execution Templates: 
Example: infra pipeline step  codex "Create Azure DevOps pipeline YAML step for dotnet build and test; matrix net8.0 net9.0; publish test results; fail on low coverage; file path .azure/pipelines/build-test.yml; concise and production-ready" ;exit
Example: simple class creation → codex "Create sealed class Utils in NetToolsKit.Core.Utilities namespace; file path src/NetToolsKit.Core/Utilities/Utils.cs; XML docs summary param returns; expression-bodied methods for simple implementations; follow NetToolsKit coding standards; no trailing empty lines" ;exit

Validation Checklist: 
Namespace matches folder structure exactly.
No trailing empty lines.
Sealed classes when appropriate.
XML documentation complete.
Using statements clean and minimal.
NetToolsKit coding standards followed.
Target frameworks net8.0;net9.0 when applicable.
No BOM (UTF-8 without BOM).

Auto-Correction Protocol: 
If Codex output fails validation then switch to Copilot; apply corrections using workspace context; update instructions to prevent recurrence.

Response Template: 
TOOL SELECTION [Copilot|Codex CLI] confidence XX%
REASONING short explanation
If Codex CLI then CODEX COMMAND codex "[task]" [flags only if allowed] ;exit
VALIDATION run checklist

Error Handling: 
Codex single command sessions must always end with ;exit
On timeout or invalid output switch to Copilot; apply corrections automatically; log failure cause

Session Tracking: 
Format project|file|component/method|action
Example: NetToolsKit.DynamicQuery|QueryBuilder.cs|BuildExpression()|add LINQ optimization
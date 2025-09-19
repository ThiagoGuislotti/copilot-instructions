---
applyTo: "**/*.*"
---

Task breakdown: split large tasks into manageable steps; avoid hard token limits; split by functional domain when possible.
Prioritization: critical config changes first; core validation logic second; template updates third; docs fourth; validation tests last; respect logical dependencies.
Separation of concerns: keep single instruction files concise; group related files by domain; handle cross-cutting changes by layer (config, validation, templates); implement new features in phases (creation, integration, testing).
Context preservation: include relevant context gathering; avoid repeating already provided information; focus on requested specific changes; use targeted file searches when necessary.
Token efficiency: avoid reproducing entire files; use comments to represent existing code when allowed; focus on minimal diffs; consolidate related changes; separate independent concerns; eliminate redundancies; never repeat provided context; focus exclusively on deltas; minimal examples; prioritize clarity over verbosity.
Workspace awareness: consider current workspace traits; apply appropriate architectural patterns when relevant; keep consistency with existing patterns; adapt approach to present technologies.[]: # ---
Execution style: maximum token efficiency; be concise and direct; avoid verbosity; prioritize actions and code; keep clarity as requirement.
Workflow optimization: cache dependencies; parallel jobs; conditional steps; reusable workflows; matrix builds for multiple target frameworks.
Response structure: use shortest preambles before commands/tools; use minimal plans for non-trivial tasks; avoid unnecessary text; focus on essential output only.
Confirmation: use concise completion cues when appropriate; keep confirmations minimal and aligned with structured answer guidelines.
Context awareness: reference files/paths precisely; include commands only when executing; assume user knowledge of workspace.
Maximum economy: respond with simplest possible form; direct tool calls; minimal explanatory text; prioritize token conservation over elaboration.
Compatibility: respect sandbox and approval policies; align with agent format including minimal preambles and structured answers.
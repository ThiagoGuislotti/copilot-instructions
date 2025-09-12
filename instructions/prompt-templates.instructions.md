---
applyTo: ".github/**"
---
Prompt engineering: specific context before objective; clear actionable requirements; measurable acceptance criteria; well‑defined output.
Chat workflow: open only files relevant to the task; separate threads by context; reference previous answer when asking to continue; request diffs only for direct patches.
Prompt structure: Context (specific file/component) → Objective (what to do) → Requirements (how) → Acceptance criteria (done) → Expected output (result format).
Templates: use .github/templates/ as needed; readme-template.md for READMEs; effort-estimation-poc-mvp-template.md for UCP estimates; changelog-entry-template.md for CHANGELOG entries or instruction feedback; changelog-entry-template.md for .github changes.
Effective example: Context: file src/hooks/useApi.ts lines 10–25. Objective: add exponential retry with jitter. Requirements: keep current interface; configurable timeout; max 3 attempts. Acceptance: existing tests passing; coverage >= 80%. Output: diff of modified function only.
Templates as prompts: use [UPPERCASE] placeholders; include usage context; standardized structure; guiding comments for completion.
Iteration: start with simplest case; refine incrementally; test one hypothesis at a time; document working patterns.
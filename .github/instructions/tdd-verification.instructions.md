---
applyTo: "**/*.{ps1,md,json,jsonc,yml,yaml,cs,csproj,sln,rs,toml,ts,tsx,js,jsx,vue,sql}"
priority: high
---

# TDD And Verification

Use this instruction for code-bearing work and bug fixes that change runtime behavior.

Rules:
- Plan work with explicit validation commands and checkpoints before implementation.
- Prefer red/green style checkpoints when the task changes behavior, tests, or bug outcomes.
- Do not claim completion from implementation alone; completion requires verification evidence.
- Use targeted validation first, then broader repository validation.
- Keep verification commands scoped to the changed area whenever practical.

Planner expectations:
- every code-bearing work item must declare at least one validation command
- every code-bearing work item should declare at least one executable checkpoint
- checkpoints should make expected outcome explicit: `expected-fail`, `expected-pass`, or `expected-verified`

Execution expectations:
- implement the smallest safe change that satisfies the current work item
- preserve or improve testability
- keep feedback loops short

Review expectations:
- reject completion claims that do not have matching validation evidence
- call out missing or weak verification as a real quality issue, not a documentation nit

Exceptions:
- POC, spike, or informal-test work may relax strict red/green discipline only when the user explicitly says so.
- Even in exceptions, targeted verification and honest status reporting remain mandatory.
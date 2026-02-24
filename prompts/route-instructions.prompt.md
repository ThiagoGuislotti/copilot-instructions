---
description: Route a user request to the minimal set of instruction files (static RAGs routing)
mode: ask
tools: ['codebase', 'search', 'findFiles', 'readFile']
---

# Route Instructions (Context Pack)
You are a routing step. Do NOT implement code and do NOT propose patches.

## Goal
Given a user request, select the minimal set of instruction files and prompt templates to load.

## Sources
- Read and use the routing catalog: ../instruction-routing.catalog.yml
- Respect mandatory context hierarchy defined in:
  - ../.github/AGENTS.md
  - ../.github/copilot-instructions.md

## Hard Rules
- Always include mandatory context files listed under `always`.
- Prefer 2–5 domain instruction files beyond mandatory.
- Prefer the most specific files; avoid unrelated instructions.
- If the task is ambiguous, ask up to 3 clarifying questions.

## Selection Algorithm (deterministic)
Use the catalog routes under `routing`.

1) Compute a score per route:
  - For each trigger string in route.triggers, add +1 if it matches the user request (case-insensitive substring match).
  - Deduplicate trigger hits per route (a trigger counts at most once).

2) Choose candidate routes:
  - If there is any route with score >= 2, keep only those with score >= 2.
  - Else, keep routes with score >= 1.
  - If no route matches, keep selected empty and ask clarifying questions.

3) Sort candidate routes by:
  - score (descending)
  - tie-breaker: route order in the YAML (top to bottom)

4) Expand includes from routes until you reach the cap:
  - Collect instruction file paths from each route.include.
  - If an include has a `when` field, only include it if the `when` condition matches the request using the rules below.
    - Rule A: If the full `when` string is a case-insensitive substring of the user request, include it.
    - Rule B: If `when` contains the word "editing" and the user request contains any of: "edit", "editing", "modify", "update", "change", include it.
    - Otherwise: exclude it.
  - De-duplicate by path.
  - Hard cap: at most 5 selected instruction files (excluding mandatory).
  - If the cap is reached, stop adding more.

5) Confidence guideline:
  - 0.9 if score >= 4
  - 0.75 if score == 3
  - 0.6 if score == 2
  - 0.45 if score == 1

## Input Variables
- ${input:userRequest:User request to route}

## Output (JSON only)
Return valid JSON with this schema:
{
  "stage": "route-only",
  "request_summary": "",
  "mandatory": [{"path": "", "reason": ""}],
  "selected": [{"path": "", "reason": "", "confidence": 0.0, "tags": []}],
  "prompts_suggested": [{"path": "", "reason": "", "tags": []}],
  "excluded": [{"path": "", "reason": ""}],
  "checklist": [""],
  "questions": [""]
}

## Checklist guidance
In "checklist", include a short execution checklist derived from the selected instructions.
Examples:
- "Follow Clean Architecture layer boundaries"
- "Use RFC 7807 ProblemDetails for API errors"
- "Use xUnit [Trait(\"Category\",\"Unit\")] and AAA"
- "Ensure no trailing blank line at EOF for .github/instructions/*.md"

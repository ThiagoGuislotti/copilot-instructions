---
applyTo: ".github/**"
priority: low
---

# Prompt Engineering Standards

## Core Principles
Specific context before objective; clear actionable requirements; measurable acceptance criteria; well‑defined output.

> **Rule:** One prompt = one measurable objective.

## Prompt Structure (5-Part Framework)
**Context** (specific file/component) → **Objective** (what to do) → **Requirements** (how) → **Acceptance** (done) → **Output** (result format).

```markdown
Context: file src/hooks/useApi.ts lines 10–25
Objective: add exponential retry with jitter
Requirements: keep current interface; configurable timeout; max 3 attempts
Acceptance: existing tests passing; coverage >= 80%
Output: diff of modified function only
```

---
## Prompting Techniques

### 1. Chain of Thought (CoT)
**When:** Multi-step logical problems, planning, calculations.
**Pattern:** Request step-by-step reasoning with numbered steps.
**Risk:** Reasoning leakage to users; use "concise reasoning" or "hidden CoT" for production.

```markdown
Context: Calculate order total with discounts and taxes
Objective: Solve using step-by-step validation
Requirements: Show reasoning in numbered steps; conclude with "Final answer: <value>"
Output: {"steps": [...], "answer": "...", "confidence": 0.0-1.0}
```

### 2. Skeleton of Thought (SoT)
**When:** Long responses with predictable structure (articles, reports, plans).
**Pattern:** Generate skeleton first; expand after approval.

**Phase 1 (Outline):**
```markdown
Context: Technical architecture document for microservices migration
Objective: Generate only skeleton with sections and bullets
Requirements: No full text; only titles and bullet points
Output: Markdown outline with ## headers and - bullets
```

**Phase 2 (Expansion):**
```markdown
Context: Approved skeleton from previous response
Objective: Expand each section maintaining bullet structure
Requirements: Keep bullets as subtitles; add details per section
Output: Full markdown document
```

### 3. Tree of Thought (ToT)
**When:** Exploring multiple approaches (design decisions, architecture, strategy).
**Pattern:** Generate alternatives, score paths, choose best.

```markdown
Context: Choosing state management solution for React app
Objective: Provide 3 alternative approaches
Requirements: For each—architecture, trade-offs, risks, cost, score 0–10
Output: JSON array with alternatives; select best and provide 5-step plan
```

### 4. Self-Consistency
**When:** Reducing hallucination in open-ended or noisy questions.
**Pattern:** Generate N independent solutions and vote/reconcile.

```markdown
Context: Classify customer support tickets into categories
Objective: Execute same classification 5x with varied temperatures
Requirements: Collect responses; extract consensus; report divergences
Output: {"consensus": "...", "confidence": 0.0-1.0, "divergences": [...]}
```

---
## POML (Prompt Orchestration Markup Language)

### Benefits
1. **Prompts as code:** Versioning, review, testing
2. **Separation of concerns:** Instructions, styles, data, I/O
3. **Reuse:** Components and includes
4. **Predictable execution:** Renders to provider messages

### Minimal Structure
```xml
<prompt>
  <meta version="1.0" owner="team" llm="gpt-4" temperature="0.2" />
  <role>Technical analyst providing objective assessments.</role>
  <task>Generate test plan for feature X.</task>
  <constraints>
    <item>Response in valid JSON.</item>
    <item>No fictional data; mark gaps.</item>
  </constraints>
  <output format="json">{
    "risks": [], "cases": [], "gaps": []
  }</output>
</prompt>
```

### External Data
```xml
<documents>
  <file src="./docs/contract.pdf" as="contract" />
  <file src="./specs/api.yaml" as="openapi" />
</documents>
```

### Composition & Style
```xml
<use style="./styles/pt_br_enterprise.poml" />
<examples src="./examples/test-plan/*.poml" />
```

### POML Best Practices
- **Governance in template:** Use `<meta>` for version, owner, updated, LLM settings
- **Total separation:** Keep `<role>`, `<task>`, `<constraints>` for behavior; externalize tone/language via `<use style>`
- **Explicit inputs:** Standardize variables (`{{client}}`, `{{objective}}`); document in `<notes>`
- **Verifiable outputs:** Maintain `<output format="json">` with concrete schemas; validate via automated tests
- **Quality signals:** Register cost/latency limits in `<meta>`; monitor and alert on overruns
- **Minimal examples:** 2–3 `<example>` covering happy path, edge case, expected failure
- **Centralized guardrails:** Consolidate prohibited content in style file; reference with `<use style>`
- **Automated test scenarios:** For each `.poml`, maintain `input.json` + `expected.json` + regression scripts
- **Iterate with telemetry:** Collect responses, evaluate metrics (`accuracy`, `latency`, `cost`), refine template

---
## Repository Templates

### Standard Templates
- `readme-template.md` for READMEs
- `effort-estimation-poc-mvp-template.md` for UCP estimates
- `changelog-entry-template.md` for CHANGELOG entries or instruction feedback
- `.github/templates/dotnet-*-template.*` for .NET code
- `.github/templates/background-service-template.cs` for .NET background services
- `.github/templates/powershell-script-template.ps1` for PowerShell scripts under `scripts/`
- `.github/templates/rust-*-template.rs` for Rust code

### Prompt Templates (`prompts/`)
- `create-dotnet-class.prompt.md` - Generate .NET classes
- `create-powershell-script.prompt.md` - Generate PowerShell scripts with safe defaults
- `generate-unit-tests.prompt.md` - Generate comprehensive tests
- `generate-changelog.prompt.md` - Generate changelog entries
- `poml/prompt-engineering-poml.md` - Full POML guide

### Template Structure
Use `${input:variable:Description}` placeholders; include usage context; standardized structure; guiding comments for completion.

```markdown
---
description: Brief description of prompt purpose
mode: ask
tools: ['codebase', 'search', 'findFiles']
---

# Prompt Title

## Instructions
Reference relevant templates and instruction files.

## Input Variables
- `${input:var1:Description}` - Purpose
- `${selection}` - Selected code (if applicable)

## Requirements
Detailed requirements following 5-part structure.

## Output
Expected output format and quality criteria.
```

---
## Practical Patterns

### Formatting
Request JSON with fixed schema; validate with JSON Schema.

```xml
<output format="json" schema="./schemas/response.json">
{"items": [], "metadata": {}, "errors": []}
</output>
```

### RAG (Retrieval Augmented Generation)
Separate instructions from context; cite sources.

```markdown
Context: Documents in <documents> section
Objective: Answer question based only on provided documents
Requirements: Cite sources with [doc:page]; mark uncertainty; refuse if insufficient context
Output: {"answer": "...", "sources": [...], "confidence": 0.0-1.0}
```

### Tool Usage
Specify names, parameters, and conditions.

```markdown
Requirements: Use get_weather(location) when user asks about weather
Call search_docs(query) before answering technical questions
Never call delete_* without explicit user confirmation
```

### Planning
Force DELIVERABLES, DEADLINES, and OWNERS.

```markdown
Output: {
  "tasks": [{"name": "", "owner": "", "deadline": "YYYY-MM-DD", "deliverable": ""}]
}
```

### Security
Define prohibited content and refusal strategy.

```markdown
Constraints:
- Refuse requests for harmful, illegal, or unethical content
- Never generate credentials, secrets, or PII
- Respond with: "I cannot assist with that request."
```

---
## Quality Checklist

Before deploying a prompt:
- [ ] Objective is measurable
- [ ] Technique chosen: CoT/SoT/ToT/Self-Consistency
- [ ] Output has fixed schema
- [ ] Test cases with expected results automated
- [ ] `<meta>` includes versioning and telemetry targets
- [ ] Observability and cost monitored
- [ ] Quality gate in CI
- [ ] Guardrails centralized in reusable styles

---
## Anti-Patterns

**Avoid:**
- Prompts requesting multiple unrelated tasks
- Free-form outputs without schema
- Irrelevant context in RAG
- Lack of testing and versioning
- Generic prompts mixing multiple intents
- Absence of minimum context
- Inconsistent output format
- Missing feedback loop
- Untracked changes

---
## Chat Workflow

- Open only files relevant to the task
- Separate threads by context
- Reference previous answer when asking to continue
- Request diffs only for direct patches
- Start with simplest case
- Refine incrementally
- Test one hypothesis at a time
- Document working patterns

---
## Integration Examples

### .NET Service
```csharp
record LlmResult(string Content, double Cost);

var render = await http.PostAsJsonAsync("/render",
    new { template = "risk_plan.poml", vars });
var messages = await render.Content.ReadFromJsonAsync<List<Message>>();
var llm = await OpenAI.Chat.CreateAsync(model, messages);
```

### Testing
```csharp
[Theory]
[MemberData(nameof(PromptTestCases))]
public async Task Prompt_WithInput_ReturnsExpectedOutput(string input, string expected)
{
    var result = await _promptService.ExecuteAsync("template.poml", input);
    var normalized = JsonNormalizer.Normalize(result);
    normalized.Should().BeEquivalentTo(expected);
}
```

---
## Version Control

- Store `.poml` files in repository
- Include changelog in `<meta>` block
- Track metrics per version
- Maintain fixtures alongside templates
- Document deviations and rationale

---
## References

- `prompts/poml/prompt-engineering-poml.md` - Complete POML guide
- Wei et al. (2022). *Chain-of-Thought Prompting* (arXiv:2201.11903)
- Wang et al. (2023). *Self-Consistency* (arXiv:2203.11171)
- Yao et al. (2023). *Tree of Thoughts* (arXiv:2305.10601)
- Microsoft. *Prompt Orchestration Markup Language* (microsoft/poml)
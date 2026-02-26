<!-- # Prompt Engineering for Developers + POML (Practical Guide) -->

## 1) Objective
Deliver a straightforward usage manual for designing, versioning, and operating prompts in products. Focus: CoT, SoT, ToT, Self-Consistency, and POML.

---
## 2) Quick Fundamentals
- **Role**: Define who the model "is".
- **Task**: Describe what to produce.
- **Constraints**: Limits, formats, policies.
- **I/O**: Structured inputs + deterministic output (JSON, Markdown, table).
- **Guardrails**: Instructions for refusal and uncertainty tracking.
- **Evaluation**: Criteria, test cases, simple metrics (accuracy, coverage, cost, latency).

> Rule: one prompt = one measurable objective.

---
## 3) Essential Prompt Types

### 3.1 Chain of Thought (CoT)
**When to use**: Problems with multiple logical steps, math, planning.
**Risk**: Reasoning leakage to users. Use "concise reasoning" or "hidden CoT" versions when it shouldn't appear.
**Template**
```
You are a methodical problem solver. Solve step by step, validating each stage.
Input: <problem>
Output: Explain reasoning in numbered steps and conclude with "Final answer: <...>".
```
**Tip**: Limit number of steps.

### 3.2 Skeleton of Thought (SoT)
**When to use**: Long responses with predictable structure (articles, reports, plans).
**Idea**: Generate skeleton first; expand after approval.
**Template (phase 1)**
```
Generate only a skeleton with sections and bullets for <task>. No full text.
```
**Template (phase 2)**
```
Expand each skeleton section maintaining bullets as subtitles.
```

### 3.3 Tree of Thought (ToT)
**When to use**: Exploration with multiple routes (puzzles, API design, strategies).
**Idea**: Branch hypotheses, score paths, and choose the best.
**Template**
```
List 3 alternative approaches for <task>.
For each approach: steps, risks, cost, and score 0–10.
Choose the best and detail the plan.
```

### 3.4 Self-Consistency
**When to use**: Reduce hallucination in open-ended or noisy questions.
**Idea**: Generate N independent solutions and vote/reconcile.
**Orchestrator template**
```
Execute the same base prompt 5x with different seeds/temperatures.
Collect responses, extract consensus, and report divergences.
```
**Final output**: response + consensus summary + uncertain items.

---
## 4) Practical Patterns
- **Formatting**: Request JSON with fixed schema. Validate with JSON Schema.
- **Retrieval (RAG)**: Separate instructions from context. Cite sources.
- **Tools**: Specify names, parameters, and usage conditions.
- **Plans**: Enforce DELIVERABLES, DEADLINES, and OWNERS in lists.
- **Security**: Define prohibited content and refusal strategy.

---
## 5) POML in 12 Lines
**What it is**: Prompt Orchestration Markup Language. XML-like language to declare prompts, styles, examples, and external inputs.
**Benefits**
1. Prompts as code: versioning, review, and testing.
2. Separation of concerns: instructions, styles, data, and I/O.
3. Reuse: components and includes.
4. Predictable execution: renders to provider messages.

### 5.1 Minimal Structure
```xml
<prompt>
  <role>Objective technical analyst.</role>
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

### 5.2 Including External Data
```xml
<documents>
  <file src="./docs/contract.pdf" as="contract" />
  <file src="./specs/api.yaml" as="openapi" />
</documents>
```
The POML engine injects contents into context with labels.

### 5.3 Compositions and Style
```xml
<use style="./styles/enterprise.poml" />
<examples src="./examples/test-plan/*.poml" />
```

---
## 6) How POML Helps Daily Work
- **Multi-client**: One instruction base, style files per client.
- **RAG**: Standard templates for queries, citations, and evidence formatting.
- **Testing**: input/expected test cases stored alongside templates.
- **Observability**: Template + rendered vars logs for auditing.

---
## 7) Integration in Your Stack (.NET)

### Thin Rendering Service
1. Store `.poml` in repository.
2. Node/Python service exposes `/render` that receives `{ template, vars }` and returns `messages`.
3. .NET API injects data, calls `/render`, sends `messages` to provider (OpenAI/Azure OpenAI).

**C# skeleton**
```csharp
record LlmResult(string Content, double Cost);

var render = await http.PostAsJsonAsync("/render", new { template = "risk_plan.poml", vars });
var messages = await render.Content.ReadFromJsonAsync<List<Message>>();
var llm = await OpenAI.Chat.CreateAsync(model, messages);
```

### CLI in Build/CI
- Run a CLI that transforms `.poml` → `.json` and packages with the application.
- Advantage: No extra service in production.

### Testing
- Store `fixtures/input.json` and `expected.json` per template.
- .NET test compares normalized JSON and allows tolerances (e.g., array order).

---
## 8) Ready-to-Use Snippets

### Short CoT
```
Act as a verifier. Solve in 3–6 steps and return:
{"steps": [..], "answer": "...", "confidence": 0–1}
```

### SoT for Technical Articles
```
Generate only the skeleton (titles and bullets) for <topic>. Nothing beyond the skeleton.
```

### ToT for Architecture Decision
```
Provide 3 alternatives. For each: architecture, trade-offs, risks, cost, score 0–10.
Choose one and give a 5-step plan.
```

### Self-Consistency (orchestrator)
```
Execute the base prompt 5x (varied temperatures). Do majority-vote on "answer" field and report divergences.
```

### POML + Fixed JSON
```xml
<prompt>
  <role>Analyst.</role>
  <task>Classify tickets into categories.</task>
  <output format="json">{"items": [{"id":"","category":"","rationale":""}]}</output>
  <constraints>
    <item>Use only: bug, feature, question.</item>
  </constraints>
  <examples>
    <example input="Id=42; Text='Error 500'" output='{ "items":[{"id":"42","category":"bug","rationale":"HTTP 500"}] }' />
  </examples>
</prompt>
```

---
## 9) Best Practices
- Always structured inputs (JSON or named fields).
- Constrain style: "concise", "no opinion", "no rhetoric".
- Prompt version and changelog.
- Cost/latency tables in monitoring.
- Feedback loop: human-labeled samples and regression tests.

### 9.1) POML Adjustments for Maximum Efficiency
- **Bring governance to the template**: Use `<meta>` to version (`version`, `owner`, `updated`) and document decisions (`llm`, `temperature`, `maxTokens`). This enables auditing why a prompt changed.
- **Total separation of responsibilities**: Keep `<role>`, `<task>`, and `<constraints>` focused on behavior, and externalize tone/language via `<use style="..." />`. Avoid repeating style instructions across multiple prompts.
- **Define explicit inputs**: Standardize variables (`{{client}}`, `{{objective}}`) and register them in comments or auxiliary `<notes>` block; combine with validated input JSON. Prompt failures often come from gaps or ambiguous names.
- **Specify verifiable outputs**: Maintain `<output format="json">` with concrete schemas and validate via automated tests before pushing changes.
- **Instrument quality signals**: Register expected cost/latency limits in `<meta>` and expose via monitoring; generate alerts when a run exceeds predicted values.
- **Include minimally sufficient examples**: Instead of extensive lists, maintain 2–3 `<example>` covering happy path, edge case, and expected failure. This speeds up model's mental parsing.
- **Standardize refusal messages**: Centralize guardrails (prohibited content, legal limits) in a style file and just point with `<use style>`. Reduces divergences between prompts.
- **Automate test scenarios**: For each `.poml`, maintain fixtures containing `input.json`, `expected.json`, and regression scripts (see section 7). Recurring errors come from absence of regression testing.
- **Iterate with real telemetry**: Collect model responses, evaluate against metrics (`accuracy`, `latency`, `cost`), and feed back into template. Failures persist when improvements stay on paper.

| Common Failure (Medium POML review) | Recommended Fix |
| --- | --- |
| Generic prompts mixing tasks | Separate each intent into a focused `.poml` and use orchestrator to combine outputs. |
| Absence of minimum context | Link `<documents>` or inject mandatory variables; add asserts that refuse if empty. |
| Inconsistent output | Define schema in `<output>` and normalize with post-processing and tests. |
| Lack of feedback loop | Register metrics in `<meta>` + dashboards, and run periodic evaluations. |
| Untracked changes | Version via Git + changelog in `<meta>` block with reason for change. |

## 10) Anti-Patterns
- Prompts that request everything at once.
- Free-form outputs without schema.
- Irrelevant context in RAG.
- Lack of testing and versioning.

---
## 11) Delivery Checklist
- [ ] Measurable objective
- [ ] Type chosen: CoT/SoT/ToT/Self-Consistency
- [ ] Output with fixed schema
- [ ] Test cases + automated expected results
- [ ] `<meta>` with versioning and target telemetry
- [ ] Observability and cost monitored
- [ ] Quality gate in CI
- [ ] Guardrails centralized in reusable styles

---
## 12) Next Steps
1. Select a use case from your product and create the first `.poml`.
2. Implement rendering via thin service or CLI.
3. Add 10 test cases and metrics to dashboard.
4. Scale to multiple clients with stylesheets.
5. Version internal library in `prompts/poml/`, maintaining reusable styles and regression fixtures per template.

---
## 13) Sources and Reading
- Wei et al. (2022). *Chain-of-Thought Prompting Elicits Reasoning in Large Language Models* (arXiv:2201.11903).
- Wang et al. (2023). *Self-Consistency Improves Chain of Thought Reasoning in Language Models* (arXiv:2203.11171).
- Yao et al. (2023). *Tree of Thoughts: Deliberate Problem Solving with Large Language Models* (arXiv:2305.10601).
- *Skeleton-of-Thought: Large Language Models Can Do Parallel Decoding* (arXiv, 2023).
- Microsoft. *Prompt Orchestration Markup Language (POML)* – official repository (microsoft/poml) and documentation.
- Microsoft Tech Community. *Introducing POML: prompts as code*.
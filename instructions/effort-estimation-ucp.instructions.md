---
applyTo: "docs/**/effort-estimation*"
---

# Template Usage
Use template .github/templates/effort-estimation-poc-mvp-template.md as base.
UCP (Use Case Points): requirements analysis and effort estimation for POC/MVP.
Goal: define scope and estimate effort to evolve from POC to MVP using UCP.

# POC→MVP Flow
Context, problem, personas, goals, metrics.

# POC Design
- Prove technical/value hypothesis
- Minimal scope, short timeline, clear success criteria
- Outputs with minimal backlog, technical design, test plan and result
```typescript
// POC design (front): hooks/composables first; minimal UI; loading/error/success states
const { data, loading, error } = useApi('/endpoint');
if (loading) return <Spinner />;
if (error) return <Error message={error.message} />;
```

```csharp
// POC design (back): stub endpoints; ProblemDetails; structured logs
[HttpGet]
public async Task<ActionResult<OrderDto>> GetOrder(Guid id)
{
    // Stub implementation with structured logging
    _logger.LogInformation("Getting order {OrderId}", id);
    return new OrderDto { Id = id, Status = "Pending" };
}
```

# POC Validation
Test with 3–5 users; measure success rate, time and errors; gate go/adjust/drop.

# MVP Requirements
- Value‑based backlog (RICE/ICE)
- NFRs security/performance/availability/A11Y/i18n/privacy
- Data with schema/migrations/idempotent seed/indexes
- API with versioned contracts, rate limiting, idempotency
- Quality with unit (xUnit), integration (NUnit), critical E2E and CI/CD

# Delivery
Roadmap and sprints; risks and mitigations; dependencies; rollout/rollback; metrics (DAU, task success, P95 latency, errors).

# UCP Formulas
- UUCP = UAW + UUCW + UCRW
- UCP = UUCP × TCF × EF
- Base effort (hours) = UCP × hours_per_point
- Extra QA = Base effort × TESTS_PERCENT
- Total effort = Base effort + Extra QA

# UAW (Actors)
Count UIs and services per actor; weight f in {1.00 low, 1.25 medium, 1.50 high, 1.75 critical}; n = uiCount + serviceCount; normalization: n=1 -> 1; 2..3 -> 1 + 0.34×(n-1); 4..7 -> 2 + 0.25×(n-4); >=8 -> 3 + 0.10×(n-8); UAW = sum(normalization × f).

# UUCW (Use Cases)
For each case n = transactions + entities; apply same normalization; UUCW = sum(normalization).

# UCRW (Technical Refactors)
Entries with type/scope/risk and weights 1..4; sum = type + scope + risk; classify interactions and normalize step 0.10; UCRW = sum(final_normalization).

# Technical and Environmental Factors
- TCF (technical factor): TFactor = sum(weight_i × level_i); TCF = 0.6 + 0.01 × TFactor
- EF (environmental factor): EFactor = sum(weight_i × level_i); EF = 1.4 − 0.03 × EFactor

# Defaults
- Hours_per_point: low 20; medium 28; high 36
- TESTS_PERCENT: 0.30
- TCF_BASE: 0.6, TCF_MULT: 0.01
- EF_BASE: 1.4, EF_MULT: −0.03

# Calculation Rules
Keep two decimals on intermediates; UCP rounded to two decimals; total effort includes extra QA (TESTS_PERCENT).

# Outputs
- POC outputs: hypotheses, criteria, design, backlog, test plan, result
- MVP outputs: prioritized backlog, NFRs, roadmap, metrics, rollout plan
# Effort Estimation — POC → MVP Template using UCP

**Project**: [PROJECT_NAME]
**Date**: [DATE_YYYY_MM_DD]
**Responsible**: [RESPONSIBLE_NAME]

Method reference: Use Case Points (UCP). Refer to docs/effortEstimationUsingUCP/useCasePoints.pdf if available in repo.

## 1) Context and objectives
- Context: [BUSINESS_CONTEXT]
- Problem: [PROBLEM_TO_SOLVE]
- Personas: [TARGET_USERS]
- Goals (expected results): [EXPECTED_GOALS]
- Metrics (KPIs/OKRs): [SUCCESS_METRICS]

## 2) POC (Proof of Concept)
- POC objective (technical/value hypothesis to prove): [POC_HYPOTHESIS]
- Minimum scope and deadline: [SCOPE_DEADLINE]
- Success criteria (objective, clear and measurable): [SUCCESS_CRITERIA]
- POC design:
  - Front: hooks/composables first; minimal UI; loading/error/success states.
  - Back: stub endpoints; ProblemDetails; structured logs.
  - Data: mocks/fixtures.
  - Observability: traceId/correlationId; simple metrics.
- Test plan (scenarios, data, acceptance criteria): [TEST_PLAN]
- Result (evidence): [POC_RESULT]
- Gate (proceed/adjust/discard) and justification: [GATE_DECISION]

## 3) POC validation
- Test users (3–5) and profile: [TEST_USERS]
- Measures: success rate, time per task, main errors: [VALIDATION_METRICS]
- Learnings and proposed adjustments: [LEARNINGS]

## 4) MVP (First usable version)
- Backlog prioritized by value (RICE/ICE) and MVP scope: [MVP_BACKLOG]
- NFRs (with targets):
  - Security: [SECURITY_REQUIREMENTS]
  - Performance (ex.: P95 < 300ms): [PERFORMANCE_REQUIREMENTS]
  - Availability (ex.: 99.9%): [AVAILABILITY_REQUIREMENTS]
  - A11Y (WCAG AA): [ACCESSIBILITY_REQUIREMENTS]
  - i18n: [I18N_REQUIREMENTS]
  - Privacy/Compliance: [PRIVACY_REQUIREMENTS]
- Data: schema, migrations, idempotent seed, indexes: [DATA_STRATEGY]
- API: versioned contracts, rate limiting, idempotency: [API_STRATEGY]
- Quality: unit tests (xUnit), integration (NUnit), critical E2E, CI/CD: [QUALITY_STRATEGY]

## 5) Delivery
- Roadmap and sprints: [ROADMAP_SPRINTS]
- Risks and mitigation: [RISKS_MITIGATION]
- Dependencies: [DEPENDENCIES]
- Rollout and rollback: [DEPLOY_STRATEGY]
- Success metrics (DAU, task success, P95 latency, errors): [PRODUCTION_METRICS]

---

## 6) Estimation by Use Case Points (UCP)

**Selected complexity**: [LOW_MEDIUM_HIGH_COMPLEXITY]

Formulas:
- UUCP = UAW + UUCW + UCRW
- UCP = UUCP × TCF × EF
- Base effort (hours) = UCP × hours_per_point
- Additional QA = Base effort × TESTS_PERCENT
- Total effort = Base effort + Additional QA

Default parameters:
- hours_per_point: low 20 | medium 28 | high 36 (select)
- TESTS_PERCENT: 0.30
- TCF = 0.6 + 0.01 × TFactor
- EF = 1.4 − 0.03 × EFactor
- Level per factor: scale 0..5 (0=none, 5=very high)

### 6.1) UAW — Actors
For each actor: n = qtdInterfaces + qtdServices; normalization:
- n=1 → 1
- 2..3 → 1 + 0.34 × (n − 1)
- 4..7 → 2 + 0.25 × (n − 4)
- ≥8 → 3 + 0.10 × (n − 8)
Factor f: 1.00 (low), 1.25 (medium), 1.50 (high), 1.75 (critical)

| Actor | Interfaces | Services | n | Normalization | f | Partial = norm × f |
|-------|------------|----------|---|---------------|---|---------------------|
| [ACTOR_1] | [QTY] | [QTY] | [N] | [NORM] | [F] | [PARTIAL] |
| [ACTOR_2] | [QTY] | [QTY] | [N] | [NORM] | [F] | [PARTIAL] |
| [ACTOR_3] | [QTY] | [QTY] | [N] | [NORM] | [F] | [PARTIAL] |

UAW = sum(partial): [TOTAL_UAW]

### 6.2) UUCW — Use Cases
For each case: n = transactions + entities; apply same normalization above (without factor f).

| Case | Transactions | Entities | n | Normalization |
|------|--------------|----------|---|---------------|
| [CASE_1] | [QTY] | [QTY] | [N] | [NORM] |
| [CASE_2] | [QTY] | [QTY] | [N] | [NORM] |
| [CASE_3] | [QTY] | [QTY] | [N] | [NORM] |

UUCW = sum(normalization): [TOTAL_UUCW]

### 6.3) UCRW — Technical Refactorings
Entries with type/scope/risk (weights 1..4); sum and normalize with 0.10 step according to adopted method.

| Item | Type (1..4) | Scope (1..4) | Risk (1..4) | Sum | Final normalization |
|------|-------------|---------------|--------------|-----|---------------------|
| [REFACT_1] | [WEIGHT] | [WEIGHT] | [WEIGHT] | [SUM] | [NORM] |
| [REFACT_2] | [WEIGHT] | [WEIGHT] | [WEIGHT] | [SUM] | [NORM] |

UCRW = sum(final normalization): [TOTAL_UCRW]

### 6.4) TCF — Technical Factor
TFactor = sum(weight_i × level_i). Document used weights.

| Technical factor | Weight | Level (0..5) | Score = Weight×Level |
|------------------|--------|--------------|--------------------|
| [TECHNICAL_FACTOR_1] | [WEIGHT] | [LEVEL] | [SCORE] |
| [TECHNICAL_FACTOR_2] | [WEIGHT] | [LEVEL] | [SCORE] |

TFactor = sum(scores): [TOTAL_TFACTOR]
TCF = 0.6 + 0.01 × TFactor = [TCF_VALUE]

### 6.5) EF — Environmental Factor
EFactor = sum(weight_i × level_i). Document used weights.

| Environmental factor | Weight | Level (0..5) | Score = Weight×Level |
|----------------------|--------|--------------|--------------------|
| [ENVIRONMENTAL_FACTOR_1] | [WEIGHT] | [LEVEL] | [SCORE] |
| [ENVIRONMENTAL_FACTOR_2] | [WEIGHT] | [LEVEL] | [SCORE] |

EFactor = sum(scores): [TOTAL_EFACTOR]
EF = 1.4 − 0.03 × EFactor = [EF_VALUE]

### 6.6) Consolidation and effort
UUCP = UAW + UUCW + UCRW = [UUCP_VALUE]
UCP = UUCP × TCF × EF = [UCP_VALUE]
Hours per point (selection): [HOURS_PER_POINT]
Base effort (hours) = [BASE_EFFORT]
Additional QA (30%) = [QA_EFFORT]
Total effort (hours) = [TOTAL_EFFORT]

Calculation observations and assumptions:
- TCF/EF weights used (if different from PDF standard): [WEIGHTS_OBSERVATIONS]
- Rounding: maintain 2 decimal places in intermediates and total.

---

## 7) Outputs
- POC: hypotheses, criteria, design, backlog, test plan, result.
- MVP: prioritized backlog, NFRs, roadmap, metrics, rollout plan.
- Estimation: [TOTAL_EFFORT] total hours; [ESTIMATION_JUSTIFICATIONS]

---

## 8) UCP calculation examples

### Example 1 (small):
**UAW:**
- Actor A (n=2, f=1.25) → norm=1+0.34×(1)=1.34 ⇒ 1.34×1.25=1.675
- Actor B (n=3, f=1.00) → norm=1+0.34×(2)=1.68 ⇒ 1.68×1.00=1.68
- UAW = 3.355

**UUCW:**
- Case1 n=2 → 1.34
- Case2 n=4 → 2.00
- Case3 n=5 → 2.25
- UUCW = 5.59

**UCRW:** normalized sum = 1.00

**TCF/EF:**
- TFactor=20 ⇒ TCF=0.6+0.01×20=0.80
- EFactor=10 ⇒ EF=1.4-0.03×10=1.10

**Result:**
- UUCP = UAW+UUCW+UCRW = 3.355+5.59+1.00 = 9.945
- UCP = UUCP×TCF×EF = 9.945×0.80×1.10 = 8.75
- Base effort (medium 28h/point) = 8.75×28 = 245.00h
- Total effort with QA (+30%) = 318.50h

### Example 2 (medium):
**Consolidated values:**
- UAW = 7.20; UUCW = 18.50; UCRW = 3.50
- UUCP = 29.20
- TFactor = 32 ⇒ TCF = 0.6+0.01×32 = 0.92
- EFactor = 14 ⇒ EF = 1.4-0.03×14 = 0.98

**Result:**
- UCP = 29.20×0.92×0.98 = 26.34
- Base effort (high 36h/point) = 26.34×36 = 948.24h
- Total effort with QA (+30%) = 1,232.71h
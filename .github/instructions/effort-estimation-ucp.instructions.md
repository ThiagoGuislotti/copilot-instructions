---
applyTo: "docs/**/effort-estimation*"
---
Use template .github/templates/effort-estimation-poc-mvp-template.md as base.
UCP (Use Case Points): requirements analysis and effort estimation for POC/MVP.
Goal: define scope and estimate effort to evolve from POC to MVP using UCP.
POC→MVP flow: context, problem, personas, goals, metrics.
POC: prove technical/value hypothesis; minimal scope, short timeline, clear success criteria; outputs with minimal backlog, technical design, test plan and result.
POC design (front): hooks/composables first; minimal UI; loading/error/success states.
POC design (back): stub endpoints; ProblemDetails; structured logs.
POC design (data): mocks and fixtures.
POC design (observability): traceId/correlationId; simple metrics.
POC validation: test with 3–5 users; measure success rate, time and errors; gate go/adjust/drop.
MVP: value‑based backlog (RICE/ICE); NFRs security/performance/availability/A11Y/i18n/privacy; data with schema/migrations/idempotent seed/indexes; API with versioned contracts, rate limiting, idempotency; quality with unit (xUnit), integration (NUnit), critical E2E and CI/CD.
Delivery: roadmap and sprints; risks and mitigations; dependencies; rollout/rollback; metrics (DAU, task success, P95 latency, errors).
UCP formulas: UUCP = UAW + UUCW + UCRW; UCP = UUCP × TCF × EF; Base effort (hours) = UCP × hours_per_point; Extra QA = Base effort × TESTS_PERCENT; Total effort = Base effort + Extra QA.
UAW (actors): count UIs and services per actor; weight f in {1.00 low, 1.25 medium, 1.50 high, 1.75 critical}; n = uiCount + serviceCount; normalization: n=1 -> 1; 2..3 -> 1 + 0.34×(n-1); 4..7 -> 2 + 0.25×(n-4); >=8 -> 3 + 0.10×(n-8); UAW = sum(normalization × f).
UUCW (use cases): for each case n = transactions + entities; apply same normalization; UUCW = sum(normalization).
UCRW (technical refactors): entries with type/scope/risk and weights 1..4; sum = type + scope + risk; classify interactions and normalize step 0.10; UCRW = sum(final_normalization).
TCF (technical factor): TFactor = sum(weight_i × level_i); TCF = 0.6 + 0.01 × TFactor.
EF (environmental factor): EFactor = sum(weight_i × level_i); EF = 1.4 − 0.03 × EFactor.
Defaults: hours_per_point: low 20; medium 28; high 36; TESTS_PERCENT: 0.30; TCF_BASE: 0.6, TCF_MULT: 0.01; EF_BASE: 1.4, EF_MULT: −0.03.
Scales and weights: PDF reference docs/effortEstimationUsingUCP/useCasePoints.pdf; levels 0..5 per factor; weights per factor as table; if unspecified, document chosen weights explicitly.
Calc rules: keep two decimals on intermediates; UCP rounded to two decimals; total effort includes extra QA (TESTS_PERCENT).
POC outputs: hypotheses, criteria, design, backlog, test plan, result.
MVP outputs: prioritized backlog, NFRs, roadmap, metrics, rollout plan.
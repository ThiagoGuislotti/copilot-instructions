---
applyTo: "**/{e2e,E2E,end-to-end,integration,spec,test}*/**/*.{cs,ts,js,json,yml,yaml,config}"
---
Frameworks: prefer Playwright (web); Cypress as alternative; SpecFlow (BDD .NET); xUnit/NUnit for .NET integration; Jest/Vitest for JS; configure in docker‑compose for CI/CD; use Testcontainers when possible.
Test structure: AAA pattern; isolated setup/teardown; test data factories; page object model for UI; reusable API clients; avoid inter‑test dependencies; appropriate timeouts.
Environment: dedicated E2E environment; clean data per run; stage‑specific env vars; dynamic URLs; secure credentials via secrets; automated DB seeding; automatic rollback.
Authentication: token/session management; predefined user personas; auto‑login; refresh token handling; multi‑tenant scenarios; permissions matrix; logout/session expiry.
Data strategies: test data builders; random data generation; realistic volumes; edge cases; cleanup after run; controlled shared fixtures; DB snapshots when applicable.
Performance validation: response time assertions; memory leak detection; basic load simulation; resource monitoring; timeouts; retry mechanisms; circuit breaker testing.
Visual testing: screenshot comparison; viewport variations; cross‑browser when applicable; accessibility checks; responsive; contrast validation; layout regression.
Flaky tests: retry mechanisms; explicit waits over implicit; stable selectors; visibility checks; network stability; async handling; deterministic order.
Reporting: aggregate test results; screenshots on failures; video for critical flows; centralized logs; metrics collection; trend analysis; failure categorization; alerts.
CI/CD integration: parallel execution; test sharding; artifact collection; failure notifications; smoke subset; env provisioning; deployment validation; rollback triggers.
API testing: contract validation; schema compliance; error scenarios; boundaries; security headers; CORS; rate limiting; auth flows; data integrity.
Browser automation: headless in CI; pinned versions; device emulation; network throttling; geolocation; file upload/download; popups; iframes.
Maintenance: update page objects; selector stability; test pyramid; execution time monitoring; coverage analysis; remove obsolete tests; docs updates; team training.
---
applyTo: "**/{e2e,E2E,end-to-end,integration,spec,test}*/**/*.{cs,ts,js,json,yml,yaml,config}"
---

# Frameworks
Prefer Playwright (web); Cypress as alternative; SpecFlow (BDD .NET); xUnit/NUnit for .NET integration; Jest/Vitest for JS; configure in docker‑compose for CI/CD; use Testcontainers when possible.
```typescript
// Playwright example
import { test, expect } from '@playwright/test';

test('user can login', async ({ page }) => {
  await page.goto('/login');
  await page.fill('[data-testid="email"]', 'user@test.com');
  await page.fill('[data-testid="password"]', 'password');
  await page.click('[data-testid="submit"]');
  await expect(page).toHaveURL('/dashboard');
});
```

# Test Structure
AAA pattern; isolated setup/teardown; test data factories; page object model for UI; reusable API clients; avoid inter‑test dependencies; appropriate timeouts.
```csharp
[Test]
public async Task Should_CreateOrder()
{
    // Arrange
    var client = _factory.CreateClient();
    var order = OrderFactory.CreateValid();

    // Act
    var response = await client.PostAsJsonAsync("/orders", order);

    // Assert
    response.StatusCode.Should().Be(HttpStatusCode.Created);
}
```

# Environment
Dedicated E2E environment; clean data per run; stage‑specific env vars; dynamic URLs; secure credentials via secrets; automated DB seeding; automatic rollback.

# Authentication
Token/session management; predefined user personas; auto‑login; refresh token handling; multi‑tenant scenarios; permissions matrix; logout/session expiry.

# Data Strategies
Test data builders; random data generation; realistic volumes; edge cases; cleanup after run; controlled shared fixtures; DB snapshots when applicable.

# Performance Validation
Response time assertions; memory leak detection; basic load simulation; resource monitoring; timeouts; retry mechanisms; circuit breaker testing.

# Visual Testing
Screenshot comparison; viewport variations; cross‑browser when applicable; accessibility checks; responsive; contrast validation; layout regression.

# Flaky Tests
Retry mechanisms; explicit waits over implicit; stable selectors; visibility checks; network stability; async handling; deterministic order.

# Reporting
Aggregate test results; screenshots on failures; video for critical flows; centralized logs; metrics collection; trend analysis; failure categorization; alerts.

# CI/CD Integration
Parallel execution; test sharding; artifact collection; failure notifications; smoke subset; env provisioning; deployment validation; rollback triggers.
```yaml
# GitHub Actions example
- name: Run E2E Tests
  run: npx playwright test
  env:
    BASE_URL: ${{ secrets.E2E_BASE_URL }}
    API_TOKEN: ${{ secrets.E2E_API_TOKEN }}
```

# API Testing
Contract validation; schema compliance; error scenarios; boundaries; security headers; CORS; rate limiting; auth flows; data integrity.

# Browser Automation
Headless in CI; pinned versions; device emulation; network throttling; geolocation; file upload/download; popups; iframes.

# Maintenance
Update page objects; selector stability; test pyramid; execution time monitoring; coverage analysis; remove obsolete tests; docs updates; team training.
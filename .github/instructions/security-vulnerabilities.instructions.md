---
applyTo: "**/*.{cs,csproj,http,json,yaml,yml,js,jsx,ts,tsx,vue,sql,psql,pgsql,mysql,db,prisma}"
priority: high
---

# Security Standards Baseline
- Use this instruction for API, frontend, backend, and database security decisions.
- Prioritize prevention of OWASP Top 10 and API Top 10 classes of vulnerabilities.
- Treat this as a secure-by-default baseline, then add domain-specific controls as needed.

# Current Reference Standards
- OWASP ASVS 5.0.0 as the application security verification baseline.
- OWASP API Security Top 10 2023 for API-specific threat classes.
- OWASP Top 10 2021 (v1.1 released July 13, 2025) for web application risk coverage.
- NIST SP 800-218 SSDF v1.1 for secure software development lifecycle practices.
- NIST SP 800-63B-4 for authentication and authenticator lifecycle controls.
- NIST SP 800-53 Rev 5 control families for governance alignment.
- CWE Top 25 current release for recurring weakness prioritization.

# Cross-Layer Secure-by-Default Rules
- Enforce least privilege for identities, services, data access, and runtime permissions.
- Enforce deny-by-default authorization and explicit allow rules per action.
- Validate all untrusted input at trust boundaries and normalize before use.
- Encode output by context to prevent injection and data interpretation flaws.
- Keep secrets out of source code and logs; use managed secret stores and short-lived credentials.
- Encrypt sensitive data in transit and at rest with managed key rotation.
- Require structured audit logging with correlationId and immutable retention policy.

# API Security Controls
- Enforce object-level and function-level authorization on every endpoint and resource ID.
- Use strong authentication with scoped tokens and explicit token audience validation.
- Validate request and response contracts with strict schemas; reject unknown or unsafe fields.
- Enforce rate limits, quotas, and abuse controls for sensitive business flows.
- Apply request size limits, timeout limits, pagination caps, and payload depth limits.
- Prevent SSRF with strict outbound allowlists, DNS rebinding defenses, and blocked link-local targets.
- Protect file upload endpoints with type validation, malware scanning, and storage isolation.
- Expose only required API versions and maintain a complete endpoint inventory.

# Frontend Security Controls
- Enforce strong Content Security Policy with nonce or hash strategy for scripts.
- Enable strict transport security and serve all traffic over HTTPS only.
- Prevent XSS with contextual output encoding and safe DOM APIs; avoid unsafe HTML rendering.
- Protect sessions using Secure, HttpOnly, SameSite cookies for cookie-based authentication.
- Enforce CSRF protections for state-changing operations when cookies are used.
- Prevent clickjacking with frame-ancestors policy and deny framing where not needed.
- Restrict browser capabilities using Permissions-Policy and least-privilege defaults.
- Keep dependency lockfiles updated and monitor vulnerable packages continuously.

# Backend Security Controls
- Centralize authentication and authorization policies; avoid ad-hoc access checks.
- Use memory-hard or industry-approved password hashing and secure credential lifecycle flows.
- Protect against injection in SQL, command execution, templates, and deserialization paths.
- Enforce safe defaults in framework middleware: headers, CORS, anti-forgery, and error handling.
- Separate privileged operations behind stronger assurance controls and explicit auditing.
- Avoid exposing internal stack traces, implementation details, and sensitive identifiers in errors.
- Use mTLS or equivalent controls for internal service-to-service traffic in zero-trust environments.

# Database Security Controls
- Use parameterized queries or ORM-safe query APIs; never concatenate untrusted SQL fragments.
- Enforce least-privilege database roles per service and per operation profile.
- Segregate read/write and administrative accounts with independent credential rotation.
- Enable row-level or tenant-scoped access controls for multi-tenant workloads.
- Encrypt backups, snapshots, and replication channels; test restore and key recovery procedures.
- Enable tamper-evident auditing for privileged changes and sensitive data reads.
- Prevent data overexposure through column-level controls, masked views, and minimal projections.

# Security Verification and Release Gates
- Require SAST, SCA, secrets scanning, IaC scanning, and dependency vulnerability checks in CI.
- Add focused DAST or API security testing for critical internet-exposed surfaces.
- Map high-risk findings to CWE and OWASP categories for triage and trend tracking.
- Require threat model updates for new external interfaces and high-impact data flows.
- Define remediation SLA by severity and verify fixes with targeted regression tests.
- Track security debt in backlog with owner, due date, and compensating control status.

# Dependency Vulnerability Automation
- Run dependency vulnerability audit before build/package for each impacted stack.
- Shared runtime scripts root:
```powershell
$SecurityScriptsRoot = Join-Path $env:USERPROFILE '.codex\shared-scripts\security'
```
- Preferred unified gate command:
```powershell
pwsh -File (Join-Path $SecurityScriptsRoot 'Invoke-PreBuildSecurityGate.ps1') -RepoRoot $PWD -FailOnSeverities Critical,High
```
- Backend .NET audit command:
```powershell
pwsh -File (Join-Path $SecurityScriptsRoot 'Invoke-VulnerabilityAudit.ps1') -RepoRoot $PWD -FailOnSeverities Critical,High
```
- Frontend audit command (npm/pnpm/yarn auto-detection):
```powershell
pwsh -File (Join-Path $SecurityScriptsRoot 'Invoke-FrontendPackageVulnerabilityAudit.ps1') -RepoRoot $PWD -ProjectPath src/WebApp -FailOnSeverities Critical,High
```
- Rust audit command:
```powershell
pwsh -File (Join-Path $SecurityScriptsRoot 'Invoke-RustPackageVulnerabilityAudit.ps1') -RepoRoot $PWD -ProjectPath . -FailOnSeverities Critical,High
```
- Persist generated artifacts under `.temp/vulnerability-audit/*` as local evidence.
- Treat Critical and High as default blocking severities for release-oriented workflows.

# Vulnerability Response and Operations
- Classify and triage findings by exploitability, blast radius, and exposure level.
- Maintain patch and upgrade cadence for frameworks, runtime, OS images, and database engines.
- Validate compensating controls when immediate patching is not possible.
- Keep incident runbooks for API abuse, credential compromise, and data exposure scenarios.
- Perform post-incident root cause analysis and codify preventive controls in this instruction set.
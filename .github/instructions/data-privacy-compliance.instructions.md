---
applyTo: "**/*.{cs,ts,js,sql,json,yml,yaml,md,ps1}"
priority: high
---

# Data Privacy and Compliance Baseline
- Use this instruction for privacy-by-design decisions across API, frontend, backend, and database layers.
- Treat personal data handling as an explicit architecture concern, not only a legal review step.

# Scope and Governance
- Maintain a current data inventory with owner, purpose, sensitivity class, and retention policy.
- Classify data at minimum as public, internal, confidential, and restricted.
- Define accountability for each processing activity and audit ownership.

# Privacy by Design
- Apply data minimization; collect and retain only what is necessary for the declared purpose.
- Enforce purpose limitation; prevent uncontrolled reuse of collected data.
- Prefer pseudonymization or tokenization for identifiers in non-core processing flows.
- Separate operational identifiers from personal identifiers whenever feasible.

# Consent and Legal Basis
- Record legal basis and consent state for processing operations that require it.
- Keep auditable records of consent capture, updates, and withdrawal events.
- Propagate consent constraints to downstream systems and derived datasets.

# Access Control and Segregation
- Enforce least privilege access to personal data by role and business purpose.
- Segment privileged access paths and require elevated controls for sensitive datasets.
- Protect multi-tenant boundaries with strict tenant-scoped access checks.

# Data Protection Controls
- Encrypt personal and sensitive data in transit and at rest.
- Use managed key lifecycle controls including rotation and access auditing.
- Mask or redact personal data in logs, telemetry, and non-production datasets.
- Prohibit secrets and personal data leakage in error messages and debug outputs.

# Retention, Deletion, and Archival
- Define retention schedules per data class and enforce automated expiration where feasible.
- Implement deletion workflows that include primary stores, replicas, caches, and derived datasets.
- Validate backup and archival deletion semantics against retention and legal constraints.
- Maintain verifiable evidence of deletion and retention policy execution.

# Data Subject Rights and Operations
- Design deterministic workflows for access, correction, export, and deletion requests.
- Track SLA and state transitions for rights requests from intake to completion.
- Ensure data exports are scoped, secure, and auditable.

# Third-Party and Cross-Border Controls
- Register external processors and define contractual/security requirements.
- Validate transfer controls for cross-region and cross-border data movement.
- Apply minimum necessary data sharing in integrations and event streams.

# Verification and Assurance
- Include privacy checks in architecture review and release readiness review.
- Add automated tests for data masking, retention rules, and tenant isolation boundaries.
- Run periodic audits of high-risk processing flows and privileged access events.
- Record findings, owners, and remediation deadlines in governance backlog.
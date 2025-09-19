---
applyTo: "**/{sonar,sonarqube,analysis,quality,lint,static}*/**/*.{properties,yml,yaml,json,xml,config,cs,ts,js}"
---

SonarQube setup: docker-compose with PostgreSQL; configured sonar-scanner-cli; quality gates set; 80%+ coverage threshold for new code; max duplication 3%; maintainability A; reliability/security A.
Example: docker-compose up -d sonar+postgres locally; configure sonar-scanner in CI; set Quality Gate new code coverage >=80% and duplication <=3%

Project config: sonar-project.properties at root; exclusions for generated code; specific inclusions; language analyzers; custom rules when needed; baseline set; incremental analysis.
Example: sonar-project.properties sets sonar.projectKey, sources=src, tests=tests, exclusions=**/*.g.cs, coverage report paths; enable Roslyn analyzers

Coverage integration: test coverage reports; jacoco for Java; coverage.py for Python; nyc for Node.js; coverlet for .NET; OpenCover/ReportGenerator; merge reports; exclude test files.
Example: .NET run coverlet with collector + ReportGenerator to SonarQube format; upload via sonar.cs.opencover.reportsPaths

Quality gates: zero tolerance for blocker/critical; differential coverage; duplication %; maintainability; reliability; security; hotspots reviewed.
Example: Fail PR if new code has coverage <80% or duplication >3% or critical issues present; review hotspots before merge

CI/CD: sonar-scanner in pipeline; quality gate status check; PR decoration; fail build on gate fail; sonar token via secrets; branch and PR analysis.
Example: Add sonar-scanner step after tests; use SONAR_TOKEN secret; wait for Quality Gate task; decorate PR with issues and coverage

Security: OWASP detection; dependency check; hotspot review; sensitive data exposure; SQL injection; XSS; authz/authn issues.
Example: Enable dependency-check; ensure SQL queries parameterized; lint for XSS sinks; review hotspots weekly

Code smells: complexity metrics; naming; unused code; magic numbers; long methods/classes; deep nesting; cognitive complexity; technical debt.
Example: Set thresholds for method length (<=50), class size (<=1000 lines); flag cognitive complexity >15; remove unused code and magic numbers

Performance rules: inefficient algorithms; leaks; resource handling; async/await; DB query optimization; caching; loops; string concatenation.
Example: Replace synchronous I/O with async; avoid large string concatenations in loops; review allocations; ensure DB queries SARGABLE

Maintainability: cyclomatic complexity <= 15; cognitive complexity <= 15; function length <= 50 lines; class size <= 1000 lines; file length <= 2000 lines.
Example: Fail gate when functions exceed 50 lines or complexity >15; refactor deep nesting into smaller functions

Custom rules: company patterns; architecture compliance; naming; coding standards; deprecated API usage; stack compliance; framework-specific rules.
Example: Custom rule: forbid domain annotations in Entities; enforce namespace structure NetToolsKit.Core.*; block deprecated APIs

Reporting: SonarQube dashboard; email; Slack/Teams; trends; team/project comparisons; technical debt; remediation plan.
Example: Weekly report to Slack with new issues and trend lines; assign remediation tasks with due dates

Branch strategy: main analysis; feature decoration; per-branch gates; merge requirements; hotfix analysis; release validation; dev branch monitoring.
Example: Analyze every feature/* branch; enforce gates before merging to main; run release validation analysis on tags

Language specifics: .NET analyzers (FxCop, StyleCop); ESLint; TSLint legacy; Java Checkstyle; Python pylint; Roslyn analyzers; custom analyzers; plugins.
Example: Enable Microsoft.CodeAnalysis.NetAnalyzers and StyleCop.Analyzers; ESLint extends recommended+security; custom Roslyn rules if needed

Exclusions: generated files; vendor libs; test utilities; migration scripts; legacy code separation; external deps; auto-generated docs.
Example: Exclude **/*.g.cs, **/Migrations/**, **/bin/**, **/obj/**; include only src/** for new code metrics

Performance monitoring: analysis duration; scanner performance; DB optimization; memory usage; parallel analysis; incremental scanning; cache; network.
Example: Cache scanner dependencies; enable incremental analysis; monitor analysis time SLA; optimize DB for SonarQube instance
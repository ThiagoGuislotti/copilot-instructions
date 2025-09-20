---
applyTo: "**/{sonar,sonarqube,analysis,quality,lint,static}*/**/*.{properties,yml,yaml,json,xml,config,cs,ts,js}"
---

# SonarQube Setup
Docker-compose with PostgreSQL; configured sonar-scanner-cli; quality gates set; 80%+ coverage threshold for new code; max duplication 3%; maintainability A; reliability/security A.
```yaml
# docker-compose.yml
services:
  sonarqube:
    image: sonarqube:community
    environment:
      SONAR_JDBC_URL: jdbc:postgresql://db:5432/sonar
```

# Project Configuration
sonar-project.properties at root; exclusions for generated code; specific inclusions; language analyzers; custom rules when needed; baseline set; incremental analysis.
```properties
sonar.projectKey=NetToolsKit
sonar.sources=src
sonar.tests=tests
sonar.exclusions=**/*.g.cs
sonar.cs.opencover.reportsPaths=coverage.xml
```

# Coverage Integration
Test coverage reports; jacoco for Java; coverage.py for Python; nyc for Node.js; coverlet for .NET; OpenCover/ReportGenerator; merge reports; exclude test files.
```bash
# .NET coverage collection
dotnet test --collect:"XPlat Code Coverage"
reportgenerator -reports:"**/coverage.cobertura.xml" -targetdir:coverage -reporttypes:SonarQube
```

# Quality Gates
Zero tolerance for blocker/critical; differential coverage; duplication %; maintainability; reliability; security; hotspots reviewed.
- Fail PR if new code has coverage <80%
- Fail if duplication >3%
- Fail if critical issues present
- Review hotspots before merge

# CI/CD Integration
sonar-scanner in pipeline; quality gate status check; PR decoration; fail build on gate fail; sonar token via secrets; branch and PR analysis.
```yaml
# GitHub Actions
- name: SonarQube Scan
  uses: sonarqube-quality-gate-action@master
  env:
    SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
```

# Security
OWASP detection; dependency check; hotspot review; sensitive data exposure; SQL injection; XSS; authz/authn issues.
- Enable dependency-check
- Ensure SQL queries parameterized
- Lint for XSS sinks
- Review hotspots weekly

# Code Smells
Complexity metrics; naming; unused code; magic numbers; long methods/classes; deep nesting; cognitive complexity; technical debt.
- Set thresholds for method length (<=50)
- Class size (<=1000 lines)
- Flag cognitive complexity >15
- Remove unused code and magic numbers

# Performance Rules
Inefficient algorithms; leaks; resource handling; async/await; DB query optimization; caching; loops; string concatenation.
- Replace synchronous I/O with async
- Avoid large string concatenations in loops
- Review allocations
- Ensure DB queries SARGABLE

# Maintainability
- Cyclomatic complexity <= 15
- Cognitive complexity <= 15
- Function length <= 50 lines
- Class size <= 1000 lines
- File length <= 2000 lines

# Custom Rules
Company patterns; architecture compliance; naming; coding standards; deprecated API usage; stack compliance; framework-specific rules.
```java
// Custom rule: forbid domain annotations in Entities
// Enforce namespace structure NetToolsKit.Core.*
// Block deprecated APIs
```

# Reporting
SonarQube dashboard; email; Slack/Teams; trends; team/project comparisons; technical debt; remediation plan.
- Weekly report to Slack with new issues and trend lines
- Assign remediation tasks with due dates

# Branch Strategy
Main analysis; feature decoration; per-branch gates; merge requirements; hotfix analysis; release validation; dev branch monitoring.
- Analyze every feature/* branch
- Enforce gates before merging to main
- Run release validation analysis on tags

# Language Specifics
.NET analyzers (FxCop, StyleCop); ESLint; TSLint legacy; Java Checkstyle; Python pylint; Roslyn analyzers; custom analyzers; plugins.
- Enable Microsoft.CodeAnalysis.NetAnalyzers and StyleCop.Analyzers
- ESLint extends recommended+security
- Custom Roslyn rules if needed

# Exclusions
Generated files; vendor libs; test utilities; migration scripts; legacy code separation; external deps; auto-generated docs.
```properties
sonar.exclusions=**/*.g.cs,**/Migrations/**,**/bin/**,**/obj/**
sonar.coverage.exclusions=**/Tests/**
```

# Performance Monitoring
Analysis duration; scanner performance; DB optimization; memory usage; parallel analysis; incremental scanning; cache; network.
- Cache scanner dependencies
- Enable incremental analysis
- Monitor analysis time SLA
- Optimize DB for SonarQube instance
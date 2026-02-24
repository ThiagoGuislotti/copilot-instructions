---
description: Generate comprehensive PR description with applied instructions, quality gates, and breaking changes
mode: ask
tools: ['codebase', 'git', 'findFiles', 'readFile']
---

# Generate PR Description
Generate a comprehensive Pull Request description following repository standards.

## Instructions
Create PR description based on:
- [pr.instructions.md](../.github/instructions/pr.instructions.md)
- [feedback-changelog.instructions.md](../.github/instructions/feedback-changelog.instructions.md)
- [clean-architecture-code.instructions.md](../.github/instructions/clean-architecture-code.instructions.md)

## Input Variables
- `${input:prType:PR type (feature/bugfix/refactor/docs)}` - Type of change
- `${input:breaking:Has breaking changes? (yes/no)}` - Breaking change flag
- `${input:jiraTicket:JIRA ticket ID (optional)}` - Issue tracker reference
- `${input:targetBranch:Target branch (main/develop)}` - Branch to merge into

## PR Description Template

### Title Format
```
[${prType}] ${summary} ${jiraTicket ? '(' + jiraTicket + ')' : ''}
```

Examples:
- `[feature] Add ECF declaration generation (ECF-123)`
- `[bugfix] Fix null reference in fiscal calculator`
- `[refactor] Migrate to Clean Architecture pattern`

### Description Structure

```markdown
## 📋 Description
${detailedDescription}

## 🎯 Type of Change
- [${prType === 'feature' ? 'x' : ' '}] ✨ New feature (non-breaking change which adds functionality)
- [${prType === 'bugfix' ? 'x' : ' '}] 🐛 Bug fix (non-breaking change which fixes an issue)
- [${prType === 'refactor' ? 'x' : ' '}] ♻️ Refactoring (no functional changes, code improvement)
- [${prType === 'docs' ? 'x' : ' '}] 📚 Documentation update
- [${breaking === 'yes' ? 'x' : ' '}] 💥 Breaking change (fix or feature that would cause existing functionality to not work as expected)

## 🔗 Related Issues
${jiraTicket ? '- Closes ' + jiraTicket : 'N/A'}
- Related to: ${relatedIssues}

## 📝 What Changed
### Added
- ${addedFeatures}

### Changed
- ${changedBehavior}

### Removed
- ${removedCode}

### Fixed
- ${fixedBugs}

## 🏗️ Architecture & Design
### Layers Affected
- [${affectsApi ? 'x' : ' '}] **API Layer** - Controllers, middleware, configuration
- [${affectsApplication ? 'x' : ' '}] **Application Layer** - Commands, queries, handlers, DTOs
- [${affectsDomain ? 'x' : ' '}] **Domain Layer** - Entities, value objects, domain logic
- [${affectsInfrastructure ? 'x' : ' '}] **Infrastructure Layer** - Repositories, external services, persistence

### Design Patterns Used
- ${designPatterns}

### Applied Instructions
This PR follows these instruction files:
${appliedInstructions.map(i => '- `' + i + '`').join('\n')}

## 🧪 Testing
### Test Coverage
- Unit Tests: ${unitTestCount} tests, ${unitTestCoverage}% coverage
- Integration Tests: ${integrationTestCount} tests
- E2E Tests: ${e2eTestCount} tests

### Test Categories
```
✅ Unit Tests
  - Domain entity behavior: ${domainTestCount} tests
  - Application handlers: ${handlerTestCount} tests
  - Validation logic: ${validationTestCount} tests

✅ Integration Tests
  - Repository operations: ${repositoryTestCount} tests
  - API endpoints: ${apiTestCount} tests
  - Database migrations: ${migrationTestCount} tests

${hasE2ETests ? '✅ E2E Tests\n  - Full workflow scenarios: ' + e2eTestCount + ' tests' : ''}
```

### Manual Testing Checklist
- [ ] Tested happy path scenarios
- [ ] Tested error handling and edge cases
- [ ] Verified database migrations (up/down)
- [ ] Checked API documentation (Swagger)
- [ ] Validated authentication/authorization
- [ ] Tested with different user roles
- [ ] Verified backward compatibility
- [ ] Checked performance impact

## 💥 Breaking Changes
${breaking === 'yes' ? breakingChangesDetails : 'None'}

${breaking === 'yes' ? `### Migration Guide
${migrationGuide}

### Affected Consumers
${affectedConsumers}` : ''}

## 📦 Dependencies
### Added Dependencies
${addedDependencies.length > 0 ? addedDependencies.map(d => '- ' + d.name + ' (' + d.version + ') - ' + d.reason).join('\n') : 'None'}

### Updated Dependencies
${updatedDependencies.length > 0 ? updatedDependencies.map(d => '- ' + d.name + ' (' + d.oldVersion + ' → ' + d.newVersion + ') - ' + d.reason).join('\n') : 'None'}

### Removed Dependencies
${removedDependencies.length > 0 ? removedDependencies.map(d => '- ' + d.name + ' - ' + d.reason).join('\n') : 'None'}

## 🗂️ Database Changes
${hasDatabaseChanges ? `### Migrations
- ${migrationFiles}

### Schema Changes
${schemaChanges}

### Data Migrations
${dataMigrations}

### Rollback Plan
${rollbackPlan}` : 'No database changes'}

## 🔒 Security Considerations
${hasSecurityChanges ? securityDetails : 'No security-related changes'}

## ⚡ Performance Impact
${hasPerformanceImpact ? performanceDetails : 'No significant performance impact expected'}

### Performance Tests
${hasPerformanceTests ? performanceResults : 'N/A'}

## 📊 Quality Gates
### Static Analysis
- [${passedLinting ? 'x' : ' '}] **Linting** - No ESLint/Roslyn warnings
- [${passedFormatting ? 'x' : ' '}] **Formatting** - Code formatted with Prettier/dotnet format
- [${passedSonarQube ? 'x' : ' '}] **SonarQube** - Quality gate passed
- [${passedSecurityScan ? 'x' : ' '}] **Security Scan** - No vulnerabilities detected

### Build & Tests
- [${buildPassed ? 'x' : ' '}] **Build** - Solution builds without errors
- [${unitTestsPassed ? 'x' : ' '}] **Unit Tests** - All unit tests passing
- [${integrationTestsPassed ? 'x' : ' '}] **Integration Tests** - All integration tests passing
- [${e2eTestsPassed ? 'x' : ' '}] **E2E Tests** - All E2E tests passing

### Code Quality Metrics
- **Code Coverage:** ${codeCoverage}% (target: >=80%)
- **Cyclomatic Complexity:** ${cyclomaticComplexity} (target: <=10)
- **Maintainability Index:** ${maintainabilityIndex} (target: >=80)
- **Technical Debt:** ${technicalDebt} (target: A rating)

## 📸 Screenshots
${hasScreenshots ? screenshots : 'N/A'}

## 📚 Documentation
### Updated Documentation
${updatedDocumentation.length > 0 ? updatedDocumentation.map(d => '- ' + d).join('\n') : 'None'}

### API Changes
${hasApiChanges ? apiChangesDocumentation : 'No API changes'}

### README Updates
${hasReadmeUpdates ? readmeUpdates : 'No README updates'}

## 🚀 Deployment Notes
### Pre-Deployment Steps
${preDeploymentSteps}

### Post-Deployment Steps
${postDeploymentSteps}

### Rollback Procedure
${rollbackProcedure}

### Environment Variables
${hasEnvVarChanges ? envVarChanges : 'No environment variable changes'}

## ✅ Reviewer Checklist
### Code Review
- [ ] Code follows repository coding standards
- [ ] Applied instruction files are correctly followed
- [ ] SOLID principles and Clean Architecture respected
- [ ] No code smells or anti-patterns
- [ ] Error handling is comprehensive
- [ ] Logging is appropriate and informative
- [ ] No sensitive data in logs or responses

### Testing Review
- [ ] Test coverage is adequate (>=80%)
- [ ] Tests follow AAA pattern (Arrange/Act/Assert)
- [ ] Edge cases and error paths are tested
- [ ] Integration tests cover critical workflows
- [ ] No flaky or non-deterministic tests

### Security Review
- [ ] Input validation is comprehensive
- [ ] Authentication/authorization is correct
- [ ] No SQL injection vulnerabilities
- [ ] No sensitive data exposure
- [ ] Dependencies have no known vulnerabilities
- [ ] Secrets are not hardcoded

### Documentation Review
- [ ] Code is well-documented with XML comments
- [ ] Complex logic has explanatory comments
- [ ] API documentation is up-to-date (Swagger)
- [ ] README reflects new changes
- [ ] Migration guide provided (if breaking changes)

### Architecture Review
- [ ] Clean Architecture layers are respected
- [ ] No circular dependencies
- [ ] Dependency injection is properly configured
- [ ] Repository pattern correctly implemented
- [ ] CQRS pattern followed (if applicable)
- [ ] Domain logic in domain entities, not handlers

## 🔍 Additional Context
${additionalContext}

## 👥 Reviewers
${suggestedReviewers.map(r => '@' + r).join(', ')}

---
**Generated by:** `generate-pr-description` prompt  
**Applied Instructions:** ${appliedInstructions.length} files  
**Quality Gate:** ${qualityGatePassed ? '✅ PASSED' : '❌ FAILED'}
```

## Usage Examples

### Example 1: Feature PR
```markdown
## [feature] Add ECF declaration generation (ECF-123)

### Description
Implements ECF (Escrituração Contábil Fiscal) declaration generation with SPED format export.

### Layers Affected
- ✅ API Layer - New `EcfDeclarationController` endpoint
- ✅ Application Layer - `GenerateEcfDeclarationCommand` and handler
- ✅ Domain Layer - `EcfDeclaration` entity with business rules
- ✅ Infrastructure Layer - `EcfFileGenerator` service

### Applied Instructions
- `clean-architecture-code.instructions.md`
- `backend.instructions.md`
- `dotnet-csharp.instructions.md`

### Test Coverage
- Unit Tests: 45 tests, 87% coverage
- Integration Tests: 12 tests
- E2E Tests: 3 tests

### Breaking Changes
None
```

### Example 2: Breaking Change PR
```markdown
## [refactor] Migrate to CQRS with MediatR 💥

### Description
Refactors application to use CQRS pattern with MediatR, replacing direct repository calls in controllers.

### Breaking Changes
**Controllers no longer expose repository methods directly.**

#### Migration Guide
1. Replace direct controller injections:
   ```csharp
   // Before
   public MyController(IRepository repo) { }
   
   // After
   public MyController(IMediator mediator) { }
   ```

2. Update client calls to use new endpoint structure (no changes to contracts)

#### Affected Consumers
- Internal API clients need to update DI configuration
- No external API contract changes
```

## Quality Checklist
- [ ] PR title follows format: `[type] summary (TICKET-ID)`
- [ ] Description is clear and comprehensive
- [ ] All affected layers documented
- [ ] Applied instruction files listed
- [ ] Test coverage documented (>=80%)
- [ ] Breaking changes clearly marked
- [ ] Migration guide provided (if breaking)
- [ ] Quality gates status included
- [ ] Security considerations addressed
- [ ] Performance impact assessed
- [ ] Database changes documented
- [ ] Deployment notes provided
- [ ] Reviewer checklist included

Generate comprehensive PR description following all repository standards.
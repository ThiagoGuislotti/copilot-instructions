# Copilot Instructions

Structured AI agent guidelines for .NET projects using Clean Architecture and CQRS patterns. Eliminates inconsistent AI responses and boosts productivity through hierarchical instruction files, domain-specific conventions, and reusable prompt templates.

## Features

✅ **Hierarchical Instruction Structure:** Solution-level → Global → Domain-specific guidelines
✅ **Complete Domain Coverage:** C#/.NET, Clean Architecture, frontend, backend, DevOps, testing
✅ **Convention Standardization:** Namespaces, test patterns, commit messages, file organization
✅ **Tool Integration:** Git workflows, .NET CLI commands, CI/CD pipelines
✅ **Custom VS Code Chat Modes:** Specialized workflows for architecture review and instruction creation
✅ **Reusable Prompt Templates:** POML-based templates for common development tasks
✅ **Prompt Engineering Framework:** CoT, SoT, ToT, Self-Consistency patterns with POML support

---

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Directory Structure](#directory-structure)
- [Usage Examples](#usage-examples)
- [Chat Modes](#chat-modes)
- [Prompt Templates](#prompt-templates)
- [API Reference](#api-reference)
- [Contributing](#contributing)
- [Dependencies](#dependencies)
- [References](#references)

---

## Installation

### Using in Existing Projects

Copy relevant files to your project's `.github/` directory:

```bash
# Copy core instruction files
cp AGENTS.md /path/to/your/project/.github/
cp copilot-instructions.md /path/to/your/project/.github/

# Copy domain-specific instructions as needed
cp -r instructions/ /path/to/your/project/.github/

# Optional: Copy chat modes and prompts
cp -r chatmodes/ /path/to/your/project/.github/
cp -r prompts/ /path/to/your/project/.github/
```

### Repository Setup

```bash
git clone https://github.com/ThiagoGuislotti/copilot-instructions.git
cd copilot-instructions
```

---

## Quick Start

### Basic Setup (3 Steps)

1. **Copy core files:**
   ```bash
   cp AGENTS.md copilot-instructions.md /your/project/.github/
   ```

2. **Adapt AGENTS.md** for your solution structure

3. **Select domain instructions:**
   ```bash
   # For .NET backend
   cp instructions/dotnet-csharp.instructions.md /your/project/.github/instructions/
   cp instructions/clean-architecture-code.instructions.md /your/project/.github/instructions/

   # For frontend
   cp instructions/frontend.instructions.md /your/project/.github/instructions/
   ```

### First AI Interaction

```text
# In GitHub Copilot Chat
"Refactor this class following clean-architecture-code.instructions.md and dotnet-csharp.instructions.md"
```

---

## Directory Structure

```
.github/
├── AGENTS.md                        # Agent policies, workflow patterns, context rules
├── copilot-instructions.md          # Global rules, domain mapping, repository overview
├── CHANGELOG.md                     # Version history for .github directory
├── LICENSE                          # MIT License
├── README.md                        # This file
├── chatmodes/
│   ├── clean-architecture-review.chatmode.md    # Architecture compliance reviewer
│   └── instruction-writer.chatmode.md           # Instruction file generator
├── instructions/
│   ├── ai-orchestration.instructions.md         # AI workflow optimization
│   ├── backend.instructions.md                  # Backend API patterns
│   ├── ci-cd-devops.instructions.md             # CI/CD and DevOps practices
│   ├── clean-architecture-code.instructions.md  # Clean Architecture patterns
│   ├── copilot-instruction-creation.instructions.md  # Meta-instructions
│   ├── database.instructions.md                 # Database design patterns
│   ├── docker.instructions.md                   # Container best practices
│   ├── dotnet-csharp.instructions.md            # C# and .NET conventions
│   ├── e2e-testing.instructions.md              # End-to-end testing
│   ├── effort-estimation-ucp.instructions.md    # Use Case Points estimation
│   ├── feedback-changelog.instructions.md       # Changelog management
│   ├── frontend.instructions.md                 # Frontend patterns
│   ├── k8s.instructions.md                      # Kubernetes guidelines
│   ├── microservices-performance.instructions.md # Microservices optimization
│   ├── orm.instructions.md                      # ORM (EF Core) patterns
│   ├── powershell-execution.instructions.md     # PowerShell automation
│   ├── pr.instructions.md                       # Pull request guidelines
│   ├── prompt-templates.instructions.md         # Prompt engineering standards
│   ├── readme.instructions.md                   # README writing guidelines
│   ├── rust-testing.instructions.md             # Rust testing patterns
│   ├── static-analysis-sonarqube.instructions.md # Code quality analysis
│   ├── ui-ux.instructions.md                    # UI/UX design patterns
│   ├── vue-quasar.instructions.md               # Vue.js + Quasar framework
│   └── workflow-optimization.instructions.md    # Development workflow optimization
├── prompts/
│   ├── create-dotnet-class.prompt.md            # .NET class generator
│   ├── generate-changelog.prompt.md             # Changelog entry generator
│   ├── generate-unit-tests.prompt.md            # Unit test generator
│   └── poml/
│       ├── prompt-engineering-poml.md           # Complete POML guide
│       ├── README.md                            # POML documentation
│       ├── styles/
│       │   └── enterprise.poml                  # Enterprise style definitions
│       └── templates/
│           ├── changelog-entry.poml             # CHANGELOG POML template
│           └── unit-test-generator.poml         # Test generation POML template
├── scripts/
│   ├── deploy/                                  # Deployment automation
│   ├── doc/                                     # Documentation tooling
│   ├── maintenance/                             # Maintenance scripts
│   └── tests/                                   # Test automation
└── templates/
    ├── changelog-entry-template.md              # Changelog entry template
    ├── docker-compose-template.yml              # Docker Compose template
    ├── dotnet-class-template.cs                 # .NET class template
    ├── dotnet-dockerfile-template               # .NET Dockerfile template
    ├── dotnet-integration-test-template.cs      # Integration test template
    ├── dotnet-interface-template.cs             # .NET interface template
    ├── dotnet-unit-test-template.cs             # Unit test template
    ├── effort-estimation-poc-mvp-template.md    # Effort estimation template
    ├── github-change-checklist-template.md      # PR checklist template
    ├── readme-template.md                       # Standard README template
    ├── rust-async-tests-template.rs             # Rust async test template
    ├── rust-error-tests-template.rs             # Rust error test template
    ├── rust-integration-tests-template.rs       # Rust integration test template
    └── rust-unit-tests-template.rs              # Rust unit test template
```

---

## Usage Examples

### Code Refactoring with Instructions

```text
# Select code snippet in editor
# Open GitHub Copilot Chat
"Refactor to C# 12 with sealed classes, file-scoped namespaces, and XML docs following dotnet-csharp.instructions.md"
```

### Architecture Review

```text
# In VS Code Chat, select clean-architecture-review mode
"Review this OrderService class for SOLID principles and Clean Architecture compliance"
```

### Generate New Instruction File

```text
# In VS Code Chat, select instruction-writer mode
"Create new instruction file for GraphQL API guidelines including schema design, resolvers, and error handling"
```

### Using Prompt Templates

```text
# Open prompts/create-dotnet-class.prompt.md
# Replace ${input:className}, ${input:namespace}, ${input:layer}
# Execute in Chat:
"Create sealed class OrderService in NetToolsKit.Domain.Orders namespace for Domain layer with XML docs and validation"
```

### POML-Based Template Usage

```csharp
// Use POML templates programmatically
var renderer = new PomlRenderer();
var input = new { version = "1.2.0", gitDiff = "..." };
var result = await renderer.RenderAsync("changelog-entry.poml", input);
```

---

## Chat Modes

### clean-architecture-review.chatmode.md

Specialized mode for reviewing code against Clean Architecture principles.

**Capabilities:**
- SOLID principles validation
- Dependency rule enforcement
- Layer boundary verification
- Code smell detection

**Usage:**
```text
@clean-architecture-review "Analyze this repository structure and identify violations"
```

### instruction-writer.chatmode.md

Specialized mode for creating new instruction files following meta-conventions.

**Capabilities:**
- Instruction file scaffolding
- Consistency with existing instructions
- Best practice enforcement
- Automatic formatting

**Usage:**
```text
@instruction-writer "Create instruction file for gRPC service development"
```

---

## Prompt Templates

### Standard Templates (Markdown-based)

Located in `prompts/`:
- **create-dotnet-class.prompt.md** - Generate Clean Architecture compliant classes
- **generate-changelog.prompt.md** - Create semantic versioning CHANGELOG entries
- **generate-unit-tests.prompt.md** - Generate comprehensive xUnit/NUnit tests

### POML Templates (XML-based)

Located in `prompts/poml/templates/`:
- **changelog-entry.poml** - Structured CHANGELOG generator with versioning
- **unit-test-generator.poml** - AAA pattern test generator with mocking

**Learn more:** [POML Documentation](./prompts/poml/README.md)

---

## API Reference

### Core Files

| File | Purpose | When to Use |
|------|---------|-------------|
| **AGENTS.md** | Agent policies, workflow patterns, context selection rules | Always load FIRST in Copilot sessions |
| **copilot-instructions.md** | Global rules, domain mapping, repository structure | Always load SECOND in Copilot sessions |

### Instruction Files

| Domain | File | Description |
|--------|------|-------------|
| **Code** | `dotnet-csharp.instructions.md` | C# 12, .NET 8/9, naming conventions |
| **Architecture** | `clean-architecture-code.instructions.md` | Clean Architecture, CQRS, DDD patterns |
| **Backend** | `backend.instructions.md` | API design, error handling, validation |
| **Data** | `orm.instructions.md`, `database.instructions.md` | EF Core, SQL, migrations |
| **Frontend** | `frontend.instructions.md`, `vue-quasar.instructions.md` | SPA, component design, state management |
| **Testing** | `e2e-testing.instructions.md`, `rust-testing.instructions.md` | Test strategies, patterns, frameworks |
| **DevOps** | `ci-cd-devops.instructions.md`, `docker.instructions.md`, `k8s.instructions.md` | Pipelines, containers, orchestration |
| **Documentation** | `readme.instructions.md`, `pr.instructions.md` | Documentation standards, PR templates |
| **Workflow** | `workflow-optimization.instructions.md`, `ai-orchestration.instructions.md` | Development efficiency, AI collaboration |

### Context Selection Rule (Hard Requirement)

**Always load FIRST in any Copilot Chat session:**
1. `copilot-instructions.md`
2. `AGENTS.md`

This ensures consistent agent behavior and proper context hierarchy.

---

## Contributing

### Making Changes

1. **Update core files:**
   - `AGENTS.md` for agent policies and workflow patterns
   - `copilot-instructions.md` for global rules and domain mapping

2. **Follow meta-instructions:**
   - Review `instructions/copilot-instruction-creation.instructions.md` before modifying instruction files
   - Use `instructions/feedback-changelog.instructions.md` for CHANGELOG updates

3. **Document changes:**
   - Update `CHANGELOG.md` for `.github/` directory changes
   - Include "Applied instructions" section in PRs when AI influenced the change

4. **Test instructions:**
   - Validate with GitHub Copilot Chat before committing
   - Ensure instructions are clear and actionable

### Pull Request Guidelines

Follow structure in `instructions/pr.instructions.md`:
- Context: Why the change is needed
- Changes: What was modified
- Rationale: Technical reasoning
- Testing: Validation performed
- Applied instructions: Which files influenced the work

### Git Workflow

```bash
# Create feature branch
git checkout -b feature/add-graphql-instructions

# Make changes following conventions
git add instructions/graphql.instructions.md
git commit -m "Add GraphQL API development instructions"

# Push and create PR
git push origin feature/add-graphql-instructions
```

---

## Dependencies

### Runtime Dependencies
None. This is a documentation and policy repository.

### Development Dependencies
- **GitHub Copilot** (or compatible AI coding assistant)
- **VS Code** with Copilot Chat extension
- **Git** for version control

### Optional Dependencies
- **POML CLI** (`npm install -g @microsoft/poml-cli`) for POML template rendering
- **.NET SDK** (if working on .NET projects using these instructions)

---

## References

### Official Documentation

- [GitHub Copilot Documentation](https://docs.github.com/en/copilot) - Complete Copilot reference
- [VS Code Copilot Tips](https://code.visualstudio.com/docs/copilot/copilot-tips-and-tricks) - Best practices and shortcuts
- [VS Code Prompt Crafting](https://code.visualstudio.com/docs/copilot/chat/prompt-crafting) - Effective prompt engineering
- [Custom Instructions Guide](https://docs.github.com/en/copilot/how-tos/configure-custom-instructions/add-repository-instructions) - Repository-level instructions

### Best Practices & Articles

- [Microsoft DevBlogs: 5 Copilot Chat Prompts .NET Devs Should Steal](https://devblogs.microsoft.com/dotnet/5-copilot-chat-prompts-dotnet-devs-should-steal-today/) - Practical .NET prompts
- [Dev.to: Supercharge VSCode Copilot](https://dev.to/pwd9000/supercharge-vscode-github-copilot-using-instructions-and-prompt-files-2p5e) - Advanced instruction techniques
- [GitHub Copilot Troubleshooting](https://docs.github.com/copilot/troubleshooting-github-copilot/troubleshooting-common-issues-with-github-copilot) - Common issues and solutions

### Standards & Specifications

- [Microsoft POML](https://github.com/microsoft/poml) - Prompt Orchestration Markup Language
- [Keep a Changelog](https://keepachangelog.com/) - Changelog format standard
- [Semantic Versioning](https://semver.org/) - Version numbering convention
- [Conventional Commits](https://www.conventionalcommits.org/) - Commit message convention

### Research Papers

- Wei et al. (2022). *Chain-of-Thought Prompting* (arXiv:2201.11903)
- Wang et al. (2023). *Self-Consistency* (arXiv:2203.11171)
- Yao et al. (2023). *Tree of Thoughts* (arXiv:2305.10601)

### Internal Documentation

- [POML Guide](./prompts/poml/README.md) - Complete POML template documentation
- [Prompt Engineering Guide](./prompts/poml/prompt-engineering-poml.md) - Advanced techniques
- [CHANGELOG](.github/CHANGELOG.md) - Version history

---

## License

This project is licensed under the MIT License. See [LICENSE](./LICENSE) for details.
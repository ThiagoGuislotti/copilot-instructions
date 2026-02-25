# Copilot Instructions

Structured AI agent guidelines for software development projects. Focuses on repeatable engineering workflows (planning, implementation, testing, docs, and reviews) using hierarchical instruction files, domain-specific conventions, and reusable prompt templates. Includes examples for .NET, Rust, frontend stacks, and DevOps, but the core goal is consistent, high-quality software delivery across technologies.

## Features

- ✅ **Hierarchical Instruction Structure:** Solution-level → Global → Domain-specific guidelines
- ✅ **Multi-Stack Coverage:** .NET/C#, Rust, Vue.js/Quasar, Docker, Kubernetes, databases
- ✅ **Architecture Patterns:** Clean Architecture, CQRS, DDD, microservices
- ✅ **Convention Standardization:** Code style, test patterns, commits, file organization
- ✅ **Tool Integration:** Git, CLI tools, CI/CD pipelines, static analysis
- ✅ **Custom Chat Modes:** Architecture review, instruction generation
- ✅ **Prompt Templates:** POML-based templates with CoT, SoT, ToT patterns

---

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Usage Examples](#usage-examples)
- [Chat Modes](#chat-modes)
- [Prompt Templates](#prompt-templates)
- [API Reference](#api-reference)
- [Dependencies](#dependencies)
- [References](#references)

---

## Installation

### Using in Existing Projects

Copy relevant files to your project (`.github/` for instructions and repo root for routing assets):

```bash
# Copy core instruction files
cp .github/AGENTS.md /path/to/your/project/.github/
cp .github/copilot-instructions.md /path/to/your/project/.github/

# Copy domain-specific instructions as needed
cp -r .github/instructions/ /path/to/your/project/.github/

# Optional: Copy chat modes, prompts, and routing schema
cp -r chatmodes/ /path/to/your/project/
cp -r prompts/ /path/to/your/project/
cp -r schemas/ /path/to/your/project/
```

### Repository Setup

```bash
git clone https://github.com/ThiagoGuislotti/copilot-instructions.git
cd copilot-instructions
```

### Repository Layout

```text
copilot-instructions/
├─ .github/   # shared Copilot + Codex instructions
├─ .codex/    # shared Codex assets (skills/mcp/scripts)
├─ chatmodes/ # reusable chat mode definitions
├─ schemas/   # schema files (e.g., routing catalog schema)
├─ scripts/   # bootstrap + automation scripts
├─ README.md
└─ .gitignore
```

### Bootstrap Local Folders

```powershell
pwsh -File .\scripts\runtime\bootstrap.ps1

# optional: also apply shared MCP servers to ~/.codex/config.toml
pwsh -File .\scripts\runtime\bootstrap.ps1 -ApplyMcpConfig -BackupConfig
```

This syncs versioned `.github/` and `.codex/` assets into your local runtime paths (`~/.github` and `~/.codex`), including shared routing assets (`instruction-routing.catalog.yml`, `prompts/`, `chatmodes/`, `schemas/`) into `~/.github`.

---

## Quick Start

### Recommended (Most Important): Static RAGs Routing

Use a routing step to select a minimal “context pack” before doing any work.

1. **Copy the core files (required):**
   ```bash
   cp .github/AGENTS.md .github/copilot-instructions.md /your/project/.github/
   ```

2. **Copy the routing assets (recommended):**
   ```bash
   cp instruction-routing.catalog.yml /your/project/
   cp prompts/route-instructions.prompt.md /your/project/prompts/
   cp -r schemas/ /your/project/
   ```

3. **Route first, then execute:**
   - Run the route-only prompt `prompts/route-instructions.prompt.md`.
   - Load ONLY the files from the returned Context Pack (mandatory + selected).
   - Execute the task using that minimal context.

### Basic Setup (3 Steps)

1. **Copy core files:**
   ```bash
   cp .github/AGENTS.md .github/copilot-instructions.md /your/project/.github/
   ```

2. **Adapt `.github/AGENTS.md`** for your project structure

3. **Select relevant instructions:**
   ```bash
   # .NET project
   cp .github/instructions/{dotnet-csharp,clean-architecture-code,backend}.instructions.md /your/project/.github/instructions/

   # Rust project
   cp .github/instructions/rust-testing.instructions.md /your/project/.github/instructions/

   # Frontend project
   cp .github/instructions/{frontend,vue-quasar,ui-ux}.instructions.md /your/project/.github/instructions/

   # DevOps
   cp .github/instructions/{docker,k8s,ci-cd-devops}.instructions.md /your/project/.github/instructions/
   ```

### First AI Interaction

```text
# In GitHub Copilot Chat (reference loaded instruction files)
"Refactor following dotnet-csharp.instructions.md conventions"
"Generate Rust tests using rust-testing.instructions.md patterns"
"Review architecture compliance per clean-architecture-code.instructions.md"
```

---

## Usage Examples

### Code Refactoring (.NET)

```text
"Refactor to C# 12 with sealed classes and file-scoped namespaces per dotnet-csharp.instructions.md"
```

### Test Generation (Rust)

```text
"Generate async tests for this module following rust-testing.instructions.md patterns"
```

### Architecture Review

```text
@clean-architecture-review "Analyze this service for SOLID violations"
```

### Component Generation (Vue)

```text
"Create Quasar component with Composition API per vue-quasar.instructions.md"
```

### Using Prompt Templates

```text
# Reference prompts/generate-unit-tests.prompt.md
"Generate xUnit tests for OrderService with AAA pattern and mocking"
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

**Learn more:** [POML Guide](./prompts/poml/prompt-engineering-poml.md)

---

## API Reference

### Core Files

| File | Purpose | When to Use |
|------|---------|-------------|
| **.github/AGENTS.md** | Agent policies, workflow patterns, context selection rules | Always load FIRST in Copilot sessions |
| **.github/copilot-instructions.md** | Global rules, domain mapping, repository structure | Always load SECOND in Copilot sessions |

### Instruction Files

| Domain | File | Description |
|--------|------|-------------|
| **.NET/C#** | `dotnet-csharp.instructions.md` | .NET 8+, naming, conventions |
| **Rust** | `rust-testing.instructions.md` | Test patterns, async, error handling |
| **Architecture** | `clean-architecture-code.instructions.md` | Clean Architecture, CQRS, DDD |
| **Backend** | `backend.instructions.md` | REST APIs, validation, error handling |
| **Frontend** | `frontend.instructions.md`, `vue-quasar.instructions.md` | SPA, Vue 3, Quasar, state management |
| **Data** | `orm.instructions.md`, `database.instructions.md` | EF Core, SQL, schema design |
| **DevOps** | `docker.instructions.md`, `k8s.instructions.md`, `ci-cd-devops.instructions.md` | Containers, orchestration, pipelines |
| **Testing** | `e2e-testing.instructions.md` | E2E strategies, test frameworks |
| **Quality** | `static-analysis-sonarqube.instructions.md` | Code quality, static analysis |
| **Documentation** | `readme.instructions.md`, `pr.instructions.md` | READMEs, PR guidelines |
| **Workflow** | `workflow-optimization.instructions.md` | Development efficiency |

### Context Selection Rule (Hard Requirement)

**Always load FIRST in any Copilot Chat session:**
1. `.github/AGENTS.md`
2. `.github/copilot-instructions.md`

This ensures consistent agent behavior and proper context hierarchy.

### Static RAGs Routing

If you want a RAGs-style routing step (selecting a minimal “context pack” before execution), use:
- `instruction-routing.catalog.yml` (single source of truth for routes)
- `prompts/route-instructions.prompt.md` (route-only prompt that outputs a JSON context pack)

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
- **Language SDKs** (.NET SDK, Rust toolchain, Node.js) depending on your project stack

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

### Internal Documentation

- [CHANGELOG](./.github/CHANGELOG.md) - Version history

---

## License

This project is licensed under the MIT License. See [LICENSE](./LICENSE) for details.

---

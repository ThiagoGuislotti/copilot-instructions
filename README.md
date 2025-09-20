# Copilot Instructions

> Structured instructions for AI agents to work efficiently on .NET projects with Clean Architecture and CQRS patterns.

---

## Introduction

This directory solves the problem of inconsistent AI responses and low productivity in .NET projects by providing clear and hierarchical guidelines for AI agents (GitHub Copilot, Claude, etc.). The context is to standardize the development of robust applications using Clean Architecture and CQRS, with mediator via NetToolsKit.Mediator, EF Core and ASP.NET Core. The technical approach adopted is a hierarchical structure of instruction files: AGENTS.md for solution-specific details, copilot-instructions.md for global rules, and instructions/*.md for technical details by domain.

**Main features:**
- ✅ Hierarchical instruction structure (solution → global → technical)
- ✅ Complete domain mapping (C#/.NET, architecture, frontend, etc.)
- ✅ Specific conventions for .NET projects (namespaces, tests, commits)
- ✅ Integration with development tools (Git, .NET CLI)
- ✅ Custom VS Code Chat Modes for specialized development workflows
- ✅ Reusable prompt templates for common tasks

---

## Table of Contents

- [Introduction](#introduction)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Usage Examples](#usage-examples)
- [API Reference](#api-reference)
- [Build and Tests](#build-and-tests)
- [Contributing](#contributing)
- [Dependencies](#dependencies)
- [References](#references)
- [License](#license)

---

## Installation

### For AI Agents
Instructions are applied automatically when working in the repository. For use in other projects, copy the relevant files to the target project's `.github/` directory.

### Repository Setup
```bash
git clone <repository-url>
cd NetToolsKit
```

---

## Quick Start

To start using instructions in a .NET project:

```text
1. Copy AGENTS.md and adapt for your solution
2. Copy copilot-instructions.md for global rules
3. Copy files from instructions/ according to needed domains
```

---

## Usage Examples

### Example 1: Copilot Chat with Context

```text
Select code snippet → "Ask Copilot" → request:
"refactor to C# 12, sealed classes when appropriate and add XML docs following dotnet-csharp.instructions.md"
```

### Example 2: Custom Chat Mode Usage

```text
In VS Code Chat → Select clean-architecture-review mode:
"Review this class for SOLID principles and Clean Architecture compliance"

In VS Code Chat → Select instruction-writer mode:
"Create new instruction file for GraphQL API guidelines"
```

### Example 3: Using Prompt Templates

```text
Open prompts/create-dotnet-class.prompt.md → Replace [PLACEHOLDERS] → Use in Chat:
"Create sealed class OrderService in Domain layer with XML docs and validation"
```

---

## API Reference

### Key Files and Purpose

- **AGENTS.md** — Agent policies and context selection rules
- **copilot-instructions.md** — Global rules and domain mapping
- **instructions/*.md** — Technical conventions (C#, backend, ORM, DevOps, tests, docs, etc.)
- **chatmodes/*.chatmode.md** — Custom VS Code Chat participants for specialized workflows
- **prompts/*.prompt.md** — Reusable prompt templates for common development tasks
- **templates/readme-template.md** — Standard README template

### Context Selection (Hard Rule)
Always load FIRST for any Copilot Chat session:
1. copilot-instructions.md
2. AGENTS.md

---

## Build and Tests

This directory doesn't require build. To verify the repository:

```bash
dotnet build -c Release
dotnet test -c Release
```

Format/Lint:
```bash
dotnet format --verify-no-changes
```

---

## Contributing

- Update AGENTS.md for agent policies/workflows
- Update copilot-instructions.md for global rules
- Follow copilot-instruction-creation.instructions.md for changes in this directory
- Include "Applied instructions" in PRs when automations influenced the change

---

## Dependencies

### Runtime
- None specific (documentation and policies)

### Development
- GitHub Copilot / chat extension
- Git

---

## References

These prompts and practices are based on official documentation and expert articles:

- [AGENTS.md](https://agents.md/) - Agent policies and context rules
- [copilot-instructions.md](https://docs.github.com/en/copilot/how-tos/configure-custom-instructions/add-repository-instructions) - Global rules and mappings
- [GitHub Copilot Documentation](https://docs.github.com/en/copilot)
- [Microsoft DevBlogs – 5 Copilot Chat prompts .NET devs should steal today](https://devblogs.microsoft.com/dotnet/5-copilot-chat-prompts-dotnet-devs-should-steal-today/)
- [VS Code Docs – Copilot tips and tricks](https://code.visualstudio.com/docs/copilot/copilot-tips-and-tricks)
- [VS Code Docs – Prompt crafting](https://code.visualstudio.com/docs/copilot/chat/prompt-crafting)
- [Dev.to – Supercharge VSCode Copilot using instructions and prompt files](https://dev.to/pwd9000/supercharge-vscode-github-copilot-using-instructions-and-prompt-files-2p5e)
- [GitHub Docs – Troubleshooting Copilot and context issues](https://docs.github.com/copilot/troubleshooting-github-copilot/troubleshooting-common-issues-with-github-copilot)

---

## License

This project is licensed under the MIT License. See the LICENSE file at the repository root for details.

---
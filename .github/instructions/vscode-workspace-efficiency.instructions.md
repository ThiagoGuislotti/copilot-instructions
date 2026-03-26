---
applyTo: "**/*.code-workspace"
priority: high
---

# Purpose
- Standardize efficient VS Code workspace design for Codex and Copilot usage, especially when multiple windows are open on the same machine.
- Reduce duplicated indexing, Git scans, file watching, and extension host pressure without losing shared instruction discovery.

# Core Rules
- Keep product workspaces focused on the active codebase only; do not add shared AI support folders to every project workspace.
- Shared instruction/runtime folders such as `.github`, `.codex`, `copilot-instructions`, and the global VS Code User folder belong in a dedicated configuration workspace, not in every product workspace.
- Do not rely on opening shared instruction folders just so Copilot can discover instructions; prefer global VS Code instruction locations pointing to the shared runtime paths.
- Treat umbrella workspaces with many heavy folders as temporary inspection tools, not as the default development workspace.

# Template Compatibility
- Treat `.vscode/settings.tamplate.jsonc` as the global/user baseline, not as the exact content to duplicate inside each `.code-workspace`.
- Treat `.vscode/settings.tamplate.jsonc` as the source of truth for the global VS Code `settings.json`; render it into the user profile with `scripts/runtime/sync-vscode-global-settings.ps1` instead of maintaining the global file by hand.
- Because VS Code does not support native inheritance from an external `.vscode/settings.json` into `.code-workspace`, use `scripts/runtime/sync-workspace-settings.ps1` plus `.vscode/base.code-workspace` as the repository-supported pseudo-inheritance mechanism.
- Treat `.vscode/base.code-workspace` as the shared base for workspace-level `extensions` recommendations and any approved top-level defaults that should be inherited into generated workspaces.
- `scripts/runtime/sync-workspace-settings.ps1` must merge the base workspace with the target workspace, preserve `folders`, preserve workspace-specific recommendations, and regenerate only the approved local override block.
- Generated `.code-workspace` files must inherit the repository-managed global baseline whenever possible and may intentionally be stricter only for approved local throttles that reduce machine pressure:
  - `git.autorefresh = false`
  - `chat.agent.maxRequests` reduced from the global default
- Keep global Git/SCM and extension throttles in the shared template:
  - `git.autofetch = false`
  - `git.detectWorktrees = false`
  - `git.detectSubmodules = false`
  - `git.openRepositoryInParentFolders = never`
  - `extensions.autoUpdate = false`
  - `github.copilot.nextEditSuggestions.enabled = false`
  - `scm.repositories.visible` kept conservative
- Keep high-cost repository metadata hidden and excluded globally:
  - hide `.git` and `.vs` from Explorer
  - exclude `.git`, `.vs`, `TestResults`, `packages`, `BenchmarkDotNet.Artifacts`, and `.sonarqube` from watcher/search scope
- Keep slow code-action providers conservative in the global baseline:
  - prefer `eslint.codeActionsOnSave.mode = problems`
  - disable ESLint quick-fix documentation and disable-rule comment actions by default
  - disable `github.copilot.chat.reviewSelection.enabled` when repeated code-action provider stalls are affecting editor responsiveness
- Keep the shared formatter baseline compatible with the repository EOF policy:
  - do not set `esbenp.prettier-vscode` as the shared global default formatter
  - do not set Prettier as the shared default formatter for `javascript`, `typescript`, `html`, `css`, `scss`, `vue`, `json`, or `markdown`
  - the repository default EOF policy uses `insert_final_newline = false`, while Prettier writes a terminal newline
  - keep shared `editor.formatOnSave`, `editor.formatOnPaste`, and `editor.formatOnType` disabled unless a narrower repository policy explicitly accepts formatter-managed EOF behavior
  - avoid language-scoped `formatOnSave` overrides in the shared global template when the formatter is known to normalize files with a terminal newline
  - repository-owned VS Code hooks should normalize edit-tool payloads before disk writes so AI edits do not reintroduce a terminal newline when the workspace policy forbids it
- Keep chat-session continuity settings aligned with the shared template:
  - `workbench.startupEditor = welcomePage`
  - `chat.emptyState.history.enabled = true`
- Keep `window.restoreWindows = all` in the user/global settings template; do not try to force this one through workspace-only policy.
- Do not copy unrelated editor, UI, formatter, language, or extension settings from the shared template into workspace scope when the global baseline already provides them.
- Do not duplicate `files.watcherExclude` or `search.exclude` in workspace scope when the global template already provides the required excludes.
- For generated workspaces, carry only approved local overrides; do not clone the global template into the workspace file.
- Do not attempt manual inheritance hacks inside `.code-workspace` files; the supported pattern is base workspace plus sync script.

# Workspace Composition
- Prefer 1 product root per active development workspace.
- Allow 2 product roots only when they are part of the same active delivery flow, such as API plus frontend or library plus sample app.
- If a workspace exceeds 4 folders, treat it as high-cost and justify it explicitly.
- Do not open the same repository in multiple VS Code windows at the same time.
- Do not mix multiple heavy product codebases with shared AI/config folders in the same always-open workspace.

# Required Workspace Settings
- Every `.code-workspace` file should keep a minimal `settings` object only when it needs local overrides.
- Effective workspace behavior must resolve to:
  - `git.autofetch = false`
  - `git.openRepositoryInParentFolders` not equal to `always`
  - required watcher/search excludes present through the global template or explicit local override
- Do not restate global defaults in workspace scope unless the workspace must pin a stricter value.

# Recommended Workspace Throttles
- Heavy or multi-folder workspaces should override `git.autorefresh = false`.
- Single-product workspaces may inherit `git.autorefresh` from the global baseline when machine pressure is acceptable.
- Do not raise `chat.agent.maxRequests` in workspace scope; if overridden locally, keep it conservative.

# Shared AI Context Strategy
- Use one dedicated configuration workspace for `.github`, `.codex`, `copilot-instructions`, and global VS Code User assets.
- Keep product workspaces free of those shared folders unless the task is specifically editing the shared instruction system.
- Maintain a minimal global `chat.instructionsFilesLocations` set so instruction discovery still works without opening the shared folders in every workspace.
- Maintain a minimal global `chat.hookFilesLocations` set so VS Code agent hooks load from the workspace `.github/hooks` or the shared runtime `~/.github/hooks` without duplicating hook logic across projects.
- Prefer `%USERPROFILE%\\.github\\` as the single recursive discovery root.
- Prefer `~/.github/hooks` as the shared user-level hook root for Copilot and Codex sessions in VS Code.
- Do not enable duplicated subfolder roots under `.github`.
- Do not enable `%USERPROFILE%\\.codex\\skills\\` in global instruction discovery unless you have measured and justified the extra cost.

# Validation Checklist
- [ ] Workspace keeps only local overrides that are not already provided by the global template
- [ ] Effective `git.autofetch` is disabled
- [ ] Effective `git.openRepositoryInParentFolders` is not `always`
- [ ] Effective watcher/search excludes cover the required build/output directories
- [ ] `git.autorefresh = false` is applied to heavy or multi-folder workspaces
- [ ] Workspace does not duplicate shared AI/config folders unnecessarily
- [ ] Workspace folder count is justified for the active task
- [ ] Shared instruction discovery is provided by global settings or by a dedicated config workspace
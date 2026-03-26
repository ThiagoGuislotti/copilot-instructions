# Plan: install-mcp-config-compatibility

## Scope

Fix the onboarding/install flow so `-ApplyMcpConfig` works with mixed MCP server manifests that contain different optional fields per server type, including `stdio` and `http`.

## Ordered Tasks

1. Confirm the failing path and identify the exact optional-property access that throws during MCP TOML rendering.
2. Make the manifest renderer tolerant of missing optional fields without changing the output contract for valid entries.
3. Add a regression test that covers a mixed manifest with one `stdio` server and one `http` server.
4. Validate the runtime test suite and confirm the install/bootstrap MCP path is no longer blocked by the mixed manifest shape.

## Validation Checklist

- `pwsh -File scripts/tests/runtime/mcp-config-sync.tests.ps1 -RepoRoot .`
- `pwsh -File scripts/validation/validate-runtime-script-tests.ps1 -RepoRoot . -WarningOnly:$false`

## Specialist Routing

- Primary specialist: `dev-software-engineer`
- Mandatory tester: yes
- Mandatory reviewer: yes
- Closeout expectations: summarize the fix, reference the regression coverage, and include the MCP install impact in commit guidance or changelog if the workstream is finalized.
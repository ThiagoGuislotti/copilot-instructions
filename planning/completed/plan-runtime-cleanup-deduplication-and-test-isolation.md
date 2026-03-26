# Runtime cleanup sweep

## Scope
Reduce duplicated helper code in maintenance/test scripts and harden runtime tests so machine-global git hook state does not change outcomes.

## Tasks
1. Harden `trim-trailing-blank-lines.tests.ps1` against global `pre-commit` hook interference.
2. Refactor `clean-build-artifacts.ps1`, `fix-version-ranges.ps1`, and `check-test-naming.ps1` to reuse shared helper imports instead of local duplicate verbose/root logic where safe.
3. Update docs/changelog/checksum manifest and rerun validation until the suite is clean.
# ✅ Checklist: .github Change

**Modified file**: `.github/[FILE_PATH]`
**Date**: `YYYY-MM-DD`
**Change type**: [New feature / Fix / Update / Removal]

## 📋 Mandatory Checklist

### ✅ 1. README.md
- [ ] Affected section identified: `[README_SECTION]`
- [ ] Information updated (table/list/documentation)
- [ ] Usage example added/updated (if applicable)
- [ ] Links and references corrected

### ✅ 2. CHANGELOG.md  
- [ ] Entry created in format: `## [X.Y.Z] - YYYY-MM-DD`
- [ ] Appropriate category: [Added / Changed / Fixed / Removed / Breaking]
- [ ] Specific file mentioned: `.github/[FILE]`
- [ ] Clear impact description

### ✅ 3. Structure verification
- [ ] File structure: naming follows pattern `[area].instructions.md` or `[name]-template.md`
- [ ] Cross-references: update `copilot-instructions.md` with new file
- [ ] Validation: run `.\scripts\copilot.ps1` after changes
- [ ] `applyTo` globs: verify they make sense for file context
- [ ] **CRITICAL**: NO files with empty lines at the end
- [ ] Working links: test references between files

## 📝 CHANGELOG Entry Template

```markdown
## [X.Y.Z] - YYYY-MM-DD

### [CATEGORY]
- `.github/[FILE]`: [CHANGE_DESCRIPTION]
  - `[SPECIFIC_COMPONENT]`: [DETAILS]
```

## 🎯 README Update Template

**For mapping table**:
```markdown
| [AREA] | [FOLDERS] | `.github/instructions/[FILE]` | `[GLOB]` | [DESCRIPTION] |
```

**For templates list**:
```markdown
| [NAME] | `.github/templates/[FILE]` | [USAGE] |
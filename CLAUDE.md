# CLAUDE.md - project1

> **Documentation Version**: 1.0
> **Last Updated**: 2026-05-10
> **Project**: project1
> **Description**: A standard Python project
> **Features**: GitHub auto-backup, Task agents, technical debt prevention

This file provides essential guidance to Claude Code (claude.ai/code) when working with code in this repository.

## CRITICAL RULES - READ FIRST

> **Before starting ANY task, Claude Code must respond with:**
> "CRITICAL RULES ACKNOWLEDGED - I will follow all prohibitions and requirements listed in CLAUDE.md"

### ABSOLUTE PROHIBITIONS
- **NEVER** create new files in root directory → use proper module structure
- **NEVER** write output files directly to root directory → use `output/`
- **NEVER** create documentation files (.md) unless explicitly requested
- **NEVER** use git commands with -i flag (interactive mode not supported)
- **NEVER** create duplicate files (manager_v2.py, enhanced_xyz.py, utils_new.js) → ALWAYS extend existing files
- **NEVER** create multiple implementations of same concept → single source of truth
- **NEVER** copy-paste code blocks → extract into shared utilities/functions
- **NEVER** hardcode values that should be configurable → use config files/environment variables
- **NEVER** use naming like enhanced_, improved_, new_, v2_ → extend original files instead

### MANDATORY REQUIREMENTS
- **COMMIT** after every completed task/phase - no exceptions
- **GITHUB BACKUP** - Push to GitHub after every commit: `git push origin main`
- **USE TASK AGENTS** for all long-running operations (>30 seconds)
- **TODOWRITE** for complex tasks (3+ steps) → parallel agents → git checkpoints → test validation
- **READ FILES FIRST** before editing
- **DEBT PREVENTION** - Before creating new files, check for existing similar functionality to extend
- **SINGLE SOURCE OF TRUTH** - One authoritative implementation per feature/concept

### MANDATORY PRE-TASK COMPLIANCE CHECK

**Step 1: Rule Acknowledgment**
- [ ] I acknowledge all critical rules in CLAUDE.md and will follow them

**Step 2: Task Analysis**
- [ ] Will this create files in root? → If YES, use proper module structure instead
- [ ] Will this take >30 seconds? → If YES, use Task agents not Bash
- [ ] Is this 3+ steps? → If YES, use TodoWrite breakdown first

**Step 3: Technical Debt Prevention (MANDATORY SEARCH FIRST)**
- [ ] **SEARCH FIRST**: Use Grep to find existing implementations
- [ ] Does similar functionality already exist? → If YES, extend existing code
- [ ] Am I creating a duplicate class/manager? → If YES, consolidate instead

## PROJECT STRUCTURE

```
src/main/python/     ← All Python source code goes here
  core/              ← Core business logic
  utils/             ← Utility functions
  models/            ← Data models
  services/          ← Service layer
  api/               ← API endpoints
src/test/            ← All tests
output/              ← Generated files only
```

## COMMON COMMANDS

```bash
# Run tests
python -m pytest src/test/

# Push to GitHub
git push origin main
```

## TECHNICAL DEBT PREVENTION

### WRONG APPROACH:
```python
# Creating new file without searching first
# new_feature.py
```

### CORRECT APPROACH:
```python
# 1. Search first: grep for existing implementations
# 2. Read existing files
# 3. Extend existing functionality
```

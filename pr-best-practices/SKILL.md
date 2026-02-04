---
name: pr-best-practices
description: Enforces safe and consistent PR/fix workflows with automatic detection of repo-specific tooling. Use when creating PRs, fixing CI failures, preparing commits for review, or ensuring code quality before pushing.
---

# PR Best Practices

## Overview

This skill enforces safe PR workflows: no force pushing, automatic lint/format detection and execution, keeping branches up-to-date with the default branch, and running relevant tests before pushing.

## Core Rules (Non-Negotiable)

### 1. Never Force Push
- **Always add new commits** instead of rewriting history
- Use `git commit --fixup` for corrections, not `git commit --amend`
- Never use `git push --force` or `git push -f`
- If a rebase is needed, create a new branch instead (exception: after merging master, you can stash and pop)

### 2. Never Commit to Protected Branches
- **Always verify** you're not on `main` or `master` before committing
- Check with: `git branch --show-current`
- If on a protected branch, create a feature branch first
- **Follow repo-specific rules**: Search for any existing branch protection rules or skills that define additional constraints for this repository

### 3. Keep Branch Up-to-Date
- Before pushing, check if behind the default branch
- Use `git merge origin/main` (or `origin/master`) to incorporate changes
- Never rebase shared branches

### 4. Run Lint/Format Before Pushing
- Always detect and run repo-specific linting/formatting
- Fix any issues before committing
- See [Auto-Detection Logic](#auto-detection-logic) for tool detection

### 5. Run Relevant Tests
- Run tests related to changed files, not the entire test suite
- Use test filtering when available (e.g., `pytest path/to/test_file.py`)
- Ensure tests pass before pushing

## Auto-Detection Logic

Before running any tooling, detect the repo's tools. See `references/detection-patterns.md` for comprehensive patterns.

**Key principle**: Always detect the correct tool before running commands. Never assume defaults.

**Quick reference:**
- **JS/TS**: Check lock files first (`yarn.lock` → yarn, `pnpm-lock.yaml` → pnpm, `package-lock.json` → npm)
- **Python**: Check for `uv.lock`, `poetry.lock`, `Pipfile.lock`, or `pyproject.toml`
- **Pre-commit**: If `.pre-commit-config.yaml` exists, hooks run automatically on commit (no manual run needed)
- **Makefile**: Check for `lint`, `fmt`, `test` targets
- **Go/Rust**: Standard tooling (`go fmt`/`cargo fmt`, etc.)

## Pre-Push Checklist

Run through this checklist before every push:

```
[ ] 1. Not on protected branch (main/master)
[ ] 2. Branch is up-to-date with default branch
[ ] 3. Lint/format passes
[ ] 4. Relevant tests pass
[ ] 5. No secrets or sensitive data in changes
```

## Workflow Steps

### When Preparing a PR

1. **Verify branch safety**
   ```bash
   git branch --show-current  # Must NOT be main/master
   ```

2. **Sync with default branch**
   ```bash
   git fetch origin
   git merge origin/main  # or origin/master
   ```

3. **Detect and run lint/format** (see [Auto-Detection Logic](#auto-detection-logic))

4. **Run relevant tests** (only for changed code paths)

5. **Push changes**
   ```bash
   git push origin <branch-name>  # Never use --force
   ```

### When Fixing CI Failures

1. **Read the CI failure logs** carefully
2. **Make fixes in new commits** (don't amend)
3. **Run the same checks locally** before pushing
4. **Push the fix commit** (no force push)

### When Addressing Review Comments

1. **Read the comment** and understand what's being requested
2. **Make the fix** in a new commit
3. **Push the fix**
4. **Resolve the comment** using `gh api` (unless asked not to):
   ```bash
   gh api graphql -f query='
     mutation {
       resolveReviewThread(input: {threadId: "<thread_node_id>"}) {
         thread { isResolved }
       }
     }'
   ```
   To get the thread ID, fetch PR review threads first.

### When Rebasing is Requested

If someone asks you to rebase:
1. **Explain the risks** of force pushing
2. **Suggest alternatives:**
   - Merge the default branch instead
   - Create a new branch with clean history
3. **Only proceed** if explicitly confirmed and understood

## Small, Focused Commits

### Guidelines

- Each commit should do **one thing well**
- Commit message should describe **what and why**, not how
- If you need "and" in your commit message, consider splitting

### Good Examples
- `Add user authentication endpoint`
- `Fix null pointer in checkout flow`
- `Update API rate limiting to 100 req/min`

### Bad Examples
- `Fix stuff` (too vague)
- `Add auth and fix checkout and update tests` (too many things)
- `WIP` (not descriptive)

## References

See `references/detection-patterns.md` for comprehensive tooling detection patterns.

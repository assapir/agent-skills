# Agent Skills

A collection of useful skills for Claude Code agent.

## Usage

Clone this repository into your Claude skills directory:

```bash
git clone git@github.com:assapir/agent-skills.git ~/.claude/skills
```

## Available Skills

### gh-cli

Comprehensive GitHub CLI reference covering repositories, issues, PRs, Actions, and more.

### pr-best-practices

Enforces safe and consistent PR/fix workflows with automatic detection of repo-specific tooling. Includes rules for no force pushing, auto-detecting lint/format tools, keeping branches up-to-date, and running relevant tests.

### using-git-worktrees

Guide for creating isolated git worktrees for feature work with smart directory selection.

### debug

Systematic debugging methodology for tracking down issues with structured approach and common bug patterns.

### security-review

Security review checklist based on OWASP Top 10, covering injection, authentication, access control, and more.

### skill-creator

Guide for creating new skills with minimal interaction. Includes Python scripts for initialization, validation, and packaging. (From [anthropics/skills](https://github.com/anthropics/skills))

### worktree-cleanup

Automated daily cleanup of dead git worktrees and merged branches. Runs on first wake/login on workdays (configurable). Includes install script for macOS launchd.

# Agent Skills

A collection of useful skills for Claude Code agent.

## How to Use

Clone this repository into your Claude skills directory:

```bash
git clone git@github.com:assapir/agent-skills.git ~/.claude/skills
```

Once cloned, the skills are automatically available in Claude Code. You can invoke them by name (e.g., `/debug`, `/security-review`) or Claude will use them automatically when relevant to your task.

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

### db-query

Query the Balance prod or sandbox PostgreSQL database via `psql`. Handles Vault authentication and credential retrieval automatically (requires `GITHUB_TOKEN`).

### snowflake-cli

Run SQL against Snowflake using the `snow` CLI. Covers schema discovery, output formats, connection switching, and common gotchas. Requires the Snowflake CLI installed and `~/.snowflake/connections.toml` configured — see the skill's Setup section.

### cbq-query

Run SQL++ (formerly N1QL) against a Couchbase cluster using the `cbq` shell. Hard read-only — the wrapper rejects INSERT/UPDATE/UPSERT/DELETE/MERGE/CREATE/DROP/ALTER/TRUNCATE/RENAME/BUILD/GRANT/REVOKE before they reach the cluster. Designed to run via a subagent so multi-MB result envelopes never enter the main agent's context. Requires `cbq`, `jq`, and `~/.config/cbq-skill/config.json` — see the skill's Setup section.

### worktree-cleanup

Automated daily cleanup of dead git worktrees and merged branches. Runs on first wake/login on workdays (configurable). Includes install script for macOS launchd.

---
name: worktree-cleanup
description: Set up automated cleanup of dead git worktrees and merged branches. Use when user wants to automate worktree/branch cleanup, schedule daily git maintenance, clean up stale branches on wake/login, or set up launchd automation for git hygiene.
---

# Worktree Cleanup

Automate daily cleanup of dead worktrees and merged branches on macOS.

## What It Does

- Prunes dead worktrees (`git worktree prune`)
- Deletes branches merged into master/main
- Prunes stale remote tracking branches (`git fetch --prune`)
- Runs once per day on configured workdays (default: Sun-Thu)
- Triggers on first wake/login of the day

## Installation

Run the install script with optional parameters:

```bash
# Default: ~/code directory, Sun-Thu
~/.claude/skills/worktree-cleanup/scripts/install-cleanup.sh

# Custom directory
~/.claude/skills/worktree-cleanup/scripts/install-cleanup.sh ~/projects

# Custom directory and workdays (Mon-Fri = 1,2,3,4,5)
~/.claude/skills/worktree-cleanup/scripts/install-cleanup.sh ~/projects "1,2,3,4,5"
```

## Management Commands

```bash
# Run cleanup manually
~/.local/bin/cleanup-worktrees.sh

# View logs
cat ~/.local/state/worktree-cleanup.log

# Disable temporarily
launchctl unload ~/Library/LaunchAgents/com.$(whoami).cleanup-worktrees.plist

# Re-enable
launchctl load ~/Library/LaunchAgents/com.$(whoami).cleanup-worktrees.plist

# Uninstall completely
launchctl unload ~/Library/LaunchAgents/com.$(whoami).cleanup-worktrees.plist
rm ~/.local/bin/cleanup-worktrees.sh ~/Library/LaunchAgents/com.$(whoami).cleanup-worktrees.plist
```

## Configuration

Environment variables (set in launchd plist):
- `WORKTREE_CLEANUP_DIR` - Directory to scan for git repos (default: ~/code)
- `WORKTREE_CLEANUP_DAYS` - Workdays as comma-separated numbers, 0=Sun..6=Sat (default: 0,1,2,3,4)

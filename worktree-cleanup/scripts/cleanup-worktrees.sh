#!/bin/bash
# Cleanup dead/merged worktrees and branches under a specified directory
# Runs once per day on specified weekdays, triggered on wake/login

set -euo pipefail

# Configuration - can be overridden by environment variables
CODE_DIR="${WORKTREE_CLEANUP_DIR:-$HOME/code}"
WORKDAYS="${WORKTREE_CLEANUP_DAYS:-0,1,2,3,4}"  # 0=Sun, 4=Thu (Israeli workweek default)
MARKER_FILE="${WORKTREE_CLEANUP_MARKER:-$HOME/.local/state/worktree-cleanup-last-run}"
LOG_FILE="${WORKTREE_CLEANUP_LOG:-$HOME/.local/state/worktree-cleanup.log}"

mkdir -p "$(dirname "$MARKER_FILE")"

# Check if today is a workday
DAY_OF_WEEK=$(date +%w)
if [[ ! ",$WORKDAYS," == *",$DAY_OF_WEEK,"* ]]; then
    exit 0
fi

# Check if already ran today
TODAY=$(date +%Y-%m-%d)
if [[ -f "$MARKER_FILE" ]] && [[ "$(cat "$MARKER_FILE")" == "$TODAY" ]]; then
    exit 0
fi

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Starting worktree cleanup for $CODE_DIR"

# Find all git repos under the code directory and clean them
find "$CODE_DIR" -maxdepth 3 -name ".git" -type d 2>/dev/null | while read -r gitdir; do
    repo_dir=$(dirname "$gitdir")

    # Skip if inside a worktree (has a file .git instead of directory)
    [[ -d "$gitdir" ]] || continue

    log "Processing: $repo_dir"
    cd "$repo_dir"

    # Prune remote tracking branches
    git fetch --prune 2>/dev/null || true

    # Prune dead worktrees
    git worktree prune 2>/dev/null || true

    # Get default branch (master or main)
    default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "master")

    # Delete merged branches (excluding current, master, main, develop)
    merged_branches=$(git branch --merged "$default_branch" 2>/dev/null | grep -vE '^\*|^\s*(master|main|develop)\s*$' || true)
    if [[ -n "$merged_branches" ]]; then
        echo "$merged_branches" | xargs -r git branch -d 2>/dev/null || true
        log "Deleted merged branches: $(echo $merged_branches | tr '\n' ' ')"
    fi
done

# Mark as run today
echo "$TODAY" > "$MARKER_FILE"
log "Cleanup complete"

#!/bin/bash
# Install the worktree cleanup automation
# Usage: ./install-cleanup.sh [code_dir] [workdays]
#   code_dir: Directory containing git repos (default: ~/code)
#   workdays: Comma-separated day numbers 0=Sun..6=Sat (default: 0,1,2,3,4 for Sun-Thu)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODE_DIR="${1:-$HOME/code}"
WORKDAYS="${2:-0,1,2,3,4}"

# Resolve to absolute path
CODE_DIR=$(cd "$CODE_DIR" 2>/dev/null && pwd || echo "$CODE_DIR")

INSTALL_DIR="$HOME/.local/bin"
STATE_DIR="$HOME/.local/state"
LAUNCHD_DIR="$HOME/Library/LaunchAgents"
PLIST_NAME="com.$(whoami).cleanup-worktrees.plist"

echo "Installing worktree cleanup automation..."
echo "  Code directory: $CODE_DIR"
echo "  Workdays: $WORKDAYS"

# Create directories
mkdir -p "$INSTALL_DIR" "$STATE_DIR" "$LAUNCHD_DIR"

# Copy and configure the cleanup script
CLEANUP_SCRIPT="$INSTALL_DIR/cleanup-worktrees.sh"
cp "$SCRIPT_DIR/cleanup-worktrees.sh" "$CLEANUP_SCRIPT"
chmod +x "$CLEANUP_SCRIPT"

# Create launchd plist
cat > "$LAUNCHD_DIR/$PLIST_NAME" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_NAME</string>
    <key>ProgramArguments</key>
    <array>
        <string>$CLEANUP_SCRIPT</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>WORKTREE_CLEANUP_DIR</key>
        <string>$CODE_DIR</string>
        <key>WORKTREE_CLEANUP_DAYS</key>
        <string>$WORKDAYS</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>StartInterval</key>
    <integer>3600</integer>
    <key>StandardOutPath</key>
    <string>$STATE_DIR/worktree-cleanup-stdout.log</string>
    <key>StandardErrorPath</key>
    <string>$STATE_DIR/worktree-cleanup-stderr.log</string>
</dict>
</plist>
EOF

# Unload existing agent if present, then load new one
launchctl unload "$LAUNCHD_DIR/$PLIST_NAME" 2>/dev/null || true
launchctl load "$LAUNCHD_DIR/$PLIST_NAME"

echo ""
echo "✅ Installation complete!"
echo ""
echo "The cleanup will run:"
echo "  - On first login/wake each workday"
echo "  - Cleans repos under: $CODE_DIR"
echo ""
echo "Useful commands:"
echo "  # Run cleanup manually"
echo "  $CLEANUP_SCRIPT"
echo ""
echo "  # View logs"
echo "  cat $STATE_DIR/worktree-cleanup.log"
echo ""
echo "  # Disable"
echo "  launchctl unload $LAUNCHD_DIR/$PLIST_NAME"
echo ""
echo "  # Uninstall"
echo "  launchctl unload $LAUNCHD_DIR/$PLIST_NAME"
echo "  rm $CLEANUP_SCRIPT $LAUNCHD_DIR/$PLIST_NAME"

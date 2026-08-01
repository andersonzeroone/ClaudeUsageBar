#!/usr/bin/env bash
set -euo pipefail
LABEL="com.andersonsantos.claudeusagebar"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"
INSTALL_DIR="$HOME/Library/Application Support/ClaudeUsageBar"

launchctl unload "$PLIST" 2>/dev/null || true
rm -f "$PLIST"
rm -rf "$INSTALL_DIR"
echo "Removed LaunchAgent: $PLIST"
echo "Removed installed binary: $INSTALL_DIR"

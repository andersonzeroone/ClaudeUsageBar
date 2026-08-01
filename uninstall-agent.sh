#!/usr/bin/env bash
set -euo pipefail
LABEL="com.andersonsantos.claudeusagebar"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"
launchctl unload "$PLIST" 2>/dev/null || true
rm -f "$PLIST"
echo "Removed LaunchAgent: $PLIST"

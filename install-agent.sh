#!/usr/bin/env bash
# Installs a per-user LaunchAgent so ClaudeUsageBar starts automatically at login.
# Safe/reversible: only touches ~/Library/LaunchAgents, no sudo required.
set -euo pipefail
cd "$(dirname "$0")"

BIN_PATH="$(pwd)/claude-usagebar"
LABEL="com.andersonsantos.claudeusagebar"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"

if [ ! -x "$BIN_PATH" ]; then
  echo "Binary not found at $BIN_PATH — run ./build.sh first." >&2
  exit 1
fi

mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${BIN_PATH}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>StandardOutPath</key>
    <string>/tmp/claudeusagebar.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/claudeusagebar.log</string>
</dict>
</plist>
EOF

launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"
echo "Installed and loaded LaunchAgent: $PLIST"

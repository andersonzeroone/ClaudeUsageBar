#!/usr/bin/env bash
# Installs ClaudeUsageBar as a per-user LaunchAgent that starts at login.
#
# Copies the built binary to a fixed location outside this repo
# (~/Library/Application Support/ClaudeUsageBar), so the running app keeps
# working even if this source checkout is later deleted. Safe/reversible:
# only touches ~/Library/Application Support and ~/Library/LaunchAgents, no
# sudo required.
#
# Re-run this after every ./build.sh to deploy the latest binary and restart
# the agent.
set -euo pipefail
cd "$(dirname "$0")"

SRC_BIN="$(pwd)/claude-usagebar"
LABEL="com.andersonsantos.claudeusagebar"
INSTALL_DIR="$HOME/Library/Application Support/ClaudeUsageBar"
INSTALLED_BIN="$INSTALL_DIR/claude-usagebar"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"

if [ ! -x "$SRC_BIN" ]; then
  echo "Binary not found at $SRC_BIN — run ./build.sh first." >&2
  exit 1
fi

mkdir -p "$INSTALL_DIR"
# Copy to a temp file and rename over the target instead of overwriting it
# in place. On Apple Silicon, rewriting an ad-hoc-signed binary that has
# already run at that exact path can leave the kernel's code-signing cache
# stale for that inode ("load code signature error 2"), killing the process
# moments after launch. A rename swaps in a fresh inode and sidesteps that.
TMP_BIN="${INSTALLED_BIN}.new"
cp -f "$SRC_BIN" "$TMP_BIN"
chmod +x "$TMP_BIN"
mv -f "$TMP_BIN" "$INSTALLED_BIN"

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
        <string>${INSTALLED_BIN}</string>
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
echo "Installed to: $INSTALLED_BIN"
echo "Loaded LaunchAgent: $PLIST"
echo "This repo checkout can now be deleted. Re-run build.sh + install-agent.sh from a checkout to deploy an update."

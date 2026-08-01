#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release
cp -f .build/release/ClaudeUsageBar ./claude-usagebar
echo "Built ./claude-usagebar"

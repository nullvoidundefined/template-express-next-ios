#!/usr/bin/env bash
# Runs the iPhone UI tests on the first available iPhone simulator. Assumes `xcodegen generate` already ran.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
project="$root/apps/client/ios/TemplateApp.xcodeproj"

# Device lines look like "    iPhone 17 (UDID) (Shutdown)"; take the first UDID.
udid="$(xcrun simctl list devices available | grep -E '^\s+iPhone ' | head -n 1 | grep -oE '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}' || true)"
if [ -z "$udid" ]; then
    echo "error: no available iPhone simulator found (xcrun simctl list devices available)." >&2
    exit 1
fi
echo "Using simulator $udid"

xcodebuild test -project "$project" -scheme App -configuration Debug \
    -destination "platform=iOS Simulator,id=$udid" CODE_SIGNING_ALLOWED=NO

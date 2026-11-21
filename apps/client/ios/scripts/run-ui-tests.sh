#!/usr/bin/env bash
# Runs the iPhone UI tests on an available iPhone on the newest iOS runtime. Assumes `xcodegen generate` already ran.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
project="$root/apps/client/ios/TemplateApp.xcodeproj"

# Prints "<udid>\t<device name>\t<runtime name>" for the first iPhone on the newest iOS runtime.
choice="$(xcrun simctl list devices available -j | python3 -c '
import json, sys
best = None
for runtime, devices in json.load(sys.stdin)["devices"].items():
    if ".iOS-" not in runtime:
        continue
    version = tuple(int(p) for p in runtime.rsplit("iOS-", 1)[1].split("-") if p.isdigit())
    phones = [d for d in devices if d["name"].startswith("iPhone")]
    if phones and (best is None or version > best[0]):
        best = (version, runtime, phones[0])
if best:
    print("%s\t%s\t%s" % (best[2]["udid"], best[2]["name"], best[1].rsplit(".", 1)[1]))
')"
if [ -z "$choice" ]; then
    echo "error: no available iPhone simulator on an iOS runtime found (xcrun simctl list devices available)." >&2
    exit 1
fi
IFS=$'\t' read -r udid name runtime <<<"$choice"
echo "Using simulator: $name, $runtime, $udid"

xcodebuild test -project "$project" -scheme App -configuration Debug \
    -destination "platform=iOS Simulator,id=$udid" CODE_SIGNING_ALLOWED=NO

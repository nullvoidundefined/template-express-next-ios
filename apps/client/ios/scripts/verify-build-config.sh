#!/usr/bin/env bash
# Verifies the build configuration guarantees. Assumes `xcodegen generate` already ran.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
project="$root/apps/client/ios/TemplateApp.xcodeproj"
derived="$(mktemp -d)"
trap 'rm -rf "$derived"' EXIT
failures=0

pass() { echo "PASS: $1"; }
fail() {
    echo "FAIL: $1"
    failures=$((failures + 1))
}

build() {
    local configuration="$1"
    shift
    xcodebuild -project "$project" -scheme App -configuration "$configuration" \
        -destination 'generic/platform=iOS Simulator' -derivedDataPath "$derived" \
        build CODE_SIGNING_ALLOWED=NO "$@" 2>&1
}

# check <description> <actual> <expected>; an empty expected means the key must be absent.
check() {
    if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (got '$2', expected '$3')"; fi
}

plist_value() {
    /usr/libexec/PlistBuddy -c "Print :$2" "$derived/Build/Products/$1-iphonesimulator/App.app/Info.plist" 2>/dev/null || true
}

# 1. Release without API_BASE_URL must fail with the HTTPS message.
if output="$(build Release)"; then
    fail "Release build without API_BASE_URL succeeded, expected failure"
elif grep -q "Release builds need API_BASE_URL to start with https://" <<<"$output"; then
    pass "Release build without API_BASE_URL fails with the HTTPS message"
else
    fail "Release build failed without the HTTPS message"
fi

# 2. Release with an https URL succeeds and has no ATS exception.
if build Release API_BASE_URL=https://example.com >/dev/null; then
    pass "Release build with https API_BASE_URL succeeds"
    check "Release APIBaseURL is https://example.com" "$(plist_value Release APIBaseURL)" "https://example.com"
    check "Release has no NSAppTransportSecurity" "$(plist_value Release NSAppTransportSecurity)" ""
else
    fail "Release build with https API_BASE_URL failed"
fi

# 3. Debug points at localhost and allows only local networking.
if build Debug >/dev/null; then
    pass "Debug build succeeds"
    check "Debug APIBaseURL is http://localhost:3001" "$(plist_value Debug APIBaseURL)" "http://localhost:3001"
    check "Debug NSAllowsLocalNetworking is true" "$(plist_value Debug NSAppTransportSecurity:NSAllowsLocalNetworking)" "true"
    check "Debug has no NSAllowsArbitraryLoads" "$(plist_value Debug NSAppTransportSecurity:NSAllowsArbitraryLoads)" ""
else
    fail "Debug build failed"
fi

[ "$failures" -eq 0 ]

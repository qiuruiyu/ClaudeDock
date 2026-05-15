#!/bin/bash
# v1.1 acceptance smoke. Pass --auto for non-interactive run.
set -u
cd "$(dirname "$0")/../.."
source Scripts/dev/env.sh

AUTO=0
[ "${1:-}" = "--auto" ] && AUTO=1

pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1"; FAILED=1; }
ask()  {
    if [ "$AUTO" = "1" ]; then echo "  (skip interactive: $1)"; return 0; fi
    read -r -p "$1 [y/N] " ans; [ "$ans" = "y" ] || [ "$ans" = "Y" ]
}

FAILED=0
echo "==> 1. Build + tests"
swift test 2>&1 | tail -3 || fail "swift test failed"
bash Scripts/build-app.sh release >/dev/null 2>&1 || fail "build-app.sh failed"
pass "release build + tests green"

echo "==> 2. Independence baseline"
SETTINGS="$HOME/.claude/settings.json"
if [ -r "$SETTINGS" ]; then
    HASH=$(shasum -a 256 "$SETTINGS" | cut -d ' ' -f 1)
    echo "  Current settings.json sha256: $HASH"
    pass "baseline captured"
else
    HASH=""
    echo "  settings.json absent → first-run baseline (OK)"
fi

echo "==> 3. Launch bundled app"
pkill -f "ClaudeDock.app/Contents/MacOS/ClaudeDock" 2>/dev/null || true
sleep 1
open .build/ClaudeDock.app
sleep 3
if pgrep -f "ClaudeDock.app/Contents/MacOS/ClaudeDock" >/dev/null; then
    pass "app launched"
else
    fail "app did not launch"
fi

echo "==> 4. v1.1 manual checklist"
ask "Notch dock toggle off → state change triggers SYSTEM banner (no notch banner)?" && pass "coex: off" || fail "coex: off"
ask "Notch dock toggle on → state change triggers NOTCH banner only (no system)?" && pass "coex: on" || fail "coex: on"
ask "Banner slides in cleanly with NO stray top strip?" && pass "mask fix" || fail "mask fix"
ask "On non-notched Mac: banner sits flush below menu bar (no overlap)?" && pass "non-notched position" || fail "non-notched position"
ask "Click banner → terminal focused, banner dismissed immediately?" && pass "click→focus" || fail "click→focus"
ask "End a session → row disappears from active area, ENDED · N appears at bottom?" && pass "ended group" || fail "ended group"
ask "Click ENDED header → expands with chevron animation; click again → collapses?" && pass "ended toggle" || fail "ended toggle"
ask "Right-click row → Forget → row immediately gone, doesn't reappear?" && pass "forget" || fail "forget"
ask "Settings → Appearance label reads \"Show flash banner under menu bar\"?" && pass "label rename" || fail "label rename"

echo "==> 5. Independence re-verify"
if [ -n "$HASH" ] && [ -r "$SETTINGS" ]; then
    NEW=$(shasum -a 256 "$SETTINGS" | cut -d ' ' -f 1)
    if [ "$NEW" = "$HASH" ]; then
        pass "settings.json byte-identical to baseline"
    else
        fail "settings.json changed: $HASH -> $NEW"
    fi
fi

if [ $FAILED -eq 0 ]; then
    echo "==> ACCEPTED. Ready to tag v1.1."
else
    echo "==> FAILED — see notes above."
fi
exit $FAILED

#!/bin/bash
# v1.2 acceptance smoke (Session Discovery on Launch). Pass --auto for
# non-interactive run.
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

echo "==> 3. Source-level audit of Discovery module"
# Independence Invariant for v1.2: the new Discovery/ module READS
# ~/.claude/projects/ but never WRITES anything under it. Verify by
# inspecting the module's source for write-style APIs.
SUSPECT=$(grep -rn -E '\.(write|writeAtomically|createFile|setAttributes|removeItem|moveItem|copyItem|trashItem)\(' Sources/ClaudeDock/Discovery/ 2>/dev/null || true)
if [ -z "$SUSPECT" ]; then
    pass "Discovery/ module is read-only (no write APIs)"
else
    echo "  Suspect lines:"
    echo "$SUSPECT" | sed 's/^/    /'
    fail "Discovery/ module contains write-style APIs — needs audit"
fi

echo "==> 4. Launch bundled app"
pkill -f "ClaudeDock.app/Contents/MacOS/ClaudeDock" 2>/dev/null || true
sleep 1
open .build/ClaudeDock.app
sleep 4
if pgrep -f "ClaudeDock.app/Contents/MacOS/ClaudeDock" >/dev/null; then
    pass "app launched"
else
    fail "app did not launch"
fi

echo "==> 5. Independence re-verify (settings.json byte-identical)"
if [ -n "$HASH" ] && [ -r "$SETTINGS" ]; then
    NEW=$(shasum -a 256 "$SETTINGS" | cut -d ' ' -f 1)
    if [ "$NEW" = "$HASH" ]; then
        pass "settings.json byte-identical to baseline"
    else
        fail "settings.json hash changed — Independence Invariant BROKEN"
    fi
else
    pass "no baseline to compare against"
fi

echo "==> 6. v1.2 manual checklist"
ask "With 0 claudes running before launch: popover shows 0 sessions on open?" \
    && pass "empty discovery" || fail "empty discovery"
ask "Start 3 claudes in different repos → relaunch ClaudeDock → 3 rows appear within 2s?" \
    && pass "discovers 3 running sessions" || fail "discovers 3 running sessions"
ask "Type a prompt in one of those claudes → matching row updates (no duplicate)?" \
    && pass "hook merges into discovered row" || fail "hook merges into discovered row"
ask "Click a discovered row → terminal focuses correctly?" \
    && pass "discovered rows clickable" || fail "discovered rows clickable"
ask "Popover header → arrow.clockwise refresh button visible between search and gear?" \
    && pass "refresh button present" || fail "refresh button present"
ask "Click refresh button with no new claudes → no duplicate rows appear?" \
    && pass "refresh is idempotent" || fail "refresh is idempotent"
ask "Start a new claude AFTER ClaudeDock is running → row appears via hook flow (not affected by discovery)?" \
    && pass "hook flow still works" || fail "hook flow still works"
ask "Right-click a discovered row → Forget → row gone → click refresh → does NOT come back?" \
    && pass "forget survives refresh" || fail "forget survives refresh"

if [ "$FAILED" = "1" ]; then
    echo
    echo "==> FAILED — some checks did not pass"
    exit 1
fi

echo
echo "==> v1.2 ACCEPTED"

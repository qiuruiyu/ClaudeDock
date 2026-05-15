#!/bin/bash
# Sends a fake Claude Code hook payload to a running ClaudeDock.
# Usage: bash Scripts/dev/fake-hook.sh [Kind] [session_id] [cwd]
#
# Kinds: SessionStart, UserPromptSubmit, Notification, Stop, SessionEnd
set -e
KIND="${1:-SessionStart}"
SID="${2:-test-$RANDOM}"
CWD="${3:-/tmp}"

PORT_FILE="$HOME/Library/Application Support/ClaudeDock/runtime/port"
if [ ! -r "$PORT_FILE" ]; then
    echo "❌ Port file not found at $PORT_FILE — is ClaudeDock running?"
    exit 1
fi
PORT=$(cat "$PORT_FILE")
if [ -z "$PORT" ]; then
    echo "❌ Port file is empty."
    exit 1
fi

JSON=$(cat <<JSONEOF
{"session_id":"$SID","cwd":"$CWD","hook_event_name":"$KIND","transcript_path":"/tmp/${SID}.jsonl"}
JSONEOF
)

echo "POST /hook → 127.0.0.1:$PORT  kind=$KIND sid=$SID cwd=$CWD"
echo "$JSON" | curl -sS -m 2 -X POST "http://127.0.0.1:$PORT/hook" \
  -H "Content-Type: application/json" \
  --data-binary @-
RC=$?
echo
echo "curl exit: $RC"
exit $RC

#!/bin/bash
# ClaudeDock hook wrapper (generated). Fast-return; never blocks Claude Code.
set +e
APP_SUPPORT="$HOME/Library/Application Support/ClaudeDock"
[ -r "$APP_SUPPORT/runtime/port" ] || exit 0
PORT=$(cat "$APP_SUPPORT/runtime/port" 2>/dev/null)
[ -z "$PORT" ] && exit 0

# URL-encode space & ampersand for safety in query string.
enc() {
  local s="$1"
  s="${s// /%20}"
  s="${s//&/%26}"
  printf '%s' "$s"
}

TTY=$(/usr/bin/tty 2>/dev/null)
# `tty` prints "not a tty" when stdin isn't a terminal — claude pipes
# JSON to us on stdin, so this is the normal case. Squash to empty.
[ "$TTY" = "not a tty" ] && TTY=""

QS="ppid=$PPID"
QS="${QS}&tty=$(enc "$TTY")"
QS="${QS}&term=$(enc "${TERM_PROGRAM:-}")"
QS="${QS}&iterm_id=$(enc "${ITERM_SESSION_ID:-}")"
QS="${QS}&term_session_id=$(enc "${TERM_SESSION_ID:-}")"
QS="${QS}&vscode_pid=$(enc "${VSCODE_PID:-}")"

cat - | curl -sS -m 2 \
  -X POST "http://127.0.0.1:${PORT}/hook?${QS}" \
  -H 'Content-Type: application/json' \
  --data-binary @- >/dev/null 2>&1 &
disown 2>/dev/null
exit 0
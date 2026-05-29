#!/usr/bin/env bash
# adb-keepalive.sh — keep a wireless ADB connection warm so debugging/driving the
# phone doesn't drop on idle. Pings the device cheaply on an interval and
# auto-reconnects if the link drops.
#
# Usage:   tool/adb-keepalive.sh <host:port> [interval_seconds]
# Example: tool/adb-keepalive.sh 100.72.6.10:40289 20
#
# Run it in the background:  nohup tool/adb-keepalive.sh 100.72.6.10:40289 >/tmp/adb-keepalive.log 2>&1 &
# Stop it:                   pkill -f adb-keepalive

set -u

DEV="${1:-}"
INTERVAL="${2:-20}"

if [[ -z "$DEV" ]]; then
  # Fall back to the first attached device if none given.
  DEV="$(adb devices | awk 'NR>1 && $2=="device"{print $1; exit}')"
fi

if [[ -z "$DEV" ]]; then
  echo "adb-keepalive: no device:port given and none attached" >&2
  exit 1
fi

echo "adb-keepalive: pinging $DEV every ${INTERVAL}s (pid $$)"
while true; do
  if ! adb -s "$DEV" shell true >/dev/null 2>&1; then
    echo "adb-keepalive: $DEV unreachable — reconnecting"
    adb connect "$DEV" >/dev/null 2>&1 || true
  fi
  sleep "$INTERVAL"
done

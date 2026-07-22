#!/usr/bin/env bash
# Continuously mirror a device's logcat to a HOST file.
#
# WHY: when an emulator dies, its logcat dies with it -- taking with it the
# only trustworthy evidence of whether the APP failed (guest-side) or the HOST
# renderer did. That is exactly the evidence gap that left run-8's "Learn OOM
# P0" unresolvable. Streaming to the host means the record survives the death.
#
# Usage: logcat_recorder.sh <port>   (reconnects across reboots; run detached)
set -uo pipefail
ADB="${ADB:-/home/daniel/Android/Sdk/platform-tools/adb}"
port="${1:?usage: logcat_recorder.sh <port>}"
out="/tmp/logcat_${port}.log"
while true; do
  if [ "$("$ADB" -s "emulator-${port}" get-state 2>/dev/null | tr -d '\r')" = device ]; then
    echo "=== [recorder] attached $(date -u +%FT%TZ) ===" >> "$out"
    "$ADB" -s "emulator-${port}" logcat -b crash,main -v time >> "$out" 2>/dev/null
    echo "=== [recorder] DETACHED (device gone) $(date -u +%FT%TZ) ===" >> "$out"
  fi
  sleep 5
done

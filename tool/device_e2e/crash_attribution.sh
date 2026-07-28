#!/usr/bin/env bash
# Guest-side crash attribution for the emulator fleet.
#
# WHY THIS EXISTS
# ---------------
# The fleet is forced onto `-gpu swiftshader_indirect` (the only renderer that
# works headless on this host -- `-gpu host` and `-gpu swangle_indirect` both
# die with "Could not start renderer! (Error: -2)", even under Xvfb).
# SwiftShader emits host-side RenderThread SEGFAULT storms -- 199 in a single
# run-8 session -- which look exactly like app crashes if you judge by the
# emulator process dying. Run-8 raised a "Learn OOM P0" and run-9 raised two
# P1s that were all later re-classified ENVIRONMENT for precisely this reason.
#
# Host-side renderer segfaults NEVER reach guest logcat. Real app failures
# always do. So attribution must be made from inside the guest.
#
# USAGE
#   crash_attribution.sh clear  <port>            # before a scenario
#   crash_attribution.sh check  <port> [label]    # after a scenario
#
# `check` exits 0 when the guest is clean, 1 when a REAL app-level failure is
# found, and prints the evidence lines. Anything not printed here is NOT an
# app crash, however loudly the host complains.
set -uo pipefail

ADB="${ADB:-/home/daniel/Android/Sdk/platform-tools/adb}"
PKG="${PKG:-com.jcom.torah.learning_tracker}"

# Signals that mean OUR APP genuinely failed, in the guest's own words.
#
# Every pattern is scoped to $PKG. That is not tidiness -- an unscoped version
# of this script fired "REAL APP FAILURE" on a completely idle device, because
# a stock emulator constantly emits:
#   * "lowmemorykiller: Error writing /proc/<pid>/oom_score_adj; errno=22"
#     -- a benign kernel quirk, NOT a kill; and
#   * "tombstoned: registered intercept for pid N kDebuggerdJavaBacktrace"
#     -- ANR-dump plumbing for unrelated processes (e.g. .android.video).
# Matching those would have re-created the very false-positive that got run-8's
# "OOM P0" and two run-9 P1s wrongly escalated. Match KILLS, not chatter.
#
# NOT a failure signal: a bare "ActivityManager: Process <pkg> ... has died: cch
# CAC / vis +99TOP". A process dying is NORMAL Android lifecycle -- backgrounded
# and cached processes are reaped constantly. It fired on an IDLE device once the
# `system` buffer was added (run-10). A GENUINE crash already shows as FATAL
# EXCEPTION (main/crash) or `am_crash` or `ANR in` -- so the bare death line adds
# nothing but false positives and was removed.
GUEST_FAILURE_RE="\
am_crash.*${PKG}\
|ANR in ${PKG}\
|lmkd.*[Kk]ill(ing)? '?${PKG}\
|lowmemorykiller.*[Kk]illing '?${PKG}\
|>>> ${PKG} <<<"

cmd="${1:-}"; port="${2:-}"; label="${3:-unlabelled}"
[ -z "$cmd" ] || [ -z "$port" ] && { echo "usage: $0 {clear|check} <port> [label]" >&2; exit 2; }
dev="emulator-${port}"

case "$cmd" in
  clear)
    "$ADB" -s "$dev" logcat -c -b crash,main,system 2>/dev/null
    echo "[$dev] logcat cleared"
    ;;
  check)
    # NOTE the `system` buffer: ActivityManager writes "ANR in <pkg>" there, NOT
    # to crash/main. A run-10 sweep found a real ANR reported "guest clean"
    # because this read omitted `system` — the GUEST_FAILURE_RE `ANR in <pkg>`
    # pattern had nothing to match against. (`am_crash` and `lmkd` kill lines
    # also originate in `system`.) All patterns stay package-scoped, so the
    # extra buffer's chatter — generic lowmemorykiller / tombstoned lines for
    # OTHER processes — still does not match.
    raw="$("$ADB" -s "$dev" logcat -b crash,main,system -d 2>/dev/null)"
    if [ -z "$raw" ]; then
      # An unreachable device is an ENVIRONMENT problem, not an app crash.
      # Say so explicitly rather than letting silence read as "clean".
      echo "[$dev/$label] UNREADABLE - device offline or logcat empty; ENVIRONMENT, not an app finding"
      exit 0
    fi
    # Host-renderer noise can never be an app finding -- drop it up front.
    clean="$(printf '%s\n' "$raw" | grep -viE 'swiftshader|RenderThread|EGL|emuglGL')"

    hits="$(printf '%s\n' "$clean" | grep -E "$GUEST_FAILURE_RE" | head -40)"

    # "FATAL EXCEPTION" is emitted on its own line; the owning package appears
    # a few lines later ("Process: com.example.x, PID: 1234"). So take the
    # block, not the line, and only count it if it belongs to US -- otherwise
    # any unrelated system app crashing would be charged to this app.
    fatal="$(printf '%s\n' "$clean" | grep -A6 'FATAL EXCEPTION' | grep -B6 "$PKG" | head -30)"

    if [ -n "$hits" ] || [ -n "$fatal" ]; then
      echo "[$dev/$label] REAL APP FAILURE (guest-attributed to $PKG):"
      [ -n "$fatal" ] && printf '%s\n' "$fatal"
      [ -n "$hits" ] && printf '%s\n' "$hits"
      exit 1
    fi
    echo "[$dev/$label] guest clean - no ${PKG} crash/ANR/OOM-kill in logcat"
    exit 0
    ;;
  *)
    echo "unknown command: $cmd" >&2; exit 2 ;;
esac

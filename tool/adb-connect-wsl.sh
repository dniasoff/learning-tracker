#!/usr/bin/env bash
# adb-connect-wsl.sh — verify all 5 learning-tracker emulators are reachable from WSL2
#
# Run AFTER emulators are online (.\tool\emulators-start.ps1 from Windows).
#
# Approach: use adb.exe (the Windows binary) directly via WSL2 Windows interop.
# This avoids WSL2→Windows TCP bridging issues entirely and reuses the Windows
# ADB server that the emulators already registered with on startup.
#
# The Windows ADB binary is at $ANDROID_SDK_WIN/platform-tools/adb.exe and is
# fully usable from WSL2 because WSL2 has built-in Windows executable interop.
#
# For flutter commands (which use the Linux flutter binary), set ANDROID_ADB_SERVER_ADDRESS
# and make sure adb.exe is on PATH so flutter can find it:
#
#   export PATH="/mnt/c/Users/dnias/AppData/Local/Android/Sdk/platform-tools:$PATH"
#   flutter devices    # flutter uses adb.exe via PATH
#
# ADB serial → AVD name → ADB port mapping
#   emulator-5554  lt_api28_pixel2  (ADB 5555)  Android 9.0
#   emulator-5556  lt_api29_pixel3  (ADB 5557)  Android 10
#   emulator-5558  lt_api31_pixel5  (ADB 5559)  Android 12
#   emulator-5560  lt_api34_pixel7  (ADB 5561)  Android 14
#   emulator-5562  lt_api36_tablet  (ADB 5563)  Android 16

set -uo pipefail

ANDROID_SDK_WIN="/mnt/c/Users/dnias/AppData/Local/Android/Sdk"
ADB="$ANDROID_SDK_WIN/platform-tools/adb.exe"

if [[ ! -x "$ADB" ]]; then
    echo "ERROR: adb.exe not found at $ADB"
    exit 1
fi

# Expected emulator serials
ALL_SERIALS=(emulator-5554 emulator-5556 emulator-5558 emulator-5560 emulator-5562)
EXPECTED_APIS=(28 29 31 34 36)
EXPECTED_NAMES=(lt_api28_pixel2 lt_api29_pixel3 lt_api31_pixel5 lt_api34_pixel7 lt_api36_tablet)

# Filter to specific serials if passed as args
if [[ $# -gt 0 ]]; then
    # Args are console port numbers (5554, 5556, ...)
    SERIALS=()
    for port in "$@"; do SERIALS+=("emulator-$port"); done
else
    SERIALS=("${ALL_SERIALS[@]}")
fi

echo "=== Windows ADB device list ==="
"$ADB" devices -l
echo ""

# Check each expected serial
ONLINE=0
OFFLINE=0
MISSING=0

echo "=== Per-device status ==="
for i in "${!ALL_SERIALS[@]}"; do
    serial="${ALL_SERIALS[$i]}"
    # Check if this serial is in our target list
    if [[ ! " ${SERIALS[*]} " =~ " $serial " ]]; then continue; fi

    state=$("$ADB" -s "$serial" get-state 2>&1 | tr -d '\r' || true)
    avd="${EXPECTED_NAMES[$i]}"
    api="${EXPECTED_APIS[$i]}"

    if [[ "$state" == "device" ]]; then
        version=$("$ADB" -s "$serial" shell getprop ro.build.version.release 2>/dev/null | tr -d '\r' || echo "?")
        printf "  %-20s %-18s API %-3s  Android %-5s  ONLINE\n" "$serial" "$avd" "$api" "$version"
        (( ONLINE++ )) || true
    elif [[ "$state" == "offline" || "$state" == *"device offline"* ]]; then
        printf "  %-20s %-18s API %-3s  OFFLINE (still booting)\n" "$serial" "$avd" "$api"
        (( OFFLINE++ )) || true
    else
        printf "  %-20s %-18s API %-3s  NOT FOUND\n" "$serial" "$avd" "$api"
        (( MISSING++ )) || true
    fi
done

echo ""
echo "Online: $ONLINE  Offline: $OFFLINE  Not found: $MISSING"

if [[ $OFFLINE -gt 0 ]]; then
    echo "  Tip: offline devices are still booting — re-run in ~30 s"
fi
if [[ $MISSING -gt 0 ]]; then
    echo "  Tip: not-found devices need their emulators started"
    echo "       Run: .\\tool\\emulators-start.ps1  (from Windows PowerShell)"
fi

echo ""
echo "=== Flutter device list ==="
# Add adb.exe to PATH so flutter's device discovery finds it
export PATH="$ANDROID_SDK_WIN/platform-tools:$PATH"
flutter devices 2>/dev/null || echo "  (flutter not in PATH — devices accessible via adb.exe directly)"

echo ""
echo "To run on a specific device:"
echo "  flutter run -d emulator-5554"
echo "  flutter test integration_test/ -d emulator-5556"

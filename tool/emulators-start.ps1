# emulators-start.ps1 — launch all 5 learning-tracker AVDs in parallel (headless)
#
# Usage (from repo root in PowerShell):
#   .\tool\emulators-start.ps1            # start all 5
#   .\tool\emulators-start.ps1 -WipeData  # cold boot — clears userdata (CI-safe)
#   .\tool\emulators-start.ps1 -Avds lt_api34_pixel7,lt_api36_tablet   # subset
#
# Each emulator gets a fixed -port so ADB serials are stable:
#   lt_api28_pixel2  → emulator-5554   (ADB TCP 5555)
#   lt_api29_pixel3  → emulator-5556   (ADB TCP 5557)
#   lt_api31_pixel5  → emulator-5558   (ADB TCP 5559)
#   lt_api34_pixel7  → emulator-5560   (ADB TCP 5561)
#   lt_api36_tablet  → emulator-5562   (ADB TCP 5563)
#
# After this, wait ~30 s then run:  tool/adb-connect-wsl.sh  (from WSL2)
# or on Windows:  adb devices

param(
    [switch]$WipeData,
    [string[]]$Avds = @()   # empty = start all five
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Set-Location C:\
if (-not $env:JAVA_HOME) {
    $studioJbr = "C:\Program Files\Android\Android Studio\jbr"
    if (Test-Path $studioJbr) { $env:JAVA_HOME = $studioJbr; $env:PATH = "$studioJbr\bin;$env:PATH" }
}

$ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
$EMULATOR     = "$ANDROID_HOME\emulator\emulator.exe"

if (-not (Test-Path $EMULATOR)) {
    Write-Error "Emulator not found at $EMULATOR`nInstall the Android Emulator via Android Studio > SDK Manager > SDK Tools."
    exit 1
}

# ---------------------------------------------------------------------------
# AVD → port mapping (must match avd-setup.ps1)
# ---------------------------------------------------------------------------
$ALL_AVDS = [ordered]@{
    lt_api28_pixel2  = 5554
    lt_api29_pixel3  = 5556
    lt_api31_pixel5  = 5558
    lt_api34_pixel7  = 5560
    lt_api36_tablet  = 5562
}

$targets = if ($Avds.Count -gt 0) { $Avds } else { $ALL_AVDS.Keys }

# ---------------------------------------------------------------------------
# Common flags
#   -no-window       headless — no GUI; remove to get an on-screen window
#   -no-audio        skip sound; reduces host CPU noise in tests
#   -no-snapshot-save  don't persist state — every start is a semi-clean boot
#                      (keeps installed apps but not transient user data)
#   -gpu host                  hardware GPU via host OpenGL drivers (RTX 5060 Ti)
# ---------------------------------------------------------------------------
$baseFlags = @(
    "-no-window"
    "-no-audio"
    "-no-snapshot-save"
    "-gpu", "host"
)
if ($WipeData) { $baseFlags += "-wipe-data" }

# ---------------------------------------------------------------------------
# Launch
# ---------------------------------------------------------------------------
$procs = @()

foreach ($avd in $targets) {
    if (-not $ALL_AVDS.Contains($avd)) {
        Write-Warning "Unknown AVD '$avd' — skipping. Valid names: $($ALL_AVDS.Keys -join ', ')"
        continue
    }
    $port = $ALL_AVDS[$avd]
    $args = @("-avd", $avd, "-port", $port) + $baseFlags

    Write-Host "Starting $avd on port $port (emulator-$port) ..." -ForegroundColor Cyan
    $proc = Start-Process -FilePath $EMULATOR -ArgumentList $args -PassThru -NoNewWindow
    $procs += [pscustomobject]@{ Name=$avd; Port=$port; Pid=$proc.Id }
}

if ($procs.Count -eq 0) {
    Write-Error "No emulators started."
    exit 1
}

# ---------------------------------------------------------------------------
# Wait for ADB to report each device as 'device' (not 'offline')
# Timeout: 120 s per emulator
# ---------------------------------------------------------------------------
Write-Host "`nWaiting for emulators to come online ..." -ForegroundColor Cyan
$adb    = "$ANDROID_HOME\platform-tools\adb.exe"
$limit  = 120   # seconds
$step   = 4

foreach ($p in $procs) {
    $serial  = "emulator-$($p.Port)"
    $elapsed = 0
    Write-Host -NoNewline "  $serial ... "
    while ($elapsed -lt $limit) {
        $state = & $adb -s $serial get-state 2>&1
        if ($state -eq "device") { break }
        Start-Sleep $step
        $elapsed += $step
        Write-Host -NoNewline "."
    }
    if ($elapsed -ge $limit) {
        Write-Warning "`n  $serial did not come online within ${limit}s — check 'adb devices'"
    } else {
        Write-Host " ONLINE ($elapsed s)" -ForegroundColor Green
    }
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host "`nRunning emulators:" -ForegroundColor Green
& $adb devices

Write-Host @"

Windows ADB serials
-------------------
$(($procs | ForEach-Object { "  emulator-$($_.Port)  ($($_.Name))" }) -join "`n")

From WSL2
---------
  tool/adb-connect-wsl.sh        # verify all devices and show flutter list
  flutter devices                # uses adb.exe via PATH (set by adb-connect-wsl.sh)

Flutter on a specific device
-----------------------------
  flutter run -d emulator-5554
  flutter test integration_test/ -d emulator-5556
  flutter test integration_test/ -d emulator-5558

Parallel test run (all 5)
-------------------------
  for port in 5554 5556 5558 5560 5562; do
    flutter test integration_test/ -d emulator-^$port --reporter json > /tmp/results_^$port.json &
  done; wait
"@ -ForegroundColor DarkCyan

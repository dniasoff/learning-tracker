# avd-setup.ps1 — create 5 representative AVDs for parallel integration testing
#
# Run once from PowerShell (no Administrator required):
#   .\tool\avd-setup.ps1
#
# What it does:
#   1. Accepts any pending SDK licences
#   2. Downloads the 4 missing system images (API 24/29/31/34) via sdkmanager
#      (API 36.1 is already installed)
#   3. Creates one AVD per device profile, overwriting if it exists (--force)
#   4. Tunes RAM/heap in each AVD's config.ini
#
# After this runs, launch all five with:  .\tool\emulators-start.ps1
# Connect from WSL2 with:                tool/adb-connect-wsl.sh

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# WSL2 compat: sdkmanager.bat shells out to cmd.exe which rejects UNC working
# directories.  Switch to a real Windows drive before any SDK tool call.
# ---------------------------------------------------------------------------
Set-Location C:\

# Android Studio bundles a JBR; use it if JAVA_HOME is not already set.
if (-not $env:JAVA_HOME) {
    $studioJbr = "C:\Program Files\Android\Android Studio\jbr"
    if (Test-Path $studioJbr) {
        $env:JAVA_HOME = $studioJbr
        $env:PATH      = "$studioJbr\bin;$env:PATH"
    }
}

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
$ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
$SDK_MGR      = "$ANDROID_HOME\cmdline-tools\latest\bin\sdkmanager.bat"
$AVD_MGR      = "$ANDROID_HOME\cmdline-tools\latest\bin\avdmanager.bat"
$AVD_DIR      = "$env:USERPROFILE\.android\avd"

foreach ($tool in @($SDK_MGR, $AVD_MGR)) {
    if (-not (Test-Path $tool)) {
        Write-Error "Not found: $tool`nInstall Command-line Tools via Android Studio > SDK Manager > SDK Tools."
        exit 1
    }
}

# ---------------------------------------------------------------------------
# Device matrix  (5 devices: API floor → latest + one tablet)
#
# Column       Meaning
# ------       -------
# api          Android API level used in the sdkmanager package ID
# tag          System-image variant (google_apis vs google_apis_playstore)
# abi          Always x86_64 for fast hardware-accelerated emulation on x86 host
# device       avdmanager hardware profile name  (avdmanager list devices)
# name         AVD name — also becomes the -avd flag in emulators-start.ps1
# port         Emulator console port; ADB port = port+1
# ram_mb       Emulator RAM in MB
# heap_mb      Dalvik/ART heap in MB
# rationale    Why this API level matters for testing
# ---------------------------------------------------------------------------
$MATRIX = @(
    [ordered]@{
        api       = "24"
        tag       = "google_apis"
        abi       = "x86_64"
        device    = "Nexus 5"
        name      = "lt_api24_nexus5"
        port      = 5554
        ram_mb    = 1536
        heap_mb   = 256
        rationale = "Flutter floor (Android 7.0 Nougat) — runtime permission model"
    },
    [ordered]@{
        api       = "29"
        tag       = "google_apis_playstore"
        abi       = "x86_64"
        device    = "pixel_3"
        name      = "lt_api29_pixel3"
        port      = 5556
        ram_mb    = 2048
        heap_mb   = 512
        rationale = "Android 10 — scoped storage, dark-mode API, gesture nav"
    },
    [ordered]@{
        api       = "31"
        tag       = "google_apis"
        abi       = "x86_64"
        device    = "pixel_5"
        name      = "lt_api31_pixel5"
        port      = 5558
        ram_mb    = 2048
        heap_mb   = 512
        rationale = "Android 12 — SplashScreen API, exact-alarm permission, Material You"
    },
    [ordered]@{
        api       = "34"
        tag       = "google_apis_playstore"
        abi       = "x86_64"
        device    = "pixel_7"
        name      = "lt_api34_pixel7"
        port      = 5560
        ram_mb    = 2048
        heap_mb   = 512
        rationale = "Android 14 — photo picker, health permissions, notification opt-in"
    },
    [ordered]@{
        api       = "36.1"
        tag       = "google_apis_playstore"
        abi       = "x86_64"
        device    = "pixel_tablet"
        name      = "lt_api36_tablet"
        port      = 5562
        ram_mb    = 4096
        heap_mb   = 512
        rationale = "Android 16 latest + tablet form factor (10.95-in, 2560x1600)"
    }
)

# ---------------------------------------------------------------------------
# Step 1 — accept SDK licences (idempotent; safe to re-run)
# ---------------------------------------------------------------------------
Write-Host "`n[1/3] Accepting SDK licences ..." -ForegroundColor Cyan
"y`n" * 10 | & $SDK_MGR --licenses | Out-Null
Write-Host "      Licences accepted."

# ---------------------------------------------------------------------------
# Step 2 — download missing system images
# ---------------------------------------------------------------------------
Write-Host "`n[2/3] Installing system images ..." -ForegroundColor Cyan

# Build the list of currently installed packages once (cheaper than N calls)
$installed = & $SDK_MGR --list_installed 2>&1

foreach ($d in $MATRIX) {
    $pkg = "system-images;android-$($d.api);$($d.tag);$($d.abi)"
    if ($installed | Select-String ([regex]::Escape($pkg))) {
        Write-Host "      SKIP (already installed): $pkg"
    } else {
        Write-Host "      Downloading: $pkg"
        "y`n" | & $SDK_MGR $pkg
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "sdkmanager returned $LASTEXITCODE for $pkg — check your network / proxy and re-run."
        } else {
            Write-Host "      OK: $pkg"
        }
    }
}

# ---------------------------------------------------------------------------
# Step 3 — create AVDs
# ---------------------------------------------------------------------------
Write-Host "`n[3/3] Creating AVDs ..." -ForegroundColor Cyan

foreach ($d in $MATRIX) {
    $pkg = "system-images;android-$($d.api);$($d.tag);$($d.abi)"
    Write-Host "      $($d.name)  [$($d.rationale)]"

    # avdmanager requires stdin to answer "Do you wish to create a custom
    # hardware profile?" — "no" takes the default profile from --device.
    "no" | & $AVD_MGR create avd `
        --name    $d.name    `
        --package $pkg       `
        --device  $d.device  `
        --force

    if ($LASTEXITCODE -ne 0) {
        Write-Warning "avdmanager exited $LASTEXITCODE for $($d.name) — check the package was downloaded."
        continue
    }

    # Tune RAM and heap in the generated config.ini
    $cfg = "$AVD_DIR\$($d.name).avd\config.ini"
    if (Test-Path $cfg) {
        $lines = Get-Content $cfg
        # Replace or append each key
        foreach ($pair in @("hw.ramSize=$($d.ram_mb)", "vm.heapSize=$($d.heap_mb)")) {
            $key = $pair.Split('=')[0]
            if ($lines -match "^$key=") {
                $lines = $lines -replace "^$key=.*", $pair
            } else {
                $lines += $pair
            }
        }
        # WriteAllLines writes UTF-8 without BOM; avdmanager rejects BOM files.
        [System.IO.File]::WriteAllLines($cfg, $lines)
        Write-Host "        RAM=$($d.ram_mb) MB  heap=$($d.heap_mb) MB  console-port=$($d.port)"
    }
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host "`nAll AVDs configured.  Device list:" -ForegroundColor Green
& $AVD_MGR list avd | Select-String "Name:|Device:|Target:"

Write-Host @"

Next steps
----------
  Start all 5 (headless):   .\tool\emulators-start.ps1
  Connect from WSL2:         tool/adb-connect-wsl.sh
  Run Flutter on one device: flutter run -d lt_api24_nexus5
  Run integration tests:     flutter test integration_test/ -d lt_api29_pixel3
"@ -ForegroundColor DarkCyan

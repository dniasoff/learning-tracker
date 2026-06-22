# Device E2E driver (black-box, on real hardware)

Genuine end-to-end automation that drives the **shipped app on a real phone**
over ADB — real pixels tapped, real screens navigated, native dialogs handled,
and state verified in **live Firestore**. This is distinct from
`learning_tracker/test/e2e/` (those are fast *headless* `flutter test` journeys
against in-memory fakes). This walks the actual device.

## Why a separate black-box driver
`flutter integration_test` can drive in-app widgets but cannot operate native
dialogs (Google sign-in picker, OS permission prompts). This driver taps real
pixels via `uiautomator`, so it can drive the whole flow including system UI, and
it asserts against the real backend.

## Prereqs (local only — NOT CI)
- Device reachable over ADB (Tailscale): `adb connect <ip:port>`.
- The **debug** build installed (`flutter build apk --debug` → `adb install`).
  Release builds can't pass App Check (Play Integrity) when sideloaded.
- The build's **App Check debug token registered** (Firestore enforces App Check):
  1. `pm clear` + launch → grab the token from logcat
     (`DebugAppCheckProvider: Enter this debug secret ... : <uuid>`),
  2. register via the `firebaseappcheck` API
     (`projects/<p>/apps/<appId>/debugTokens`).
- `gcloud auth print-access-token` available (Firestore reads + admin email-verify).

## Layout
- `driver.py` — reusable `Device` class: find-by-text/desc/hint → tap center
  (resolved from `uiautomator` bounds, not hardcoded pixels), keyboard-safe text
  entry, polling waits, screenshots, and Firestore REST verification.
- `journey_*.py` — one real user journey each. Run: `python3 journey_01_signup_profile.py`.
- Screenshots land in `/tmp/device_e2e/` per step for an audit trail.

## Key lessons baked into the driver
- Flutter exposes labels as **content-desc** (text=""); native dialogs use
  **text**. `text=` matches either.
- The soft keyboard shifts layout → re-resolve each field's coords; dismiss the
  IME between fields.
- Poll for elements (`wait`), don't blind-sleep.
- Verify the **backend** (Firestore), not just the UI — that's what makes it E2E.

## Coverage
`journey_01` (signup → create profile → cloud-verify) is the proven reference.
Full "every screen / every button" coverage is built out journey-by-journey
against the catalog in `docs/planning/e2e-test-suite-plan.md`.

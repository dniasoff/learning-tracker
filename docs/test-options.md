# Test options — overview of every testing layer

A single reference to every way this project is tested: what each layer covers,
what it does **not**, how to run it, and where it lives. Layers run from
fastest/cheapest (run constantly) to slowest/highest-fidelity (run deliberately).

For *how to write* tests (patterns, fixtures, gotchas) see the companion
[testing-guide.md](testing-guide.md). For the full E2E journey catalogue see
[planning/e2e-test-suite-plan.md](planning/e2e-test-suite-plan.md).

> TL;DR pyramid: unit + widget (headless, ms) → codec↔rules contract (ms) →
> merge round-trip (sec) → headless full-app E2E journeys (sec) → overflow sweep
> (sec) → Firestore-rules + Cloud-Functions emulator suites (min) → on-device
> black-box E2E (min, real phone).
>
> All Dart commands run from `learning_tracker/`. Local runs need two env fixes
> (see [Local toolchain](#local-toolchain)): Flutter on PATH + a `libsqlite3.so`
> shim for Drift-backed tests.

---

## At a glance

| # | Layer | Where | Real backend? | Real device? | Speed | Run with |
|---|---|---|---|---|---|---|
| 1 | Unit + widget tests | `learning_tracker/test/**` | No (fakes) | No | ms–sec | `flutter test` / `make ci` |
| 2 | Codec ↔ rules contract | `test/sync/codec_rules_contract_test.dart` | No (static) | No | ms | in `make ci` |
| 3 | Merge round-trip / sync | `test/sync/**` | No (in-mem Drift) | No | sec | in `make ci` |
| 4 | Headless full-app E2E journeys | `test/e2e/**` | No (fake FS + in-mem DB) | No | sec | in `make ci` |
| 5 | Overflow-guard sweep | `test/overflow/` + `test/e2e/journeys/overflow_sweep_p2_test.dart` | No | No (multi-size) | sec | in `make ci` |
| 6 | Firestore security-rules | `functions/test/firestore_rules.test.mjs` | Emulator (real rules) | No | ~1 min | `make test-rules` |
| 7 | Cloud Functions | `functions/test/cf_*.test.mjs` | Emulator (auth+FS) | No | ~min | `make test-functions` |
| 8 | Story-acceptance suites | `test/story_acceptance/**` | No | No | sec | `make test-epic-N` |
| 9 | On-device black-box E2E | `tool/device_e2e/` (Python) | **Live Firestore** | **Yes (ADB)** | min | `python3 journey_*.py` |
| 10 | Flutter `integration_test` | `integration_test/app_test.dart` | Emulator/real | Yes (device) | min | `flutter test integration_test -d <id>` |

CI (`.github/workflows/ci.yml`) runs: **format-check, analyze, audit, lint,
test** (the full `make ci`), **firestore-rules** (emulator), **arb-parity**.
Layers 9 and 10 are **not** in CI — they need a physical device / emulator.

---

## 1. Unit + widget tests (the bulk)

- **What:** ~10,000 `test()` / `testWidgets()` across `test/**` — domain logic,
  providers, repositories, DAOs, individual widgets/screens pumped headless.
- **Backend:** `fake_cloud_firestore` + in-memory Drift. Fast, deterministic.
- **Does NOT:** enforce Firestore security rules, hit the network, or run on a
  device. A passing widget test does **not** prove the cloud write is allowed.
- **Run:** `flutter test` (all) · `flutter test test/path/foo_test.dart` (one).

## 2. Codec ↔ rules contract test

- **What:** statically parses every `lib/core/sync/codec/*_codec.dart` `encode()`
  AND the live `toFirestore()` builders, and asserts their key-set ⊆ the
  `hasOnly()` allowlists in `firestore.rules`.
- **Why it exists:** the #1 recurring production bug was a codec emitting a field
  the rules reject → `PERMISSION_DENIED`, invisible to layer 1 (the fake doesn't
  enforce rules). This catches that class in milliseconds, inside `make ci`.
- **File:** `test/sync/codec_rules_contract_test.dart`.
- **Run:** `flutter test test/sync/codec_rules_contract_test.dart`.

## 3. Merge round-trip / sync tests

- **What:** `test/sync/**` — LWW mergers, the outbox push path, and per-entity
  **write→merge round-trips** (the layer that catches push↔merge key mismatches,
  e.g. the bookmarks `content_item_id` vs `sefaria_ref` drop).
- **Run:** `flutter test test/sync/`.

## 4. Headless full-app E2E journeys ⚠️ (not on-device)

- **What:** `test/e2e/` — a **harness** (`test/e2e/harness/e2e_harness.dart`)
  boots the **real** AppRouter + all 5 guards + real providers headless, over an
  in-memory DB + fake Firestore, with locale injection and ergonomic helpers.
  34 journey files across three waves implement the
  [232-journey catalogue](planning/e2e-test-suite-plan.md): P0 happy paths, P1
  important paths (incl. Hebrew-RTL), P2 edges.
- **Fidelity:** real screens, routing, guards, widgets — but `find().tap()` on
  the widget tree, **not** real pixels, and **not** the real backend. Runs in
  ~seconds — which is exactly why it is NOT "drive the device and tap
  everything"; that is layer 9.
- **Run:** `flutter test test/e2e/`. Device-only surfaces (native dialogs,
  persistent switcher bar, sacred-time overlay, guarded-push screens) are
  `skip:`-marked with a documented reason.

## 5. Overflow-guard sweep

- **What:** `expectNoOverflowAcrossDevices` pumps screens at multiple device
  sizes + text scales, in `en` and `he` (RTL), asserting no RenderFlex overflow.
  Found 9 real overflow bugs.
- **Files:** harness `test/overflow/overflow_guard_test.dart`; the 48-screen
  sweep `test/e2e/journeys/overflow_sweep_p2_test.dart`. In `make ci`.

## 6. Firestore security-rules (emulator) — the real rules

- **What:** `functions/test/firestore_rules.test.mjs` runs the **live**
  `firestore.rules` under the Firestore emulator (owner/tutor/stranger matrices,
  `hasOnly` field validation, append-only enforcement).
- **Why it matters:** the only layer that proves the actual deployed rules; the
  fake in layer 1 cannot. (This CI job was historically broken — read a
  non-existent rules path — so rules drift shipped unnoticed; now fixed.)
- **Run:** `make test-rules` (needs Java 21 + the Firebase emulator).

## 7. Cloud Functions (emulator)

- **What:** `functions/test/cf_*.test.mjs` — real CF handlers vs the
  Firestore+Auth emulator: tutor grant invite/revoke, deletes, triggers, tutor
  completions/content/goals/settings proxies.
- **Run:** `make test-functions`.

## 8. Story-acceptance suites

- **What:** `test/story_acceptance/epic_NN_*_test.dart` — acceptance tests
  grouped by epic/story (the BMAD workflow).
- **Run:** `make test-story-X.Y` (one story) · `make test-epic-N` (an epic) ·
  `make test-all-stories`.

## 9. On-device black-box E2E (real phone) ✅ the genuine end-to-end

- **What:** `tool/device_e2e/` (Python, local-only) drives the **shipped app on
  a real phone** over ADB — real pixel taps via `uiautomator`, native-dialog
  handling, and verification against **live Firestore**. This is the
  "tap every button on the device, check everything" layer.
- **Pieces:**
  - `driver.py` — reusable `Device` class: find-by-text/desc/hint → tap resolved
    center (not hardcoded pixels), keyboard-safe text entry, polling waits,
    screenshots, Firestore REST assertions.
  - `journey_01_signup_profile.py` — proven reference journey: first-run →
    signup → create profile → assert it landed in Firestore.
  - `README.md` — prereqs + lessons.
- **Critical prereq — App Check:** Firestore **enforces App Check
  (Play Integrity)**. A sideloaded build can't attest, so **all cloud ops are
  denied** unless you use a **debug build with its App Check debug token
  registered** (capture the secret from logcat → register via the
  `firebaseappcheck` API). This was the real cause of "sync never works on my
  phone" — Play Store users are unaffected.
- **Run:** `cd tool/device_e2e && python3 journey_01_signup_profile.py` (device
  reachable via `adb connect`, debug build installed + token registered,
  `gcloud auth print-access-token` available).
- **Status:** driver + one journey proven; full per-screen coverage builds out
  journey-by-journey against the catalogue.
- **Accessing the emulator farm from WSL2** (emulators run on the Windows host;
  drive them via the Windows `adb.exe` shim, never the Linux adb server): see
  [testing-guide.md › Accessing On-Device Emulators](testing-guide.md#accessing-on-device-emulators-wsl2--windows-host).

## 10. Flutter `integration_test` (on-device, in-app)

- **What:** `integration_test/app_test.dart` — Flutter's on-device harness.
  Currently a single "app launches" smoke test. Drives real widgets on a
  device/emulator; can assert against real/emulator Firebase. **Cannot** drive
  native dialogs (Google sign-in picker, OS permission prompts) — those need
  layer 9.
- **Run:** `flutter test integration_test -d <device-id>`.

---

## Which layer catches which bug

| Bug class | Caught by |
|---|---|
| Logic / widget regressions | 1 unit/widget |
| Field emitted that rules reject (PERMISSION_DENIED) | 2 contract (ms) + 6 emulator |
| Push↔merge key mismatch (silent data drop) | 3 merge round-trip |
| Navigation / guard / flow regressions | 4 headless E2E |
| Layout overflow (small/foldable, RTL) | 5 overflow sweep |
| Wrong / drifted security rule | 6 rules emulator |
| Cloud Function behaviour | 7 CF emulator |
| App Check / real attestation / true device sync | 9 on-device |
| Real native-dialog flows (Google sign-in, OS perms) | 9 on-device (10 for in-app) |

Recurring lesson: **offline-first swallows cloud failures**, so a bug can be
invisible to layers 1–5 (UI looks fine) yet break real sync. Layers 2, 6, and 9
exist specifically to surface that class.

---

## Quick commands

```bash
cd learning_tracker

make ci                       # analyze + format + full flutter test (layers 1–5,8)
flutter test test/e2e/        # headless full-app journeys
flutter test test/sync/       # contract + merge + sync
make test-rules               # Firestore security rules (emulator)
make test-functions           # Cloud Functions (emulator)
make test-epic-13             # one epic's story-acceptance suite

# on-device (real phone) — local only:
cd ../tool/device_e2e && python3 journey_01_signup_profile.py
```

## Local toolchain

Local Dart/Flutter runs from a non-interactive shell need:
```bash
export PATH="/home/daniel/flutter/bin:$PATH"
mkdir -p ~/.local/lib/sqliteshim
ln -sf /usr/lib/x86_64-linux-gnu/libsqlite3.so.0.8.6 ~/.local/lib/sqliteshim/libsqlite3.so
export LD_LIBRARY_PATH="$HOME/.local/lib/sqliteshim:$LD_LIBRARY_PATH"
```
The sqlite shim is required for any Drift-backed test (most of `test/sync/**`,
`test/e2e/**`). The emulator suites (6, 7) need Java 21 + `firebase-tools`.
GitHub CI handles all of this itself.

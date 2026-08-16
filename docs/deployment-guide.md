# Deployment Guide — Learning Tracker

> Part of the Learning Tracker project documentation. Start at [index.md](./index.md).
> Last verified 2026-08-16 against the repository configuration and source tree.

The shipping path is **Android → Google Play**. iOS is not deployment-ready. Firebase project: **`torah-study-tracker`** (`learning_tracker/firebase.json`'s `flutter.platforms` block). No `.firebaserc` is committed; the `npm run deploy` script itself does not select a project, so direct Firebase CLI deploys should pass `--project torah-study-tracker` explicitly.

## 1. Platform status

| Platform | Status |
|---|---|
| **Android** | Shipping. `applicationId` `com.jcom.torah.learning_tracker`. AAB → Play Store via CI. |
| **iOS** | **Not deployment-ready** — no `Podfile`, no `GoogleService-Info.plist`, absent from `firebase.json`'s platform list. Would need Firebase iOS config + CocoaPods setup before it can build/ship. |

## 2. Android build configuration

`android/app/build.gradle.kts`:
- `applicationId` / `namespace`: `com.jcom.torah.learning_tracker`.
- `minSdk` / `targetSdk` / `compileSdk` / `versionCode` / `versionName`: delegated to Flutter (`flutter.minSdkVersion` etc.) — not pinned in Gradle. App `versionName` comes from `pubspec.yaml` (`1.0.69+1`).
- Java 17 source/target, Kotlin `jvmTarget 17`, core-library desugaring enabled.
- Gradle: AGP `8.11.1`, Kotlin `2.2.20`, google-services `4.4.4`. `gradle.properties` sets `-Xmx8G`.

**Permissions** (`AndroidManifest.xml`): `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`, `VIBRATE`, `ACCESS_COARSE_LOCATION` (local Shabbos/Yom Tov sunset calc). Two deep-link `intent-filter`s (`autoVerify`) handle Firebase email-link auth at `https://torah-study-tracker.firebaseapp.com/sign-in` and tutor invites at `/invite`.

**Signing.** The release `signingConfig` is built from a `key.properties` file (`keyAlias`, `keyPassword`, `storeFile`, `storePassword`) when present; it falls back to debug signing if absent — kept for local dev so `flutter run --release`/`flutter build apk --release` work with no keystore configured. That fallback is **no longer silent**: whenever a release artifact is assembled with the debug keystore, `build.gradle.kts`'s `gradle.taskGraph.whenReady` hook logs a loud, boxed warning (`⚠️  AUD-platform-03: RELEASE artifact is being DEBUG-SIGNED …`) so such a build can never be mistaken for a distributable one. `key.properties` and `keystore.jks` are **CI-injected from secrets — never committed**. `build.yml`'s release job is stricter: its keystore-decode step aborts (exit 1) if `KEYSTORE_BASE64` is empty, and it sets `REQUIRE_RELEASE_SIGNING=true` so the same `whenReady` hook escalates the warning to a hard `GradleException` and refuses to assemble a release artifact without a real `key.properties` — a misconfigured secret can no longer produce a debug-signed APK uploaded as `learning-tracker-release-apk` (AUD-platform-03).

## 3. Firebase

`learning_tracker/firebase.json` declares `functions` (`nodejs22`), `firestore` (rules + indexes), the Firestore/Auth/Functions emulators, and the `flutter` platforms block (**android + dart only — no iOS**). It is the repo's only `firebase.json`; there is no committed `.firebaserc`.

| Component | Deploy command | Source |
|---|---|---|
| Cloud Functions | `cd learning_tracker/functions && npm run deploy` (= `firebase deploy --only functions`; select the project separately) | `learning_tracker/functions/src/index.ts` |
| Firestore rules | `firebase deploy --project torah-study-tracker --only firestore:rules` | `learning_tracker/firestore.rules` |
| Firestore indexes | `firebase deploy --project torah-study-tracker --only firestore:indexes` | `learning_tracker/firestore.indexes.json` (10 composite indexes: 6 on `tutor_grants` and 4 on other collections) |

Cloud Functions build with `tsc` (`npm run build`). Local emulation: `npm run serve` (from `learning_tracker/functions`, functions only; the script expands to `npm run build && firebase emulators:start --only functions`) or `firebase emulators:start --project demo-rules --only firestore` (from `learning_tracker`). The repository's rules and Functions test targets use isolated `demo-rules`/`demo-cf` emulator projects via `make test-rules` and `make test-functions`.

## 4. CI/CD — GitHub Actions

Three workflows in `.github/workflows/`:

### `ci.yml` — continuous integration
Triggers: PRs to `main`/`dev`, pushes to `main`/`dev`/`dev/**`. 9 mostly-parallel jobs:
1. **format-check** — `dart format --set-exit-if-changed`.
2. **analyze** — pub get → `build_runner` → `flutter gen-l10n` → `prepare_asset.dart` → inject Firebase config → `dart analyze --fatal-infos`.
3. **audit** — `make audit` if present (repository enforcement checks).
4. **lint** — `dart run custom_lint` if the package is in deps; **non-blocking** (custom_lint 0.8.1 needs analyzer ^8 but the app forces analyzer ^9 — a known unresolved conflict; failures emit a warning only).
5. **test** — `make validate-calendar test`; enforces the `< 60%` line-coverage floor and uploads coverage/golden-failure artifacts.
6. **test-serial-tools** — serial-tagged tool tests.
7. **firestore-rules** — Java 21 + Node 22 → `firebase emulators:exec --only firestore --project demo-rules` → `node --test functions/test/firestore_rules.test.mjs` + the TQ-9 rule-coverage gate (the old `test/firestore-rules/` Jest suite is absent).
8. **functions** — Node 22 + Java 21 → `make test-functions` (builds and tests Cloud Functions against Firestore/Auth emulators).
9. **arb-parity** — root `make arb-parity` → `tool/arb_parity_check.dart`.

### `build.yml` — Build APK
`workflow_dispatch` only, with a `build_type` choice (release/debug). Sets up Flutter + Java 21, codegen, prepare-asset, secret injection (+ keystore for release), `flutter build apk`, uploads the APK artifact (30-day retention).

### `deploy-play-store.yml` — Deploy to Google Play
Triggers on the configured version-tag patterns (`v[0-9]+.[0-9]+.[0-9]+` and the `-*` suffix form) and `workflow_dispatch` (track choice). The tag suffix selects the Play track (plain → production). Tagged runs derive `versionName` from the tag; manual runs fall back to `pubspec.yaml`. Both use `versionCode = run_number*100 + run_attempt` (re-run-safe), auto-generate release notes from the last 10 commits, run `flutter build appbundle --release`, then upload the AAB to Google Play via `r0adkll/upload-google-play@v1` (`packageName: com.jcom.torah.learning_tracker`).

Before the build/signing job starts, `gate-ci-status` requires a completed successful `ci.yml` run for the exact SHA being deployed.

### Release flow

```text
merge to dev/main  ──►  ci.yml (gate)
tag vX.Y.Z         ──►  deploy-play-store.yml  ──►  AAB  ──►  Play production
tag vX.Y.Z-beta    ──►  deploy-play-store.yml  ──►  AAB  ──►  Play beta track
```

## 5. CI secrets

The workflows consume these GitHub Actions secrets:

| Secret | Use |
|---|---|
| `GOOGLE_SERVICES_JSON_BASE64` | `android/app/google-services.json` |
| `FIREBASE_OPTIONS_DART` | `lib/firebase_options.dart` |
| `KEYSTORE_BASE64`, `KEY_ALIAS`, `KEY_PASSWORD`, `STORE_PASSWORD` | release signing |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | Play Store upload |
| `CODECOV_TOKEN` | coverage upload |

All secret-derived files are cleaned up on `always()` at the end of the build/deploy jobs.

## 6. Store assets

`learning_tracker/tool/screenshots/store_screenshots_test.dart` generates light and dark Play Store screenshot goldens (`phone_1_dashboard` … `phone_5_gamification`) under `learning_tracker/tool/screenshots/goldens/` — a manual asset generator, not a regression test (it lives under `tool/`, not `test/`, and is run explicitly via `flutter test tool/screenshots/store_screenshots_test.dart`, not picked up by `flutter test`/`make ci`). `tool/upload_store_assets.py` uploads the listing/screenshots/icon/feature-graphic via the Android Publisher API (it does not upload the APK/AAB — that is `deploy-play-store.yml`'s job). Raw store assets live in `store_assets/`.

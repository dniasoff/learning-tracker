# Deployment Guide — Learning Tracker

> Part of the Learning Tracker project documentation. Start at [index.md](./index.md).
> Generated 2026-05-19 by an exhaustive codebase scan (BMAD `document-project` workflow).

The shipping path is **Android → Google Play**. iOS is not deployment-ready. Firebase project: **`torah-study-tracker`** (`learning_tracker/firebase.json`'s `flutter.platforms` block; deploy commands pass `--project torah-study-tracker` explicitly — no committed `.firebaserc`).

## 1. Platform status

| Platform | Status |
|---|---|
| **Android** | Shipping. `applicationId` `com.jcom.torah.learning_tracker`. AAB → Play Store via CI. |
| **iOS** | **Not deployment-ready** — no `Podfile`, no `GoogleService-Info.plist`, absent from `firebase.json`'s platform list. Would need Firebase iOS config + CocoaPods setup before it can build/ship. |

## 2. Android build configuration

`android/app/build.gradle.kts`:
- `applicationId` / `namespace`: `com.jcom.torah.learning_tracker`.
- `minSdk` / `targetSdk` / `compileSdk` / `versionCode` / `versionName`: delegated to Flutter (`flutter.minSdkVersion` etc.) — not pinned in Gradle. App `versionName` comes from `pubspec.yaml` (`1.0.61+1`).
- Java 17 source/target, Kotlin `jvmTarget 17`, core-library desugaring enabled.
- Gradle: AGP `8.11.1`, Kotlin `2.2.20`, google-services `4.4.4`. `gradle.properties` sets `-Xmx8G`.

**Permissions** (`AndroidManifest.xml`): `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`, `VIBRATE`, `ACCESS_COARSE_LOCATION` (local Shabbos/Yom Tov sunset calc). A deep-link `intent-filter` (`autoVerify`) handles Firebase email-link auth at `https://torah-study-tracker.firebaseapp.com/sign-in`.

**Signing.** The release `signingConfig` is built from a `key.properties` file (`keyAlias`, `keyPassword`, `storeFile`, `storePassword`) when present; it falls back to debug signing if absent. `key.properties` and `keystore.jks` are **CI-injected from secrets — never committed**.

## 3. Firebase

`learning_tracker/firebase.json` declares `functions` (`nodejs20`), `firestore` (rules + indexes), the Firestore/Auth/Functions emulators, and the `flutter` platforms block (**android + dart only — no iOS**). It is the repo's only `firebase.json`; a duplicate repo-root `firebase.json`/`.firebaserc` pair pointing at nonexistent root-level `firestore.rules`/`firestore.indexes.json` was removed as dead config (AUD-firebase-14).

| Component | Deploy command | Source |
|---|---|---|
| Cloud Functions | `cd functions && npm run deploy` (= `firebase deploy --only functions`) | `functions/src/index.ts` |
| Firestore rules | `firebase deploy --only firestore:rules` | `firestore.rules` |
| Firestore indexes | `firebase deploy --only firestore:indexes` | `firestore.indexes.json` (currently empty) |

Cloud Functions build with `tsc` (`npm run build`). Local emulation: `npm run serve` (functions) or `firebase emulators:start --only firestore`.

## 4. CI/CD — GitHub Actions

Three workflows in `.github/workflows/`:

### `ci.yml` — continuous integration
Triggers: PRs to `main`/`dev`, pushes to `main`/`dev`/`dev/**`. 8 mostly-parallel jobs:
1. **format-check** — `dart format --set-exit-if-changed`.
2. **analyze** — pub get → `build_runner` → `prepare_asset.dart` → inject Firebase config → `dart analyze --fatal-infos`.
3. **audit** — `make audit` if present (layering enforcement greps).
4. **lint** — `dart run custom_lint` if the package is in deps; **non-blocking** (custom_lint 0.8.1 needs analyzer ^8 but the app forces analyzer ^9 — a known unresolved conflict; failures emit a warning only).
5. **test** — `make ci`; uploads golden-failure artifacts on failure.
6. **coverage-floor** — fails if line coverage `< 60%`; uploads to Codecov.
7. **firestore-rules** — Java 21 + Node 22 → `firebase emulators:exec --only firestore` → Jest.
8. **arb-parity** — `tool/arb_parity_check.dart`.

### `build.yml` — Build APK
`workflow_dispatch` only, with a `build_type` choice (release/debug). Sets up Flutter + Java 21, codegen, prepare-asset, secret injection (+ keystore for release), `flutter build apk`, uploads the APK artifact (30-day retention).

### `deploy-play-store.yml` — Deploy to Google Play
Triggers on semver tags (`v[0-9]+.[0-9]+.[0-9]+`, optionally with `-alpha`/`-beta`/`-internal` suffix) and `workflow_dispatch` (track choice). The tag suffix selects the Play track (plain → production). Derives `versionName` from the tag and `versionCode = run_number*100 + run_attempt` (re-run-safe), auto-generates release notes from the last 10 commits, `flutter build appbundle --release`, then uploads the AAB to Google Play via `r0adkll/upload-google-play@v1` (`packageName: com.jcom.torah.learning_tracker`).

### Release flow

```text
merge to dev/main  ──►  ci.yml (gate)
tag v1.0.62        ──►  deploy-play-store.yml  ──►  AAB  ──►  Play production
tag v1.0.62-beta   ──►  deploy-play-store.yml  ──►  AAB  ──►  Play beta track
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

`learning_tracker/test/golden/store_screenshots_test.dart` generates Play Store screenshots as golden images (`phone_1_dashboard` … `phone_5_gamification`). `tool/upload_store_assets.py` uploads the listing/screenshots/icon/feature-graphic via the Android Publisher API (it does not upload the APK/AAB — that is `deploy-play-store.yml`'s job). Raw store assets live in `store_assets/`.

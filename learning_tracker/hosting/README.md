# Firebase Hosting — deep-link verification host (AUD-platform-01)

This site is what makes `https://torah-study-tracker.firebaseapp.com`
resolvable at all. Before this finding, `firebase.json` had no `hosting`
block, so the domain root, `/sign-in`, `/invite`, and
`/.well-known/assetlinks.json` all 404'd — confirmed live on 2026-07-03 and
re-confirmed on 2026-07-19 (`curl -sI` against the domain still returns 404
with no `hosting` block present). Android's App Links verifier requires
`assetlinks.json` to resolve with HTTP 200 before it will honor the
`android:autoVerify="true"` intent-filters in
`android/app/src/main/AndroidManifest.xml` for the `/sign-in` and `/invite`
paths (used by the Firebase email-link sign-in and tutor-invite-accept
flows — see `lib/features/account/data/repositories/auth_repository_impl.dart`).
Until this resolves, both flows dead-end: the OS falls back to the system
browser, which also 404s.

## `.well-known/assetlinks.json` is intentionally NOT a static file here

Firebase Hosting auto-serves `/.well-known/assetlinks.json` (and
`apple-app-site-association`) itself, derived from the SHA-256 certificate
fingerprints registered against this project's Android app
(`1:346569574648:android:3519edaeb5ce5df9d6130d`, package
`com.jcom.torah.learning_tracker`) — this is the `appAssociation` hosting
feature (default `AUTO`; would need `"appAssociation": "NONE"` in
`firebase.json` to disable, which this config deliberately does not set).
Hand-authoring a static `.well-known/assetlinks.json` in `hosting/public/`
would fight that mechanism and risk drifting out of sync with whatever
fingerprints are actually registered. **Do not add one here.**

## What still has to happen before this is live (cannot be done from a code change alone)

1. **Register the release signing certificate's SHA-256 fingerprint.**
   Because `deploy-play-store.yml` uploads an App Bundle, Google Play App
   Signing re-signs the artifact users actually download — the fingerprint
   that must be registered is the **app signing key certificate** from
   Play Console → *Setup → App integrity*, **not** the upload-keystore
   fingerprint `deploy-play-store.yml` already prints via `keytool`
   (`Print upload key SHA fingerprints` step). Only a human with Play
   Console access can read it.
2. **Register that fingerprint with the Firebase project**, e.g.:
   ```
   firebase apps:android:sha:create 1:346569574648:android:3519edaeb5ce5df9d6130d \
     <SHA256_FROM_PLAY_CONSOLE> --project torah-study-tracker
   ```
   (or via the Firebase console: Project Settings → the Android app →
   "Add fingerprint"). This step needs an authenticated `firebase` CLI
   session / service account — not available inside an isolated worktree
   with no deploy credentials.
3. **Deploy hosting**: `firebase deploy --only hosting --project
   torah-study-tracker`.
4. **Verify**: `tool/check_assetlinks_live.sh` (wired into
   `.github/workflows/deploy-firebase-hosting.yml`) curls
   `https://torah-study-tracker.firebaseapp.com/.well-known/assetlinks.json`
   and fails the pipeline if it isn't HTTP 200 with the expected
   `package_name`.
5. **On-device confirmation** (AC2): once 1–4 are live, install a release
   (or a debug build signed with a certificate also registered per step 2)
   build on a real or emulated Android device and tap a sign-in
   continuation link / tutor-invite link from an email client — it should
   open the app directly, not the browser.

Steps 1–2 need a human with Play Console access; step 3 needs deploy
credentials this repo's CI does not yet have wired for Hosting (only Play
Store upload is currently automated, via `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`).
`.github/workflows/deploy-firebase-hosting.yml` documents the new secrets
(`FIREBASE_TOKEN`, `PLAY_APP_SIGNING_SHA256`) a repo admin needs to add
before this workflow can run end-to-end.

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

## `.well-known/assetlinks.json` is a committed static file

**History:** this was originally left to Firebase Hosting's `appAssociation`
`AUTO` feature, which is *documented* to auto-serve `/.well-known/assetlinks.json`
derived from the SHA-256 fingerprints registered against this project's Android
app (`1:346569574648:android:3519edaeb5ce5df9d6130d`, package
`com.jcom.torah.learning_tracker`). **In practice, verified live on 2026-07-21,
AUTO serves an empty `[]`** even with a SHA-256 fingerprint registered on the app
(`cache-control: private, no-store`, so the empty body is live, not stale). The
AUTO generator only includes an app once it is *linked to this specific Hosting
site*, a console-side association that the `firebase` CLI cannot set — so relying
on AUTO dead-ends the App Links verifier exactly as a missing file would.

We therefore serve a **static** `hosting/public/.well-known/assetlinks.json`
(Firebase's default `ignore: ["**/.*"]` does NOT exclude it — the glob only
matches a leaf segment starting with `.`, and `assetlinks.json` does not — so it
deploys and is served with precedence over AUTO). The array holds the SHA-256 of
every signing certificate whose builds must verify App Links.

**The fingerprint currently committed is this repo's Android *debug* keystore
SHA-256** (`53:A8:90:…:46:38`), which is what local/`flutter build apk --debug`
builds are signed with — sufficient to verify the flow end-to-end on a device
(done 2026-07-21: `/sign-in` and `/invite` open `.MainActivity` directly, not the
browser). **For production you MUST add the Play App Signing key's SHA-256** to
the `sha256_cert_fingerprints` array (see step 1 below) and redeploy — a
Play-distributed build is re-signed by Google and will otherwise not verify.
Multiple fingerprints are allowed; keep the debug one for local testing and add
the release one alongside it.

## Status: verified live for debug (2026-07-21); production needs the release SHA

The hosting block, the static `assetlinks.json` (debug SHA), and the deploy were
done and verified on 2026-07-21: `firebase deploy --only hosting` →
`tool/check_assetlinks_live.sh` PASSES (HTTP 200, valid entry) → on an Android-34
emulator, `/sign-in` and `/invite` open the app directly once the domain is
verified against the live file. The **only** remaining step for production is
adding the Play App Signing SHA-256:

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

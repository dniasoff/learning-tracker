---
title: "App Check Enforcement Status"
description: "Current Firebase App Check enforcement status and the gating criteria (CI/device token registration, metrics review) that must be met before flipping enforcement on, per PV-6."
date: 2026-07-29
---

# App Check Enforcement Status

This document is the record PV-6 (`docs/coding-standards.md`) points to. It tracks whether
Firebase App Check enforcement has been flipped on for this project, and what has to be true
before it is.

## Current status: **Firestore ENFORCED** (confirmed via API, 2026-07-29)

Firebase App Check enforcement for **Cloud Firestore is ENFORCED** on the `torah-study-tracker`
project (verified directly:
`GET firebaseappcheck.googleapis.com/v1/projects/346569574648/services/firestore.googleapis.com`
→ `enforcementMode=ENFORCED`). Functions/Storage were not returned as enforced at that check.

> **This document previously (and wrongly) read "not enforced."** It was created 2026-07-13 and
> never updated when the console toggle was flipped, in exactly the manner the "update the status
> line the same day" instruction warns against. That staleness is what made the incident below
> take a full investigation to diagnose. Keep this line honest.

- `learning_tracker/lib/app/bootstrap/firebase_bootstrap.dart` activates App Check
  (`FirebaseAppCheck.instance.activate(...)`) in a non-fatal `try`/`catch` — a failed/missing
  attestation is logged (`app_check_activation_failed`) and startup continues local-first. **But
  with enforcement ON, every Firestore request is then rejected `PERMISSION_DENIED`.**
- Debug builds (`kDebugMode`) use `AndroidDebugProvider` / `AppleDebugProvider`; release builds use
  `AndroidPlayIntegrityProvider` / `AppleAppAttestProvider`.

### Incident (2026-07-29): enforcement on before Play Integrity was functional

Enforcement was flipped on for Firestore **without gating criterion 3 (and the Play Integrity
prerequisites) actually met**. On the 1.0.67 Play internal build, fresh installs showed
"Cloud backup is temporarily unavailable" and Send-Diagnostic-Logs failed — because:

- the **Play Integrity API (`playintegrity.googleapis.com`) was DISABLED** in the project, so
  release builds could not obtain an App Check token (`Error getting App Check token … Too many
  attempts`), and
- the **Play App Signing SHA-256 was not registered** in Firebase.

Emulator/debug builds were unaffected (they use the *debug* provider with a registered token),
which is why all on-device testing passed while production was broken.

**Remediation applied 2026-07-29** (enforcement kept ON):
1. Enabled `playintegrity.googleapis.com` in project 346569574648.
2. Registered the Play App Signing SHA-256 (`2fb5354664f2440547b37365bbd76f76af14a3156e78d3a1c281f71dccabd27f`)
   and the upload key SHA-256 in the Firebase Android app.
3. Confirmed the Play Integrity provider is registered (`playIntegrityConfig`, `NO_INTEGRITY`);
   the Play↔project link is Google-managed for App Check.

This is a manually-maintained record — **update the status line above the same day the Firebase
console enforcement toggle changes** for any of Firestore, Functions, or Storage.

## Debug-token operational procedure

A fresh cloud sign-in requires **two** App Check debug tokens. The default `FirebaseApp` mints
one token, and the app also creates a separate named, per-account `FirebaseApp`, which mints its
own distinct token. Both tokens must be registered in the Firebase App Check debug-token registry;
registering only the default app's token is the common mistake and makes sign-in fail with
`permission-denied` / `403`, which can look like an authentication bug.

The debug-token registry has a hard cap of **20 tokens per app registration**. Once the cap is
full, new registrations fail until stale entries are pruned. Repeated device testing reaches this
cap routinely because every fresh device state generates new tokens, so prune stale entries as part
of test setup rather than waiting for registration to fail.

Debug tokens are stored in the app's SharedPreferences at
`shared_prefs/com.google.firebase.appcheck.debug.store*.xml` and are regenerated whenever that
state is cleared, including `adb shell pm clear <pkg>`, an emulator `-wipe-data` boot, or any
first-run reset. A token registered before such a reset is dead afterwards. Any test-harness seed
flow that clears app data (for example, a launch-with-clear step) therefore invalidates a
pre-registered token: register tokens **after** the clear, not before it.

Do not try to determine whether a token is already registered by decoding registry resource IDs.
Those IDs are opaque, server-assigned identifiers, not a base64 or otherwise reversible encoding
of the raw token. There is no client-side way to map a local token to a registry entry;
re-registering is safe and is the correct approach when in doubt.

## Gating criteria (all required before flipping enforcement on)

1. **CI tokens registered** — every CI runner that exercises Firestore/Functions/Storage has a
   registered App Check debug token in the Firebase console allowlist (capped at 20 — prune
   stale entries first).
2. **Device tokens registered** — active development/test devices have registered debug tokens,
   and the team has a documented process for re-registering a token after a data wipe (wipes
   regenerate the debug token, which otherwise causes `403 permission-denied` outages — see the
   on-device test setup notes).
3. **Metrics reviewed** — the Firebase App Check "Metrics" tab has been reviewed for an
   acceptable verified-vs-rejected request ratio across a representative window, so flipping
   enforcement does not lock out legitimate clients.

Only once all three are true should enforcement be switched from monitor-only to enforced, and
this document updated to reflect it.

## Related [Pending] items (PV-6)

These are named in PV-6's `Enforce` line and are tracked there, not duplicated here:

- Audit grep confining App Check symbols to the bootstrap module.
- Audit grep asserting no UUID-shaped debug token is committed to the tree.
- Secret-scanning CI step for App Check debug tokens.

## Source

- `learning_tracker/lib/app/bootstrap/firebase_bootstrap.dart`
- `docs/coding-standards.md` — PV-6
- firebase.google.com/docs/app-check/flutter/debug-provider, /monitor-metrics

---
title: "App Check Enforcement Status"
description: "Current Firebase App Check enforcement status and the gating criteria (CI/device token registration, metrics review) that must be met before flipping enforcement on, per PV-6."
date: 2026-07-13
---

# App Check Enforcement Status

This document is the record PV-6 (`docs/coding-standards.md`) points to. It tracks whether
Firebase App Check enforcement has been flipped on for this project, and what has to be true
before it is.

## Current status: **not enforced**

Firebase App Check enforcement for Firestore/Functions/Storage has **not** been flipped on for
the `torah-study-tracker` project. The codebase runs in the pre-enforcement state described by
PV-6:

- `learning_tracker/lib/app/bootstrap/firebase_bootstrap.dart` activates App Check
  (`FirebaseAppCheck.instance.activate(...)`) but the call is wrapped in a non-fatal `try`/`catch`
  — a failed or missing attestation is logged (`app_check_activation_failed`) and startup
  continues in local-first mode.
- Debug builds (`kDebugMode`) use `AndroidDebugProvider` / `AppleDebugProvider`; release builds use
  `AndroidPlayIntegrityProvider` / `AppleAppAttestProvider`.
- No CI step or `make audit` check currently confirms that CI runners' or developers' debug
  tokens are registered, and no attestation-failure metrics have been reviewed against an
  enforcement decision.

Because none of the gating criteria below have been met, enforcement must stay off. This is a
manually-maintained record — update the status line above the same day the Firebase console
enforcement toggle changes for any of Firestore, Functions, or Storage.

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

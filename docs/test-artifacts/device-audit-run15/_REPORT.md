---
title: "Device Audit Run 15 — Learning and Content Browsing"
description: "Re-audit of device 5560 after the active-account provider-cycle fix in the rebuilt v1.0.72-internal APK."
date: 2026-08-19
---

# Device Audit Run 15 — Learning and Content Browsing

## Executive answers

- **Sign-in on `emulator-5560`: NOT STABLE for the clean re-audit.** The initial seed flow signed in and reached Track Ready, but after the specified device reconnect and clean app reset, Firebase Auth accepted the credentials and the named-account handoff failed with `AccountNotAuthenticatedException`; the UI returned to Sign In.
- **Mark Complete persistence: UNTESTABLE.** No learning detail screen was reachable after the clean re-audit failure.
- **Final coverage:** Learning + Completion **0/4**; Content Browsing **0/4**; **0/8 total**.

## Scope

- **Device:** `emulator-5560` (Pixel 7, API 34)
- **Package:** `com.jcom.torah.learning_tracker`
- **Build:** `1.0.72`, rebuilt from HEAD `d2f45fbc` (`fix` commit already present: `8ee7e47d`)
- **APK:** `learning_tracker/build/app/outputs/flutter-apk/app-debug.apk`, mtime `2026-08-19 22:38:08 +0200` (after the fix commit)
- **Areas:** Learning + Completion; Content Browsing
- **Assigned:** 8 screens total (4 per area)
- **Run condition:** rebuilt debug APK, real cloud account, admin-verified email, and both App Check debug tokens registered after each app-data reset

## Seed and sign-in evidence

The rebuilt APK installed successfully. The initial seed flow created and admin-verified a real
cloud account, then completed profile and active-track setup. The app visibly reached `Track Ready!`
for the `משניות` track, confirming that this first in-process sign-in/session path and track seed
completed before the emulator process exited.

- Email: `e2e-run15-5560-1787171981@example.com`
- Firebase UID: `dpPL0RdUIUgYBuF4a1mpTsFug9y2`
- Profile: `Abba` (adult mode)
- Track: `משניות`, one active track

After the emulator reconnect, the named Firebase session was no longer available to the running
process. A clean `pm clear` was performed, and the newly generated App Check tokens were registered
after that reset:

- Default FirebaseApp token: `18bc3bdd-7fd8-439a-9270-47d828a622f3`
- Named per-account FirebaseApp token: `f4029980-8338-4cb1-a520-b04e4353a25f`

The registry had reached its 20-token cap during setup; stale entries were pruned before the new
tokens were registered. The default and named tokens were both accepted for registration.

On the clean re-audit sign-in, Firebase Auth logged the credential exchange and accepted the user,
but the app then surfaced:

```text
AccountNotAuthenticatedException: account "dpPL0RdUIUgYBuF4a1mpTsFug9y2" has no authenticated Firebase session — call createAnonymousAccount or signInCloudAccount before resolve.
```

The failure came from `activeAccountFirebaseProvider` while the named account session was not
available, and the UI returned to the Sign In form. No `CircularDependencyError` was observed in
this run. The emulator's connectivity state also briefly reported airplane/offline status during
the retries; Wi-Fi was restored and validated before the final retry, but the same session-handoff
failure remained.

## Verdict

**BLOCKED — the provider-cycle regression is absent, but clean sign-in/session handoff is not
confirmed fixed.** The initial seed process reached Track Ready, but the clean post-reset re-entry
needed to exercise the target areas failed after Firebase Auth acceptance and before the app shell.

- **Root Cause A (sign-in): NOT CONFIRMED FIXED on the clean re-audit.** Auth accepted the credentials, but the named-account Firebase session was unavailable to the active-account resolution path and the UI returned to Sign In. The prior `CircularDependencyError` did not recur.
- **Root Cause C (mark-complete persistence): UNTESTABLE.** No learning detail screen was reachable in the final clean run.

## Coverage

### Area 1 — Learning + Completion

| Screen | Result | Note |
|---|---|---|
| LearningScreen / Daily Tasks | UNREACHABLE | Clean sign-in/session handoff failed before the app shell. |
| Learning detail / Hebrew text display | UNREACHABLE | Not reached. |
| Hebrew-Text / English-Translation chips and task controls | UNREACHABLE | Not reached. |
| Mark complete + next daily task persistence | UNTESTED | Root Cause C could not be exercised. |

**Coverage: 0/4 passed.**

### Area 2 — Content Browsing

| Screen | Result | Note |
|---|---|---|
| CurriculumList | UNREACHABLE | Clean sign-in/session handoff failed before the app shell. |
| ContentHierarchy | UNREACHABLE | Curriculum/seder/masechta/perek navigation not reached. |
| ContentSearch | UNREACHABLE | Hebrew and English queries were not attempted. |
| TextDisplay | UNREACHABLE | No text page was reached. |

**Coverage: 0/4 passed.**

**Total coverage: 0/8 passed (0%).**

## Findings

| Device / Screen | Finding | Suggested fix location | Severity |
|---|---|---|---|
| `emulator-5560` / clean cloud sign-in → named account session handoff | Firebase Auth accepted the credentials, but `activeAccountFirebaseProvider` resolved an `AccountNotAuthenticatedException` for the signed-in UID before a usable named-account Firebase session was available. The UI returned to Sign In. This remained after registering both fresh App Check tokens and restoring validated Wi-Fi. No `CircularDependencyError` recurred. | `learning_tracker/lib/features/account/presentation/notifiers/sign_in_controller.dart` session-establishment ordering; `learning_tracker/lib/data/firestore/active_account_providers.dart` resolution path | P0 |

## Out of scope / not run

No Flutter tests, `dart analyze`, `make audit`, `build_runner`, or source-file changes were made.

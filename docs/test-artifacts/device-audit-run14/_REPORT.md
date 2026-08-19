---
title: "Device Audit Run 14 — Learning and Content Browsing"
description: "Focused re-audit of device 5560's previously untested Learning and Content Browsing areas after the v1.0.72-internal Root Cause A and C fixes."
date: 2026-08-19
---

# Device Audit Run 14 — Learning and Content Browsing

## Scope

- **Device:** `emulator-5560` (Pixel 7, API 34)
- **Build:** `1.0.72` (`learning_tracker/build/app/outputs/flutter-apk/app-debug.apk`)
- **Package:** `com.jcom.torah.learning_tracker`
- **Areas:** Learning + Completion; Content Browsing
- **Assigned:** 8 screens total (4 per area)
- **Run condition:** clean app state, real cloud sign-up, admin-verified email, and both App Check debug tokens registered after the clear

The run could not pass the sign-in handoff. Firebase Auth accepted the credentials, but the
post-auth account/session setup failed before a learner profile or active track could be created.
Consequently, no Learning or Content Browsing screen was reachable and no downstream behavior is
reported as observed.

## Seed and sign-in evidence

The app was cleared, launched, and the supplied APK installed successfully. A real cloud account
was created and email-verified server-side:

- Email: `e2e-run14-5560-1787167231@example.com`
- Firebase UID: `YC6HKBNvqDcoSlt6NHxBZadxeCy1`
- Firebase Auth signup completed and returned to the Sign In screen with the expected verification
  message.

The clean launch generated the default App Check token
`de1dc4a7-698e-4802-afc4-c2d06733cc07`. After the named per-account FirebaseApp was initialized,
it generated the distinct token `9d8632ea-4f15-4ee0-b69b-bd35bef0f1f0`. The registry was at its
20-token cap, so two stale June entries were pruned and both run14 tokens were registered before
the final sign-in retry.

After both tokens were registered, Firebase Auth accepted the same credentials, but the app then
logged:

```text
CircularDependencyError: Circular dependency detected.
FutureProvider<AccountFirebaseHandles?>#c17f4
#2 ActiveAccountId.set.<anonymous closure>
  (package:learning_tracker/data/firestore/active_account_providers.dart:54:35)
```

The subsequent profile query failed as:

```text
Firestore: Listen for QueryWrapper(query=Query(target=Query(users/YC6HKBNvqDcoSlt6NHxBZadxeCy1 order by __name__);limitType=LIMIT_TO_FIRST)) failed: Status{code=PERMISSION_DENIED, description=Missing or insufficient permissions., cause=null}
```

The UI returned to the Sign In form. The final failure state was captured in
`/tmp/run14-signin-attempt2.png`.

## Verdict

**BLOCKED — Root Cause A is not confirmed fixed; this run reproduced a post-auth session-handoff
failure.** The default Firebase Auth sign-in succeeded, but `ActiveAccountId.set` triggered a
Riverpod circular-dependency error while the named account session was being established. The
resulting Firestore permission-denied profile read prevented onboarding and blocked all eight target
screens.

- **Root Cause A (sign-in): NOT FIXED on this device.** Auth credentials were accepted, but the
  account/session handoff did not complete.
- **Root Cause C (mark-complete persistence): UNTESTABLE.** No learning detail screen was reachable,
  so no completion could be attempted or checked for persistence/advancement.

## Coverage

### Area 1 — Learning + Completion

| Screen | Result | Note |
|---|---|---|
| LearningScreen / Daily Tasks | UNREACHABLE | Sign-in handoff failed before a profile and track existed. |
| Learning detail / Hebrew text display | UNREACHABLE | Not reached. |
| Hebrew-Text / English-Translation chips and task controls | UNREACHABLE | Not reached. |
| Mark complete + next daily task persistence | UNTESTED | Root Cause C could not be exercised. |

**Coverage: 0/4 passed.**

### Area 2 — Content Browsing

| Screen | Result | Note |
|---|---|---|
| CurriculumList | UNREACHABLE | Sign-in handoff failed before the app shell. |
| ContentHierarchy | UNREACHABLE | Curriculum/seder/masechta/perek navigation not reached. |
| ContentSearch | UNREACHABLE | Hebrew and English queries were not attempted. |
| TextDisplay | UNREACHABLE | No text page was reached. |

**Coverage: 0/4 passed.**

**Total coverage: 0/8 passed (0%).**

## Findings

| Device / Screen | Finding | Suggested fix location | Severity |
|---|---|---|---|
| `emulator-5560` / cloud sign-in → account session handoff | After Firebase Auth accepted the credentials, `ActiveAccountId.set` triggered a Riverpod `CircularDependencyError` at `active_account_providers.dart:54`. The subsequent `users/{uid}` profile query returned `PERMISSION_DENIED`, and the UI returned to Sign In. Reproduced after registering both fresh App Check debug tokens. | `learning_tracker/lib/data/firestore/active_account_providers.dart:54`; inspect the invalidation triggered by `ActiveAccountId.set` and the `_navigateAfterSignIn` ordering in `learning_tracker/lib/features/account/presentation/notifiers/sign_in_controller.dart`. | P0 |

## Out of scope / not run

No Flutter tests, `dart analyze`, `make audit`, `build_runner`, or source-file changes were made.

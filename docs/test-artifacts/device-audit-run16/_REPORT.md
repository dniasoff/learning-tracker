---
title: "Device Audit Run 16 — Learning and Content Browsing"
description: "On-device audit of device 5560 after the bootstrap session guard, with sign-in blocked before the target areas."
date: 2026-08-19
---

# Device Audit Run 16 — Learning and Content Browsing

## Executive answers

- **Sign-in on `emulator-5560`: NO.** Firebase Auth accepted correctly formed credentials for the seeded account, but the first account Firestore lookup returned `PERMISSION_DENIED`; a clean re-entry with no local account then reached `AccountRepositoryNotReadyException`. A later fresh account was created and email-verified, but the final adb retry had a malformed email field and was rejected before navigation.
- **Mark Complete persistence: UNTESTABLE.** No learning detail screen was reachable.
- **Final coverage:** Learning + Completion **0/4**; Content Browsing **0/4**; **0/8 total**.

## Scope

- **Device:** `emulator-5560` (Pixel 7, API 34)
- **Package:** `com.jcom.torah.learning_tracker`
- **Build:** `1.0.72` debug APK, rebuilt from HEAD `d2f45fbc` with the uncommitted bootstrap session-guard fix present in the working tree
- **APK:** `learning_tracker/build/app/outputs/flutter-apk/app-debug.apk`, mtime `2026-08-19 23:27:01 +0200`; newer than the bootstrap edit (`2026-08-19 23:23:52 +0200`)
- **Areas:** Learning + Completion; Content Browsing
- **Assigned:** 8 screens total (4 per area)
- **Run condition:** APK installed successfully; the device registry was verified empty before the first clean seed; App Check registry capacity was reached and stale entries were pruned; fresh default and named debug tokens were registered after each app-data reset

## Seed and sign-in evidence

The first fresh account was created in-app and server-side email-verified:

- Email: `e2e-run16b-5560-1787175202@example.com`
- Firebase UID: `QJPB5dan5gXbkPwlWbOmWK0zqaI2`
- Password: `Run16Pass123`

With the correctly formed credentials, Firebase Auth logged a successful exchange and notified the app of the signed-in UID. The named per-account FirebaseApp generated a separate debug token; after that token and the default token were registered, the next attempt still failed at the account lookup:

```text
Listen for QueryWrapper(query=Query(target=Query(users/QJPB5dan5gXbkPwlWbOmWK0zqaI2 order by __name__);limitType=LIMIT_TO_FIRST)) failed: Status{code=PERMISSION_DENIED, description=Missing or insufficient permissions., cause=null}
```

No `CircularDependencyError` appeared in this run. A subsequent `pm clear` intentionally reset app data and regenerated both local debug tokens. The app was relaunched, the new default token was registered, and a second fresh account was created and email-verified:

- Email: `e2e-run16c-5560-1787175723@example.com`
- Firebase UID: `cUKzO2mdc9WHGNUaSa1YXEhv3aV2`

That signup completed in-app and the email was verified through Identity Toolkit. The final sign-in form, however, visibly contained `ee2e-run16c-...` after adb field editing; the resulting Auth attempt was rejected as malformed credentials. No profile or active track was created, and the target audit flows were not reached.

The sign-in form screenshot was captured and visually inspected. It showed the app's normal `Get Started` cloud-account form, with the malformed email visible, password field, and Sign In button; no app shell, Learning, or Browse screen was visible.

## Verdict

**BLOCKED — Learning and Content Browsing remain unaudited.** The rebuilt APK installed, Auth acceptance was observed for a correctly formed account, and the provider-cycle regression did not recur. The account handoff still did not reach a usable signed-in app state, so neither target area could be exercised.

- **Root Cause A (sign-in): NOT CONFIRMED FIXED on this run.** No circular-dependency error was observed, but the correctly formed clean sign-in stopped at Firestore `PERMISSION_DENIED`, and a later clean re-entry with no local account produced `AccountRepositoryNotReadyException`.
- **Root Cause C (mark-complete persistence): UNTESTABLE.** No learning detail screen was reachable.

## Coverage

### Area 1 — Learning + Completion

| Screen | Result | Note |
|---|---|---|
| LearningScreen / Daily Tasks | UNREACHABLE | Sign-in did not reach the app shell. |
| Learning detail / Hebrew text display | UNREACHABLE | Not reached. |
| Hebrew-Text / English-Translation chips and task controls | UNREACHABLE | Not reached. |
| Mark complete + next daily task persistence | UNTESTED | Root Cause C could not be exercised. |

**Coverage: 0/4 passed.**

### Area 2 — Content Browsing

| Screen | Result | Note |
|---|---|---|
| CurriculumList | UNREACHABLE | Sign-in did not reach the app shell. |
| ContentHierarchy | UNREACHABLE | Curriculum/seder/masechta/perek navigation not reached. |
| ContentSearch | UNREACHABLE | Hebrew and English queries were not attempted. |
| TextDisplay | UNREACHABLE | No text page was reached. |

**Coverage: 0/4 passed.**

**Total coverage: 0/8 passed (0%).**

## Findings

| Device / Screen | Finding | Suggested fix location | Severity |
|---|---|---|---|
| `emulator-5560` / clean cloud sign-in → account lookup | Firebase Auth accepted correctly formed credentials, but the first Firestore account query for the signed-in UID returned `PERMISSION_DENIED` after both fresh App Check debug tokens had been registered. | App Check enforcement/registration procedure and the sign-in account-handoff path; inspect `learning_tracker/lib/data/firestore/active_account_providers.dart` and account repository resolution | P0 |
| `emulator-5560` / clean re-entry with empty device registry | After app data was cleared, the bootstrap guard did not invent an active device account; the app logged `AccountRepositoryNotReadyException: no active device account` and remained out of the app shell. | `learning_tracker/lib/app/bootstrap/bootstrap.dart` and the sign-in flow that establishes the local device account after cloud authentication | P0 |

## Out of scope / not run

No Flutter tests, `dart analyze`, `make audit`, `build_runner`, or source-file changes were made for this audit. The working tree already contained the bootstrap source/test changes and the run15 report before run16; they were preserved.

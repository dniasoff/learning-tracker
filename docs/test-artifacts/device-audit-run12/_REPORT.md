# On-Device Audit — Run 12 Report

## Scope

- **Run:** 12 — 3-device parallel on-device E2E re-audit; **first on-device validation pass against the post-Drift→Firestore-migration build.** Runs 1–11 all predate the migration (baseline `f8b42240`, 518 commits and a full sync/auth/data-layer rewrite ago) and are **not** a continuation of that scorecard — treat this run as a fresh baseline.
- **Build under test:** current `dev` HEAD `f9818b55`.
- **Preconditions:** full `flutter test` suite (783 files, serialized-verified) and `make audit` are both **green**. This run exists specifically to check what those can't see — real on-device UX/rendering/navigation behavior.
- **Devices / areas:** emulator-5560 (dashboard, learning, content, tracks, scheduler), emulator-5554 (profiles_childmode, settings, auth_account, infra), emulator-5562 (gamification, progress, tutoring, hebrew_rtl).
- **Verification:** every candidate finding was adversarially re-verified against source + screenshot/logcat evidence before being counted. This report additionally re-verified the two largest clusters directly against current HEAD (`git log`, `grep`) — see Root Causes below.

---

## Executive Summary

**Gate verdict: FAIL.**

One defect blocks nearly the entire app: **cloud email/password (and Google) sign-in is unconditionally broken on this build.** `AccountFirebase.signInCloudAccount()` / `createAnonymousAccount()` — the only methods that authenticate the per-account named-FirebaseApp session that all Firestore data access depends on — are fully implemented but have **zero production call sites anywhere in `lib/`** (independently re-confirmed by this report: `grep -rn ".signInCloudAccount(\|.createAnonymousAccount(" learning_tracker/lib/` returns nothing outside definitions/tests). Firebase Auth itself succeeds on every attempt; ~150ms–1s later `AccountFirebase.resolve()` throws `AccountNotAuthenticatedException` and the user is bounced back to a generic "Sign-in failed" toast. This reproduced deterministically on **all 3 devices, both locales (EN + Hebrew), for every account tried** — it is not a race, a flake, or device-specific.

Practical effect: **the authenticated surface of the app is effectively unaudited this run**, not merely "failing." Of 72 assigned screens, only 7 were reachable (all via device-local/childmode-adjacent paths that don't require a fresh cloud round-trip); the other 65 were blocked behind this sign-in wall, not independently exercised. Treat the 21-finding count below as a **floor**, not a ceiling — Dashboard, Learning, Content, Tracks, Scheduler, Progress, Tutoring, and most of Settings/Gamification/Auth are unverified beyond what could be reached before the wall.

- **Findings filed: 24. Confirmed as real app defects: 21** (3 reclassified — see Rejected section; all 3 were the same "no offline-account UI" observation, contradicted by direct evidence at HEAD that its removal was an intentional, later owner decision).
- **Severity: P0 = 9, P1 = 4, P2 = 3, P3 = 5.**
- **Two root-cause clusters account for 14 of the 21 confirmed findings** (11 = unwired sign-in session; 3 = AuthGuard misroute) — see below. The remaining 7 are independent, screen-local defects.
- **Coverage: 72 screens assigned, 7 passed (10%).** Not a quality signal on its own — most failures are "blocked," not "broken."

---

## Root Cause A — Cloud sign-in is unwired (11 of 21 findings, includes all P0s)

**Mechanism.** `sign_in_controller.dart`'s `_navigateAfterSignIn` (and the equivalent signup/Google/magic-link paths) authenticates against Firebase's **default** app, then sets `activeAccountIdProvider` and calls `setCloudBornSessionFromFirebaseUser`, which resolves Firestore access through `activeAccountFirebaseProvider` → `AccountFirebase.resolve(accountId)`. `resolve()` operates on a **separate, per-account named `FirebaseApp`** and — by its own documented contract — never signs one in itself; that is the job of `AccountFirebase.signInCloudAccount()` / `createAnonymousAccount()`. Neither is ever called from sign-in, sign-up, Google sign-in, magic-link, or bootstrap cold-start restore. `account_firebase_providers.dart`'s own doc comment concedes the gap: wiring "belongs to whichever concrete sign-in/signup/switch flow calls this registry (Epic C), which does not exist yet." Result: `resolve()` throws `AccountNotAuthenticatedException` for every account, every time, on every device — confirmed independently against current HEAD, not just accepted from the audit.

**Blast radius (confirmed findings):** #1 (5560 onboarding), #4 (5554 onboarding), #6 (5562 onboarding, Hebrew), #7 (5560 dashboard), #8 (5560 learning), #9 (5560 content), #11 (5560 tracks, medium-confidence variant), #14 (5554 profiles_childmode, existing-account restore), #20 (5554 infra), #22 (5562 gamification), #24 (5562 hebrew_rtl, total lockout). This is why coverage is 7/72 — it is the single blocking gate in front of every area.

**Fix location:** `learning_tracker/lib/features/account/presentation/notifiers/sign_in_controller.dart` (`_navigateAfterSignIn`, `_signInWithEmailBody`, `_signInWithGoogleBody`) must call `AccountFirebase.signInCloudAccount(accountId, credential)` (or `createAnonymousAccount`) via `accountFirebaseRegistryProvider` **before** `activeAccountIdProvider` is set / before anything resolves `activeAccountFirebaseProvider`. The `AuthCredential` needs to be threaded down from where it's currently captured (email/password entry, Google token). Same gap in `learning_tracker/lib/features/account/onboarding/presentation/screens/signup_screen.dart` and `learning_tracker/lib/features/account/presentation/providers/magic_link_providers.dart`.

---

## Root Cause B — AuthGuard misroutes a zero-account device (3 of 21 findings)

**Mechanism.** `auth_guard.dart:87-91` calls `countProfiles()` **before** checking `kIntroSeen` (line 93), both inside one `try` closed by a blanket `catch` at line 116 that unconditionally redirects to `SignInRoute`. On a zero-account device, `countProfiles()` throws `ProfileRepositoryNotReadyException` (documented as the normal "no active account yet" signal, not a real error) — which is swallowed by the outer catch instead of falling through to the intro-seen check. Net effect: a genuinely fresh install never sees the AppIntro carousel or the onboarding permission prompt, and never reaches AccountPicker; it is dumped straight onto the cloud-only Sign In screen. Confirmed against current HEAD (`auth_guard.dart:87-93,116`).

**Findings:** #2 (5560, AppIntro skipped on true first launch), #15 (5554, Settings/onboarding unreachable from a zero-account device), #19 (5554, log-hygiene tail — the same exception is logged at ERROR level for what is a routine, expected state).

**Fix location:** `learning_tracker/lib/app/router/guards/auth_guard.dart:87-91` — catch `ProfileRepositoryNotReadyException` locally, treat it as "0 profiles," and fall through to the existing `kIntroSeen`/AccountPicker decision tree instead of letting it hit the blanket fail-safe catch. Downgrade that exception's log level from error to info/debug at the catch site (~116-121).

---

## Confirmed Findings

### P0 (9) — all Root Cause A

| # | Device / Screen | Finding | Fix location |
|---|---|---|---|
| 1 | 5560 / onboarding-seed | Sign-in fails post email-verification, every first-time account | `sign_in_controller.dart` (see Root Cause A) |
| 4 | 5554 / onboarding-seed | Same wall, first sign-in with no local registry entry | same |
| 6 | 5562 / onboarding-seed (Hebrew) | Same wall, Hebrew locale | same |
| 7 | 5560 / dashboard | Sign-in throws immediately after successful auth | same |
| 8 | 5560 / learning | Sign-in broken; blocks entire LEARN area | same |
| 9 | 5560 / content | Sign-in broken; 0/4 Content screens reached | same |
| 11 | 5560 / tracks | Device permanently stuck at sign-in wall *(medium confidence — auditor's App-Check theory was not confirmed; verified root cause is the same Root Cause A wall plus an `AuthStateNotifier._init()` reconciliation gap on cold start)* | same, + `auth_state_provider.dart:_init()` |
| 14 | 5554 / profiles_childmode | Existing, verified cloud account cannot restore on a device that's never seen it | same |
| 22 | 5562 / gamification | Existing verified account cannot sign in; blocks entire Gamification area | same |
| 24 | 5562 / hebrew_rtl | Total lockout; not RTL-specific, found incidentally while auditing under Hebrew locale | same |

### P1 (4)

| # | Device / Screen | Finding | Fix location |
|---|---|---|---|
| 2 | 5560 / onboarding-seed | AppIntro carousel + permission prompt silently skipped on true first launch (Root Cause B) | `auth_guard.dart:87-91` |
| 15 | 5554 / settings | Zero-account device can never reach onboarding/Settings via UI (Root Cause B) | `auth_guard.dart:87-91` |
| 20 | 5554 / infra | First-time cloud sign-in throws `AccountNotAuthenticatedException` (Root Cause A) | `sign_in_controller.dart` |
| 17* | — | see P2 (17 corrected to Signup-only during verify; listed there) | — |

### P2 (3)

| # | Device / Screen | Finding | Fix location |
|---|---|---|---|
| 5 | 5554 / onboarding-seed | System Back on Register screen exits app to launcher instead of returning to Sign In (uses `.replace()` instead of `.push()`) | `sign_in_screen.dart:403` — change `context.router.replace(SignupRoute())` to `.push(SignupRoute())` |
| 12 | 5560 / tracks | Sign-in failure is a dead end: generic toast, no diagnostic; a 15s sign-in watchdog timer fires while the blocking email-verification dialog is still open, producing two contradictory messages on screen at once. *(Auditor's secondary "retries mint duplicate orphaned accounts" claim was corrected on verify — Firebase already blocks `email-already-in-use`; that specific sub-claim does not hold.)* | `sign_in_controller.dart` watchdog `Timer` (~L526-536) not paused while `showEmailVerificationDialog` is open |
| 17 | 5554 / auth_account | Bottom CTA ("Sign Up with Google") clipped below the fold on first paint, no scroll affordance — **confirmed on Signup only**; the Sign In half of this finding was checked pixel-by-pixel and does not reproduce (content clears the nav bar with margin), so it is dropped for Sign In | `signup_screen.dart` (~L341-590) — add a scroll-affordance cue / tighten vertical spacing |

### P3 (5)

| # | Device / Screen | Finding | Fix location |
|---|---|---|---|
| 3 | 5560 / onboarding-seed | Verification email sender display name typo: "Torah Learning Trarcker" | Firebase Console config only (project `torah-study-tracker` → Authentication → Templates → Email verification → Sender name) — no code file, confirmed zero repo hits for "Trarcker" |
| 16 | 5554 / settings | Post-signup "Verification email sent" snackbar overlaps the Google sign-in button and Register Here link on short screens | `signup_screen.dart` (~L122-124) snackbar margin, and/or `sign_in_screen.dart` reserve bottom padding |
| 18 | 5554 / auth_account | Signup's password-visibility icon uses a padlock (`Icons.lock_rounded`) instead of the crossed-eye used on Sign In, inconsistent within the same flow | `signup_screen.dart:451` — change to `Icons.visibility_off_rounded` to match `sign_in_form.dart:94-99` |
| 19 | 5554 / auth_account | Zero-account cold start logs the expected "no active account" state at ERROR level (Root Cause B log-hygiene tail) *(medium confidence)* | `auth_guard.dart` catch block (~L116-121) — log at info/debug, not error |
| 21 | 5554 / infra | Sign-in failure surfaces only a generic message with no diagnostic detail for internal (non-Firebase) exceptions | `sign_in_controller.dart` `_mapAuthErrorFromException`/`_resolveFailureMessage` (~L135-157) |

---

## Rejected / Reclassified (3)

All three are the **same underlying observation** — "Create Account offers no path when offline, despite `createOfflineAccount` / offline-signup l10n strings existing in the ARB files" — filed independently on three devices (5560 #10, 5554 #13, 5562 #23) and initially verified as real P1/P2 app defects, each citing pre-2026-08-11 evidence (a 2026-06-14 project memory note, `docs/qa/legacy/`, `docs/architecture.md`) as proof of current intended design.

**This report independently re-verified against current HEAD and reclassifies all three as BY_DESIGN, not defects:**

- `git log` shows commit `91798ab8` — **"Phase 3: remove local-born account support (owner decision 2026-08-11)"** — postdates every artifact the confirming verifiers relied on, and states explicitly: *"Signup now shows a clear 'no connection' message instead of falling back to a credential-less offline account when offline, since Firebase signup inherently requires network."* That is exactly the behavior observed.
- No commit since `91798ab8` reintroduces the feature (`git log --since=2026-08-11 -- learning_tracker/lib/features/account` shows only cleanup/fix commits, none restoring it).
- `grep -rn "createOfflineAccount(" learning_tracker/lib/` returns zero call sites at HEAD — the l10n strings are the deletion's own admitted residue ("too many call sites to remove cleanly," per the commit message), not evidence of a half-built feature.
- The memory note and docs the "confirmed" verifiers relied on are simply stale relative to the owner's later decision.

**Not dropped — carried forward as follow-ups (not app defects):**
1. `tool/device_e2e/_full_suite_lib.mjs:147`'s device-5560 seed recipe still instructs "Create Offline Account" — the harness's own seed template is unexecutable as written. Note: it cannot simply be switched to cloud sign-up either, since Root Cause A blocks that path too — seeding is doubly broken until Root Cause A lands.
2. `docs/architecture.md`, `docs/qa/legacy/02-auth-and-accounts.md`, and this session's own memory note `onboarding-offline-account-model.md` are stale and should be archived/updated to reflect the 2026-08-11 reversal so future audits don't re-flag this.

---

## Coverage

| Device | Area | Screens | Passed |
|---|---|---|---|
| 5560 | dashboard | 1 | 0 |
| 5560 | learning | 6 | 1 |
| 5560 | content | 4 | 0 |
| 5560 | tracks | 5 | 0 |
| 5560 | scheduler | 3 | 0 |
| 5560 subtotal | | **19** | **1** |
| 5554 | profiles_childmode | 13 | 4 |
| 5554 | settings | 4 | 0 |
| 5554 | auth_account | 5 | 0 |
| 5554 | infra | 5 | 0 |
| 5554 subtotal | | **27** | **4** |
| 5562 | gamification | 5 | 0 |
| 5562 | progress | 5 | 0 |
| 5562 | tutoring | 6 | 0 |
| 5562 | hebrew_rtl | 10 | 2 |
| 5562 subtotal | | **26** | **2** |
| **Total** | | **72** | **7 (10%)** |

The 7 passes are concentrated in `profiles_childmode` (device-local profile/child-mode surfaces reachable without a fresh cloud round-trip) and `hebrew_rtl` (2 screens reachable the same way). Every other area is 0/N — consistent with Root Cause A blocking the cloud sign-in gate in front of essentially all of them. **Read this table as "blocked," not "broken": scheduler, progress, tutoring, and most of dashboard/learning/content/tracks/gamification/settings received no independent exercise this run.**

---

## Recommended Fixes (by severity)

1. **P0 — Wire `AccountFirebase.signInCloudAccount()`/`createAnonymousAccount()` into every sign-in entry point** (`sign_in_controller.dart`, `signup_screen.dart`, `magic_link_providers.dart`, Google path) before `activeAccountIdProvider` is set. This single fix resolves 9 P0s + 2 P1s (11 of 21 confirmed findings) and unblocks re-audit of the ~65 screens this run could not reach.
2. **P1 — Fix `AuthGuard`'s check ordering** (`auth_guard.dart:87-91`): treat `ProfileRepositoryNotReadyException` from `countProfiles()` as "0 profiles" and fall through to the `kIntroSeen`/AccountPicker tree, instead of hitting the blanket fail-safe catch. Resolves 2 P1s + downgrades the P3 log-hygiene tail.
3. **P2 — `sign_in_screen.dart:403`**: `.replace(SignupRoute())` → `.push(SignupRoute())` so system Back returns to Sign In instead of exiting the app.
4. **P2 — Pause/extend the sign-in watchdog timer** while the email-verification dialog is open (`sign_in_controller.dart` ~L526-536), to stop the contradictory "still waiting" + "timed out" double-message.
5. **P2 — Add a scroll affordance to the Signup form** (`signup_screen.dart` ~L341-590) so the Google sign-up button isn't hidden below the fold on small/old devices.
6. **P3 — Firebase Console**: fix verification-email sender name typo ("Trarcker" → "Tracker"), project `torah-study-tracker`.
7. **P3 — Snackbar positioning** on post-signup Sign In screen (`signup_screen.dart` ~L122-124 / `sign_in_screen.dart`).
8. **P3 — Icon consistency**: `signup_screen.dart:451`, `Icons.lock_rounded` → `Icons.visibility_off_rounded`.
9. **P3 — Log level**: downgrade the expected `ProfileRepositoryNotReadyException` from error to info/debug in `auth_guard.dart` (~L116-121).
10. **P3 — Diagnostic detail** for internal (non-Firebase) sign-in exceptions in `sign_in_controller.dart`'s error mapping (~L135-157).

**Follow-ups (tooling/docs, not app code):** update `tool/device_e2e/_full_suite_lib.mjs:147`'s 5560 seed recipe once #1 above lands (it currently references a deleted "Create Offline Account" flow and cloud sign-up is blocked either way until then); archive/update `docs/architecture.md`, `docs/qa/legacy/02-auth-and-accounts.md`, and memory note `onboarding-offline-account-model.md` to reflect the 2026-08-11 offline-account removal.

---

## Residual Risk

1. **Coverage is a floor, not a ceiling.** 65 of 72 assigned screens were never independently reached this run; they are unaudited, not passing. A full re-run against every area is required once Root Cause A is fixed.
2. **#11's root cause differs from the auditor's original App-Check theory** — verified instead as the same Root Cause A wall compounded by an `AuthStateNotifier._init()` cold-start reconciliation gap. Fix Root Cause A first, then re-test cold-start restore specifically.
3. **Google sign-in and magic-link sign-in share the identical Root Cause A code path** (`_navigateAfterSignIn`) but were not separately exercised on-device this run — treat as blocked for the same reason, not separately verified.
4. **This rung is still manual.** No CI harness drives these device flows; every finding is a one-shot observation from this session, not a repeatable automated check.

---

*Findings sourced from three device-agent audit passes (5560, 5554, 5562) plus this report's own independent HEAD verification of the two largest clusters (git history + grep) and the AuthGuard code path.*

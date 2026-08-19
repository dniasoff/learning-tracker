# On-Device Audit — Run 13 Report

## Scope

- **Run:** 13 — 3-device parallel on-device E2E re-audit; **first pass since Root Cause A (unwired cloud sign-in) and Root Cause B (AuthGuard misroute) from Run 12 landed** (commits `2a458b96`, `de53f1b6`, tagged `v1.0.71-internal`, live on Google Play), alongside 6 follow-on P2/P3 polish fixes (`515f8da1`, `965e2712`, `8fd16843`).
- **Devices / areas:** emulator-5560 (dashboard, learning, content, tracks, scheduler), emulator-5554 (profiles_childmode, settings, auth_account, infra), emulator-5562 (gamification, progress, tutoring, hebrew_rtl).
- **Job:** seed real cloud accounts (offline-account creation was permanently removed 2026-08-11) and finally audit the ~90% of the app Run 12 could not reach.
- **Out of scope:** Run 12 finding #3 (Firebase Console verification-email sender-name typo "Trarcker") — needs manual Console action, not code; does not block anything.
- **Verification:** every candidate finding was adversarially re-verified against source + screenshot/logcat evidence before being counted.

---

## Verdict

**Gate verdict: FAIL.**

Run 12's single blocking wall is down — coverage jumped from 7/72 (10%) to 73/115 (63.5%), confirming Root Causes A and B are fixed for the common case. But this run surfaced **11 new/regressed P0s across four distinct root causes**, one of which is more serious than anything in Run 12: the app's core "Mark complete" action — the entire point of a learning tracker — **silently fails on every attempt, on both devices where it was reached**, with a raw internal exception leaking to the user and zero completions ever persisted. A second P0 root cause is a *regression in the same sign-in lineage* Run 12 just fixed: a race between `AccountFirebase.resolve()` and the real authenticating call still fully blocks sign-in on device 5560 (Learning and Content areas: 0/4 screens each). A third P0 cluster (10 findings) is a systemic missing-Firestore-index problem that breaks the Streak/gamification feature on nearly every screen it appears and makes Point Settings entirely unusable. A fourth standalone P0 (Delete Profile) silently no-ops on a destructive action with zero error feedback.

Higher coverage is real progress, but the severity profile is not better than Run 12 — it is differently bad. Run 12 was one wall in front of everything; this run found the app's central feature broken behind the wall, plus a regressed variant of the wall itself still standing on one device.

- **Findings filed: 46. Confirmed as real app defects: 37.** Rejected/reclassified: 8 (false-positive or by-design). Needs-device/unresolved: 1.
- **Severity: P0 = 11, P1 = 6, P2 = 14, P3 = 6.**
- **Four root-cause clusters account for 20 of the 37 confirmed findings** — see below. The remaining 17 are independent, screen-local defects.
- **Coverage: 115 screens assigned, 73 passed (63.5%)** — up from Run 12's 7/72 (10%), a ~10x increase in exercised screens; screen counts aren't directly comparable 1:1 (this run's inventory was rescoped/expanded), but the pass-rate jump is the meaningful signal that Root Causes A/B are genuinely fixed for the common path.

---

## Root Cause A (regression) — Cloud sign-in race still blocks device 5560 (3 findings, all P0)

**Mechanism.** Run 12's fix (`2a458b96`/`de53f1b6`) correctly reordered `sign_in_controller.dart`'s own `establishAccountFirebaseSession()` before `activeAccountIdProvider.notifier.set()`. It did **not** address an ambient, ordering-independent hazard: `AccountFirebase._obtain()` memoizes in-flight establishment futures in one `_pending` map keyed **only by accountId** (account_firebase.dart:604-649), with no distinction between the reattach-only `resolve()` path (never authenticates, throws `AccountNotAuthenticatedException` if no session exists) and the authenticating `signInCloudAccount()` path. An ambient `resolve()` call — routinely triggered via `AuthGuard.onNavigation`/`activeAccountFirebaseProvider` for any device with a persisted "last active account" row, or via `bootstrap.dart`'s cold-start restore setting `activeAccountIdProvider` from pure local state before any session is established — can win that shared slot and short-circuit a concurrent, genuinely-correct sign-in into a spurious exception. Firebase Auth itself succeeds every time (~150ms-1.6s, confirmed via logcat token-issued events); the app then throws before navigation. Reproduced 100% (5+ consecutive attempts including after force-stop) on device 5560; not device/App-Check-specific.

**Findings:** sign-in wall on 5560/onboarding-seed, 5560/learning (blocks 4/4 Learning screens), 5560/content (blocks 4/4 Content screens).

**Fix location:** `learning_tracker/lib/data/firestore/account_firebase.dart:604-649` (`_obtain`/`_pending` — stop sharing one memoization slot between reattach-only and authenticating callers) and `learning_tracker/lib/data/firestore/active_account_providers.dart:90-97` (`activeAccountFirebaseProvider` — invalidate rather than staying pinned to a cached `AsyncError` when `activeAccountIdProvider` is re-set to the same id). Secondary: `learning_tracker/lib/app/bootstrap/bootstrap.dart:95-99` (seeds `activeAccountIdProvider` from local-only persisted state with no prior session-establishment check).

---

## Root Cause B — Missing Firestore composite indexes break Streak everywhere + Point Settings entirely (10 findings, 3 P0)

**Mechanism.** The `streak_events` read path (`FirestoreStreakEventRepository.watchRecentEvents`, ordered by document id) and the `point_configs` read path (`FirestorePointConfigRepository._queryForCurriculum`, `curriculum_id` + `stage_order`) both fail with `cloud_firestore/failed-precondition — The query requires an index`, deterministic and reproducible across relaunches/reboots — a genuine backend deploy gap, not a client bug on its own. `learning_tracker/firestore.indexes.json` has **zero entries for either collection**. Compounding it: at least three screens (`learning_screen.dart`'s `_StreakHeroCard`, the Dashboard header chip, `point_config_screen.dart`) render `error.toString()` directly via the generic `l10n.errorGeneric` fallback instead of the project's own `AppErrorView`/`InlineAsyncError` convention (correctly used elsewhere in the same codebase) — leaking a raw exception **including a live internal Firebase Console deep-link naming the project id** into end-user (in one case child-user) UI. On the Gamification Hub, this is worse than cosmetic: the broken header chip is the app's *only* in-app tap target that navigates to `GamificationRoute`, so the whole Hub screen becomes unreachable once the query starts failing.

**Findings:** 5554/onboarding-seed (LEARN tab raw error), 5562/onboarding-seed (LEARN tab raw error, child-facing), 5554/profiles_childmode (Dashboard raw error), 5554/auth_account (Dashboard streak card broken), 5554/auth_account (duplicate mid-word-wrapped error chip), 5554/infra (SyncStatus/Dashboard streak broken), 5562/gamification (Point Settings raw error — **P0**, blocks a whole parent-facing feature), 5562/gamification (Gamification Hub unreachable — **P0**), 5562/progress (Streak stat fails on Progress + Recent Activity), 5562/hebrew_rtl (same class, Hebrew locale, confirms not translation-related). A related, lower-confidence variant (screenshot lost to an emulator crash) was also seen on 5560/dashboard but is tracked separately at medium confidence, not merged into this count.

**Fix location:** `learning_tracker/firestore.indexes.json` — add composite indexes for `streak_events` (order by `__name__`) and `point_configs` (`curriculum_id` + `stage_order`, mirroring the existing `stage_definitions` entry), then `firebase deploy --only firestore:indexes`. **Verify the exact query scope (COLLECTION vs COLLECTION_GROUP) against a live Firestore error capture before deploying** — two of the ten findings independently corrected the auditor's "collection-group" framing; the actual query is a plain single-collection `orderBy`. Client-side: `learning_tracker/lib/features/learning/presentation/screens/learning_screen.dart:209`, `learning_tracker/lib/features/dashboard/presentation/widgets/dashboard_body.dart:306-313`, `learning_tracker/lib/features/gamification/presentation/screens/point_config_screen.dart` — replace raw `error.toString()` rendering with `AppErrorView`/`InlineAsyncError`, and give the Gamification Hub chip an error-state tap affordance so it isn't the sole navigation path that can die.

---

## Root Cause C — "Mark complete" always fails: disposed-Ref crash, zero completions ever persisted (2 findings, both P0)

**Mechanism.** `completionPointsPortProvider` and the rest of the completion write chain (`completionOrchestratorProvider`, `markCompletionUseCaseProvider`, etc.) are plain `@riverpod` autoDispose providers, reached only via a one-shot `ref.read()` at the single call site (`text_display_screen.dart:720`) with no watcher anywhere in the app. `CompletionOrchestrator.markComplete` awaits a Firestore round-trip before calling `_pointsPort.calculatePoints(...)` — a real async gap during which Riverpod's autoDispose GC tears the provider down (zero listeners, no `keepAlive`). The awarder then does `_ref.read(...)` again inside `calculatePoints` and throws `Cannot use the Ref of completionPointsPortProvider after it has been disposed`, rendered as a raw internal exception in an orange toast. **Nothing is written** — verified directly against Firestore (`completions`, `streak_events`, `points_ledger` all empty) after every attempt, on both an adult profile (device 5554) and a child profile (device 5562), 100% reproducible including after force-stop/relaunch/fresh-profile-selection. Sibling providers in the same feature (`completion_writer_providers.dart`, `optimistic_completion_provider.dart`) already carry `@Riverpod(keepAlive: true)` with a doc comment explaining why — this chain simply never got the same treatment, and no existing unit test exercises the real generated autoDispose provider's lifecycle (they construct the classes directly or wrap them in a non-autoDispose test double).

**Findings:** 5554/onboarding-seed, 5562/onboarding-seed (child profile).

**Fix location:** `learning_tracker/lib/features/learning/presentation/providers/completion_providers.dart` — add `@Riverpod(keepAlive: true)` to `completionPointsPortProvider`, `completionStreakPortProvider`, `completionDetectionServiceProvider`, `completionOrchestratorProvider`, `markCompletionUseCaseProvider`, `bulkMarkCompletionUseCaseProvider`. Root capture site: `learning_tracker/lib/features/learning/data/repositories/completion_points_awarder.dart` (holds a disposable `Ref` across multiple `await` gaps with no `ref.mounted` guard).

---

## Root Cause D — One-shot Firestore stream adapters latch into a permanent error/stale state with no self-heal (5 findings)

**Mechanism.** A recurring pattern across several repository adapters (`profile_repository_impl.dart`'s `watchProfiles()`, `curriculum_track_repository_impl.dart`'s `watchActiveTracks()`/`watchActiveCurriculumIds()`): a bare `async*` generator calls `_resolveOrNull()`/`_resolve()` **once** before its first `yield`. If that one-shot read lands during the ordinary cold-start/profile-switch window where the active account/profile hasn't finished resolving, the generator throws or yields `[]` and **the underlying Dart stream terminates permanently** — Dart `async*` semantics mean nothing re-enters the generator body after a pre-yield throw/return. The consuming `StreamProvider`s never `ref.watch` anything that would trigger a rebuild once the account/profile genuinely becomes ready moments later, so the error/empty state is stuck until a manual Retry tap, pull-to-refresh, or full app relaunch. Concrete user impact ranges from a jarring but self-service-recoverable "Something went wrong" right after onboarding, up to a real P0: a child's own Dashboard/Learn/Progress showing "No tracks yet" for a track the parent had already configured and which is fully visible on the Parent's own Track Management screen.

**Findings:** 5554/onboarding-seed (Profile Switcher stuck), 5562/onboarding-seed (transient, self-heals via Retry), 5554/profiles_childmode (child's own track invisible — **P0**), 5562/gamification (points balance stale after parent adjustment until relaunch), 5562/gamification (Dashboard vs Progress disagree on active tracks).

**Fix location:** `learning_tracker/lib/features/profiles/data/repositories/profile_repository_impl.dart` and `learning_tracker/lib/features/tracks/setup/data/repositories/curriculum_track_repository_impl.dart` — both need a resubscribing wrapper or a reactive dependency on account/profile readiness instead of a bare one-shot `async*`. Consuming providers (`profile_providers.dart`, `dashboard_providers.dart`, `track_management_providers.dart`) should `ref.watch` the resolved-repository future directly rather than hiding it behind `ref.read`.

---

## Confirmed Findings

### P0 (11)

| Device / Screen | Finding | Fix location |
|---|---|---|
| 5560 / onboarding-seed | Sign-in fails post-Firebase-auth-success — `resolve()` races real authenticate call *(medium confidence — exact racing caller not pinned at runtime)* | Root Cause A |
| 5554 / onboarding-seed | Mark complete: disposed-Ref crash, zero completions persisted | Root Cause C |
| 5554 / onboarding-seed | LEARN tab "Current Achievement" — raw Firestore exception + internal Console URL leaked | Root Cause B |
| 5562 / onboarding-seed | Mark complete (child profile): disposed-Ref crash, zero completions persisted | Root Cause C |
| 5560 / learning | Sign-in fails; blocks entire Learning area (0/4 screens) | Root Cause A |
| 5560 / content | Sign-in fails; blocks entire Content Browsing area (0/4 screens) | Root Cause A |
| 5560 / tracks | Reorder Content screen renders blank — missing `.limit()` trips `firestore.rules`' `request.query.limit <= 500` gate | `firestore_track_learning_order_repository.dart:152-155` (add `.limit(500)`); `track_learning_order_screen.dart:40-73` (add error branch) |
| 5554 / profiles_childmode | Delete Profile silently does nothing — profile never removed, no error shown | `profile_edit_delete_actions.dart:130` (wrap `deleteProfile` callable in try/catch, surface failure) |
| 5554 / profiles_childmode | A track the parent configured is invisible on the child's own Dashboard/Learn/Progress | Root Cause D |
| 5562 / gamification | Point Settings screen shows raw Firestore error instead of the point-value editor | Root Cause B (`firestore.indexes.json` — missing `point_configs` index) |
| 5562 / gamification | Streak permanently broken AND is the app's only in-app entry point to Gamification Hub — Hub unreachable | Root Cause B |

### P1 (6)

| Device / Screen | Finding | Fix location |
|---|---|---|
| 5554 / onboarding-seed | Profile Switcher sheet stuck on "Something went wrong" after a one-time cold-start race, no auto-recovery | Root Cause D |
| 5562 / onboarding-seed | LEARN tab CURRENT ACHIEVEMENT banner (child-facing) — raw Firestore exception + Console URL | Root Cause B |
| 5554 / profiles_childmode | Dashboard "Current Achievement" card — raw Firestore exception | Root Cause B |
| 5554 / auth_account | Account Picker "SIGN IN AGAIN" reauth ignores real auth provider, routes through Google Sign-In, produces non-durable session on cancel | `account_picker_screen.dart` (`_reauthAndActivateCloudAccount`) — needs a persisted provider column + branch to email/password reauth |
| 5554 / infra | Dashboard Streak card permanently errored (missing index) | Root Cause B |
| 5562 / progress | Streak stat permanently fails on Progress + Recent Activity, Retry is a dead end | Root Cause B |

### P2 (14)

| Device / Screen | Finding | Fix location |
|---|---|---|
| 5560 / onboarding-seed | Streak/stats widgets showed "Something went wrong" on a later dashboard visit *(medium confidence — screenshot lost to crash)* | `dashboard_providers.dart` `dashboardStreak` — needs reactive dependency on backend readiness |
| 5554 / onboarding-seed | Bottom "Register Here" row clipped by system nav bar (Pixel 2 API 28) | Native splash/system-UI restore wiring, not `sign_in_screen.dart` (its SafeArea usage is already correct) |
| 5562 / onboarding-seed | Profile list / streak chip transient "Something went wrong" right after onboarding/profile switch, self-heals via Retry | Root Cause D |
| 5560 / scheduler | Selecting a past Hebrew deadline date silently does nothing, no error/feedback | `goal_setup_screen.dart:_pickHebrewDate()` (259-273) — add feedback; `hebrew_date_picker.dart` — add min-date floor |
| 5554 / auth_account | "Not signed in" row in Settings has no tap affordance, unlike its signed-in sibling | `user_profile_header_card.dart:61-75` |
| 5554 / auth_account | Dashboard Streak card permanently errored (missing index) | Root Cause B |
| 5554 / auth_account | Dashboard header error banner wraps mid-word, duplicates Retry, overlaps Streak tile | `inline_async_error.dart`; `dashboard_body.dart:306-313`; `progress_tier_counter_row.dart:214-215` |
| 5554 / infra | Location detect timeout collapses to a permanent "denied" icon even when OS permission was granted | `permission_prompt_screen.dart:_requestLocation()` (78-90) — preserve `LocationFetchResult` variant |
| 5562 / gamification | Child's displayed point balance stale after parent "Adjust Points" write, until relaunch | Root Cause D (`parent_settings_screen.dart` — add missing invalidation) |
| 5562 / gamification | Dashboard and Progress disagree on whether child has an active track — hides points/Redeem card | Root Cause D |
| 5562 / tutoring | ManageTutors empty-state message permanently disappears once all grants reach terminal state | `manage_tutors_screen.dart:238` — check post-filter `active`/`pending` lists, not raw `grants.isEmpty` |
| 5562 / tutoring | AcceptInvite (real email deep link) shows generic "a child" copy instead of the app's own personalized string | `accept_invite_screen.dart:369` — use `acceptInviteBodyFromParentForChild` when `_loadedGrant` is non-null |
| 5562 / hebrew_rtl | Streak widget permanently fails across Dashboard/Progress/Recent Activity (Yedid) | Root Cause B |
| 5562 / hebrew_rtl | English word "Synced" leaks into an otherwise fully-Hebrew Settings > Backup & Sync card | `backup_sync_section.dart:_buildSyncStatus` (102-145) — route through `AppLocalizations`, add missing `app_he.arb` keys |

### P3 (6)

| Device / Screen | Finding | Fix location |
|---|---|---|
| 5562 / onboarding-seed | Fresh sign-in needs TWO App Check debug tokens registered (default + named per-account app); 20-token cap recurring hazard | Test-infra doc gap (`docs/appcheck-enforcement.md`) — not an app-code fix |
| 5560 / dashboard | Error-chip text wraps mid-word, clipped with ellipsis | `dashboard_body.dart:306-313` (remove/widen fixed `SizedBox(width:150)`); `inline_async_error.dart:15-38` |
| 5554 / settings | App Permissions vs Notification Settings disagree on notification-permission status (API 28) | `permission_prompt_screen.dart` — seed `_notifStatus` from `NotificationGateway.hasPermission()` on init |
| 5554 / infra | App Permissions never reflects already-granted OS permissions, always resets to "Allow" prompt | `permission_prompt_screen.dart` — add `initState()` hydration from real permission status |
| 5554 / infra | Import backup "Preview backup" silently closes dialog when field is empty, no feedback | `backup_sync_section.dart` — distinguish empty-submit from Cancel |
| 5562 / hebrew_rtl | Likely mistranslation: "נקודות שהורו" title above correct "נקודות שנצברו" subtitle on Points card | `app_he.arb` key `chartPointsEarned` — fix translation, regenerate via `flutter gen-l10n` |

---

## Rejected / Reclassified (8)

| Verdict | Finding as filed | Why rejected |
|---|---|---|
| by_design | Onboarding carousel chip labels truncated ("Review…" / "…yos") | ARB source (`introMishnaReviewChip`/`introMishnaWordFragmentChip`) is authored that way, with an explicit description confirming intentional decorative word-fragment pairing; mirrored in Hebrew. No layout-driven truncation involved. |
| false_positive | Manage Tracks FAB at bottom-right "contradicts RTL mirroring convention" | Screen is English/LTR, not RTL — chrome strings match `app_en.arb` verbatim. The Hebrew script seen is the separate, documented "Hebrew Terms" content toggle, not a locale/direction switch. FAB uses the standard `endFloat`, correct under the actual LTR directionality in effect. |
| by_design | Add-Track wizard Step 4 — Saturday row rendered in low-contrast style vs siblings | A documented `ShaderMask` fades the bottom ~40% of the viewport as a scroll affordance (position-anchored, not per-day); Friday is also visibly faded, just less, falsifying a Saturday-specific styling theory. |
| false_positive | Parent Track Management screen — top identity bar exposes no accessibility text | The bar is rendered once, globally, by `PersistentSwitcherScaffold`, route-name-gated with no per-screen logic; a structural sibling route (Parent Settings) uses the identical shared widget and works. Most likely a stale/mid-transition accessibility-dump capture artifact. |
| false_positive | Dashboard streak error — root cause claimed as missing collection-group index | The claimed `collectionGroup(streak_events)` query does not exist anywhere in `lib/`; the actual query is a plain single-collection `orderBy(FieldPath.documentId)`, which Firestore never requires a composite index for. The underlying UI error symptom may still be real (see the medium-confidence Root Cause B variant), but this specific root-cause citation does not hold. |
| false_positive | Settings footer icons (triangle/feedback/star) have no text label or accessible content-desc | The icons have zero `onTap`/interactive wrapper anywhere in the code — there is no hidden action to expose, and Flutter's `Icon` widget excludes an unlabeled, non-interactive glyph from the accessibility tree by design (same as `alt=""`), so it is correctly skipped rather than exposed as a broken button. |
| by_design | Recent Activity "Points Earned (All Time)" shows 0 while account balance elsewhere shows 10 | Intentional scoping: the chart is completions-only (`liveOnly` tier per the code's documented "three-tier credit policy"), the account balance legitimately includes non-completion `parent_add` ledger entries. A prior fix explicitly replaced a "misleading all-time label" with this range-accurate one. |
| by_design | Add Track wizard Step 2 — "garbled" Hebrew pace title "דרשו עמוד היומי" | "דרשו" (Dirshu) is a real, branded Torah-study organization name, not a mistranslated verb — confirmed by three sibling `calendar_program_registry.dart` entries all sharing the same "Dirshu"-prefixed naming convention with matching English names. |

**Needs-device / unresolved (1):** Add-Track wizard Step 3 (Select Scope) — a מועד list row's Seder subtitle text reported as hard-clipped without ellipsis. Not independently verifiable from static code/screenshot evidence this run; carry forward to the next device pass.

---

## Coverage

| Device | Area | Screens | Passed |
|---|---|---|---|
| 5560 | dashboard | 6 | 4 |
| 5560 | learning | 4 | 0 |
| 5560 | content | 4 | 0 |
| 5560 | tracks | 7 | 6 |
| 5560 | scheduler | 8 | 5 |
| 5560 subtotal | | **29** | **15 (52%)** |
| 5554 | profiles_childmode | 19 | 14 |
| 5554 | settings | 14 | 13 |
| 5554 | auth_account | 9 | 5 |
| 5554 | infra | 7 | 4 |
| 5554 subtotal | | **49** | **36 (73%)** |
| 5562 | gamification | 7 | 4 |
| 5562 | progress | 6 | 4 |
| 5562 | tutoring | 7 | 3 |
| 5562 | hebrew_rtl | 17 | 11 |
| 5562 subtotal | | **37** | **22 (59%)** |
| **Total** | | **115** | **73 (63.5%)** |

**vs Run 12: 7/72 (10%).** This run passed roughly 10x as many screens (7 → 73), and screens outside device 5560's Learning/Content areas were all at least reachable (0/4 on those two is entirely attributable to the Root Cause A regression, not a fresh unrelated wall). Note the assigned-screen totals aren't directly 1:1 comparable — this run's inventory (115) was rescoped/expanded versus Run 12's (72) — but the pass-rate delta is the meaningful confirmation that Root Causes A and B are genuinely fixed for the common path. Device 5554 (73%) and, to a lesser extent, 5562 (59%) got a real audit this run; device 5560 (52%) is still materially gated by the Root Cause A regression.

---

## Recommended Fixes (by severity)

1. **P0 — Root Cause C:** Add `@Riverpod(keepAlive: true)` to the Mark Complete provider chain (`completion_providers.dart`). This is the single highest-priority fix — it restores the app's core function (learning-tracking) for every user, on every device.
2. **P0 — Root Cause A (regression):** Stop `AccountFirebase._obtain()` from sharing one `_pending` memoization slot between the reattach-only `resolve()` path and the authenticating `signInCloudAccount()` path; invalidate `activeAccountFirebaseProvider` on same-id re-activation. Unblocks sign-in on device 5560 and re-opens Learning + Content for audit.
3. **P0 — Root Cause B:** Deploy the missing `streak_events` and `point_configs` composite indexes (verify exact query scope against a live error capture first); replace raw `error.toString()` UI with `AppErrorView` in `learning_screen.dart`, `dashboard_body.dart`, `point_config_screen.dart`; give the Gamification Hub chip a working tap affordance in its error state.
4. **P0 — `firestore_track_learning_order_repository.dart:152-155`:** add `.limit(500)` so the Reorder Content query satisfies `firestore.rules`' list-limit gate; add an error branch to `track_learning_order_screen.dart`.
5. **P0 — `profile_edit_delete_actions.dart:130`:** wrap the Delete Profile callable in try/catch and surface failures — a destructive action must never silently no-op.
6. **P0 — Root Cause D (child-track visibility):** make `FirestoreCurriculumTrackRepositoryAdapter`'s `watch*` methods reactively re-resolve instead of terminating permanently on a one-shot null read.
7. **P1 — Root Cause D (remaining):** give `profileListStreamProvider` and sibling one-shot stream adapters a resubscribing wrapper; add the missing `dashboardGlobalPointsProvider` invalidation after parent point adjustments.
8. **P1 — `account_picker_screen.dart`:** persist the account's real auth provider; route email/password accounts to email/password reauth instead of unconditional Google Sign-In; fix the synthetic-session profile-header collapse.
9. **P2 batch:** `InlineAsyncError` mid-word-wrap sizing (affects 3+ screens); Hebrew date picker silent past-date rejection; "Not signed in" dead tap target; App Permissions location-timeout/denied conflation; ManageTutors empty-state gap; AcceptInvite personalization gap; Hebrew "Synced" string leak in Backup & Sync.
10. **P3 batch:** App Check dual-debug-token doc gap; error-chip mid-word wrap on Dashboard; App Permissions status never reflects prior grants (both settings surfaces); Import-backup empty-submit silent no-op; `chartPointsEarned` Hebrew mistranslation fix + `flutter gen-l10n` regen.

---

## Residual Risk

1. **Coverage is still not complete.** 42/115 screens (36.5%) were not passed this run, concentrated on device 5560 (Learning and Content fully blocked, 0/4 each) by the Root Cause A regression. A full re-audit of those two areas is required once Root Cause A and Root Cause C both land.
2. **Root Cause A's exact racing caller was not pinned at runtime** — static reading of `sign_in_controller.dart` shows correct establish-then-set ordering on its face, yet the exception still fires; the fix needs runtime tracing to confirm which ambient caller wins the race, not just a code-level patch.
3. **Root Cause B's precise index shape needs a live capture before deploy** — two findings independently corrected the auditor's "collection-group query" framing to a plain single-collection query; deploying the wrong-scoped index (as literally decoded from the Console URL) may not resolve the failure.
4. **One needs_device item remains open** (Add-Track wizard Step 3 מועד subtitle clipping) — carry to the next pass.
5. **This rung is still manual.** No CI harness drives these device flows; every finding is a one-shot observation from this session, not a repeatable automated check.

---

*Findings sourced from three device-agent audit passes (5560, 5554, 5562), each independently code-verified against source, screenshot, and logcat evidence before being counted as confirmed.*

# Test-and-fix bug log

One line per defect: **symptom → cause → fix → test**. Newest first. Part of the exhaustive
test-and-fix run (plan: `exhaustive-test-and-fix-plan-2026-05-29.md`).

> Production fixes are Opus-owned. Sonnet sub-agents only write/verify test files.

---

## On-device sweep 2026-05-31 (ADB, real phone) — F-flows + clusters

**D1 (HIGH, product-rule §5 / `feedback_profile_switcher_top` — repeatedly-requested, "top priority"):**
*Symptom* — On-device F6: the **persistent profile/role switcher is absent from the default Dashboard /
Learn / Progress contexts.** Tapped through Dashboard + Learn (self-learner adult, "Daniel Niasoff"): no
top role label / switcher anywhere; only Settings exposed an entry (`UserProfileHeaderCard`), and that now
opens the **account** sheet (`showAccountActionsSheet`), not the switcher (correct per §6, but it means the
switcher entry is gone from the default context entirely).
*Cause* — `AppShellScreen.appBarBuilder` (`lib/app/router/app_shell.dart`) only rendered top chrome
conditionally: `OfflineTopBanner` (offline), `_TutorModeIndicatorBar` (tutor session, →switcher),
`_ChildViewBanner` (parent-mode, →switcher). The **default own-profile case** (neither tutor nor parent-mode)
rendered **no bar at all**, so `showProfileSwitcherSheet` was unreachable from Dashboard/Learn/Progress.
*Fix* — Added a slim always-present `_ProfileSwitcherBar` (44px) to `appBarBuilder`, shown exactly when
`!hasActiveTutoredProfiles && !isViewingChildProfile` (mutually exclusive with the tutor/child bars, so every
context now has exactly one tappable switcher entry at the top). Shows active-profile avatar + name +
`SELF-LEARNER` role badge + `unfold_more` affordance; `onTap → showProfileSwitcherSheet(context)`. Height
folded into the `PreferredSize` calc. Reuses existing l10n (`selfLearnerBadge`) — no new strings. *(Visual
treatment is a sensible default consistent with the existing tutor/child bars; flagged for owner polish.)*
*Name-resolution follow-up (caught on-device)* — first build showed the bar as **"User"** (generic fallback)
instead of "Daniel Niasoff": the bar's name chain skipped the account name. Fixed to the SAME chain as
`UserProfileHeaderCard` — `activeProfile?.displayName ?? account.displayName ?? account.email-handle ??
userFallbackDisplayName` — so a self-learner whose identity lives on the account (no own profile row / pre-stream)
shows their real name.
*Test* — `test/core/navigation/app_shell_test.dart` group "persistent profile switcher": (a) default context
renders the keyed bar + the **resolved active-profile name** + `SELF-LEARNER` badge + unfold icon; (b) tapping
the bar presents `ProfileSwitcherSheet`. The active profile id is pinned deterministically via a
`_FixedActiveProfileId` notifier override (the nav harness never sets the selected-profile pref), so the test
asserts the REAL name, not a fallback. 9/9 green; `make ci` green (8939). **On-device re-verified** (2026-05-31):
bar renders "D · Daniel Niasoff · SELF-LEARNER · ⇕" at top of Dashboard / Learn / Progress / Settings; tapping
opens `ProfileSwitcherSheet` (ACCOUNT / Profiles / TALMID PROFILES / Add Profile). Confirmed Daniel's account has
NO own profile row (Profiles section empty) — identity is the account, which is exactly why the account-name
fallback was required. Pushed drill-down screens (e.g. Manage Tracks) keep their own title bar + back, no
switcher — by design (§5 targets the main tab contexts + parent portal).

**D2 (HIGH, correctness/UX — F8 rewards economy):**
*Symptom* — Child redeems a reward (balance debits in DB) but the **Dashboard star-points counter stays
stale** (shows the pre-redemption balance) until a pull-to-refresh or the next completion. Same staleness for
a parent **decline-refund** not reflecting on the child Dashboard. (Source-confirmed; the redemption screen is
pushed OVER the still-mounted Dashboard, so the dashboard provider is kept alive but never re-evaluated.)
*Cause* — `dashboardGlobalPointsProvider` (`lib/features/dashboard/presentation/providers/dashboard_providers.dart`)
was a one-shot `Future<int>` reading `getBalance`, re-evaluated ONLY on `completionCommittedProvider` change or
pull-to-refresh. `child_redemption_screen.dart:171` invalidates only its own `childRedemptionBalanceProvider`,
NOT the dashboard provider; the parent refund path doesn't touch it either. The DAO already exposed an unused
reactive `watchBalance` stream (`points_balance_dao.dart:62`).
*Fix (root cause)* — Converted `dashboardGlobalPointsProvider` to a reactive `Stream<int>` over
`pointsBalanceDao.watchBalance(profileId)` (`async*`, awaiting `dashboardUserModeProvider.future` to keep the
adults-have-no-points gate and avoid a load-time rebuild/dispose race). Now EVERY balance mutation — completion
credit, redemption debit, decline refund — updates the star counter live; no per-call-site invalidation needed
(eliminates the whole staleness class). build_runner regenerated the provider as a StreamProvider.
*Test* — `dashboard_providers_test.dart`: new "reflects balance changes reactively without invalidate (D2)" —
seeds a child balance, holds a listener (mirrors the mounted dashboard), writes a debit to the balance row, and
asserts the provider emits the new value with NO manual invalidate. Added `_readGlobalPoints` listener-holding
helper (autoDispose StreamProvider whose build awaits → `.read(.future)` without a listener disposes mid-load).
Migrated all `dashboardGlobalPointsProvider.overrideWith((ref) => Future.value(x))` test sites (4 files) to
`Stream.value(x)` (+ the perpetual-loading one to `Completer.future.asStream()`). 91 affected tests green;
`make ci` green. **On-device re-verify: pending (needs a child profile + reward + redemption; will confirm in
the F8 on-device pass).**

**D3 (MEDIUM, l10n — F7 parent-PIN):**
*Symptom* — The parent-PIN lockout panel (shown after 5 failed attempts) renders **hard-coded English**
("Too many failed attempts" / "Try again in N minute(s)") regardless of locale → a Hebrew-locale user sees
English. Violates the Hebrew-terms/locale rule.
*Cause* — `_LockoutPanel.build` in `parent_pin_keypad_dialog.dart` used string literals instead of l10n
(while the tutor equivalent `tutorPinLockedOut` was already localized).
*Fix* — Added `parentPinLockoutTitle` + `parentPinLockoutBody` (with `{minutes}` placeholder) to `app_en.arb`
and `app_he.arb` (HE: "יותר מדי ניסיונות כושלים" / "נסה שוב בעוד {minutes} דקות"); `_LockoutPanel` now uses
`l10n.parentPinLockoutTitle` + `l10n.parentPinLockoutBody(minutes)`. Regenerated via `flutter gen-l10n`.
*Test* — `parent_pin_keypad_dialog_test.dart`: new "lockout panel is localized in Hebrew (not hard-coded
English)" — pumps the panel (`PinKeypadDialogFrame`, lockedOut, 12 min) in `Locale('he')`, asserts the Hebrew
title renders and the English title is absent. Existing English lockout assertions unchanged (EN value is the
same string). ARB parity (DNI-389) + analyze green.

**D4 (HIGH, silent failure — F6/profile creation):**
*Symptom* — On-device: switcher → **Add Profile** → fill name + pick Child → **Create Profile** dismisses the
dialog but **no profile is created and there is NO feedback** (3 attempts, the active account's Profiles list
stayed empty). Found while setting up a test child profile for the F7/F8/F11 on-device pass.
*Evidence* — Pulled the active account's Drift DB (`app_flutter/user_acc_65b3a433….sqlite`): account
`dniasoff@gmail.com` is `accounts.id=2` with **zero** `learner_profiles`; no user-DB was written today (mtime
unchanged). `learner_profiles.account_id` has `REFERENCES accounts(id)`; a test insert with `account_id=2`
SUCCEEDS but `account_id=1` fails **FOREIGN KEY constraint**. "Tttt" in the switcher is a *tutored grant* from
the OTHER account (familyniasoff, id=1), not an own profile.
*Cause (symptom)* — `showAddProfileDialog` (`add_profile_dialog.dart`) caught only `DuplicateProfileNameException`
/ `MaxProfilesExceededException`; ANY other failure (e.g. a `createProfile` account_id FK violation when
`currentAccountId` doesn't match the active DB's accounts row) **propagated and was silently swallowed** — dialog
just closed, no profile, no message. Separately, the success path disposed the `TextEditingController`
*immediately* (use-after-dispose assertion while the dialog animates out) and the error paths leaked it.
*Fix* — (1) Added a generic `catch (e, st)` → `AppLogger.error(event: 'profile_create_failed', …)` + a friendly
`unexpectedError` snackbar, so a failed creation is never a silent no-op. (2) Consolidated controller disposal to
a single delayed `Future.delayed(300ms, ctrl.dispose)` in `finally` (covers all paths; fixes the use-after-dispose
+ error-path leak).
*Test* — `add_profile_dialog_test.dart` (new): "createProfile failure surfaces an error snackbar (not a silent
no-op)" (mock repo throws → asserts the snackbar) + a success-path sanity test (no error snackbar). 2/2 green.
*Root cause (FOUND + FIXED, D4b)* — `profile_switcher_sheet.dart` "Add Profile" row did
`Navigator.of(context).pop(); unawaited(showAddProfileDialog(context, ref))` — popping the modal sheet FIRST
unmounted both the sheet's `context` AND its `ref`. The dialog still opened (it uses `useRootNavigator`), but
after the user tapped Create, `showAddProfileDialog`'s `if (result == null || !context.mounted) return null`
saw the popped sheet context as **unmounted** and bailed *before* `createProfile` — a true silent no-op
(createProfile was never called; not an FK throw after all). FIX: make the row `onTap` keep the sheet mounted
while the dialog runs (`await showAddProfileDialog(context, ref)`) then close the sheet — context+ref stay valid
through the async flow. *Test:* `profile_switcher_sheet_test.dart` — "keeps the sheet mounted and actually
invokes createProfile" (modal-present the sheet → tap Add Profile → assert sheet still mounted + dialog shown →
fill + Create → `verify(createProfile).called(1)`). **On-device VERIFIED** (2026-05-31): switcher → Add Profile →
Child "TestKid" → Set Parent PIN → the profile now appears in the switcher Profiles list (was a silent no-op
before). `make ci` green.

**D5 (HIGH, correctness/race — F8 rewards):**
*Symptom* — A parent's **Fulfil** could overwrite an already-**Declined** (and refunded) redemption, flipping
it to `fulfilled` WITHOUT re-debiting → the child keeps the refund AND gets the reward; also double-fulfil and
fulfil-vs-decline races (two parent devices / rapid taps after the pending list refreshes).
*Cause* — `points_balance_dao.dart` `fulfilRedemption` was an **unconditional** status write (no guard), unlike
`declineRedemption` which guards `status != 'pending_fulfilment'` and returns early.
*Fix* — Added the same guard to `fulfilRedemption`: read the row first, return early unless
`status == 'pending_fulfilment'`. Now idempotent and race-safe (a fulfil can't resurrect a declined/refunded row
or double-fulfil).
*Test* — `points_balance_dao_test.dart`: "fulfilRedemption is a no-op on an already-declined redemption (D5)" —
decline (refund → balance restored, status declined), then a late fulfil → asserts status STAYS declined and
balance unchanged. `make ci` green (8945).

---

## Phase 5b — Navigation guards (unit tests + SYSTEMIC LOCKOUT FIX)

Added unit tests for all 5 AutoRoute guards (Auth 19, Restore 12, Pin 25, ChildMode 7, Profile 14 — branch
coverage + per-branch "resolver always resolves, never a dead-end" assertions). Adversarial verifiers then
surfaced a **systemic production bug** across the whole guard layer:

**BUG (HIGH, lockout): no guard wrapped `onNavigation` in a top-level try/catch.** Any throw inside a guard —
`PinLockoutException` from the PIN prompt, `ProfileMode.fromStorageKey` `ArgumentError` on an unknown mode, a
Drift/SharedPreferences/device_registry failure, a disposed-provider lambda — escaped `onNavigation`, so
AutoRoute's `NavigationResolver` completer was never completed. auto_route 11.1.0 awaits that completer →
**permanent navigation hang (lockout)** on the affected route, with no error surfaced. This is precisely the
lockout class the project has been burned by before.

**FIX:** wrapped every guard's `onNavigation` body in a try/catch that logs (`AppLogger.error`) and always
resolves, guarded by `if (!resolver.isResolved)`. Fail direction chosen per guard role:
- `AuthGuard` → fail to the always-reachable **SignInRoute** + `next(false)` (was a `try/finally` with no
  `catch`, so a corrupt `device_registry` made `getAllAccounts()`/`close()` propagate → hang).
- `ProfileGuard`, `RestoreGuard` → **fail OPEN** (`next()`) — not security gates; let the user into the
  app/shell (which handle empty/no-profile state) rather than hang. (ProfileGuard body extracted to `_resolve`.)
- `PinGuard`, `ChildModeGuard` → **fail CLOSED** (`next(false)`) — security gates; deny cleanly, never bypass.

**Tests:** each guard got a fail-safe regression test that injects a throwing dependency and asserts the safe
resolve (no throw, no hang). AuthGuard's is exercised by writing a non-sqlite file to the registry path.
`make analyze` clean; all 111 navigation/auth tests green.

**Dismissed as NOT a bug:** the ChildModeGuard "corrupt mode string → ArgumentError" finding is already
defended at the DB layer — `learner_profiles.mode` has a CHECK constraint `IN ('adult','child')`, so a corrupt
string can't be persisted. The fail-safe stays for the reachable throw sources (disposed provider, DB I/O,
defence-in-depth against a future migration). Also **deleted** the redundant old `test/core/auth/auth_guard_test.dart`
(3 branches, no lockout assertions, shared-path mock) — fully subsumed by the new canonical
`test/core/navigation/auth_guard_test.dart` (19 tests).

---

## Phase 8 — Coverage wave 10: account/settings/content <75% lift

**+99 tests** (green, analyze clean, standalone, no prod bugs): **sign_in_controller routing** (7 — NOW real,
post connectivity-DI: cloudBorn online→Firebase, offline→local-restore, offline+no-data→error, email-verify
guard, Submitting state; 2 honest skips for the localBorn argon2id path), settings utils send_logs +
account_actions (11), curriculum_settings + change_password_dialog (23), content tile/search/providers (28),
pending_local_signup + sign_in_mode_card (30).

### Backlog (verifier-flagged, not bugs)
- sign_in localBorn arm + `_navigateAfterSignIn` destination routing + 15s watchdog + tutor-grant bypass still
  uncovered — gated by the `LocalAuthService` argon2id seam (PasswordHasher.dummyVerify blocks tests >30s).
  Needs a fast-hasher provider injection (the next auth testability refactor).
- `showDeleteLocalAccountFlow` (account_actions) guard-heavy flow untested; one weak tautological assert in
  send_logs (lvl-uppercase). Logged.

---

## Phase 8 — Testability refactor: connectivity DI in sign-in (unblocks account coverage)

`sign_in_controller` called `InternetConnectionChecker.instance.hasConnection` directly at 3 sites, bypassing the
existing `internetConnectionCheckerProvider` — whose own doc says it's "exposed as a provider so tests can override
with a fake". That made the local-vs-cloud routing + offline branches untestable (wave 6's sign-in test was
discarded as false-confidence for exactly this reason). FIX: read the provider via `_ref` (3 sites) and dropped the
now-unused direct import. Behaviour-preserving (configured instance vs singleton, same probe); analyze clean.
Tests can now override connectivity online/offline. (Remaining auth testability debt: `LocalAuthService` is
constructed internally with production argon2id — the localBorn sign-in branch still needs a fast-hasher provider
seam; logged.)

---

## Phase 8 — Coverage wave 9: worst-feature lift (+ sacred-time race fix)

**+217 tests** (green, analyze clean, standalone): sacred_location + cities_repository + location_service (47),
notification_gateway (60), account_picker_screen (14), siyumim_timeline + lifetime_knowledge_providers (32),
tutor_pin_entry_dialog + goal_setup_screen (34), text_display reader deeper (30).

**BUG fixed (sacred_time, MEDIUM race):** `InIsraelNotifier._load()` is re-triggered by `ref.invalidate()` inside
`setManualCity`/`detect`. Being async, the rebuilt notifier's `_load()` could resume AFTER a synchronous
`setInIsrael(true)` and clobber it with the stale prefs value — silently reverting a visitor's manual "two-day
chag" inIsrael toggle (set non-IL city, then flip inIsrael=true → race reverted it to false). FIX: a per-instance
`_explicitlySet` flag — an explicit `setInIsrael` wins over a racing `_load`; the flag resets on rebuild, giving
the intended semantics (location change → country default; manual override sticks until the next location change).
Also added `ref.mounted` guards to both `_load()`s (no set-after-dispose on account switch). Un-skipped the race test.

---

## Phase 8 — Coverage waves 7+8: profiles cluster + SYNC-ENGINE internals

**Wave 7 (+150, all behavioral, no prod bugs):** pin_flow + parent_pin_setup_dialog (28), profile_picker +
tutored_children deeper (24), settings_screen + point_config (36), notification_providers deeper (32),
step_study_days + content_hierarchy (25), scheduler amnesty/deadline branches (5). Logged latent: pin
change-mode confirm lacks an ArgumentError catch (likely unreachable behind the 4-digit guard).

**Wave 8 — sync-engine internals (+229, all behavioral, no prod bugs):** the historical quality-crisis area is
now heavily tested and verified correct: `push_pipeline_impl` (39 — per-collection routing, single-flight
serialisation per kind, partial-commit propagation), **`drift_merge_store` (59 — the LWW / merge-forward rules
for every entity: remote-newer vs older, clock-skew tie-break, tombstone resurrection, malformed-skip,
idempotency)**, `outbox_processor` (17 — drain ordering/retry/single-flight guard), `seed_manager` (43 —
extract/upgrade/integrity-recovery branches), `stage_definition_codec` + `ui_preferences_merger` (71 — codec
round-trips + per-field preference merge). No merge/sync correctness bugs found — the engine holds.

### Verifier-flagged backlog (gaps, not bugs)
- push_pipeline: concurrent-failure-with-queued-waiter path; wrong-typed `profile_id` payload cast.
- drift_merge_store: bookmark LWW is enforced at the DAO layer (not the store); `_upsertTrack` is_active→state
  back-compat shim untested.

---

## Phase 8 — Coverage wave 6: deep logic (scheduler engine, credit policy, controllers)

**+167 tests** (green, analyze clean, standalone, no prod bugs found): the high-value ones drive REAL logic, not
mocks:
- **scheduler `allDailyTasksProvider`** (11) — wires the actual SchedulerEngine + projection + DAOs over an
  in-memory DB and asserts the COMPUTED task list: self-paced pace→N tasks, overdue vs new bucketing, the
  bulk-prior SENTINEL-date shift, skipped-ref exclusion, previously-skipped→overdueChazara priority boost,
  rest-day study-day configs, multi-curriculum, priority sort. (Previously the provider body was overridden away.)
- **reward_config_controller** (47) — real Drift DB + RewardMilestoneService (save/edit/delete/validation).
- **completion_writer** (41) — the three-tier credit policy + bulk-mark sentinel date (credits lifetime/siyum,
  not streak/recent) + dedup. Policy holds (no bug).
- **step_chazara_readonly + step_goal** (31); **signup_screen** (37).

### Integrity note — DISCARDED a false-confidence test
The sign_in_controller "main flow" test (12) was **discarded**: the independent verifier found every non-trivial
assertion was network-conditional (silently skipped offline) or tautological. Root cause is testability debt, not
the tests — committing them would have inflated the coverage number without verifying behaviour.

### Testability debt logged (DI refactors for a focused pass)
- `sign_in_controller` / `signup_screen`: `InternetConnectionChecker.instance` is a non-injectable STATIC
  singleton (no provider) → connectivity can't be mocked, so the local-vs-cloud routing + offline paths can't be
  deterministically unit-tested. Also `LocalAuthService` is constructed internally with production argon2id
  (19 MiB / 2 iters) which blocks the test event loop >30s. Fix: provider-inject the connectivity checker + a
  test-fast PasswordHasher. Sign-in error-MAPPING is already covered (leverage wave); this unblocks the deep flow.
- `signup_screen`: `_showError` strings hardcoded English (i18n).

---

## Phase 8 — Coverage wave 5: magic-link + tracks/progress/content/onboarding (+ magic-link crash fix)

**+169 tests** (green, analyze clean, all standalone-green — the wave required isolation after a prior
order-dependent file): magic_link_service (27), edit_track + track_detail (41), add_track_flow (12),
recent_activity + hierarchy_selection_panel (27), onboarding_screen (34).

**BUG fixed (magic_link_service, MEDIUM):** `_extractActionUri` called `Uri.decodeComponent(next)` with no
try/catch when unwrapping a `link=`/`deep_link_id=` deep link. A malformed percent-encoded value (e.g. `%%%`)
threw `ArgumentError: Invalid URL encoding`, which propagated uncaught through the deep-link stream listener and
crashed the service. FIX: the decode is wrapped in try/catch and returns the current URI (stops unwrapping) on
failure. Un-skipped the regression test.

### Findings logged (backlog)
- `add_track_flow` (MEDIUM): the DNI-202 scope auto-skip (empty scope content) means pressing Back from the step
  after scope lands on the scope step which immediately re-advances — the user can't navigate back past an
  auto-skipped step. Fix would need skip-on-back symmetry in the wizard nav; logged.
- magic_link deeper paths (verifier): `onSignedIn`/`updateDisplayName` throwing escapes the listener; simultaneous
  cold+warm duplicate delivery → double sign-in; >3-level wrapping silently fails; warm-link tests use a 50ms
  `Future.delayed` timing hack (CI-fragile) rather than a completion signal.

---

## Phase 8 — Coverage wave 4: account/tutoring/dashboard (+ CRITICAL upgrade-crash fix)

**+188 tests** (green; 3 skips on email-panel medium bugs): upgrade_to_cloud_service (33), email_verification_confirm_panel
(24), firestore_tutor_grant_repository (76), dashboard_providers (41), achievement_unlock_celebration (14).
(`magic_link_service` agent failed to return output — re-target next wave.)

**BUG fixed (CRITICAL — runtime crash on the account-merge flow):** `discardLocalCredentials()` called
`UserProfileDao.updateUserProfile()` → `update(accounts).replace(entry)`, which requires a COMPLETE row but was
handed a partial companion (`id` + `passwordHash` only) → **`InvalidDataException` at runtime**. Any user who
chose "discard local" on the email-collision merge path (and thus all of `executeKeepCloudDiscardLocal()`) would
crash. FIX: added a dedicated `UserProfileDao.clearPasswordHash(profileId)` doing a targeted `.write()` (the same
partial-update pattern as `upgradeLocalToCloud`); `discardLocalCredentials` now calls it. **Un-skipped the 3
tests** the wave had parked over this crash — they pass against the real in-memory DAO. Full suite re-gated.

### Findings logged (email_verification_confirm_panel — medium/low, backlog)
- RTL (he) layout overflow (~16px) in the Send-Again+Cancel row at 360px (wrap children in Flexible).
- `_wrapSendAgain`/`_wrapVerified` use try/finally with NO catch → a throwing callback propagates as an unhandled
  async error (should catch + surface). (2 tests skipped over this.)
- All panel strings hardcoded English (i18n) — `Confirm Your Email`, `I've verified`, `Open Email`, `Send Again`, `Cancel`.
- `upgrade_to_cloud_service` deeper paths (verifier): `tryFinalizeVerifiedCloudUpgrade` bare `catch(_)` swallows
  DB/network errors; `executeUploadLocalIntoCloud` no cloudBorn guard; `_extractFirebaseCode` null-return rethrow.

---

## Phase 8 — Coverage wave 3: remaining screens & widgets (+ scope-save bug fix)

**+242 tests** (green, analyze clean): scope_selection + lifetime_marking (42), track_management_body +
track_learning_order (29), onboarding + bulk_mark (34), profile_picker + tutored_children_section (19),
text_display reader (38, incl. tutor live-mark gating), lifetime_folder_styled_widgets + notification_providers (79).

**BUG fixed (scope_selection_screen, LOW but real):** `_save()` had no else-branch — with "select all" toggled
OFF, a level picked, but NO values ticked, it wrote nothing yet still `pop()`ed with a *success* snackbar, so
the user believed the scope was cleared/changed while the previous scope silently survived. FIX: the AppBar
Save button is now disabled (`onPressed: null`) unless `_selectAll || _selectedValues.isNotEmpty` (a `_canSave`
getter) — an empty subset is no longer "saveable". Regression test added (Save disabled on empty subset, re-enabled
once a value is ticked).

### Findings logged (not fixed — low/edge or test-coverage gaps)
- `scope_selection._save`: `trackId = track?.id ?? 0` fallback can write a dangling `trackId=0` row if a
  curriculum has no track (likely unreachable for an enrolled curriculum; logged).
- `TrackManagementBody` vs `TrackManagementHubScreen`: archive path diverges (low).
- Verifier false-confidence notes: several suites pre-set state rather than driving the widget (sliders/drag),
  and a couple of "policy" asserts call the mock directly rather than through the screen — backlog to harden.

---

## Phase 8 — Coverage wave 2: sync engine + onboarding/settings/profiles

**+298 tests** (green, analyze clean, 2 documented skips; no high-severity prod bugs): `firestore_gateway_impl`
19.6%→ (**114** — path building, merge idempotency, internal-key stripping, Timestamp normalisation, batch
chunking, pagination, listeners, unauthenticated/permission-denied error paths), `sync_orchestrator` 54.5%→
(**29** — pull/push state machine, once-per-launch guard, resume throttle, status emissions, pull ordering),
`local_data_upload_service` 0%→ (**42** — outbox pipeline), onboarding `wizard_steps` 0%→ (**62**),
`account_actions` 0%→ (**25** — sign-out/delete dialog confirm+cancel flows), `parent_pin_keypad_dialog` 30%→
(**26** — digit entry, verify, error/clear).

### Documented skips / findings (not high-severity)
- `firestore_gateway` fetchPage cursor test: `fake_cloud_firestore` can't handle a `FieldPath.documentId`
  startAfter cursor (`skip:true`) — fake-library limitation, works on the real emulator/prod.
- `sync_orchestrator` timeout test: `_perStepTimeout`/`_overallTimeout` are private static consts with no
  injectable seam (`skip:true`); would need 30–90s real waits. Low — recommend constructor Duration params.
- `sync_orchestrator` goals-subcollection PUSH gap: known/pre-existing (memory project_sync_orchestrator_status_bug)
  — pull works + is tested; push absence is the open item, unchanged here.
- `account_actions` (LOW): `_DeletingAccountOverlay` calls `ref.read(authStateProvider.notifier).signOut()` in a
  catch during the build/initState-driven deletion; if `deleteAccount` threw *synchronously* it would mutate a
  provider during build. Edge case (deleteAccount is an async CF call). Logged.

### Verifier-flagged deeper gaps (backlog)
- `firestore_gateway`: real multi-chunk partial-commit `SyncPushException` committed-keys accuracy;
  `deleteLearnerProfile` callable path; `_timestampify` DateTime input branch; self-tutoring grant dedup in
  `listenToTutorGrants`; `deleteUserData` nested sub-subcollection cleanup.
- `local_data_upload_service`, `wizard_steps` (sliders pre-set not dragged), `pin_keypad`: several branches.

---

## Phase 8 — Coverage-leverage wave (highest-uncovered files)

Coverage measured 2026-05-30: **68.4%** overall (36774/53763), up from the 58.5% baseline; full suite +6956
tests green. Targeted the highest-leverage uncovered files with **+249 tests** (all green, analyze clean, no
prod bugs):
- `sefaria_ref_matcher.dart` (was 0%) — **116 unit tests** across normalize/displayRef/range-expand/fuzzy-match/
  container-resolution/program-today-refs.
- `scheduler_providers.dart` (was 11.7%) — 43 tests (section/grouped notifiers, SkippedTasks date-rollover,
  paceStatus, overdueCount, firstTaskInTrackForCategory).
- `sign_in_controller.dart` (was 8.5%) — 24 tests (auth-error mapping, Google sign-in routing, resend-verify).
- `step_scope.dart`/`scope_views.dart` (was ~0%) — 22 tests (DNI-202 scope auto-skip, toggle/select-all/Learn-All).
- `step_starting_position(+calendar+goal).dart` (was ~0%) — 44 tests (the [today−30, today] window + **back-date
  → positive daysFromToday/overdue** product rule, goal step).

### OPEN — deeper integration paths still uncovered (verifier-flagged backlog)
- `scheduler_providers`: `allDailyTasksProvider`'s ~400-line body is bypassed (tests override it with fixed
  lists) — the previously-skipped priority-boost + bulk-prior sentinel paths aren't exercised end-to-end.
- `sefaria_ref_matcher`: level4 hierarchy filtering, fuzzy-score==1 boundary, container-vs-indexed fallback
  ordering, range→container fallback, and `normalizeTitle` blind spots (bavli/yerushalmi/tractate/masechta).
- track-setup scope: re-render/re-selection stateful logic; start-position: a few production UI paths.

---

## Phase 6 — Settings / scheduler / notifications / sacred-time / learning (wave a)

+127 L1 behaviour tests across 5 zero/low-coverage screens (all green, analyze clean): **CityPicker** (19 —
search/filter, select→`setManualCity`+`router.pop`, loading/empty/error), **CurriculumSettings** (26 —
program tiles, change/request, no track-type label), **Learning** (22 — reader states + the **tutor
live-mark-block product invariant** `canMarkLiveCompletion=false`, chazara-only-when-enabled), **Scheduler**
(23 — view toggle, skip writes + snackbar, states), **Notifications** (37 — each reminder toggle persists to
prefs, permission-denied/disabled, states). The LearningScreen live-mark invariant test passes → the gate
holds in the UI.

### OPEN — i18n / cosmetic (Phase 8 / backlog)
- `city_picker_screen.dart:79`: empty-state `'No matches for "$query".'` hardcoded English (not l10n).
- `learning_screen.dart` `_LearnTaskCard`: `Icons.history_rounded` renders on ALL task cards regardless of
  priority (cosmetic, not a product bug).

### OPEN — coverage strengthening (verifier-flagged; backlog for the loop pass)
- Notifications: reminder **time** selection persistence (`reminderTimeProvider`) is not asserted (toggles are).
- Scheduler: skip **Undo** action is found but not tapped/asserted to call `undoSkip`.
- CurriculumSettings: error-state path claimed in header but no throwing-provider test (screen is thin).
- Learning: OVERDUE task UI branch (priority_high icon + red OVERDUE badge) not asserted.
- CityPicker: `TrimLeadingSpaceFormatter`, `admin1==""` branch, query-change provider re-watch untested.

---

## Phase 7 — Backend / Cloud Functions (wave b)

**All 27 Cloud Functions now have tests: 271 assertions, 271/271 green** via `make test-functions`
(tsc build → `firebase emulators:exec --only firestore,auth` → `node --test --test-concurrency=1
functions/test/cf_*.test.mjs`). The suites run the REAL built handlers through `fft.wrap()` and assert the
gate matrix (unauthenticated / invalid-argument / not-found / inactive-grant / wrong-tutor / missing-permission)
plus the Firestore side-effect + audit-log write of each happy path. Files: cf_tutor_completions (8),
cf_tutor_goals_tracks (48), cf_tutor_content (70), cf_tutor_settings_profile (44), cf_grant_invite (29),
cf_grant_revoke (29), cf_deletes (22), cf_triggers (21).

**DEPLOYED 2026-05-30:** `firebase deploy --only functions --project torah-study-tracker` — all 27 functions
"Successful update operation", "Deploy complete!". The 3 fixes (expirePendingInvites / declineTutorInvite /
deleteCurriculumTrack) are live; the live backend now matches the repo.

**HARNESS BUG fixed (was hiding 31 failures):** `clearFirestore()` used the emulator REST clear endpoint,
which returned before nested subcollections (`tutor_grants/{id}/audit_log`) were purged — stale grants
survived (so "no grant → not-found" tests instead hit a stale active grant → permission-denied) and audit
entries accumulated across tests (`2 !== 1`, `3 !== 1`…). Switched to the Admin SDK's awaited
`recursiveDelete` over `tutor_grants`/`users`/`tutor_active_access`. Also added the **Auth emulator**
(`--only firestore,auth`) since accept/decline invite call `admin.auth().getUser()`.

### Server-function findings (triaged)
**FIXED (real bugs, with regression tests — 274/274 green):**
- `expirePendingInvites` (MEDIUM): the Firestore transaction `txn.update(grantDoc.ref, …)` never re-read the
  doc inside the txn — the snapshot was taken outside it, so a state change (accept/decline/rescind) between
  the query and commit was a lost-update race that could expire an already-accepted grant. FIXED: re-read
  inside the txn and only expire if `state === 'pending'`; return whether it actually expired.
- `declineTutorInvite` (MEDIUM): called `admin.auth().getUser(callerUid)` BEFORE the cheap uid check. FIXED:
  resolve `isTutorByUid` first (no Auth call) and only fall back to the live `getUser` email comparison when
  the uid doesn't match — preserves the permission-before-state order, avoids an Auth round-trip on the common
  path, and makes the uid-match decline path testable without the Auth emulator (2 new regression tests).
- `deleteCurriculumTrack` (MEDIUM): used shallow `trackRef.delete()` while every sibling delete CF uses
  `recursiveDelete`. FIXED: `db.recursiveDelete(trackRef)` (+ a regression test seeding a nested subcollection
  doc and asserting it's purged).

**Documented (defensible design / low value — NOT changing):**
- `tutorBulkPriorCompletions`: today/future completion → `permission-denied` (arguably `invalid-argument`);
  also inline-duplicates `verifyTutorGrant` instead of calling it (drift risk). Rejection itself is correct.
- `revokeTutorGrant`/`resignTutorGrant`: inactive grant → `failed-precondition` (not `permission-denied` like
  the verifyTutorGrant CFs) — defensible; and neither writes an audit_log entry (grant `state`/`revoked_at`
  are self-documenting). Consider an audit entry later.
- `tutorEditProfile`: `permKey=null` → any active grant may edit name/avatar/mode (intentional per FR-3 §1920).
- `listTutorGrants` `pending_for_me` returns `[]` when caller has no verified email (silent, not an error).
- `purgeExpiredAuditLogs`: counter increments per-grant not per-entry (cosmetic logging only).

### Coverage gap (logged)
- `acceptTutorInvite`/`declineTutorInvite` happy paths need a seeded Auth-emulator user; the gate tests are in
  but the full accept/decline success flow is not yet asserted. Follow-up: seed `admin.auth().createUser` +
  assert the grant→active transition + tutor_active_access doc + audit entry.

---

## Phase 7 — Backend / Firestore rules (wave a)

`functions/test/firestore_rules.test.mjs`: **5 → 24/24 match paths, 70 assertions, 0 fail** (4.8s under the
firestore emulator via `make test-rules`). New coverage: the full learner subtree (settings, stage_definitions,
curriculum_tracks, bookmarks, learning_order, preferences, streak_events, learning_ledger, points_ledger,
reward_redemptions, import_metadata, profile_programs, curriculum_scopes, study_day_configs) — each asserting
owner read+write, tutor active-access read-only, write-block, stranger/anon deny, delete policy, and `hasOnly`
field whitelists; the tutor-EXCLUSION blocks (`users/{uid}/profile/{docId}`, `diagnostic_logs`); the
`tutor_grants/audit_log` party-read/no-client-write; and the global `/{document=**}` default-deny.

**Rule hardening (comment-only — no behaviour/deploy change, re-verified green):** added explicit "tutor access
intentionally excluded" intent comments to the `/profile/{docId}` and `/diagnostic_logs` blocks (agent finding
#1) — account-scoped siblings of `learner_profiles/`, owner-only by design; guards against a future refactor
accidentally extending tutor read access to account data.

### Reviewed & dismissed (NOT bugs)
- Finding #2 (tutor_active_access asymmetry): the parent/owner cannot directly read the
  `{tutor}_{owner}_{profile}` access-index doc (only the tutor can). BY DESIGN — the index is a CF-maintained
  tutor-side lookup; the parent discovers active tutors via `tutor_grants` (which they CAN read). No change.

---

## Phase pre-0 — green the baseline (WIP-induced failures)

The working tree carried in-progress work (profile-switcher / settings account-separation /
tutor-permissions). The full suite was red: **12 failing tests**. Owner decision: *treat the working
tree as the baseline and fix the 12*. Each WIP change was checked against the product memories and
found correct; two of the WIP files also carried real bugs that the stale tests had masked.

### Real production bugs (fixed)

- **BUG-001 · AppShell crashes for profile-less users.**
  *Symptom:* `app_shell_test` threw `AutoTabsRouter operation requested with a context that does not
  include an AutoTabsRouter`; in production a tutor-only adult (0 own profiles) entering the shell
  would crash in a post-frame callback.
  *Cause:* the WIP "jump to Settings tab" called `AutoTabsRouter.of(context)` using the
  `_AppShellScreenState`'s own context, which sits **above** the `AutoTabsScaffold` that creates the
  tabs router — so the lookup fails.
  *Fix:* `lib/app/router/app_shell.dart` — schedule the jump from inside `appBarBuilder`, which hands
  a valid `tabsRouter`; `build()` only resets the `_didJumpToSettings` latch.
  *Test:* `test/core/navigation/app_shell_test.dart` (seeds a profile so the shell stays on Dashboard;
  the profile-less jump path is exercised on-device in Phase 5).

- **BUG-002 · Account actions sheet — invisible ink / framework assertion.**
  *Symptom:* opening the account sheet threw `ListTile background color or ink splashes may be
  invisible` (one per tile); tile taps had no ink feedback.
  *Cause:* `account_actions_sheet.dart` wrapped its `ListTile`s in a coloured `DecoratedBox` with no
  `Material` ancestor between them.
  *Fix:* `lib/features/settings/presentation/widgets/account_actions_sheet.dart` — root container is
  now a `Material(color, shape)`.
  *Test:* `test/features/profiles/presentation/profile_switcher_sheet_test.dart` — tapping the Settings
  header opens the account sheet and finds ACCOUNT / Switch account / Sign Out.

### Test-truth alignments (stale tests updated to the intended WIP behavior — no production change)

- **Tutor permission defaults false→true.** `ws3_3d_tutor_permissions_surface_test.dart` asserted the
  old read-only defaults. Updated AC5 to expect the parent-equivalent defaults (`canEdit*` = true) and
  rewrote the copyWith test to start from `TutorPermissions.readOnly()`. (`feedback_tutor_parent_view`.)
- **Profile-less → AppShell (not the picker).** `profile_guard_test.dart` Branch-2 now expects
  `resolver.next()` (allow into shell) instead of `router.replace(ProfilePickerRoute)`.
- **Settings account-separation.** `settings_screen_test.dart` "renders lower sections" → repurposed to
  assert account actions are **absent** from the Settings body (they live in the header sheet).
  (`feedback_settings_account_profile_separation`.)
- **Header tap opens the account sheet.** `profile_switcher_sheet_test.dart` — header tap now opens the
  account-actions sheet, not the profile switcher.
- **Empty-login CTA copy.** `empty_login_ws2_test.dart` — banner CTA is now "Add a learning track".

**Result:** `make ci` green — analyze (no issues) · validate-calendar (OK) · test (6098 pass / 125
skip / 0 fail). Line coverage baseline **58.4%** (31,238 / 53,527).

---

## On-device verification (2026-05-29, Galaxy S24 over Tailscale ADB)

Confirmed live on the physical phone (`com.jcom.torah.learning_tracker`):
- **Build→install→run pipeline** works end-to-end: `flutter build apk --debug` (JDK 21) → `adb install`
  → relaunch → MainActivity renders. `flutter devices` lists the phone (android-arm64, Android 16).
- **Dashboard** (empty-state "Add a learning track"), **Settings**, the **account-actions sheet**
  (Switch/Add/Sign-out/Delete — Material fix confirmed, no invisible-ink), and the **Account Picker**
  (Daniel = CLOUD valid; Family = "SIGN IN AGAIN" expired) all render correctly.
- **Account switch**: tapping the valid account switched **instantly back to the Dashboard, no sign-out**
  — matches DEC-34. (Locked by `account_picker_switch_test.dart`.)
- **Deploy**: `firebase deploy --only firestore:rules` → "Deploy complete!".

L4 tooling note: this Flutter build does **not** expose a semantics tree to `uiautomator` (single-surface
render), so the on-device sweep harness must be **screenshot-coordinate based** (read screenshot → compute
pixel → `input tap`), NOT UI-hierarchy based. The app bottom-nav row is ~y≈2200 on 1080×2340; the system
nav bar sits ~y≈2300 (don't tap there — it backgrounds the app). `integration_test` (widget-finder based)
needs the debug-VM connection, which is flaky over wireless ADB — prefer the coordinate sweep for L4.

---

## Phase 1 — Tutoring (wave 1: 6 zero-coverage screens)

Added **111 L1 widget tests** across the 6 screens that had no dedicated tests — TutorPinSetup (18),
TutorPinReset (9), InviteTutor (19), ManageTutors (31), ManageGrants (12), TutorAuditLog (22). 108 pass,
3 skipped pending the RP3-RETRY decision below. (Fan-out: Sonnet wrote/greened tests; Opus reproduced
every reported bug + owns this analysis.)

### FIXED (root cause)

- **RP3-RETRY · Riverpod 3 auto-retry hides the error+retry UI on persistent first-load errors.**
  *Symptom:* a hand-written `FutureProvider` that errors on first load (e.g. `incomingTutorGrantsProvider`,
  `tutorAuditLogProvider`) never reaches `asyncValue.when(error:)` — the screen shows the loading spinner
  forever. Reproduced with a `ProviderContainer`: default → `AsyncLoading(error:)` (`isLoading=true`);
  with `retry: (_, __) => null` → `AsyncError` (`.when(error:)` fires). Riverpod 3.0 **retries failed
  providers by default** (the app upgraded to flutter_riverpod 3.3.1). Codegen `@riverpod` providers
  already emit `retry: null`; only the hand-written `FutureProvider`s inherit the retrying default, so
  their error UI is effectively unreachable on persistent errors (transient errors do still recover —
  that's the upside of retry).
  *Scope:* app-wide (every `.when(loading:, error:, data:)` over a hand-written FutureProvider).
  *Options:* (A) bounded global retry on the root container/ProviderScope (transient recovery **and**
  eventual `AsyncError` → error view) — recommended; (B) `retry: (_, __) => null` globally (matches
  codegen, immediate error view, no transient recovery); (C) per-provider `retry: null`; (D) change the
  render pattern to treat `hasError` as error even while loading (loses transient recovery).
  *Resolution (FIXED 2026-05-29):* disabled provider retry globally in `bootstrap()`
  (`retry: (_, __) => null` on the root `ProviderContainer`) — restores the app's original error+retry
  design intent and matches the codegen providers (already `retry: null`). Errored providers now surface
  `AsyncError`, so `.when(error:)` renders the error+retry view. The 3 tests are un-skipped (their test
  `ProviderScope` sets `retry: (_, __) => null` to match production) and pass. Owner granted full
  authority for this app-wide change.

### OPEN — i18n (Phase 8)

- Hardcoded fallbacks in `tutor_grant_aggregate.dart`: `childDisplayLabel` → `'Talmid'` (~:144),
  `parentDisplayLabel` → `'Parent account'` (~:150) when the name is null — not l10n. Fix belongs in the
  presentation layer (domain VO must not import l10n — layering Rule). 
- Shared widgets with hardcoded English: `AppErrorView` `'Retry'` / `'Report this issue'`
  (`app_error_view.dart`); `pin_entry_widget.dart` `'Clear'` / `'Too many failed attempts'` /
  `'Try again in N minute(s)'`. Reachable from tutor PIN setup error state.

### Wave 2 (2026-05-29)

+104 behaviour-focused L1 tests: AcceptInviteScreen (23 — all 6 `_AcceptStep` transitions, auth gate,
offline stub-grant fallback, precondition branches), DeclineInviteScreen (21), TutorPinEntryGate (21 —
correct/wrong PIN, lockout, reset), ManageTutorsScreen strengthened (31→39). Each file has an he-RTL
smoke test. No production bugs found; the only finding is the `pin_entry_widget.dart` hardcoded strings
(already logged under i18n). **All 10 tutoring screens now have L1 coverage.**

### Tests need strengthening (tracked, not blocking)

Verify pass flagged the wave-1 tests as render-heavy (render-only counts: PinSetup 11, ManageTutors 19,
AuditLog 10, others fewer). Missing cells noted: loading/`_isSaving` spinner, he-RTL, negative
assertions (callback NOT fired on error). Wave 2 will strengthen behaviour assertions + add he-RTL.

---

## Phase 2 — Sync & offline-first (wave 1)

+52 L1 tests: **OfflineTopBanner** (15 — tier-gated visibility: cloud-born+offline shows, local-born/
online hidden), **SyncStatusIndicator** (19 — 7 states: localOnly/synced/syncing/pending/offline/error/
degraded), **BackupSyncSection** (18 — cloud-synced / cloud-offline "LOCAL ONLY" / local-born upgrade
cards). All green.

### FIXED — dead code removed

- **SyncScreen (`/sync`) was an unreachable placeholder.** AppBar + a static `Center(Text)` with no
  state-driven rendering; the `SyncRoute` was registered with authGuard but **never navigated to** from
  anywhere in the app (no in-app push, no deep-link). The real sync UX is BackupSyncSection + the offline
  banner + the status indicator (sync is informational-only, `feedback_offline_first`). Deleted the
  screen + route + import and regenerated the router. (The 6 "bugs" the test agent reported against it
  were all "this placeholder is unimplemented" — resolved by removal, not implementation.)

### OPEN — i18n (Phase 8)

- `offline_top_banner.dart`: banner body + Semantics label are hardcoded English ("Offline — changes
  will sync when you're back…"), not l10n.
- `sync_status_indicator.dart`: 9 hardcoded status labels ("Local only", "Synced", "Syncing",
  "$n pending", "$n queued", "Offline", "Sync error", "Sync paused", …) — not l10n.

---

## Phase 4 — Gamification (wave 1)

+67 L1 tests: **GamificationScreen** (19 — achievements/streak/points; adults have no points),
**ChildRedemption** (15 — affordable vs unaffordable gating, confirm/cancel, balance deduction verified),
**ParentPendingRedemptions** (17 — approve/decline), **RewardConfiguration** (16 — create/edit validation,
delete confirm). All green, analyze clean.

### FIXED (production)

- **Double-tap guard on ParentPendingRedemptions Fulfil/Decline.** Both buttons were always-enabled; a
  rapid double-tap could run `fulfilRedemption` → `_pushRedemption` (a redundant sync push) twice. LOW
  severity — the DAO is idempotent (`fulfilRedemption` sets `status='fulfilled'`; `declineRedemption`
  early-returns unless `status == 'pending_fulfilment'`, so **no double-refund**) — but the kickoff
  requires the guard and it matches the app's `_isFinishing`/`_isSaving` pattern. Fix: `_RedemptionCard`
  is now `StatefulWidget` with a `_busy` flag that disables both actions while the async is in flight.
  (A deterministic double-tap regression test is infeasible in flutter_test here — guarded `tap()` calls
  can't overlap and the in-memory DAO resolves before a second awaited tap — so the test asserts the
  fulfil path and the guard is verified by construction.)

### OPEN — i18n (Phase 8)

- `streak_widget.dart`: `'${currentStreak} day streak!'` (:125) + `'(best: $maxStreak)'` (:177) hardcoded.
- `points_display_widget.dart`: `'+$pointsEarned points!'` (:96) hardcoded.

### Strengthening backlog

- GamificationScreen render-heavy (9/19 render-only): lock/affordability gating (`LockedAchievementShell`),
  progress-bar arithmetic, status labels, unlock-celebration double-tap guard, pull-to-refresh, sort order
  untested. → strengthen in a later wave.

## Phase 5 — Account / Onboarding screens (wave a)

+68 L1 tests: **AppIntro** (12 — palette, page swipes, Skip/Get-Started → SignInRoute + kIntroSeen write),
**PermissionPrompt** (24 — notification/location asks, grant→gateway, skip→proceed), **UpgradeToCloud**
(17, +7 skipped — see DI note), **DeviceRestore** (15 — in-progress/success/error states). All green,
analyze clean. No functional production bugs.

### OPEN — i18n (Phase 8)
- `app_intro_screen.dart`: `'Skip'` / `'Continue Journey'` / `'Get Started'` hardcoded.
- `permission_prompt_screen.dart`: ALL user-facing strings hardcoded (titles, CTAs, card titles/subtitles, body).

### OPEN — testability / DI refactor (Opus, careful — security-sensitive)
- `UpgradeToCloudScreen` inline-instantiates `UpgradeToCloudService` (2 call sites) instead of injecting it
  via a provider, so L1 tests can't mock the argon2id-gated local→cloud upgrade path → **7 tests skipped**.
  Fix: add `upgradeToCloudServiceProvider` (its deps — authRepository, dao, registry — are already
  providers) and read it; then un-skip + complete the 7 tests. Functional path works; this is a
  testability/DI debt to clear in a focused pass.

---

## Phase 4 — Profiles (wave 1)

+90 L1 tests: **ProfilePicker** (17 — selection, sign-out matrix, max-10, empty→TutoredChildrenSection),
**ManageLearners** (20 — CRUD, edit/delete flows), **ParentSettings** (33 — tutor-permission tile matrix:
edit tiles gated on `activeTutorPermissionsProvider`, owner-only tiles hidden in tutored context),
**ParentTrackManagement** (20). All green, analyze clean.

### FIXED (production)

- **[HIGH] ProfileEditFormDialog crashed on open** — the avatar picker was a lazy horizontal `ListView`
  inside `AlertDialog`, which measures its content's intrinsic dimensions; a lazy `RenderViewport` throws
  *"RenderViewport does not support returning intrinsic dimensions"*. The edit/rename-profile dialog
  crashed whenever opened. Fix (`profile_edit_delete_actions.dart`): replaced the `ListView.builder` with
  a `Row` inside a horizontal `SingleChildScrollView` (intrinsic-friendly; only 10 avatars). Un-skipped
  the 3 edit-dialog tests → green.
- **[medium] AddProfileCard RTL/grid overflow** — fixed icon (96) + spacing + text with no flex
  overflowed (~43px) at constrained grid-cell heights. Fix (`add_profile_card.dart`): wrapped the column
  in `FittedBox(scaleDown)`.

### OPEN — i18n + RTL (Phase 8)

- `manage_learners_screen.dart`: AppBar title `'Manage Learners'` hardcoded (not l10n).
- `parent_track_management_screen.dart`: `'Active Tracks'` header + `'$activeCount RUNNING'` badge hardcoded.
- Residual small RTL overflows in the profile-grid cards (ProfileCard) at 360×780-logical Hebrew
  (~12px horizontal, ~3.6px vertical) — for the Phase 8 RTL/overflow sweep.

### UX note (low)

- `ManageLearnersScreen` FAB is always enabled; the 10-profile cap is enforced only by the repository
  (`MaxProfilesExceededException`). Consider a proactive cap indicator / disabled FAB at 10.

### Skipped-suite repair — epic_15 multi-profile

Un-skipped the library-level `@Skip` on `epic_15_multi_profile_test.dart` (was fully dark) → **119 tests
now passing**, 12 intentionally skipped (file-existence/git/architecture/compile-time-API checks that
can't be unit-asserted), analyze clean. **No production bugs** — all 11 exposed failures were test-fixture
issues (7 repairs): missing `seedProfile`/`seedProfileZero` before FK-constrained inserts, the 10-profile
cap test colliding with the pre-seeded "Test User", `getGlobalTotal()`→`getDerivedTotal()` (raw events
don't touch points_balance), per-curriculum distinct `trackId`s, and FK-valid trackId/profileId in ledger
tests.

---

## Phase 3 — Tracks & track-setup wizard (wave 1)

+87 L1 tests: **AddTrackFlow** (23 — the LIVE screen + real controller, 6-step machine, exit-confirm +
replace-existing dialogs, TutorWriteException snackbar, generic error + retry), **EditTrack +
ChazaraInlineSetup** (25), **TrackManagementHub** (19 — empty/populated, delete archive vs wipe),
**StudyDayConfig** (20). All green. **No production bugs.**

- Test-harness notes (not prod bugs): EditTrack's ListView lazily culls offstage sections → tall test
  viewport needed; `FutureProvider.autoDispose.family` `overrideWith((ref) async …)` needs a pump to
  settle (use `overrideWithValue(AsyncData(x))` for synchronous resolution). study_day_config sizes the
  viewport via the deprecated `binding.window.*TestValue` (file-level `deprecated_member_use` ignore —
  no non-deprecated binding-level setter exists for `setUp`; test-only, functional).
- **Strengthening backlog** (verify flagged render-heavy + partial product-rule coverage): chazara
  conditional checked only at step-count level, not which chazara widget renders per track type; scope
  auto-skip positive case (single child → auto-drill) untested; back-date→overdue exercised at the
  service layer, not through the widget's StartingPositionStep; no-track-type-label asserted only at
  step 0. → revisit in a strengthening wave.
</content>
</invoke>

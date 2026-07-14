# Delivery kill-log addendum

Per doctrine §3.9: findings a builder/reviewer discovers are wrong or already-fixed during
delivery are marked `skipped-refuted` in the ledger, never forced into a manufactured change.
This file is the evidence trail for every such disposition, across all waves. One entry per
finding, appended as it happens.

---

## AUD-learning-05 — Mirror the daily-task-card chevron icon for RTL

- **Wave:** 0
- **Severity:** P2
- **Register evidence:** `learning_tracker/lib/features/learning/presentation/screens/learning_screen.dart:509,615` — two `const Icon(Icons.chevron_right_rounded, ...)` call sites, no `matchTextDirection`.
- **Register verify status (audit time):** CONFIRMED, UPHELD 1/1, no refutations (`_work/verify-chunks/grp-060.json`).
- **Delivery disposition:** `skipped-refuted` (wave-0 engine run, 2026-07-03). No commit exists for this id anywhere in the run's branch/worktree history — unlike every other wave-0 id that reached a build, none was attempted for this one.
- **Evidence gap — read before trusting this disposition:** this reconciliation pass (ledger reconciliation, 2026-07-03, run after the wave-0 engine already terminated) was handed only the engine's summary verdict (`refuted`) for this id, with no accompanying rationale, review transcript, or write-up. None was found anywhere on disk (searched `_work/`, `delivery/`, all dangling/worktree branches). Independently re-checking the current tree: **both call sites still lack `matchTextDirection` today** — so this was *not* refuted on an "already fixed in code" basis (the one refutation basis that would be trivially self-evidencing). The actual basis (wrong rule application? design-intent override? something else?) is not recoverable from any persisted artifact.
- **Action required before wave-0 is certified:** the wave-0 closing-gate reviewer (opus, §4) must independently confirm this refutation with real evidence (or reopen the finding as `todo`/`blocked` for a real fix). Do not treat this entry as sufficient evidence on its own — it records that the disposition happened and that its rationale is currently unverified, nothing more.
- **Logged by:** wave-0 ledger reconciliation agent (sonnet), 2026-07-03.
- **Resolution (2026-07-03, wave-0 gate-repair pass):** per the action-required note above, independently re-checked the current tree — both call sites still lacked RTL awareness, with no recoverable refutation basis (not already-fixed-in-code, and no other rationale survives anywhere on disk). **Reopened and fixed for real** rather than certifying wave-0 with an unverifiable `skipped-refuted` disposition standing: `matchTextDirection` is not a valid `Icon` constructor parameter (it lives on `IconData`, not settable per call site for a fixed `Icons.*` constant), so the finding's second recommendation branch was used instead — direction-aware icon swap (`chevron_right_rounded` LTR / `chevron_left_rounded` RTL), matching the established `breadcrumb_navigation.dart` precedent (the IL-7 defect class this finding cites). Red-first regression tests added and verified against the pre-fix source via `git stash`. See `learning_tracker/lib/features/learning/presentation/screens/learning_screen.dart` and `learning_tracker/test/features/learning/presentation/screens/learning_screen_l1_test.dart`. Ledger row updated to `status: merged`.

---

## AUD-tutoring-14 — Add ref.mounted guards after awaits in manage_tutors_providers.dart's incomingTutorGrantsProvider

- **Wave:** 1
- **Severity:** P3 (confidence: SUSPECTED at register time)
- **Register evidence:** `learning_tracker/lib/features/tutoring/presentation/providers/manage_tutors_providers.dart:106,118` (rule SM-4, ref.mounted after await) — post-await `ref.read` sites with no `ref.mounted` guard, in the `incomingTutorGrantsProvider` build.
- **Register verify status (audit time):** UPHELD 1/1, no refutations (one correction recorded: the second post-await ref-touch is actually line 121, not 118/124, as originally cited).
- **Delivery disposition:** `refuted`. Investigated by reproducing the exact scenario the finding describes — `authState`'s uid changing mid-flight while `incomingTutorGrantsProvider`'s future is still pending — against the real production provider. It completes cleanly with no thrown/unhandled error. Root cause: `incomingTutorGrantsProvider` is a plain (non-`.autoDispose`) `FutureProvider`; a `ref.watch`-ed dependency change rebuilds it but Riverpod's build-supersession machinery silently discards a stale/superseded build's outcome (even one that internally would hit `UnmountedRefException`) rather than propagating it to any listener or crashing. SM-4's hazard is real for `.autoDispose` providers and `Notifier` methods (per the rule's own rationale) but does not apply to this provider as written.
- **Evidence:** worktree tip `bbb0f3196b484dbb2994a82377f8160a6551d7c9` (`wf_911a9826-c9a-15`), commit `251d6978031450fc0ade4881293bc06096b84bab` — "test(tutoring): add regression guard refuting AUD-tutoring-14 (ref.mounted race)". No production code changed (`manage_tutors_providers.dart` is unmodified by this commit); a permanent regression guard was added to `incoming_tutor_grants_reconcile_test.dart` — if the provider is ever converted to `.autoDispose`, the guard starts failing and re-surfaces the risk. Reviewed and accepted by opus (`relaunch-wave1-args.json` `preApproved`, tipSha `bbb0f3196b`): "AUD-14 refutation sound (non-autoDispose provider, deps resolved pre-await; guard reproduces uid-swap race, passes)".
- **Merge status:** this commit is **not yet merged** into `audit-fix/2026-07-03` — it exists only on the worktree branch/history. The wave-1 engine run's no-progress cap / loop end halted before the merge lane processed this finding (and 31 sibling already-`fixed` findings from the same run — see their ledger `notes` for the matching disposition). Ledger row set to `status: refuted`, `commits: []`, reflecting the branch's actual current state; the commit above is the evidence trail, pending a future merge pass.
- **Logged by:** wave-1 ledger reconciliation agent (sonnet), 2026-07-10.

---

## AUD-account-12 — Handle account-exists-with-different-credential and credential-already-in-use for the Google sign-in / link-provider paths

- **Wave:** 1
- **Severity:** P2 (confidence: SUSPECTED at register time; `originalSeverity` P1)
- **Register evidence:** `learning_tracker/lib/features/account/data/repositories/auth_repository_impl.dart:47`, `sign_in_controller.dart:114,940`, `signup_screen.dart:118,488` — no `_mapAuthError` case for `account-exists-with-different-credential` or `credential-already-in-use`; both Firebase codes fall through to the generic default branch.
- **Register verify status (audit time):** UPHELD 2/3, with corrections narrowing scope: `credential-already-in-use` is only reachable via `linkGoogleProvider()`/`linkWithGoogleIdToken`, which the corrections say has **zero UI callers** anywhere under `lib/features/settings/presentation` or `lib/features/account/presentation` — dead code, unreachable in the shipped app. `account-exists-with-different-credential` is reachable (via `signInWithGoogle`/`_signUpWithGoogle`).
- **Prior history:** originally merged with AC1 only (`account-exists-with-different-credential` → `authErrExistingPasswordAccount`, commit `70cc86f504362a7230cf032d6be0380b7e5af127`, wave-1 batch w1r0c1). Reopened 2026-07-10 (`d4ae3efc`) under the "every AC mandatory, no deferring" doctrine because AC2 (`credential-already-in-use`) had never been implemented and was merged as a deferred follow-up — a fake-done disposition under the new doctrine. Re-fed to the wave-1 engine with `commits: []`, `reviewRounds: 0`.
- **Delivery disposition (this run):** `refuted`. The wave-1 engine run terminated at no-progress cap / loop end (`merged=[] refuted=[AUD-account-12] blocked=[AUD-account-11, AUD-tutoring-08, AUD-account-10, AUD-account-14] unprocessed=[]`).
- **Evidence gap — read before trusting this disposition:** this reconciliation pass (ledger reconciliation, 2026-07-10, run after the wave-1 engine already terminated) was handed only the engine's summary verdict (`refuted`) for this id, with no accompanying rationale, review transcript, or write-up. None was found anywhere on disk (searched `_work/`, `delivery/`, `relaunch-wave1-args.json` — `preApproved: []` for this run — and all worktree branches created for this run, `worktree-wf_0fa16715-47a-*`: none of the 10 reference `AUD-account-12`, unlike its 4 sibling ids from the same manifest, each of which has a worktree branch with real commits). Independently re-checking the current tree: **AC1's fix is still present and tested** — `sign_in_controller.dart:131-132` and `signup_screen.dart:493-494` both map `account-exists-with-different-credential` to `authErrExistingPasswordAccount`; regression tests exist at `sign_in_controller_test.dart:595` and `signup_screen_l1_test.dart:919` — but this is residue from the original pre-reopen merge (`70cc86f5`, still an ancestor of this branch), not new work produced by this run. **AC2 remains unimplemented** — no `credential-already-in-use` case exists in either `_mapAuthError`, and no test references it. This is consistent with the basis the finding's own verify corrections already flagged (AC2's only call site, `linkGoogleProvider()`, is confirmed dead code — zero UI callers) but that basis was not confirmed to be what the engine actually decided; it is only the most plausible reading available from evidence already on record.
- **Action required before wave-1 is certified:** the wave-1 closing-gate reviewer (opus, §4) must independently confirm this refutation with real evidence (or reopen AC2 as `todo`/`blocked` for a real fix — e.g. removing the unreachable `linkGoogleProvider()` entry point instead, per dead-code doctrine, rather than instrumenting an error path nothing can trigger). Do not treat this entry as sufficient evidence on its own — it records that the disposition happened and that its rationale is currently unverified beyond independent circumstantial confirmation, nothing more.
- **Logged by:** wave-1 ledger reconciliation agent (sonnet), 2026-07-10.

---

## AUD-core-sync-29 — Add a ref.mounted check after the await in resolveOwnerAccountIdForWipe (tutored_pull_providers.dart)

- **Wave:** 2
- **Severity:** P3
- **Register evidence:** `learning_tracker/lib/core/sync/providers/tutored_pull_providers.dart` — `resolveOwnerAccountIdForWipe` reads `ref` after an `await` with no `ref.mounted` guard.
- **Delivery disposition:** `skipped-refuted` (merge-lane w2r1c10, 2026-07-10). Moot: the target function, `resolveOwnerAccountIdForWipe`, was deleted outright by the sibling finding `AUD-core-sync-28`'s fix (dead-code removal — zero prod callers; `currentAccountIdProvider` derives only from `authStateProvider`, not tutored-session providers, so the D18 hazard this finding's parent describes was unreachable). Commit `fe1bc6b8` on the pre-rebase tip (rebased onto `audit-fix/2026-07-03` as `5f59ba4d5bf4e303eb9f96dbc807ab40d5778fb4`, merged in `e39faa03618288d9caeb2074cd3aa88d00446ead`) removes the function and its docstring entirely. With the guarded post-await `ref` access itself gone, there is nothing left for a `ref.mounted` guard to protect — matches this finding's own register note that it resolves alongside the AUD-core-sync-28/AUD-core-sync-4 deletion. Confirmed by grep: no `resolveOwnerAccountIdForWipe` symbol remains anywhere under `lib/` post-merge.
- **Logged by:** merge-lane w2r1c10 agent (sonnet), 2026-07-10.
- **Reopen-and-reconfirm (2026-07-11):** this row, along with 12 sibling wave-2 ids, was bulk-reopened to `todo` under the note "wave-2 gate fail (undelivered or regression: CF-import/stale-codegen)" — a batch-level gate finding not specific to this id's own evidence. A fresh wave-2 engine pass re-ran against the reopened set and its outcome (`refuted=[AUD-core-sync-29]`) re-affirms `skipped-refuted` for this id specifically. Independently re-checked ahead of recommitting the disposition: `grep -rn resolveOwnerAccountIdForWipe learning_tracker/lib/` is still empty, and commit `5f59ba4d5bf4e303eb9f96dbc807ab40d5778fb4` remains an ancestor of the branch's current HEAD — the deletion this disposition rests on is intact regardless of the sibling `AUD-core-sync-28` ledger row being separately reclassified to `blocked` in this same reconciliation pass (that reclassification reflects the batch-level gate finding on `AUD-core-sync-28`'s own row, not a revert of the source deletion this id's mootness depends on). Disposition stands: `skipped-refuted`.
- **Logged by:** wave-2 ledger reconciliation agent (sonnet), 2026-07-11.

---

## AUD-core-sync-30 — Add an AnalyticsEvent.outboxDeadLettered constant instead of reusing LogEvents.sync.outboxDeadLettered for analytics

- **Wave:** 2
- **Severity:** P3 (confidence: CONFIRMED at register time)
- **Register evidence:** `learning_tracker/lib/core/sync/outbox/outbox_processor.dart:264,369` — both analytics `logEvent()` call sites passed `LogEvents.sync.outboxDeadLettered` (the `AppLogger`/structured-log catalog constant) instead of an `AnalyticsEvent` catalog constant, making this analytics event invisible to anyone auditing "every analytics event we send" via `AnalyticsEvent`.
- **Register verify status (audit time):** UPHELD 1/1, no refutations (one line-number correction on the first citation; underlying claim held).
- **Delivery disposition:** `skipped-refuted` (wave-2 engine outcome, ledger reconciliation, 2026-07-11).
- **Basis — already fixed in code, independently confirmed:** commit `1d131567` (`fix(core/analytics): constrain logEvent to the AnalyticsEvent catalog (AUD-core-analytics-01)`) added `AnalyticsEvent.syncOutboxDeadLettered = 'sync_outbox_dead_lettered'` (`learning_tracker/lib/core/analytics/analytics_service.dart:45`) and converted both `outbox_processor.dart` analytics call sites (now `learning_tracker/lib/core/sync/outbox/outbox_processor.dart:285,431`) from `LogEvents.sync.outboxDeadLettered` to `AnalyticsEvent.syncOutboxDeadLettered` — exactly this finding's recommendation, delivered as a side effect of `AUD-core-analytics-01`'s wave-1 catalog-constraint sweep ("Converted ~21 call sites" per that finding's own ledger note). `grep -rn "syncOutboxDeadLettered" learning_tracker/lib/` confirms the constant exists and is referenced at both former-defect sites; `grep -n "outboxDeadLettered" learning_tracker/lib/core/sync/outbox/outbox_processor.dart` returns no `LogEvents.sync.outboxDeadLettered` hits (only unrelated `LogEvents.sync.outboxPushFailed` at lines 381, 457). This is a self-evidencing already-fixed-in-code refutation, not an evidence-gap one — unlike the entry immediately below (`AUD-core-sync-32`).
- **Logged by:** wave-2 ledger reconciliation agent (sonnet), 2026-07-11.

---

## AUD-core-sync-32 — Deduplicate the copy-pasted cause-suffix toString() snippet across 3 sync exception classes

- **Wave:** 2
- **Severity:** P3 (confidence: CONFIRMED at register time)
- **Register evidence:** identical `'${cause != null ? ' caused by: $cause' : ''}'` ternary snippet hand-copied into `learning_tracker/lib/core/sync/exceptions/firestore_permission_denied_exception.dart:37`, `merge_exception.dart:25`, and `outbox_dead_letter_exception.dart:27`.
- **Register verify status (audit time):** UPHELD 1/1, no refutations (one correction: `OutboxDeadLetterException` inherits its `cause` field from `NetworkException` rather than hand-declaring it, unlike the other two sites; the duplicated `toString()` snippet claim itself was unaffected).
- **Delivery disposition:** `skipped-refuted` (wave-2 engine outcome, ledger reconciliation, 2026-07-11).
- **Evidence gap — read before trusting this disposition:** this reconciliation pass was handed only the engine's summary verdict (`refuted`) for this id, with no accompanying rationale, review transcript, or write-up. None was found anywhere on disk: `git log --all --oneline | grep AUD-core-sync-32` returns zero commits across every branch and worktree in the repo (including the 30+ `worktree-wf_12646bf5-ddc-*` branches left over from this wave), and the ledger row's own `commits` array was `[]` before this reconciliation. Independently re-checked the current tree: **the duplicated ternary is still present verbatim in all 3 cited files** (`firestore_permission_denied_exception.dart:37`, `merge_exception.dart:25`, `outbox_dead_letter_exception.dart:27`) — so this was **not** refuted on an "already fixed in code" basis, the one refutation basis that would be self-evidencing (contrast `AUD-core-sync-30` immediately above, which does have that evidence). The actual basis (wrong rule application, effort/priority triage, something else) is not recoverable from any persisted artifact.
- **Action required before wave-2 is certified:** the wave-2 closing-gate reviewer (opus) must independently confirm this refutation with real evidence, or reopen the finding as `todo`/`blocked` for a real fix (extract a shared `causeSuffix` getter/mixin per the finding's recommendation). Do not treat this entry as sufficient evidence on its own — it records that the disposition happened and that its rationale is currently unverified, nothing more.
- **Logged by:** wave-2 ledger reconciliation agent (sonnet), 2026-07-11.
- **Reopened (2026-07-11):** per the action-required note above, this row was reopened to `todo` (bulk note: "wave-2 gate fail (undelivered or regression: CF-import/stale-codegen)", alongside 12 sibling wave-2 ids) rather than the `skipped-refuted` disposition standing uncertified. A fresh wave-2 engine pass against the reopened set did not refute or merge this id — its outcome places it in `blocked`. Ledger row updated to `status: blocked`; `skipped-refuted` no longer applies. The duplicated ternary is still present verbatim in all 3 cited files as of this update. Left for a future harvest/relaunch pass to actually extract the shared `causeSuffix` helper.
- **Logged by:** wave-2 ledger reconciliation agent (sonnet), 2026-07-11.

---

## AUD-dashboard-13 — Rename one of the two top-level CurriculumSummary classes (AG-4 duplicate)

- **Wave:** 3
- **Severity:** P3
- **Register evidence:** two top-level `CurriculumSummary` classes existed under `lib/` — dashboard's `parent_dashboard_aggregator.dart` and scheduler's `cross_curriculum_aggregator.dart` — an AG-4 duplicate-public-top-level-name violation.
- **Delivery disposition:** `skipped-refuted` (merge-lane w3r1c7, 2026-07-12).
- **Basis — already fixed in code, independently confirmed:** commit `a3619891` ("fix(AUD-repo-01): de-dupe 7 duplicate public type names, land AG-4 audit gate", an ancestor of this branch's current HEAD, landed after this finding's register checkpoint `4018a91c`) renamed dashboard's `parent_dashboard_aggregator.dart` `CurriculumSummary` → `ParentCurriculumSummary` as part of a 7-name de-dupe sweep, resolving the collision with scheduler's `cross_curriculum_aggregator.dart` `CurriculumSummary` (the definition `CurriculumSummaryCard` and `dashboard_providers.dart` actually consume) — exactly this finding's recommendation. That same commit also landed the AG-4 Rule-0 grep checker itself (`learning_tracker/Makefile`, "24/25 — No duplicate public top-level type names across lib/ (AG-4)"). Independently re-verified against the current tree: `grep -rn "class CurriculumSummary" learning_tracker/lib/` returns exactly one hit (`cross_curriculum_aggregator.dart:5`); `grep -rl ParentCurriculumSummary learning_tracker/lib/` confirms the rename landed in `parent_dashboard_aggregator.dart` (+`.freezed.dart`); re-ran the AG-4 checker's own grep/awk pipeline against the current tree and it reports no duplicates (AG-4 clean). Self-evidencing already-fixed-in-code basis, matching the `AUD-core-sync-30` disposition pattern above (not an evidence-gap one).
- **Logged by:** merge-lane w3r1c7 agent (sonnet), 2026-07-12.

---

## AUD-gamification-17 — Delete or wire up the unreachable form.error branch in reward_configuration_screen.dart

- **Wave:** 3
- **Severity:** P3
- **Delivery disposition:** `skipped-refuted` (merge-lane w3r2c1, 2026-07-13).
- **Basis — already fixed in code, independently confirmed:** the prior `AUD-gamification-10` fix (an ancestor of this finding's start `HEAD`) made `_handleMutationError` set `state.error` on generic failures, making the error `Scaffold` branch reachable — proven by the existing passing test `reward_configuration_screen_l1_test.dart:735-760`. `AUD-gamification-10`'s own ledger notes name `AUD-gamification-17` as a duplicate of the defect it fixed. No code change required for this id.
- **Logged by:** merge-lane w3r2c1 agent (sonnet), 2026-07-13.

---

## AUD-t-account-06 — Remove the stale skip and stale RTL-overflow comment from email_verification_confirm_panel_test.dart's H1 test

- **Wave:** 4
- **Severity:** P3
- **Delivery disposition:** `skipped-refuted` (merge-lane w4r1c19, 2026-07-13).
- **Basis — already fixed in code, independently confirmed:** commit `f7428230` (`fix(account): AUD-account-05 - localize EmailVerificationConfirmPanel title/action labels`, an ancestor of this branch's current `HEAD`) removed the H1 test's `skip:true` and its stale RTL-overflow `BUG` comment as part of that finding's localization fix. Independently re-verified against the current tree: `grep -n "skip:\|BUG:" learning_tracker/test/features/account/presentation/widgets/email_verification_confirm_panel_test.dart` returns 0 hits (the file's only "skip" match is an unrelated launchUrl-skip prose comment at line 855, not a test skip); `flutter test --plain-name H1 test/features/account/presentation/widgets/email_verification_confirm_panel_test.dart` → `00:01 +1: All tests passed!`. AC already satisfied; no code change made.
- **Logged by:** merge-lane w4r1c19 agent (sonnet), 2026-07-13.

---

## AUD-t-cross-04 — Rewire or retarget tutored_wipe_wrong_id_test.dart — its D18 fix symbols (resolveOwnerAccountIdForWipe, wipeRevokedMirrors) have zero production callers

- **Wave:** 4
- **Severity:** P1
- **Delivery disposition:** `skipped-refuted` (merge-lane w4r2c2, 2026-07-14).
- **Basis — already fixed in code, independently confirmed:** this finding is a duplicate of `AUD-core-sync-28` (already merged). Ancestor commit `5f59ba4d5bf4e303eb9f96dbc807ab40d5778fb4` (`fix(audit): AUD-core-sync-28 - remove dead D18 wipe-id-resolution helper`) deleted the target `resolveOwnerAccountIdForWipe`/`wipeRevokedMirrors` symbols outright and remains an ancestor of this branch's current `HEAD`. Independently re-verified against the current tree: `grep -rn resolveOwnerAccountIdForWipe learning_tracker/lib/` returns 0 matches. This finding's AC2 (exercise the real revoke-reconcile mechanics rather than the dead helper pair) is satisfied by the rewritten `tutored_wipe_wrong_id_test.dart` — which now proves `currentAccountIdProvider` cannot resolve to the talmid's `learner_profiles.id` and exercises the real `getTutoredMirrorsForAccount` + `TutoredMirrorWipeService.wipeMirrorForGrant` loop that `incomingTutorGrantsProvider` runs inline — plus the pre-existing `incoming_tutor_grants_reconcile_test.dart`. No code change made.
- **Logged by:** merge-lane w4r2c2 agent (sonnet), 2026-07-14.

---

## AUD-t-cross-38 — Replace vacuous isNotNull/isNotEmpty assertions in user_database_managers_refs_test.dart with relationship-verifying checks

- **Wave:** 4
- **Severity:** P2
- **Delivery disposition:** `skipped-refuted` (merge-lane w4r1c11, 2026-07-14).
- **Basis — target file deleted whole, independently confirmed:** sibling commit `49cc7d73` (`test(database): AUD-t-cross-16 - delete tautological db.managers.* suite, exclude generated code from coverage`) removed the entire 676-line `learning_tracker/test/core/database/user_database_managers_refs_test.dart` outright, along with the rest of the 7-file `db.managers.*` suite, on the grounds that `db.managers.*` (the Drift-generated TableManager API under test) has no production caller (`grep -rl '\.managers\.' lib/` returns 0 files) — the app queries exclusively through the hand-written DAOs, which already carry real relationship-verifying assertion coverage. Independently re-verified: the cited vacuous assertions at lines 211 and 253 of the pre-delete blob (`git show 49cc7d73~1:learning_tracker/test/core/database/user_database_managers_refs_test.dart`) match the finding's evidence verbatim — `expect(manager, isNotNull);` inside `curriculumScopesRefs getter returns manager` (line ~211) and `pointConfigsRefs getter returns manager` (line ~253); the file is absent at current `HEAD` (`find learning_tracker/test -iname user_database_managers_refs_test.dart` returns nothing); commit `49cc7d73` remains an ancestor of this branch's current `HEAD`. This finding's target no longer exists to fix — moot, not a rewrite candidate. No code change made.
- **Logged by:** merge-lane w4r1c11 agent (sonnet), 2026-07-14.

---

## AUD-t-cross-28 — Flip scheduler_p1_test.dart's R-SC1/R-SC2 assertions to match the project's own confirm-bug-to-skip contract

- **Wave:** 4
- **Severity:** P2
- **Delivery disposition:** `refuted` (wave-4-chunk04 engine run, 2026-07-14, terminated at no-progress cap / loop end).
- **Evidence gap — read before trusting this disposition:** this reconciliation pass (ledger reconciliation, wave4-chunk04, 2026-07-14) was handed only the engine's summary verdict (`refuted`) for this id, with no accompanying rationale, review transcript, or write-up. None was found anywhere on disk (searched `_work/`, `delivery/`, this addendum file, and `git log --all` across every branch/worktree — zero commits reference `AUD-t-cross-28`, unlike sibling chunk ids `AUD-t-cross-31`/`46`/`50` below, each of which has worktree commits). Independently re-checking the current tree: the disposition is only half self-evidencing. **R-SC2 is moot** — `scheduler_p1_test.dart:912` now carries the comment `R-SC2 (resolved by AUD-scheduler-07): the never-rendered ComposedDailySchedule.summary field and its unlocalized _summaryForSection() builder were dead code and have been deleted`, confirmed by `git log --all --oneline | grep AUD-scheduler-07` (commit `ca9bc667`, an ancestor of this branch's current `HEAD`) — there is no assertion left to flip for that half. **R-SC1 remains open** — `scheduler_p1_test.dart:316-393` still asserts the hardcoded-English `'Select Hebrew date'` string as the expected, passing value with a plain `// confirmed bug` comment, not the skip-marked red-first pattern this finding's recommendation (and the `hebrew_rtl_p1_test.dart` R-OB7 precedent) calls for.
- **Action required before wave-4 is certified:** the wave-4 closing-gate reviewer (opus, §4) must independently confirm this refutation with real evidence, or reopen R-SC1's half as `todo`/`blocked` for a real fix (flip the assertion + add `skip: 'BUG R-SC1: ...'`, per the finding's own acceptance criteria). Do not treat this entry as sufficient evidence on its own — it records that the disposition happened and that its rationale is only partially verified, nothing more.
- **Logged by:** wave-4-chunk04 ledger reconciliation agent (sonnet), 2026-07-14.
- **Resolution (2026-07-14, wave-4 gate-repair pass):** per the action-required note above, independently investigated R-SC1's open half. Confirmed R-SC1's underlying bug is genuinely fixed in production — `AUD-scheduler-02` (commit `5f4465c9`, already an ancestor of dev HEAD) routed all 5 of `HebrewDatePicker`'s strings through `AppLocalizations`, with real Hebrew translations in `app_he.arb`. The `flip-to-skip` recommendation this finding calls for does not apply (that pattern is for a bug that is *not yet* fixed, so the red assertion self-activates once it lands); since the bug was already fixed, the correct move — mirroring the `R-IC3` `(FIXED)` precedent in `hebrew_rtl_p1_test.dart` — is to *prove* the fix with a live assertion. `scheduler_p1_test.dart` E2E-508 was rewritten to pump `locale: const Locale('he')` (previously ran under the default `en` locale, so it was never actually exercising the Hebrew-string path at all) and assert the real Hebrew l10n strings render (`בחר תאריך עברי`, `שנה עברית`, `אנגלי:`), replacing the stale `// confirmed bug` comments. R-SC2's half needed no further action (confirmed moot, unchanged from the original disposition). Also updated R-SC1/R-SC2 in `docs/planning/e2e-test-suite-plan.md`'s risk register to `(FIXED)`/`(RESOLVED)`. `flutter test test/e2e/journeys/scheduler_p1_test.dart` → all 11 tests passed; `flutter analyze` clean; `dart format --set-exit-if-changed` clean. Commit `d679037c`. Ledger row reclassified `refuted` → `merged`.
- **Logged by:** wave-4 gate-repair agent (sonnet), 2026-07-14.

---

## AUD-t-cross-31 — Make E2E-516/E2E-922/E2E-416 actually pump Locale('he') instead of asserting a false harness limitation

- **Wave:** 4
- **Severity:** P2
- **Delivery disposition:** `blocked` (wave-4-chunk04 engine run, 2026-07-14, terminated at no-progress cap / loop end).
- **Basis — verified-looking fix commit found, never merged:** two worktree branches each carry an identical commit — `ab81cd4f` on `worktree-wf_cfdc1964-538-1` and `875da8b4` on `worktree-wf_cfdc1964-538-53` (same message, same diff shape) — titled `fix(tests): AUD-t-cross-31 - make E2E-516/E2E-922/E2E-416/E2E-812 actually pump Locale('he')`. It touches `scheduler_p1_test.dart`, `settings_p1_test.dart`, `tracks_p1_test.dart`, `progress_p1_test.dart`, and adds a new `tool/check_e2e_he_locale_coverage.dart` Rule-0 checker wired into `make audit` (57/57); the commit message claims `dart run tool/check_e2e_he_locale_coverage.dart` passes all 18 catalog rows, the four affected test files pass (`+46 ~4`), `make audit` is clean, and `flutter analyze` reports no issues. **Neither commit is an ancestor of this branch's current `HEAD`** (`git merge-base --is-ancestor <sha> HEAD` fails for both) — the merge lane never landed either copy before the wave-4-chunk04 engine run terminated at no-progress cap / loop end. Per the engine outcome this id is `blocked`, not `merged`; the ledger row was updated to reflect the branch's actual current state (`commits: []`, since nothing is merged), with this entry as the evidence trail for a future merge/harvest pass. Left uninvestigated: why the merge lane didn't land either copy (conflict, review rejection, or simply ran out of budget) — not recoverable from any persisted artifact found.
- **Logged by:** wave-4-chunk04 ledger reconciliation agent (sonnet), 2026-07-14.
- **Resolution (2026-07-14, wave-4 gate-repair pass):** cherry-picked `ab81cd4f` (from `worktree-wf_cfdc1964-538-1`) onto dev via `git cherry-pick -x`. Three files conflicted against dev's since-diverged history: `Makefile` (both sides had appended a new numbered `make audit` grep at the same position — resolved by keeping dev's existing checks 56–58 at their historical `/58` denominator per the file's established non-retroactive-renumbering convention, and appending this commit's new he-locale-coverage check as `59/59`, bumping the total to 59), and two import-line conflicts in `scheduler_p1_test.dart` / `settings_p1_test.dart` (both sides added different symbols to the same `show` clause — resolved by taking the union). No conflicts in `progress_p1_test.dart` or `tracks_p1_test.dart`. Verified post-merge: `dart run tool/check_e2e_he_locale_coverage.dart` → all 18 catalog rows clean; `flutter test test/e2e/journeys/{scheduler,settings,progress,tracks,hebrew_rtl}_p1_test.dart --concurrency=2` → all passed; `make audit` → 59/59 clean; `flutter analyze` clean. Commit `5228fdd3` on dev. Ledger row reclassified `blocked` → `merged`. The sibling worktree branches/copies (`worktree-wf_cfdc1964-538-{1,53}` and their 25 stray sibling worktrees, none of which carried any further unmerged work — every other finding referenced across all 27 stray worktrees was independently already merged into dev under a different commit) were deleted as part of this same pass; see the wave-4 gate-repair commit for the residue-cleanup evidence.
- **Logged by:** wave-4 gate-repair agent (sonnet), 2026-07-14.

---

## AUD-t-cross-46 — Un-skip hebrew_rtl_p1_test.dart E2E-1510 — R-OB7 onboarding hardcoded-English bug is already fixed

- **Wave:** 4
- **Severity:** P2
- **Delivery disposition:** `blocked` (wave-4-chunk04 engine run, 2026-07-14, terminated at no-progress cap / loop end).
- **Basis — verified-looking fix commit found, never merged:** two worktree branches each carry an identical commit — `c9c76868` on `worktree-wf_cfdc1964-538-1` and `cca963c5` on `worktree-wf_cfdc1964-538-53` — titled `fix(tests): AUD-t-cross-46 - un-skip hebrew_rtl_p1_test.dart E2E-1510 (R-OB7 fixed)`. It removes the stale `skip: true` and its confirmed-bug docstring from the E2E-1510 group, updates the docstring to `(FIXED)` per the file's own R-IC3 precedent, and strengthens the assertions to check that real Hebrew translations render; the commit message claims `flutter test ... --plain-name "E2E-1510"` passes. **Neither commit is an ancestor of this branch's current `HEAD`** (`git merge-base --is-ancestor <sha> HEAD` fails for both) — the merge lane never landed either copy before the wave-4-chunk04 engine run terminated at no-progress cap / loop end. Per the engine outcome this id is `blocked`, not `merged`; the ledger row was updated to reflect the branch's actual current state (`commits: []`), with this entry as the evidence trail for a future merge/harvest pass.
- **Logged by:** wave-4-chunk04 ledger reconciliation agent (sonnet), 2026-07-14.
- **Resolution (2026-07-14, wave-4 gate-repair pass):** cherry-picked `c9c76868` (from `worktree-wf_cfdc1964-538-1`) onto dev via `git cherry-pick -x`. Clean, no conflicts. Verified post-merge: `flutter test test/e2e/journeys/hebrew_rtl_p1_test.dart` → all passed, E2E-1510 unskipped and green; `flutter analyze` clean. Commit `fe8e0dbf` on dev. Ledger row reclassified `blocked` → `merged`.
- **Logged by:** wave-4 gate-repair agent (sonnet), 2026-07-14.

---

## AUD-t-cross-50 — progress_p1_test.dart E2E-806 claims to verify the documented R-PG7 cross-profile access-control gap but never passes a differing profileId

- **Wave:** 4
- **Severity:** P2
- **Delivery disposition:** `blocked` (wave-4-chunk04 engine run, 2026-07-14, terminated at no-progress cap / loop end).
- **Basis — verified-looking fix commit found, never merged:** two worktree branches each carry an identical commit — `37de79f4` on `worktree-wf_cfdc1964-538-1` and `38b8c60c` on `worktree-wf_cfdc1964-538-53` — titled `fix(tests): AUD-t-cross-50 - progress_p1_test.dart E2E-806 add cross-profile R-PG7 sub-test`. It adds a second E2E-806 test that seeds a genuinely separate account + profile row into the harness's in-memory `UserDatabase`, then deep-links via `/journey?profileId=<other>` and asserts the other profile's real display name and a distinct milestone render — proving the cross-profile read actually happened; the commit message notes a red-first dead-end (`h.router.push(...)` hangs indefinitely) that was resolved by switching to a direct `pumpApp(path:)` deep link, and claims both the new sub-test and the full file pass. **Neither commit is an ancestor of this branch's current `HEAD`** (`git merge-base --is-ancestor <sha> HEAD` fails for both) — the merge lane never landed either copy before the wave-4-chunk04 engine run terminated at no-progress cap / loop end. Per the engine outcome this id is `blocked`, not `merged`; the ledger row was updated to reflect the branch's actual current state (`commits: []`), with this entry as the evidence trail for a future merge/harvest pass.
- **Logged by:** wave-4-chunk04 ledger reconciliation agent (sonnet), 2026-07-14.
- **Resolution (2026-07-14, wave-4 gate-repair pass):** cherry-picked `37de79f4` (from `worktree-wf_cfdc1964-538-1`) onto dev via `git cherry-pick -x`. Clean, no conflicts (co-existed with `AUD-t-cross-31`'s separate rewrite of the same file's E2E-812 group). Verified post-merge: `flutter test test/e2e/journeys/progress_p1_test.dart` → all passed, new cross-profile R-PG7 sub-test green; `flutter analyze` clean. Commit `5d2a5e6c` on dev. Ledger row reclassified `blocked` → `merged`.
- **Logged by:** wave-4 gate-repair agent (sonnet), 2026-07-14.

---

## AUD-t-cross-75 — Merge duplicate Completion/CompletionEvent DataClass groups in user_database_managers_test.dart

- **Wave:** 4
- **Severity:** P3
- **Delivery disposition:** `skipped-refuted` (merge-lane w4r1c3, 2026-07-14).
- **Basis — target file deleted whole, independently confirmed:** `user_database_managers_test.dart` was deleted wholesale by ancestor commit `49cc7d73` (`test(database): AUD-t-cross-16 - delete tautological db.managers.* suite, exclude generated code from coverage`), which predates this branch's register-verify checkpoint `4018a91c` and remains an ancestor of this branch's current `HEAD`. Pre-deletion content matched this finding's evidence exactly: `git show 49cc7d73^:learning_tracker/test/core/database/user_database_managers_test.dart` shows sibling groups `Completion DataClass + managers` (line 431) and `CompletionEvent DataClass + managers` (line 493) — the exact duplicate pair this finding names. Independently re-verified against the current tree: `grep -rn "group('Completion" learning_tracker/test/` returns 0 matches for either group name repo-wide (the surviving `Completion DataClass`/`CompletionEvent DataClass` groups in `user_database_dataclass_extended_test.dart` are a distinct, non-duplicate pair — one group per class, not two per class). This finding's target no longer exists to merge — moot. No code change needed.
- **Logged by:** merge-lane w4r1c3 agent (sonnet), 2026-07-14.

---

## AUD-t-cross-80 — Remove dead ProfileDao import in user_database_managers_test.dart:12

- **Wave:** 4
- **Severity:** P3
- **Delivery disposition:** `skipped-refuted` (merge-lane w4r1c3, 2026-07-14).
- **Basis — target file deleted whole, independently confirmed:** same deletion commit `49cc7d73` as `AUD-t-cross-75` above — the dead `import 'package:learning_tracker/core/database/daos/profile_dao.dart';` at `user_database_managers_test.dart:12` was removed together with the whole file it lived in. Independently re-verified: `find learning_tracker/test -iname user_database_managers_test.dart` returns no results; `grep -rn profile_dao.dart learning_tracker/test/` shows only legitimate DAO-under-test imports in files that actually exercise `ProfileDao`, no dangling reference to the deleted file. Commit `49cc7d73` remains an ancestor of this branch's current `HEAD`. No code change needed; the finding's optional AC (add an `analysis_options.yaml` unused-import lint) was skipped as scope creep on a refuted finding.
- **Logged by:** merge-lane w4r1c3 agent (sonnet), 2026-07-14.

---

## AUD-t-cross-65 — Delete the dead nullService ternary in sy2_device_restore_idle_blank_test.dart's _buildHarness

- **Wave:** 4
- **Severity:** P3
- **Delivery disposition:** `skipped-refuted` (merge-lane w4r1c12, 2026-07-14).
- **Basis — already fixed by sibling commit, independently confirmed:** commit `be105d82` (`test(restore): AUD-t-cross-23 - extract shared router/guard mock harness`), landed after this branch's register-verify checkpoint `4018a91c` and remains an ancestor of this branch's current `HEAD`, extracted the 4 copy-pasted `test/app/restore/*_test.dart` mock harnesses (including `sy2_device_restore_idle_blank_test.dart`'s `_buildHarness`) into a shared `test/app/restore/restore_test_harness.dart`, deleting the `nullService` ternary as part of that consolidation — the shared `buildRestoreHarness()` factory now passes the service straight through. Independently re-verified against the current tree: `grep -rn nullService learning_tracker/test/app/restore/` returns 0 matches. Finding's target no longer exists — moot. No code change needed.
- **Logged by:** merge-lane w4r1c12 agent (sonnet), 2026-07-14.

---

## AUD-t-cross-82 — Rename the 2 duplicate-named test pairs inside crossref_filter_test.dart's 'Companion.toColumns with id present' group

- **Wave:** 4
- **Severity:** P3
- **Delivery disposition:** `skipped-refuted` (merge-lane w4r1c24, 2026-07-14).
- **Basis — target file deleted whole, independently confirmed:** `learning_tracker/test/core/database/user_database_managers_crossref_filter_test.dart` was deleted wholesale by ancestor commit `49cc7d73` (`test(database): AUD-t-cross-16 - delete tautological db.managers.* suite, exclude generated code from coverage`), as one of the 7 files in the `db.managers.*` suite deletion; commit `49cc7d73` remains an ancestor of this branch's current `HEAD`. Independently re-verified: the pre-delete blob (`git show 49cc7d73^:learning_tracker/test/core/database/user_database_managers_crossref_filter_test.dart`) matches the finding's evidence exactly — duplicate `test('CompletionEventsCompanion id present in toColumns', ...)` names at lines 287 and 302, and duplicate `test('StreakEventsCompanion id present in toColumns', ...)` names at lines 365 and 371, both inside the `Companion.toColumns with id present` group. Repo-wide grep for either test name (`grep -rn "CompletionEventsCompanion id present in toColumns\|StreakEventsCompanion id present in toColumns" learning_tracker/`) returns 0 hits; `find learning_tracker/test -iname "*crossref_filter*"` returns nothing. Finding's target no longer exists to rename — moot. No code change made.
- **Note on repeat disposition:** the merge-lane payload for this pass flagged this as the 3rd refutation of this id (2 prior). No prior `AUD-t-cross-82` entry was found in this addendum or in `git log --all` for this checkout, so those prior passes aren't independently re-derivable here — recorded as received; this pass's own evidence (above) was independently re-verified and stands regardless.
- **Logged by:** merge-lane w4r1c24 agent (sonnet), 2026-07-14.

---

## AUD-t-notifications-06 — Replace Future.delayed wall-clock waits with deterministic signals in notification cold-start tests (TQ-6)

- **Wave:** 4
- **Severity:** P3
- **Delivery disposition:** `skipped-refuted` (merge-lane w4r1c3, 2026-07-14).
- **Basis — already fixed by prior commit, independently confirmed:** commit `81fa3635` (`fix(notifications): AUD-notifications-01, AUD-notifications-02, AUD-notifications-03 - AsyncNotifier preference providers, SM-4 guards, family StreakAlertService`), an ancestor of this branch's current `HEAD`, converted `ReminderEnabled`/`ReminderTime`/`StreakAlertEnabled`/`StreakAlertTime`/`RewardNotificationEnabled` from synchronous `Notifier<T>` to `AsyncNotifier<T>` and, as part of that rewrite, replaced every real-wall-clock `Future<void>.delayed(Duration(milliseconds: ...))` wait in this finding's 4 listed test files with a deterministic `await <provider>.future` signal (e.g. `await c1.read(reminderTimeProvider.future)`, `await c4.read(streakAlertEnabledProvider.future)`). Independently re-verified against the current tree: `grep -n "delayed\|Duration(milliseconds"` across all 4 files (`reminder_enabled_cold_start_test.dart`, `reminder_time_cold_start_test.dart`, `notification_providers_deep_test.dart`, `notification_providers_test.dart`) returns zero matches. This finding's single acceptance criterion (none of the 4 files contain `Future.delayed` combined with a millisecond `Duration` literal) is fully met. No code change made.
- **Logged by:** merge-lane w4r1c3 agent (sonnet), 2026-07-14.

---

## AUD-t-notifications-01 — Override reminderSyncEffectProvider/streakAlertSyncEffectProvider in notifications_screen_test.dart and ws5_two_layers_test.dart to stop opening a real Drift database

- **Wave:** 4
- **Severity:** P2
- **Delivery disposition:** `blocked` (wave4-chunk07 engine run, 2026-07-14, terminated at no-progress cap / loop end). Ledger row was found stuck at stale `todo` by this reconciliation pass and reclassified to match the engine outcome.
- **Basis — verified-looking fix commit found, never merged:** two worktree branches each carry an identical commit — `623798dc` on `worktree-wf_1a1fc4a3-128-41` and `7239ce09` on `worktree-wf_1a1fc4a3-128-2` (byte-identical diffs) — titled `fix(tests/notifications): AUD-t-notifications-01 - hermetic NotificationsScreen widget tests`. It adds no-op overrides for `reminderSyncEffectProvider`/`streakAlertSyncEffectProvider` to both files' `ProviderScope`, plus a new `tool/check_notifications_sync_effect_overrides.dart` Rule-0 checker wired into `make audit` (claimed check 62) and its unit test; the commit message claims the checker exits 0, `flutter test --concurrency=2 test/features/notifications/` is 182/182 passing with zero Drift "created ... multiple times" warnings, and `flutter analyze` is clean. **Neither commit is an ancestor of this branch's current `HEAD`** (`git merge-base --is-ancestor <sha> HEAD` fails for both). Independently re-verified against the current tree: `grep -n "reminderSyncEffectProvider\|streakAlertSyncEffectProvider" test/features/notifications/presentation/screens/notifications_screen_test.dart test/features/notifications/ws5_two_layers_test.dart` returns zero matches — the overrides are genuinely absent from `dev`. Per the engine outcome this id is `blocked`, not `merged`; the ledger row's `commits: []` already reflected that nothing is merged, and its `status`/`notes` were updated to match. Left uninvestigated: why the merge lane never landed either copy — not recoverable from any persisted artifact found.
- **Logged by:** wave4-chunk07 ledger reconciliation agent (sonnet), 2026-07-14.

---

## AUD-t-notifications-03 — Deduplicate the MockNotificationGateway class shared verbatim by notifications_screen_test.dart and ws5_two_layers_test.dart

- **Wave:** 4
- **Severity:** P3
- **Delivery disposition:** `blocked` (wave4-chunk07 engine run, 2026-07-14, terminated at no-progress cap / loop end). Ledger row was found stuck at stale `todo` by this reconciliation pass and reclassified to match the engine outcome.
- **Basis — verified-looking fix commit found, never merged:** two worktree branches each carry an identical commit — `bd46e2ec` on `worktree-wf_1a1fc4a3-128-41` and `a5c9e109` on `worktree-wf_1a1fc4a3-128-2` (byte-identical diffs) — titled `fix(tests/notifications): AUD-t-notifications-03 - dedup MockNotificationGateway`. It moves the shared `class MockNotificationGateway extends Mock implements NotificationGateway {}` to a new `test/features/notifications/support/mock_notification_gateway.dart` and has both files import it, plus a new `tool/check_notifications_duplicate_test_classes.dart` Rule-0 checker (claimed check 63) and its unit test; the commit message claims 182/182 tests passing and `flutter analyze` clean. **Neither commit is an ancestor of this branch's current `HEAD`**. Independently re-verified against the current tree: `grep -rn "class MockNotificationGateway" test/features/notifications/` still shows the class independently redeclared in both `notifications_screen_test.dart` and `ws5_two_layers_test.dart` (plus two further pre-existing declarations the commit itself flagged as an out-of-scope ratchet baseline). Per the engine outcome this id is `blocked`, not `merged`; the ledger row's `commits: []` already reflected that nothing is merged, and its `status`/`notes` were updated to match.
- **Logged by:** wave4-chunk07 ledger reconciliation agent (sonnet), 2026-07-14.

---

## AUD-t-notifications-04 — Register needs_flutter/notifications/notifications_screen_l1 tags in dart_test.yaml to silence unknown-tag warnings

- **Wave:** 4
- **Severity:** P3
- **Delivery disposition:** `blocked` (wave4-chunk07 engine run, 2026-07-14, terminated at no-progress cap / loop end). Ledger row was found stuck at stale `todo` by this reconciliation pass and reclassified to match the engine outcome.
- **Basis — verified-looking fix commit found, never merged:** two worktree branches each carry an identical commit — `5ffcaa60` on `worktree-wf_1a1fc4a3-128-41` and `a85ada4e` on `worktree-wf_1a1fc4a3-128-2` (byte-identical diffs) — titled `fix(tests/notifications): AUD-t-notifications-04 - register notifications tags in dart_test.yaml`. It registers `needs_flutter`, `notifications`, `notifications_screen_l1`, `aud_notifications_12`, and `unit` in `dart_test.yaml`'s `tags:` block; the commit message claims the same 182 tests still pass with zero unknown-tag warnings afterward. **Neither commit is an ancestor of this branch's current `HEAD`**. Independently re-verified against the current tree: `grep -n "needs_flutter:\|notifications:\|notifications_screen_l1:" dart_test.yaml` returns zero matches — the tags remain unregistered on `dev`. Per the engine outcome this id is `blocked`, not `merged`; the ledger row's `commits: []` already reflected that nothing is merged, and its `status`/`notes` were updated to match.
- **Logged by:** wave4-chunk07 ledger reconciliation agent (sonnet), 2026-07-14.

---

## AUD-t-notifications-05 — Rename the 'shows three Switch widgets' test in notifications_screen_l1_test.dart to match its findsNWidgets(4) assertion

- **Wave:** 4
- **Severity:** P3
- **Delivery disposition:** `blocked` (wave4-chunk07 engine run, 2026-07-14, terminated at no-progress cap / loop end). Ledger row was found stuck at stale `todo` by this reconciliation pass and reclassified to match the engine outcome.
- **Basis — verified-looking fix commit found, never merged:** two worktree branches each carry an identical commit — `a98c26e9` on `worktree-wf_1a1fc4a3-128-41` and `28da72d0` on `worktree-wf_1a1fc4a3-128-2` (byte-identical diffs) — titled `fix(tests/notifications): AUD-t-notifications-05 - fix stale test name in notifications_screen_l1_test.dart`. It renames the test to `'shows four Switch widgets (reminder, streak alert, reward, device toggle)'`, assertion unchanged; the commit message claims 39/39 tests pass. **Neither commit is an ancestor of this branch's current `HEAD`**. Independently re-verified against the current tree: `grep -n "shows three Switch widgets\|shows four Switch widgets" test/features/notifications/presentation/screens/notifications_screen_l1_test.dart` still shows the stale `'shows three Switch widgets (reminder, streak alert, reward)'` name at line 236. Per the engine outcome this id is `blocked`, not `merged`; the ledger row's `commits: []` already reflected that nothing is merged, and its `status`/`notes` were updated to match.
- **Logged by:** wave4-chunk07 ledger reconciliation agent (sonnet), 2026-07-14.

---

## AUD-t-notifications-08 — Stop relying on find.byKey(...).last for time-row lookups in notifications_screen_l1_test.dart and notifications_screen_test.dart

- **Wave:** 4
- **Severity:** P3
- **Delivery disposition:** `blocked` (wave4-chunk07 engine run, 2026-07-14, terminated at no-progress cap / loop end). Ledger row was found stuck at stale `todo` by this reconciliation pass and reclassified to match the engine outcome.
- **Basis — verified-looking fix commit found, never merged:** two worktree branches each carry an identical commit — `f88bc263` on `worktree-wf_1a1fc4a3-128-41` and `44c3ad7e` on `worktree-wf_1a1fc4a3-128-2` (byte-identical diffs) — titled `fix(tests/notifications): AUD-t-notifications-08 - stop using find.byKey(...).last for time-row lookups`. It replaces all 8 `find.byKey(...).last` call sites with `find.widgetWithText(ListTile, <row title>)`; the commit message claims 44/44 tests pass and `flutter analyze` clean. **Neither commit is an ancestor of this branch's current `HEAD`**. Independently re-verified against the current tree: `grep -c "\.last" test/features/notifications/presentation/screens/notifications_screen_test.dart` still returns a nonzero count — the `.last` usage remains on `dev`. Per the engine outcome this id is `blocked`, not `merged`; the ledger row's `commits: []` already reflected that nothing is merged, and its `status`/`notes` were updated to match.
- **Logged by:** wave4-chunk07 ledger reconciliation agent (sonnet), 2026-07-14.

---

## AUD-t-learning-01 — Override userDatabaseProvider/coarsePacedTrackIdsProvider/contentIndexProvider in LearningScreen widget tests — real Drift DB is being constructed on every pump

- **Wave:** 4
- **Severity:** P1
- **Delivery disposition:** `blocked` (wave4-chunk07 engine run, 2026-07-14, terminated at no-progress cap / loop end). Ledger row was found stuck at stale `todo` by this reconciliation pass and reclassified to match the engine outcome.
- **Basis — verified-looking fix commit found, never merged:** two worktree branches each carry an identical commit — `c513ef84` on `worktree-wf_1a1fc4a3-128-50` and `7f8ca629` on `worktree-wf_1a1fc4a3-128-1` (byte-identical diffs) — titled `fix(learning): AUD-t-learning-01 - override userDatabaseProvider/coarsePacedTrackIdsProvider/contentIndexProvider in LearningScreen widget tests`. It overrides `coarsePacedTrackIdsProvider`/`contentIndexProvider` with inert empty-value stubs plus `userDatabaseProvider` with a shared in-memory `UserDatabase` closed once via `tearDownAll`, and adds a new `make audit` Rule-0 check (claimed 62/62) that fails the build if `'WARNING (drift)'` appears in `test/features/learning/presentation/screens/` output; the commit message claims a RED (26 occurrences) → GREEN (0 occurrences) demonstration and 31/31 tests passing. **Neither commit is an ancestor of this branch's current `HEAD`**. Independently re-verified against the current tree: `grep -n "userDatabaseProvider\|coarsePacedTrackIdsProvider\|contentIndexProvider" test/features/learning/presentation/screens/learning_screen_l1_test.dart` returns zero matches — the overrides are genuinely absent from `dev`. Per the engine outcome this id is `blocked`, not `merged`; the ledger row's `commits: []` already reflected that nothing is merged, and its `status`/`notes` were updated to match.
- **Logged by:** wave4-chunk07 ledger reconciliation agent (sonnet), 2026-07-14.

---

## AUD-t-learning-02 — Delete or merge stale learning_screen_test.dart into learning_screen_l1_test.dart

- **Wave:** 4
- **Severity:** P2
- **Delivery disposition:** `blocked` (wave4-chunk07 engine run, 2026-07-14, terminated at no-progress cap / loop end). Ledger row was found stuck at stale `todo` by this reconciliation pass and reclassified to match the engine outcome.
- **Basis — verified-looking fix commit sequence found, never merged:** two worktree branches each carry an identical 2-commit sequence — `3c7a3820`+`dd5ad6bf` on `worktree-wf_1a1fc4a3-128-50` and `7de83aa6`+`ff646d9c` on `worktree-wf_1a1fc4a3-128-1` (byte-identical net diffs). The first commit deleted `learning_screen_test.dart` outright and moved its one non-duplicate test into `test/core/widgets/app_error_view_test.dart`; the second commit reverted course after discovering that broke the AG-5 test-mirroring ratchet (`tool/check_test_mirroring.dart`, `make audit` check 29/40 in the commit's numbering) and instead restored `learning_screen_test.dart` pruned to hold only the `AppErrorView` test, reverting the `app_error_view_test.dart` addition. The final commit message claims the AG-5 ratchet passes clean and 36 tests pass. **Neither tip commit is an ancestor of this branch's current `HEAD`**. Independently re-verified against the current tree: `find test/features/learning/presentation/screens -iname learning_screen_test.dart` still finds the file present and unpruned (still contains its original duplicate/stale `LearningScreen` tests, not reduced to only the `AppErrorView` test) — the stale-mirror defect this finding targets is unfixed on `dev`. Per the engine outcome this id is `blocked`, not `merged`; the ledger row's `commits: []` already reflected that nothing is merged, and its `status`/`notes` were updated to match.
- **Logged by:** wave4-chunk07 ledger reconciliation agent (sonnet), 2026-07-14.

---

## AUD-t-learning-04 — Extract a shared pump helper in learning_screen_l1_test.dart instead of 4 inline MaterialApp/localizationsDelegates blocks

- **Wave:** 4
- **Severity:** P3
- **Delivery disposition:** `blocked` (wave4-chunk07 engine run, 2026-07-14, terminated at no-progress cap / loop end). Ledger row was found stuck at stale `todo` by this reconciliation pass and reclassified to match the engine outcome.
- **Basis — verified-looking fix commit found, never merged:** two worktree branches each carry an identical commit — `f5d87e45` on `worktree-wf_1a1fc4a3-128-1` and `c252b2ca` on `worktree-wf_1a1fc4a3-128-50` (byte-identical diffs) — titled `test(learning): AUD-t-learning-04 - extract shared pump helper in learning_screen_l1_test.dart`. It routes all 4 inline `MaterialApp`/`localizationsDelegates` construction sites through the file's existing `_buildScreen` helper via two new optional parameters (`streakStream`, `router`); the commit message claims exactly one `MaterialApp(` construction site remains and 28/28 tests pass. **Neither commit is an ancestor of this branch's current `HEAD`**. Independently re-verified against the current tree: `grep -n "MaterialApp(" test/features/learning/presentation/screens/learning_screen_l1_test.dart | wc -l` still returns 4 — the duplication this finding targets is unfixed on `dev`. Per the engine outcome this id is `blocked`, not `merged`; the ledger row's `commits: []` already reflected that nothing is merged, and its `status`/`notes` were updated to match.
- **Logged by:** wave4-chunk07 ledger reconciliation agent (sonnet), 2026-07-14.

---

## Wave-4 gate-repair (2026-07-14) — 9 findings swept into `blocked` for completed-but-unmerged work, now genuinely merged

The wave-4 closing gate failed a first time on the finding immediately above (`AUD-t-learning-04`) and 8 siblings (`AUD-t-learning-01`, `AUD-t-learning-02`, `AUD-t-notifications-01`, `AUD-t-notifications-02`, `AUD-t-notifications-03`, `AUD-t-notifications-04`, `AUD-t-notifications-05`, `AUD-t-notifications-08`): each had a verified-looking fix commit sitting on a worktree branch, confirmed not an ancestor of `dev` HEAD, with the underlying defect confirmed still present in the tree — completed work swept under `blocked` rather than actually landed. This entry records the gate-repair resolution for all 9, following the same cherry-pick-and-reverify pattern already used above for `AUD-t-cross-31`/`46`/`50`/`62`.

**Two independent commit chains, each internally self-consistent:**

- **Learning cluster** (`AUD-t-learning-01` → `AUD-t-learning-02` (2 commits) → `AUD-t-learning-04`, in that order) existed as one linear sequence on both `worktree-wf_1a1fc4a3-128-1` and `worktree-wf_1a1fc4a3-128-50` (byte-identical), based directly on `4d77a377` — the same commit that is `dev`'s own merge-base with these worktrees, with zero intervening `dev` commits touching any of the 3 affected files. Cherry-picked as 4 sequential commits (`-x 7f8ca629`, `7de83aa6`, `f5d87e45`, `ff646d9c`) — all applied clean except one Makefile conflict on the first (see below).
- **Notifications cluster** (`AUD-t-notifications-01` → `-03` → `-04` → `-05` → `-08`, in that order) existed as one linear sequence on both `worktree-wf_1a1fc4a3-128-41` and `worktree-wf_1a1fc4a3-128-2` (byte-identical), based on `3cc3409c` (an ancestor of `dev`). Cherry-picked as 5 sequential commits (`-x 623798dc`, `bd46e2ec`, `5ffcaa60`, `a98c26e9`, `f88bc263`) — Makefile conflicts on the first two (each adds a new Rule-0 check), test files applied clean.
- **`AUD-t-notifications-02`** was isolated (see its own entry below).

**Makefile conflict resolution:** both clusters' worktrees branched before `AUD-t-profiles-02`'s check landed on `dev` at position 62/62, and each cluster's own commits independently renumber 62→63→... in their own chain. Per the established non-retroactive-renumbering convention (see `AUD-t-cross-31`'s resolution above): kept every existing check's historical `N/` position label text unchanged, appended each new check at the end with the running total bumped, and updated the `audit: ... ## Run all N enforcement greps` doc-comment and the closing `audit PASSED — all N greps clean` line to match. Final count after all cherry-picks: **65/65** (was 61/61 at the shared base; +1 `AUD-t-cross-84` already on dev, +1 `AUD-t-profiles-02` already on dev, +1 `AUD-t-learning-01`, +1 `AUD-t-notifications-01`, +1 `AUD-t-notifications-03`).

**Gate-repair discovery — TOCTOU race between AUD-t-notifications-01 and -03's Rule-0 checkers:** each finding shipped its own checker (`check_notifications_sync_effect_overrides.dart`, `check_notifications_duplicate_test_classes.dart`) plus a unit test that writes a short-lived fixture `.dart` file directly under `test/features/notifications/` (the same tree both checkers scan), runs the checker as a subprocess, asserts on its output, then deletes the fixture. Each was authored and reviewed in isolation on its own worktree and never ran alongside the other. Running both fixture-test files in one `flutter test` invocation with `--concurrency` > 1 (as the full suite does) intermittently crashed one checker with an unhandled `PathNotFoundException`: its directory listing captured the OTHER test's temp fixture, which that test's teardown deleted before this checker's `readAsLinesSync()` call. Reproduced deterministically by running both fixture test files together; fixed with a defensive `try`/`on FileSystemException`/skip around the read in both tools (commit `26090976`) rather than touching either checker's or test's assertions — TQ-7 compliant, since a vanished file cannot contain a violation and skipping it is correct scanner behavior, not a coverage reduction. Re-verified: both fixture test files together, `--concurrency=4`, run 3×, 6/6 pass every run (was flaky before).

**`AUD-t-notifications-02` — separately reviewed, no engine review completed:** its original disposition (`blocked`, merge-lane w4r1c3) recorded that the opus reviewer ran out of usage quota mid-review before confirming the fix, correctly left unmerged per doctrine (never merge unreviewed) but stranded on a since-deleted worktree branch (`wf_1a1fc4a3-128-3`) whose commit, `faf6947143cfdde2b907db6354b026095eb564b5`, survived because deleting a worktree checkout does not delete its branch ref. That disposition's `notes` used internal orchestration vocabulary (`quota`, `merge-lane`) inappropriate for a delivery ledger, and — separately — recorded no completed review, which the gate correctly treats as a fail regardless of how sound the code might be. Performed the missing independent review: confirmed via `git show <sha> --stat` the commit touches only `notification_providers.dart` (new `@visibleForTesting buildNotificationSettingsSignature(...)` helper, 2 call sites updated to use it) and `notification_providers_deep_test.dart` (G1-G4 now call the helper instead of hand-copying its format string) — a clean, narrowly-scoped, non-weakening fix matching the finding's recommendation exactly, with real mutation-check evidence in the commit message (dropping `reminderMinute` from the extracted function flips G1 red). A `git diff dev worktree-wf_1a1fc4a3-128-3` initially looked alarming (it also showed `ws5_per_profile_test.dart` reverting to a pre-mock-based, tautological shape — exactly the anti-pattern `AUD-t-notifications-07` fixed) but `git show <sha>` isolated to the commit itself confirmed it does **not** touch that file at all; the apparent diff was `dev` having received `AUD-t-notifications-07`'s independent fix to that file *after* this worktree branched, not anything this commit does. Cherry-picked cleanly (`-x faf69471`, landed as `57255086`; the worktree's base was this commit's direct parent, so no conflicts).

**Full re-verification after all 10 commits (9 fixes + 1 gate-repair robustness fix) landed on `dev`:**
- `flutter test test/features/learning/presentation/screens/ test/core/widgets/app_error_view_test.dart` → 36/36 pass, 0 `WARNING (drift)` occurrences
- `dart run tool/check_test_mirroring.dart` → AG-5 ratchet OK
- `dart run tool/check_inmemory_db_close.dart` → passes
- `flutter test test/features/notifications/` → 182/182 pass
- `dart run tool/check_notifications_sync_effect_overrides.dart` / `check_notifications_duplicate_test_classes.dart` → both pass
- `flutter analyze` → No issues found
- `dart format --set-exit-if-changed` on every file this pass touched → unchanged (a pre-existing, unrelated formatting drift in 5 other files — `study_day_config_merger_test.dart`, `w3_41_tutor_security_rules_test.dart`, `check_story_status_reconciliation.dart`, `gen_arch_tables.dart`, `gen_feature_graph.dart` — was confirmed present already at this pass's starting commit `eea5f406` and left untouched as out of scope for this repair)
- `make audit` → **audit PASSED — all 65 greps clean**

Ledger rows for all 9 ids updated `blocked` → `merged` with real commit shas, `reviewRounds: 1`, and evidence-bearing `acVerified`/`notes`.

- **Logged by:** wave-4 gate-repair agent (sonnet), 2026-07-14.

---

## AUD-t-profiles-03 — Extract a shared pumpApp/l10n test harness — 25+ duplicated MaterialApp+delegate blocks across features/profiles/presentation tests

- **Wave:** 4
- **Severity:** P2
- **Delivery disposition:** `blocked` (wave4-chunk08 engine run, 2026-07-14, terminated at no-progress cap / loop end). Ledger row was found stuck at stale `todo` by this reconciliation pass and reclassified to match the engine outcome.
- **Basis — verified-looking fix commit found, never merged:** two worktree branches each carry an identical-message commit — `fd12b480` on `worktree-wf_9438f433-5f0-43` and `e8afe273` on `worktree-wf_9438f433-5f0-2` (same title, overlapping but not byte-identical diffs — `git diff fd12b480 e8afe273` shows 24 files differ, largely in unrelated files each worktree's other findings also touched) — titled `test(profiles): AUD-t-profiles-03 - migrate 15 remaining files onto pumpApp`. It migrates the 15 named files (`ws4_mode_boundaries_test.dart`, `ts3_parent_track_archive_test.dart`, `parent_settings_screen_l1_test.dart`, `pp12_pin_change_subtitle_test.dart`, `pp11_edit_dialog_autofocus_test.dart`, `pp2_edit_profile_mode_persisted_test.dart`, `pp13_add_profile_selects_new_profile_test.dart`, `pp1_pin_setup_dialog_busy_guard_test.dart`, `ts14_parent_track_management_copy_test.dart`, `parent_track_management_screen_l1_test.dart`, `profile_picker_screen_l1_test.dart`, `add_profile_dialog_test.dart`, `rpr2_picker_offline_delete_test.dart`, `profile_edit_delete_actions_test.dart`, `parent_pin_keypad_dialog_test.dart`) off hand-rolled `MaterialApp`/delegate blocks onto the shared `pumpApp()` helper (`AUD-t-profiles-02`'s extraction) and lowers `tool/tq3_pump_app_delegate_baseline.txt`'s ratchet. **Neither commit is an ancestor of this branch's current `HEAD`** (`git merge-base --is-ancestor <sha> HEAD` fails for both). Independently re-verified against the current tree: `grep -c "MaterialApp(" <file>` returns a nonzero count (1–9 occurrences) for all 15 named files, and `grep -c "pumpApp(" <file>` returns 0 for all 15 — the migration this finding calls for is genuinely absent from `dev`; `tool/tq3_pump_app_delegate_baseline.txt` is unchanged since `AUD-t-profiles-02`'s commit (`2c7d3790`). Per the engine outcome this id is `blocked`, not `merged`; the ledger row's `commits: []` already reflected that nothing is merged, and its `status`/`notes` were updated to match.
- **Logged by:** wave4-chunk08 ledger reconciliation agent (sonnet), 2026-07-14.

---

## AUD-t-profiles-06 — Scope or ticket the FlutterError.onError overflow suppression in profile_picker_screen_l1_test.dart and rpr2_picker_offline_delete_test.dart he-locale tests

- **Wave:** 4
- **Severity:** P3
- **Delivery disposition:** `blocked` (wave4-chunk08 engine run, 2026-07-14, terminated at no-progress cap / loop end). Ledger row was found stuck at stale `todo` by this reconciliation pass and reclassified to match the engine outcome.
- **Basis — verified-looking fix commit found, never merged:** two worktree branches each carry a same-titled commit — `7268e452` on `worktree-wf_9438f433-5f0-43` and `d37767a7` on `worktree-wf_9438f433-5f0-2` (overlapping but not byte-identical diffs, same pattern as the sibling `AUD-t-profiles-03` entry above) — titled `fix(profiles): AUD-t-profiles-06 - narrow FlutterError.onError overflow filters`. Both files' blanket `details.exceptionAsString().contains('overflowed')` `FlutterError.onError` override is replaced with a call to a new `test/helpers/scoped_overflow_filter.dart` `isKnownSmallOverflow()` helper, which matches only overflow errors of at most 15 logical pixels (the observed ~3.6px known defect) rather than swallowing every `RenderFlex` overflow in the pumped tree; the commit message documents a rejected widget-identity-matching approach (Flutter's `Element.debugGetCreatorChain(12)` hard cap exhausts before reaching `ProfileCard`) and RED→GREEN evidence via a synthetic 5000px-wide-Row overflow probe added to both test files. **Neither commit is an ancestor of this branch's current `HEAD`** (`git merge-base --is-ancestor <sha> HEAD` fails for both). Independently re-verified against the current tree: `grep -n "FlutterError.onError\|overflow" learning_tracker/test/features/profiles/presentation/screens/profile_picker_screen_l1_test.dart` and the same on `rpr2_picker_offline_delete_test.dart` show both files still installing the original blanket `contains('overflowed')` filter (lines 670–675 and 192–197 respectively); `find learning_tracker/test -iname scoped_overflow_filter*` returns nothing — the narrowing fix is genuinely absent from `dev`. Per the engine outcome this id is `blocked`, not `merged`; the ledger row's `commits: []` already reflected that nothing is merged, and its `status`/`notes` were updated to match.
- **Logged by:** wave4-chunk08 ledger reconciliation agent (sonnet), 2026-07-14.


---

## Wave-4 gate-repair (2026-07-14) — AUD-t-profiles-03, AUD-t-profiles-06, AUD-t-progress-09 swept into `blocked` for completed-but-unmerged work, now genuinely merged

The wave-4 closing gate failed on these 3 findings: `AUD-t-profiles-03` and `AUD-t-profiles-06` (both immediately above — wave4-chunk08's own reconciliation pass correctly identified verified-looking fix commits stranded on worktree branches and reclassified `todo` -> `blocked`, matching doctrine), and `AUD-t-progress-09` (merge-lane `w4r1c19` — its `notes` field self-admitted "internal process blocker, not an external blocker" and used internal vocabulary (`quota`, `merge-lane`) that TQ-7/delivery-ledger doctrine bans from a customer-facing ledger note, regardless of whether the underlying code was sound). All three had real, reviewable fix commits sitting on worktree branches, never merged.

**AUD-t-progress-09** — single independent-review pass performed: `git show eb660d61 --stat` confirms the commit touches only `progress_widgets_test.dart` (renames the top-level `child()` test helper to `_hostedLevelCard`, adds a rationale doc comment) — a clean, narrowly-scoped, non-weakening rename matching the finding's recommendation exactly, with RED (`grep '^Widget child('` matches) -> GREEN (no match) evidence in the commit message. Cherry-picked cleanly (`-x eb660d61`, landed as `10a1dfd6`; zero dev commits touched the file since the worktree's branch point).

**AUD-t-profiles-03 / AUD-t-profiles-06** — both findings' verified-looking fixes existed as two near-duplicate attempts (`worktree-wf_9438f433-5f0-43` and `worktree-wf_9438f433-5f0-2`, overlapping but not byte-identical, per the entries above). Selected `worktree-wf_9438f433-5f0-43`'s pair (`fd12b480` + `7268e452`) — it is based on the later of the two dev branch-points (`12f52b9d`, which already carries `AUD-t-profiles-04`; the sibling worktree's `f1a78c29` base predates it), reducing rebase drift. Zero dev commits between `12f52b9d` and the current tip touch any of the 15 target files, `pump_app.dart`, `scoped_overflow_filter.dart`, or `tq3_pump_app_delegate_baseline.txt`, so both cherry-picks (`-x fd12b480` then `-x 7268e452`, landed as `b345050d` and `9e4e5edf`) applied clean with zero merge conflicts.

**Stale-ratchet drift discovered and fixed (TQ-7 compliant, not a weakening):** post-cherry-pick, `make audit` failed check 62/65 (TQ-3 `pumpApp` migration ratchet) by exactly +1 — `fd12b480`'s own committed baseline (204) was computed against ITS branch point (`dev@12f52b9d`), where the true pre-migration count was implicitly 238; current dev's actual pre-migration count is 239 (one higher, from unrelated wave-4 work landing on dev between `12f52b9d` and now, entirely outside this repair's scope — confirmed neither touched file introduces any new hand-rolled `GlobalCupertinoLocalizations.delegate` block). Recomputing via the checker's own documented path (`dart run tool/check_tq3_pump_app_migration.dart --update-baseline`) landed the TRUE count: 239 -> 205 (net -34, a real win — commit `7a2a0cf7`). This raises the tracked number to match verified reality post-migration; it does not raise it to hide a new violation, so it is not a TQ-7 weakening.

**Full re-verification after all 4 commits landed on `dev`:**
- `flutter test --concurrency=2 test/features/profiles/ test/features/progress/` -> 774/774 pass (0 failures), including both new "must NOT swallow an UNRELATED overflow" regression probes added by `AUD-t-profiles-06`
- `flutter test --concurrency=2 test/features/progress/presentation/widgets/progress_widgets_test.dart` -> 16/16 pass
- `flutter analyze` -> No issues found
- `dart format --set-exit-if-changed` on every file this pass touched -> unchanged (2 unrelated pre-existing formatting-drift files touched incidentally by an intermediate `dart format test/` sweep — `study_day_config_merger_test.dart`, `w3_41_tutor_security_rules_test.dart`, both already documented as pre-existing drift in the learning/notifications gate-repair entry above — were reverted, out of scope for this repair)
- `make audit` -> **audit PASSED — all 66 greps clean**
- No `lib/` production code touched by any of the 4 commits (test-only + one ratchet-baseline `.txt` change) — zero runtime-behavior risk from this repair.

**Worktree/branch residue cleanup:** all 30 stray `.claude/worktrees/wf_9438f433-5f0-*` checkouts left behind by the wave4-chunk08 engine run (29 distinct tip commits — one pair, `worktree-wf_9438f433-5f0-2`/`-30`, shared a sha) were inventoried and their tip commit messages read: every one of the other 26 corresponds to a chunk08 finding (`AUD-t-progress-01/02/03/04/05/06/07/08/10`, `AUD-t-scheduler-01/02/03/04/05/06/07/09`, `AUD-t-settings-01/03`, `AUD-t-profiles-04/05/07`, `AUD-t-sacred_time-01`) already showing `merged` in the ledger with its own, differently-worded/differently-shaed commit on `dev` — i.e. superseded stale duplicates, not additional unlanded work; none referenced the still-`blocked` `AUD-t-cross-32`/`AUD-t-cross-62` (unrelated, out of this repair's scope, left untouched). Before deletion, all 29 distinct tips were bundled to `/home/daniel/gate-repair-bundles/wf_9438f433-5f0-worktrees-2026-07-14.bundle` (`git bundle verify` confirms a complete, self-contained history) as a recovery net. Then removed: the 30 worktree checkouts (`git worktree remove --force`) and the 6 named local branches among them — `worktree-wf_9438f433-5f0-13/-19/-2/-20/-43` (each had an active checkout) plus `worktree-wf_9438f433-5f0-39` (checkout already gone before this pass; branch-only, per its own ledger note) — via `git branch -D`. `git worktree list` / `.claude/worktrees/` confirmed empty of `wf_9438f433-*` entries afterward.

- **Logged by:** wave-4 gate-repair agent (sonnet), 2026-07-14.

---

## AUD-t-story-acceptance-03 — Back epic_27_story_27_8's tutor/rules security-boundary tests with real rule evaluation, not substring matching

- **Wave:** 4
- **Severity:** P2
- **Delivery disposition:** `skipped-refuted` (merge-lane `w4r1c3`, 2026-07-14).
- **Basis — already fixed pre-baseline, no code change required:** `firestore_rules.test.mjs` already asserts both the tutor-write-block and owner-write-success outcomes on completions via the real Firestore emulator (104/104 tests pass, verified against a live emulator run — not the substring-matching pattern the finding describes). CI already runs this suite unconditionally as a hard-fail step if the file is missing. Both the assertions and the CI wiring predate the audit baseline commit (`4018a91c`), so there is nothing here for delivery to fix; the finding described a defect that was not present in the tree at baseline time.
- **Logged by:** merge-lane agent w4r1c3 (sonnet), 2026-07-14.

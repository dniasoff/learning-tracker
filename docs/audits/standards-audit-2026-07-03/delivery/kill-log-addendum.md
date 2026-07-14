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

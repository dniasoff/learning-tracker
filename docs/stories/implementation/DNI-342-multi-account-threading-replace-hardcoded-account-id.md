# DNI-342 — 25.21 Multi-account threading — replace hardcoded currentAccountId = 1 sites

Status: review

Linear: https://linear.app/orvexai/issue/DNI-342

## Story

As a user with multiple accounts on one device, I want the active account to be
properly threaded through the data layer so that switching accounts (or having
multiple accounts on a shared family device) actually loads the right account's
data (FR22, completes Epic 21 plumbing).

## Acceptance Criteria

1. Each call site that previously hardcoded `accountId = 1` now reads the
   active account via `currentAccountIdProvider`, which is backed by
   `authStateProvider` and ultimately the `DeviceAccounts` registry / per-user
   DB's `accounts.id`.
2. `grep -rn 'currentAccountId.*=.*1\b' lib/` returns zero results — covered
   by a static acceptance test that scans every `lib/**/*.dart`.
3. Profile queries downstream of account context (`getProfilesByAccount`,
   `countProfilesForAccount`, `watchProfilesByAccount`, `profileExistsByName`,
   `createProfile`) all derive their account from `currentAccountIdProvider`.
4. When the user switches between accounts via the account picker, profiles
   and snapshot data load from the active account's user DB file (per Epic
   19's per-account DB split) — the provider re-emits when
   `authStateProvider` flips, so widgets watching it rebuild automatically.
5. Tier-aware offline UX from Epic 19 is preserved end-to-end:
   - `OfflineTopBanner` only renders for `cloudBorn` users who are offline.
   - `NoBackupBadge` only renders for `localBorn` users and is now mounted in
     the profile-picker header (the canonical "profile area").

## Tasks / Subtasks

- [x] Write red acceptance test covering provider derivation, grep-source
      invariants, and tier-aware UI gating.
- [x] Make `currentAccountIdProvider` watch `authStateProvider` and resolve
      to `currentUser.profileId` (`accounts.id` in the active per-user DB),
      falling back to `1` only during the brief signed-out window.
- [x] Replace all 13 hardcoded `1` call sites across `onboarding_screen`,
      `profile_picker_screen`, `manage_learners_screen`, `sign_in_screen`,
      `pending_local_signup`, and `profile_repository_impl`.
- [x] Use `existing.accountId` in `ProfileRepositoryImpl.deleteProfile`'s
      last-profile guard so the count is scoped to the actual account of the
      profile being deleted, not a hardcoded constant.
- [x] Mount `NoBackupBadge` in `ProfilePickerScreen` above the title; the
      widget self-gates by tier so cloud-born users see nothing.
- [x] Update the stale `// ... getProfilesByAccount(1)` comment in
      `sync_engine.dart` so the test's grep is unambiguous.
- [x] Register `epic_25` + `story_25_21` tags in `dart_test.yaml`.
- [x] Add `make test-story-25.21` Makefile target.
- [x] `dart analyze --fatal-infos` clean.
- [x] Full regression: `flutter test` passes (1811 passed, 103 pre-existing
      skips, 0 failed).

## File List

- `learning_tracker/lib/features/profiles/presentation/providers/profile_providers.dart` (modified)
- `learning_tracker/lib/features/profiles/presentation/screens/profile_picker_screen.dart` (modified)
- `learning_tracker/lib/features/profiles/presentation/screens/manage_learners_screen.dart` (modified)
- `learning_tracker/lib/features/profiles/data/repositories/profile_repository_impl.dart` (modified)
- `learning_tracker/lib/features/onboarding/presentation/screens/onboarding_screen.dart` (modified)
- `learning_tracker/lib/features/auth/presentation/screens/sign_in_screen.dart` (modified)
- `learning_tracker/lib/features/auth/domain/services/pending_local_signup.dart` (modified)
- `learning_tracker/lib/features/sync/data/sync_engine.dart` (modified — comment only)
- `learning_tracker/test/story_acceptance/epic_25_story_21_multi_account_threading_test.dart` (new)
- `learning_tracker/dart_test.yaml` (modified — register epic_25 / story_25_21 tags)
- `learning_tracker/Makefile` (modified — add `test-story-25.21` target)
- `docs/stories/implementation/DNI-342-multi-account-threading-replace-hardcoded-account-id.md` (new)

## Dev Agent Record

- Branched from `dev` (`513a4a86`) into worktree `.claude/worktrees/dev-dni-342`.
- Followed BMAD dev-story TDD workflow — red test first, then minimal green.
- All 12 new acceptance tests green; broader Epic 25 (77), Epic 21 (58), Epic
  20 (auth), Epic 15 (multi-profile), Epic 13 (cloud-sync), Epic 9 (onboarding),
  and full `flutter test` suite (1811) pass with no regressions.

## Change Log

- `currentAccountId(Ref)` now resolves from
  `authStateProvider.currentUser?.profileId` instead of returning a constant
  `1`. Falls back to `1` only when signed-out, preserving the previous
  behavior for the brief signup→onboarding transition window.
- 13 hardcoded `accountId = 1` / `accountId: 1` / DAO call sites replaced
  with `ref.read(currentAccountIdProvider)` (or with `existing.accountId`
  in the case of `ProfileRepositoryImpl.deleteProfile`).
- `NoBackupBadge` mounted in `ProfilePickerScreen` — the widget was already
  tier-gated but had no mount point in the rebuilt shell.

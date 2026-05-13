# DNI-384 — 27.8: Integration tests — Firestore rules + offline completion flush

Status: review

## Acceptance Criteria

From Linear DNI-384:

- Given the Firestore emulator is configured, when the rules test runs, allowed cases pass and denied cases (negative points, future completedAt, arbitrary fields, deletes) are rejected.
- Given the offline-flush test runs, when the device is offline and the user records 50 completions, 50 outbox rows exist; when the device "reconnects" (test toggles a flag), the OutboxProcessor drains all 50 and the corresponding Firestore docs exist.

Requirements covered: NFR13, FR4, FR24.

## Tasks/Subtasks

- [x] Cherry-pick DNI-377 (`9938b579`) test infrastructure onto base.
- [x] Add `test/story_acceptance/epic_27_story_27_8_rules_and_offline_flush_test.dart`.
- [x] Group A — Firestore rules (8 dynamic delete-denial cases + 6 structural validator assertions).
- [x] Group B — Offline completion flush (50-row queue+drain happy path + retry-on-failure case).
- [x] Add `test-story-27.8` + extend `test-epic-27` make targets.
- [x] `dart analyze test/` — clean.
- [x] Full regression: `flutter test` → 1895 passing / 103 skipped / 0 failing.

## Dev Agent Record

Worktree branch: `dev-dni-384` (based on `origin/dev` 6ffe6d54 + cherry-pick of DNI-377 `9938b579`).

### Limitations honored

`fake_firebase_security_rules` 0.5.4 does NOT evaluate clauses referencing `request.resource.data`, `resource`, or `functions {}`. Our rules use all three (notably `request.resource.data.points >= 0`, `keys().hasOnly([...])`, and the helper `isOwnerByDocId()`). Under strict mode the fake therefore deny-falls-through to the wildcard rule for any write that depends on these constructs.

To stay honest:

- The dynamic deny-cases use `delete()` exclusively, since `Method.delete` resolves the explicit `allow delete: if false;` line in every rule block.
- The "negative points / future completed_at / arbitrary fields" denials are pinned via structural assertions on `firestore.rules`. The companion Node-based emulator suite under `test/firestore-rules/` (DNI-325) exercises them dynamically against the real rule engine in CI.

## File List

- `learning_tracker/test/story_acceptance/epic_27_story_27_8_rules_and_offline_flush_test.dart` (new)
- `learning_tracker/Makefile` (updated — added `test-story-27.8`, extended `test-epic-27`)
- `docs/stories/implementation/DNI-384-firestore-rules-and-offline-flush.md` (new)

## Change Log

- Initial implementation of Story 27.8 integration coverage.

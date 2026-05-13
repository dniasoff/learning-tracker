# DNI-327 — 25.6: Schema-check tool for profileId-in-PK invariants

Status: review

## Acceptance Criteria

From Linear DNI-327:

- `tool/schema_check.dart` exists and parses every `@DataClassName` / `@TableIndex` annotation in `learning_tracker/lib/core/database/tables/`.
- For every table on a whitelist of profile-scoped tables: assert `profileId` is in the primary key (or, for `autoIncrement()` tables, in `uniqueKeys`).
- For every such table: assert at least one composite `@TableIndex` OR composite `uniqueKeys` constraint.
- Exit non-zero with offending table names on violation; print a remediation hint.
- A test verifies the tool fails on a violating fixture.

## Tasks/Subtasks

- [x] Write `tool/schema_check.dart`
- [x] Add `make schema-check` target
- [x] Add acceptance test at `learning_tracker/test/tool/schema_check_test.dart` covering violation + clean cases
- [x] Run `make schema-check` against current `lib/core/database/tables/` → must pass

## Dev Agent Record

Worktree branch: `dev-dni-327`

## File List

- `tool/schema_check.dart` (new)
- `Makefile` (updated)
- `learning_tracker/test/tool/schema_check_test.dart` (new)
- `docs/stories/implementation/DNI-327-schema-check-profileid-invariants.md` (new)

## Change Log

- Initial implementation of schema-check tool for E25 v1 schema invariants.

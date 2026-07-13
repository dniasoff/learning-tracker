# Learning Tracker

## Story Acceptance Tests

When you finish implementing a story, **always validate it** before marking it done:

```bash
cd learning_tracker
make test-story-X.Y     # e.g. make test-story-1.2
```

### Workflow

1. Implement the story
2. Run `make test-story-X.Y` for your story -- fix until green
3. Run `make test-epic-N` to check you didn't break sibling stories
4. Run `make ci` (analyze + format + all stories) before committing

### Key Targets

| Command | What it does |
|---------|-------------|
| `make test-story-1.2` | Run one story's acceptance tests |
| `make test-epic-1` | Run all stories in Epic 1 |
| `make test-all-stories` | Run the full acceptance suite |
| `make analyze` | `dart analyze --fatal-infos` |
| `make format-check` | `dart format` dry-run |
| `make ci` | analyze + format + all stories |
| `make help` | List every target |

### Activating Backlog Tests

When you implement a backlog story, remove the `skip:` parameter from its `group()` in the corresponding `test/story_acceptance/epic_NN_*_test.dart` file. Replace the empty `() {}` bodies with real assertions. The test should then go from "skipped" to "passed".

### Test Structure

- One file per epic: `test/story_acceptance/epic_01_foundation_test.dart` ... `epic_14_settings_test.dart`
- Tags enable filtering: `@Tags(['epic_1'])` at file level, `tags: ['story_1_2']` on each group
- Existing test helpers: `test/helpers/test_database.dart`, `test/fixtures/`, `test/mocks/`

### Code Generation

After changing Drift tables, Freezed models, or Riverpod providers, regenerate before testing:

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## Layering Rules

The dependency direction is: `app → features → core`. These five invariants are **non-negotiable**.

> **custom_lint status:** each rule below has a matching rule under `packages/custom_lints/` (DNI-386 / DNI-387), unit-tested via `make audit`'s `lint-rules-test` step. The `custom_lint` CLI itself does **not** currently run against this codebase — it cannot discover the project and silently reports "No issues found!" even when violations exist (AUD-guardrails-03; see [docs/coding-standards.md](../docs/coding-standards.md), "custom_lint toolchain status"). Do not read a green `dart run custom_lint` as a passing signal. The real, active enforcement today is the `make audit` grep named under each rule below — the greps for Rules 1 and 2 are **warn-only**, pending legacy cleanup; Rules 3–5 are hard gates.

### Rule 1 — No `core/` → `features/` imports

`lib/core/` MUST NOT import anything from `lib/features/`. Core is shared infrastructure; it cannot depend on feature business logic.

**Enforced by:** the `no-feature-cross-import` custom lint rule (DNI-386, currently non-functional — see status note above) and the `make audit` check "No features/ imports inside lib/core/" — **warn-only**, pending legacy cleanup.

### Rule 2 — No cross-feature deep imports

`lib/features/X/` MUST NOT import directly from `lib/features/Y/` sub-paths. The only permitted cross-feature reference is the barrel file `lib/features/Y/Y.dart` (the feature's public surface).

**Enforced by:** the `no-feature-cross-import` custom lint rule (DNI-386, currently non-functional — see status note above) and the `make audit` check "No cross-feature deep imports" — **warn-only**, pending legacy cleanup.

### Rule 3 — Firebase symbols confined to `core/` Firebase modules

`FirebaseAuth`, `FirebaseFirestore`, and `FirebaseStorage` MUST only appear inside `lib/core/sync/` and `lib/core/auth/`. All other code receives Firebase objects through injected providers — never by importing Firebase packages directly.

**Enforced by:** the `no-firebase-outside-core` custom lint rule (DNI-387, currently non-functional — see status note above) and the `make audit` Firebase-import checks — hard gate.

### Rule 4 — Raw Talker confined to `core/logging/`

`package:talker/talker.dart` MUST only be imported inside `lib/core/logging/`. All other code logs through `AppLogger` (`lib/core/logging/logger.dart`).

**Enforced by:** the `no-raw-talker` custom lint rule (DNI-387, currently non-functional — see status note above) and the `make audit` check "No raw talker import outside core/logging" — hard gate.

### Rule 5 — `.displayNameEn` / `.displayNameHe` confined to `core/labels/` and generated files

Direct access to `.displayNameEn` or `.displayNameHe` on curriculum enums MUST only appear in `lib/core/labels/` and in generated files (`.g.dart`). Presentation code MUST use the `CurriculumLabelRenderer` in `lib/core/labels/curriculum_label_renderer.dart`.

**Enforced by:** the `no-curriculum-display-name-bypass` custom lint rule (DNI-386, currently non-functional — see status note above) and the `make audit` displayNameEn/He checks — hard gate.

### Local enforcement

Run `make audit` before pushing — it executes the layering greps above (Rules 1–5) plus every other enforcement grep, and depends on the `packages/custom_lints` unit tests (`lint-rules-test`, a hard gate that never soft-skips). `make audit` does **not** run `dart run custom_lint` against this codebase. `dart run custom_lint` (also reachable via `make lint`) is currently non-functional — see the status note above; do not rely on its exit code.

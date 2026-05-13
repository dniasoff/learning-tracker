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

The dependency direction is: `app → features → core`. These five invariants are **non-negotiable** and are enforced by custom lints (DNI-386 / DNI-387 — see `docs/coding-standards.md` for details):

### Rule 1 — No `core/` → `features/` imports

`lib/core/` MUST NOT import anything from `lib/features/`. Core is shared infrastructure; it cannot depend on feature business logic.

**Enforced by:** `no-feature-cross-import` custom lint (DNI-386).

### Rule 2 — No cross-feature deep imports

`lib/features/X/` MUST NOT import directly from `lib/features/Y/` sub-paths. The only permitted cross-feature reference is `lib/features/Y/providers.dart` (the feature's public surface).

**Enforced by:** `no-feature-cross-import` custom lint (DNI-386).

### Rule 3 — Firebase symbols confined to `core/` Firebase modules

`FirebaseAuth`, `FirebaseFirestore`, and `FirebaseStorage` MUST only appear inside `lib/core/sync/` and `lib/features/auth/`. All other code receives Firebase objects through injected providers — never by importing Firebase packages directly.

**Enforced by:** `no-firebase-outside-core` custom lint (DNI-387).

### Rule 4 — Raw Talker confined to `core/logging/`

`package:talker/talker.dart` MUST only be imported inside `lib/core/logging/`. All other code logs through `AppLogger` (`lib/core/logging/logger.dart`).

**Enforced by:** `no-raw-talker` custom lint (DNI-387).

### Rule 5 — `.displayNameEn` / `.displayNameHe` confined to `core/labels/` and generated files

Direct access to `.displayNameEn` or `.displayNameHe` on curriculum enums MUST only appear in `lib/core/labels/` and in generated files (`.g.dart`). Presentation code MUST use the `CurriculumLabelRenderer` in `lib/core/labels/curriculum_label_renderer.dart`.

**Enforced by:** `no-curriculum-display-name-bypass` custom lint (DNI-386).

### Local enforcement

Run `make audit` to execute every layering grep and lint check locally before pushing. Full docs: [`docs/coding-standards.md`](../docs/coding-standards.md).

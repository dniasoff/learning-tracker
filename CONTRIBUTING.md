# Contributing to Learning Tracker

Welcome — and thank you for considering a contribution. This guide takes you from a fresh clone to your first merged pull request. It assumes no prior knowledge of the project, so read it top to bottom the first time; afterwards you can treat it as a reference.

If anything here is unclear or out of date, that itself is worth a pull request.

## Table of Contents

- [Ways to contribute](#ways-to-contribute)
- [Before you start](#before-you-start)
- [Prerequisites](#prerequisites)
- [Set up the project](#set-up-the-project)
- [Find your way around the codebase](#find-your-way-around-the-codebase)
- [Project conventions](#project-conventions)
- [The development workflow](#the-development-workflow)
- [Testing your change](#testing-your-change)
- [Finding something to work on](#finding-something-to-work-on)
- [Opening a pull request](#opening-a-pull-request)
- [Getting help](#getting-help)
- [Code of conduct](#code-of-conduct)

## Ways to contribute

You do not have to write Dart code to help:

- **Code** — fix a bug, build a feature, improve performance.
- **Documentation** — clarify a guide, fix an example, fill a gap.
- **Translations** — the app ships in Hebrew and English; both ARB files live in `learning_tracker/lib/l10n/`.
- **Testing and bug reports** — reproduce an issue, file a clear report, or add a missing test.

## Before you start

Read the [README](./README.md) for what the app does, then skim the [documentation index](./docs/index.md). Two documents are worth reading in full before you touch code:

- **[Architecture](./docs/architecture.md)** — how the system fits together. [Section 12, *Known issues*](./docs/architecture.md#12-known-issues--remediation-context), is the most useful page for a newcomer: it lists real, current rough edges.
- **[Developer guide](./docs/development-guide.md)** — the authoritative reference for setup, testing, and conventions. This contributing guide is the friendly on-ramp; the developer guide is the detail.

This is a **brownfield project** — an established app, not a blank slate. Treat the code as the source of truth: when a document and the code disagree, the code wins (and the document needs a fix).

## Prerequisites

Install the following before you set up the project:

| Tool | Version | Purpose |
|---|---|---|
| Flutter SDK | 3.38.6 or newer | Builds and runs the app |
| Dart SDK | 3.10.8 or newer | Bundled with Flutter |
| Android Studio or VS Code | Current | IDE and Android toolchain |
| Git | Any recent version | Version control |
| Node.js | 20 | Only for the Firebase Cloud Functions in `learning_tracker/functions/` |

You do **not** need a Firebase account to develop the app. Firebase configuration files are injected by CI and are never committed; without them, the app runs in local-only mode, which is enough for most work.

## Set up the project

The Flutter app lives in the `learning_tracker/` subdirectory. Most commands run from there.

```bash
git clone https://github.com/dniasoff/learning-tracker.git
cd learning-tracker/learning_tracker

flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

The `build_runner` step is **mandatory** — it generates code for the database, state management, navigation, and models. The app will not compile without it. Re-run it whenever you change a database table, a Riverpod provider, a Freezed model, a route, or a serializable model. While developing, you can leave it running in watch mode:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

## Find your way around the codebase

The repository is one Flutter app plus supporting tooling:

```text
learning-tracker/
├── learning_tracker/    # the Flutter app — almost all the code
│   ├── lib/
│   │   ├── main.dart    # the entry point
│   │   ├── core/        # shared infrastructure (database, sync, navigation, ...)
│   │   └── features/    # 18 feature modules, each with data/domain/presentation
│   ├── test/            # the test suite
│   └── functions/       # Firebase Cloud Functions (TypeScript)
├── packages/            # the custom-lint package
└── docs/                # project documentation
```

The app is built in three layers, and dependencies only ever point **downward**:

```text
app  →  features  →  core
```

- `core/` is shared infrastructure (database, sync, navigation, theming, logging).
- `features/` holds 18 self-contained feature modules; each has a `data/`, `domain/`, and `presentation/` folder.
- `app` is the thin top layer in `main.dart`.

For a guided tour, read [`docs/source-tree-analysis.md`](./docs/source-tree-analysis.md). For the deeper concepts, the explainers cover the trickiest areas — [the sync subsystem](./docs/explainers/sync-subsystem.md), [the data model](./docs/explainers/data-model.md), and [the content database](./docs/explainers/content-database.md).

## Project conventions

The project enforces five architectural boundaries with custom lint rules. They are non-negotiable and checked in CI. In short:

1. **`core/` never imports `features/`** — shared infrastructure cannot depend on feature logic.
2. **Features do not deep-import each other** — a feature crosses another feature's boundary only through its public surface.
3. **Firebase code stays in the sync and auth layers** — other code receives Firebase through injected providers.
4. **Logging goes through `AppLogger`** — never the raw logging library, so redaction is always applied.
5. **Curriculum display names render through `core/labels/`** — never accessed directly, so labels stay locale-aware.

A few more rules you will meet quickly:

- **Never call `DateTime.now()` directly** — use the time abstraction in `core/time/` so tests can control the clock.
- **Record completions only through `CompletionWriter`** — never write the event log directly.
- **The UI uses direction-aware layout** (`start`/`end`, not `left`/`right`) so right-to-left Hebrew renders correctly.

Run all of these checks locally before you push:

```bash
cd learning_tracker
make audit          # the architectural boundary checks
dart format .       # formatting
dart analyze --fatal-infos
```

The full convention reference is in the [developer guide](./docs/development-guide.md) and in `learning_tracker/CLAUDE.md`.

## The development workflow

1. **Branch from `dev`.** All work targets the `dev` branch.
2. **Make your change** in small, focused commits.
3. **Regenerate code** if you touched anything that `build_runner` generates.
4. **Run the checks** (see [Testing your change](#testing-your-change)).
5. **Open a pull request against `dev`.**

The project uses a **story-based acceptance test suite** — tests are grouped by the feature story they verify. When you implement or change a behavior, find or add the matching story test.

## Testing your change

Run tests from the `learning_tracker/` directory:

```bash
make ci                 # the full local check: analysis, seed validation, all tests
make test-epic-7        # all tests for one epic
make test-story-6.1     # one story's acceptance tests
flutter test            # the raw unit and widget test run
```

Two rules keep the project stable:

- **`make ci` must pass before you open a pull request.** Continuous integration runs the same checks and will block a merge otherwise.
- **If you change anything in the sync subsystem, also run `make test-invariants`.** This suite (the N1–N8 invariants) guards against a set of bugs the project has fixed before and does not want back. A failing invariant must be fixed in the code, never by weakening the test.

New behavior needs a test. The test suite layout and helpers are described in the [developer guide](./docs/development-guide.md#5-testing).

## Finding something to work on

- **Open issues** are the first place to look. Comment on an issue before you start so work is not duplicated.
- **`docs/architecture.md` section 12** lists known issues and rough edges in the codebase — several are well-scoped, real improvements.
- **Documentation and translations** always have room for help and are a low-risk way to make a first contribution.

If you are unsure whether a change is wanted, open an issue to discuss it before writing a large amount of code.

## Opening a pull request

1. Confirm `make ci` passes locally (and `make test-invariants` if you touched sync).
2. Push your branch and open a pull request **against `dev`**.
3. Write a clear description: what changed, and why. Link any related issue.
4. Keep the pull request focused — one logical change per pull request reviews faster.

Optionally, install the pre-commit hook so formatting and analysis run automatically before each commit:

```bash
# from the repository root
make install-hooks
```

## Getting help

- Open a **GitHub issue** for bugs, questions, or proposals.
- Reference the [documentation index](./docs/index.md) — most "how does this work" questions are answered there.
- When reporting a bug, include your platform, the steps to reproduce, and what you expected versus what happened.

## Code of conduct

Be respectful, patient, and constructive. Assume good intent, give helpful feedback, and remember that contributors join with a wide range of experience. Behavior that makes the project unwelcoming is not acceptable.

By contributing, you agree that your contributions are licensed under the project's [MIT License](./LICENSE).

---
title: Developer Handbook
description: One-stop guide for working on Learning Tracker — domain concepts, architecture mental models, setup, workflows, coding standards, and troubleshooting.
date: 2026-04-19
---

# Developer Handbook

A single guide for everyone touching this codebase. Read the domain section first if you are new to Jewish learning concepts — the app's architecture only makes sense once the domain does.

## Table of Contents

- [Part 1 — Domain and Mental Models](#part-1--domain-and-mental-models)
  - [Why this app exists](#why-this-app-exists)
  - [Jewish learning concepts](#jewish-learning-concepts)
  - [The curricula](#the-curricula)
  - [Tracks (the core domain unit)](#tracks-the-core-domain-unit)
  - [Programs](#programs)
  - [Scheduling and chazara](#scheduling-and-chazara)
  - [Adult mode vs child mode](#adult-mode-vs-child-mode)
  - [Daily tracking loop](#daily-tracking-loop)
- [Part 2 — Setup and Workflow](#part-2--setup-and-workflow)
  - [Prerequisites](#prerequisites)
  - [First-time setup](#first-time-setup)
  - [Firebase configuration](#firebase-configuration)
  - [Key Make targets](#key-make-targets)
  - [Code generation](#code-generation)
  - [Testing strategy](#testing-strategy)
  - [Git workflow](#git-workflow)
  - [Pre-commit hook](#pre-commit-hook)
  - [CI/CD](#cicd)
- [Part 3 — Common Tasks](#part-3--common-tasks)
  - [Add a new feature module](#add-a-new-feature-module)
  - [Add a new database table](#add-a-new-database-table)
  - [Add a new screen](#add-a-new-screen)
  - [Add a new Riverpod provider](#add-a-new-riverpod-provider)
- [Part 4 — Coding Standards](#part-4--coding-standards)
- [Part 5 — Troubleshooting](#part-5--troubleshooting)

---

## Part 1 — Domain and Mental Models

### Why this app exists

Learning Torah at scale is hard. A committed learner juggles multiple texts — Mishnah, Talmud, Bible, law codes — each with their own review cycles, progress markers, and deadlines. Some follow a global calendar shared by thousands of learners worldwide; others are self-paced.

Most people track this with spreadsheets, paper, or memory. It breaks.

Learning Tracker turns large-scale learning goals into a clear daily plan. You choose what to study, set your pace, and the app tells you what to do today — including what needs review and when.

### Who uses it

- **Children** (ages 10–13): daily structure and motivation with points, streaks, mystery rewards, plus a PIN-protected parent dashboard.
- **Adults**: self-directed learners, clean progress tracking without gamification.
- **Parents**: configure and monitor their child's learning.

### Jewish learning concepts

| Term                  | Hebrew | Meaning                                                                                                                                |
| --------------------- | ------ | -------------------------------------------------------------------------------------------------------------------------------------- |
| **Chazara**           | חזרה   | Review. You don't read something once — you review it on a structured cycle to retain it. This is the app's core scheduling challenge. |
| **Sefaria**           | —      | An [open-source library](https://www.sefaria.org) of Jewish texts. The app's content source — every learnable item has a `sefariaRef`. |
| **Shabbos / Shabbat** | שבת    | The Jewish Sabbath. Many learners use Shabbos as a weekly review day.                                                                  |
| **Siyum**             | סיום   | Completion celebration — finishing an entire unit. Tracked in the learning ledger.                                                     |

**Programs** (Daf Yomi, Dirshu, Oraysa) are global study schedules where thousands of people learn the same material on the same day, following a fixed calendar.

### The curricula

The app supports nine curricula grouped into four categories. All content is sourced from Sefaria and bundled with the app — no internet connection required at runtime.

**Biblical Texts** (`CurriculumId`s: `chumash`, `nach`, `tanach`)

- **Chumash** (חומש) — Five Books of Moses. ~5,845 verses. Hierarchy: Sefer → Parsha → Perek → Pasuk.
- **Nach** (נ"ך) — Prophets and Writings. Hierarchy: Section → Sefer → Perek → Pasuk.
- **Tanach** (תנ"ך) — The complete Hebrew Bible as a single curriculum (Torah + Nevi'im + Ketuvim). Same hierarchy as Nach.

**Oral Law** (`CurriculumId`s: `mishnayos`, `bavli`, `yerushalmi`)

- **Mishnayos** (משניות) — The Mishnah, ~200 CE. 6 sedarim, 63 tractates, ~4,192 mishnayos. Hierarchy: Seder → Masechta → Perek → Mishna.
- **Talmud Bavli** (תלמוד בבלי) — Babylonian Talmud, ~2,711 dapim. Hierarchy: Masechta → Daf → Amud.
- **Talmud Yerushalmi** (תלמוד ירושלמי) — Jerusalem Talmud. Hierarchy: Masechta → Daf → Halacha.

**Law Codes** (`CurriculumId`s: `mishna_berurah`, `mishneh_torah`)

- **Mishna Berurah** (משנה ברורה) — Practical Jewish law guide, early 1900s. 697 simanim. Hierarchy: Siman → Se'if → Se'if Katan.
- **Mishneh Torah** (משנה תורה) — Maimonides' 12th-century code of Jewish law. 14 books. Distinct from Torah/Chumash — despite the name, this is a medieval legal code, not the Pentateuch.

**Ethics and Character** (`CurriculumId`: `mussar`)

- **Mussar** (מוסר) — Ethical literature genre. Hierarchy: Sefer → Section → Chapter.

> **Authoritative list:** 9 curricula, per `CurriculumId` enum in `lib/core/enums/curriculum_id.dart`.

### Tracks (the core domain unit)

A **track** is the atomic unit of the app. Everything hangs off it.

A track is a named, independent learning instance within a curriculum. It represents one context in which a person is learning one body of text.

| Property              | Description                                                                        |
| --------------------- | ---------------------------------------------------------------------------------- |
| **Type**              | `personal` (default, mandatory), `school` or `tutor` (optional, parent-activated). |
| **Label**             | User-provided name (e.g., "Daf Yomi", "My Mishnayos").                             |
| **Curriculum**        | Which body of text this track covers.                                              |
| **Scope**             | Optional subset (e.g., only Masechta Berachos within Bavli).                       |
| **Program**           | Optional global calendar (e.g., Daf Yomi).                                         |
| **Bookmark**          | Current position in the learning sequence.                                         |
| **Goals**             | Deadline, target completion percentage, study days.                                |
| **Stage definitions** | Chazara (review) schedule configuration.                                           |
| **Points**            | Accumulated score (child mode only).                                               |
| **Streak**            | Consecutive-day learning counter.                                                  |

A user can have multiple tracks within the same curriculum, distinguished by label. Content items can appear in multiple tracks simultaneously; each track independently schedules its own chazara.

**School and Tutor tracks** are supported in the database and in parent-mode's track management screen, but they're not promoted in the v1 onboarding flow. The default user flow creates a single `personal` track per active curriculum. See [`docs/_archive/scrapped-ideas/school-and-tutor-tracks.md`](_archive/scrapped-ideas/school-and-tutor-tracks.md) for the original three-track PRD design and why it was deprioritized from active promotion.

### Programs

A **program** is a global, calendar-based study schedule shared by learners worldwide. Optionally attached to a track.

| Program      | Curriculum     | Description                                                             |
| ------------ | -------------- | ----------------------------------------------------------------------- |
| **Daf Yomi** | Bavli          | One folio page of Talmud per day. ~7.5 years. The most widely followed. |
| **Dirshu**   | Mishna Berurah | Structured study with periodic tests.                                   |
| **Oraysa**   | Bavli          | Alternative Talmud study program.                                       |

Programs define _what_ to learn each day. Users can layer the app's chazara system on top. Program calendars are bundled with the app.

### Scheduling and chazara

Each track has configurable **stages**. The default:

| Stage | Name      | Delay                  |
| ----- | --------- | ---------------------- |
| 0     | Learn     | —                      |
| 1     | Chazara 1 | 1 day after Learn      |
| 2     | Chazara 2 | 7 days after Chazara 1 |

Users customize per curriculum: add stages (up to 10), rename, adjust delays.

**Schedule types** (one per curriculum):

| Type                      | How it works                                                                         |
| ------------------------- | ------------------------------------------------------------------------------------ |
| **Delay**                 | Review item X days after the previous stage. Classic spaced repetition. Core engine. |
| **Friday/Shabbos Review** | Weekly consolidation layered on top of delay-based chazara.                          |
| **Shabbos Review**        | Same idea, single review day.                                                        |

Priority when the scheduler builds a day's tasks:

1. Overdue chazara
2. Scheduled chazara due today
3. Weekly review (Friday/Shabbos layer)
4. New learning

### Adult mode vs child mode

| Aspect                  | Adult           | Child                                          |
| ----------------------- | --------------- | ---------------------------------------------- |
| **Configuration**       | Self-managed    | Parent-managed (PIN-protected)                 |
| **Gamification**        | None            | Points, streaks, mystery rewards, celebrations |
| **UI tone**             | Clean, minimal  | Animated, playful                              |
| **Completion feedback** | Subtle snackbar | Points popup, celebration                      |
| **Parent dashboard**    | N/A             | PIN-protected analytics and reward management  |

### Daily tracking loop

1. Open app → Dashboard shows today's tasks across tracks.
2. Pick from recommended tasks or browse curriculum manually.
3. Read Hebrew/English text from bundled Sefaria content.
4. Mark complete — transaction writes to `completions` and `learning_ledger`, advances bookmark, recalculates chazara, triggers sync enqueue.
5. Child mode: points popup, celebration, possible reward reveal. Adult mode: subtle confirmation.

All writes hit local SQLite immediately. Offline writes queue for sync; the app is fully functional without internet.

---

## Part 2 — Setup and Workflow

### Prerequisites

- **Flutter SDK** 3.38.6+ (stable channel)
- **Dart** 3.10.8+
- **Android SDK** (API 21+, Android 5.0+)
- **Git**
- **FlutterFire CLI** (only if regenerating Firebase config)

### First-time setup

```bash
git clone https://github.com/dniasoff/learning-tracker.git
cd learning-tracker/learning_tracker
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

### Editor setup

**Android Studio** — install the Flutter and Dart plugins. Create an API 21+ emulator.

**VS Code** — install Dart, Flutter, Flutter Riverpod Snippets, Drift DB Viewer, Error Lens.

Recommended `.vscode/settings.json` (not checked in):

```json
{
  "dart.lineLength": 80,
  "editor.formatOnSave": true,
  "[dart]": {
    "editor.defaultFormatter": "Dart-Code.dart-code"
  }
}
```

### Firebase configuration

Firebase project: **torah-study-tracker**.

Required files:

- Android: `google-services.json` in `learning_tracker/android/app/`.
- `lib/firebase_options.dart` is generated by FlutterFire CLI. Regenerate only if project configuration changes: `flutterfire configure --project=torah-study-tracker`.

Services used:

| Service          | Purpose                             |
| ---------------- | ----------------------------------- |
| Firebase Auth    | Email/password + Google Sign-In     |
| Cloud Firestore  | Cloud sync                          |
| Firebase Storage | Remote content delivery             |
| Firebase Hosting | Firestore security rules deployment |

Local development falls back to bundled content if Firebase is unavailable.

### Key Make targets

| Target                  | Description                                          |
| ----------------------- | ---------------------------------------------------- |
| `make test-story-X.Y`   | Run one story's tests (e.g., `make test-story-1.1`). |
| `make test-epic-N`      | Run all stories in an epic.                          |
| `make test-all-stories` | Full acceptance suite.                               |
| `make analyze`          | `dart analyze --fatal-infos`.                        |
| `make format-check`     | `dart format` dry-run.                               |
| `make ci`               | Analyze + format + all stories (full CI locally).    |

### Code generation

Generators used: Drift, auto_route, freezed, riverpod_generator, json_serializable.

```bash
dart run build_runner build --delete-conflicting-outputs
# Or, for continuous generation:
dart run build_runner watch --delete-conflicting-outputs
```

Generated files (`.g.dart`, `.freezed.dart`) are gitignored — never edit them manually.

### Testing strategy

- **Unit tests** — pure logic (services, utilities, domain models).
- **Widget tests** — UI components with mocked dependencies.
- **Integration tests** — cross-feature flows on in-memory databases.
- **Acceptance tests** — story-based, organized by epic.

Infrastructure: in-memory Drift, Mocktail (not Mockito), fixtures in `test/fixtures/`, helpers in `test/helpers/`.

Story-based TDD loop:

1. Implement.
2. `make test-story-X.Y` — verify the story passes.
3. `make test-epic-N` — verify no regressions in the epic.
4. `make ci` — full validation before pushing.

Coverage targets: Core ≥ 80%, Domain ≥ 80%, Data ≥ 70%, Presentation ≥ 60%.

### Git workflow

- Branch from `dev`.
- Conventional commits: `feat:`, `fix:`, `refactor:`, `test:`, `docs:`, etc.
- `make ci` must pass before opening a PR.

### Pre-commit hook

Runs `dart format` and `dart analyze` on staged `.dart` files. Commit is blocked on failure — fix and re-commit.

### CI/CD

- `ci.yml` — format check, static analysis, tests, coverage. Runs on every push/PR.
- `build.yml` — release APK build (manual trigger).

Both run against `dev` as the primary integration branch.

---

## Part 3 — Common Tasks

### Add a new feature module

1. Create under `lib/features/<feature_name>/` with three layers:

   ```
   data/           # Repositories, data sources, DTOs
   domain/         # Entities, use cases, repository interfaces
   presentation/   # Screens, widgets, providers
   ```

2. Define domain interfaces first. Implement data, then presentation.
3. Register routes in `lib/core/navigation/app_router.dart`.
4. Dependency rule: presentation → domain, data implements domain, **features never import other features**.
5. Run `dart run build_runner build --delete-conflicting-outputs`.

### Add a new database table

1. Create the table in `lib/core/database/tables/<table>.dart`:

   ```dart
   import 'package:drift/drift.dart';

   class MyNewTable extends Table {
     IntColumn get id => integer().autoIncrement()();
     TextColumn get name => text()();
     DateTimeColumn get createdAt => dateTime()();
   }
   ```

2. Create the DAO in `lib/core/database/daos/<table>_dao.dart` with `@DriftAccessor`.
3. Register both in `lib/core/database/app_database.dart` (`@DriftDatabase(tables: [...], daos: [...])`).
4. Run `dart run build_runner build --delete-conflicting-outputs`.
5. Increment `schemaVersion` in the relevant database file — User DB is currently **v4** (`lib/core/database/user/user_database.dart`), Content DB **v3**, Device Registry DB **v1**.
6. Add a migration block in the `migration` getter.

### Add a new screen

1. Create screen in `lib/features/<feature>/presentation/screens/<screen>_screen.dart` with `@RoutePage()`.
2. Register in `app_router.dart` as `AutoRoute(page: MyNewRoute.page, path: 'my-new')`.
3. Apply guards (auth, profile, PIN) if the screen requires them.
4. Run build_runner.

### Add a new Riverpod provider

1. Create in `lib/features/<feature>/presentation/providers/<name>.dart` with `@riverpod`.
2. Run build_runner.
3. Use via `ref.watch(myProviderProvider)`.

> **Known gotcha:** Providers returning `Map<K, V>` require hand-authored `.g.dart`. See [Troubleshooting](#part-5--troubleshooting).

---

## Part 4 — Coding Standards

Full rules live in [`coding-standards.md`](../coding-standards.md). The non-negotiables:

1. **Use `AsyncValue`, not custom state classes.** All async state in providers uses Riverpod's `AsyncValue<T>`.
2. **`DateTime` MUST use UTC.** Store and compare in UTC; convert to local only at display.
3. **NEVER mutate state.** All models are `freezed` with `copyWith`.
4. **Database writes MUST use transactions** when touching multiple tables.
5. **NEVER import between features.** Features communicate through core providers and shared domain interfaces.
6. **NEVER commit generated files.** `.g.dart` and `.freezed.dart` are gitignored (with a small number of hand-authored exceptions).
7. **Completion records are append-only.** Completions cannot be deleted or unmarked.

Clean code principles: Boy Scout Rule, single responsibility, meaningful names, small functions, DRY.

XP practices: simple design, FIRST tests (Fast, Isolated, Repeatable, Self-validating, Timely), continuous refactoring, incremental design.

---

## Part 5 — Troubleshooting

### `build_runner` fails with conflicting outputs

```bash
dart run build_runner build --delete-conflicting-outputs
# If still failing:
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```

### Code generation produces stale output

1. Delete `.dart_tool/build`.
2. `flutter pub get`.
3. Re-run build_runner.

### Drift migration errors at runtime

1. Verify `schemaVersion` matches the latest migration step in the relevant database file: `user_database.dart` (User DB), `content_database.dart` (Content DB), `device_registry_database.dart` (Device Registry).
2. Check every schema bump has a corresponding migration block.
3. For dev only: uninstall and reinstall to start with a fresh DB. That **confirms** the migration is at fault; it does not fix it.

### `auto_route` generation fails

1. Every screen widget has `@RoutePage()`.
2. Screen class name ends with `Screen`.
3. No circular imports between the screen file and the router.

### Analyzer reports errors in generated files

Always run a full build before trusting analyzer output:

```bash
dart run build_runner build --delete-conflicting-outputs
dart analyze
```

### Tests fail with "database is closed"

A test is reusing a DB after it's been disposed. Each test creates its own in-memory DB — use the helpers in `test/helpers/`.

### `flutter pub get` fails with dependency conflicts

`flutter pub upgrade` resolves transitive conflicts. If that fails, check `pubspec.yaml` for overly strict version constraints.

### Providers returning `Map<K, V>` require hand-authored `.g.dart`

Riverpod's generator does not support Map return types. The file `lib/features/progress/presentation/providers/progress_providers.g.dart` is manually written. Do not regenerate it. If you modify `progress_providers.dart`, update the `.g.dart` by hand to match.

---

For data model details, see [`data-models.md`](data-models.md). For architecture, see [`architecture.md`](architecture.md). For test patterns, see [`testing-guide.md`](testing-guide.md) and [`planning/testing-quick-reference.md`](planning/testing-quick-reference.md).

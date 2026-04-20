# Learning Tracker — Flutter App

Multi-curriculum Torah learning tracker for daily study management. Part of the [learning-tracker](../README.md) project — see the root README for the product overview.

This sub-repo is the Flutter application. For project-wide docs, start at [`docs/index.md`](../docs/index.md).

## Features

- **9 Curricula**: Mishnayos, Gemara Bavli, Talmud Yerushalmi, Mishna Berurah, Mishneh Torah, Chumash, Nach, Tanach, Mussar
- **Multi-stage Learning**: Learn → Chazara 1 → Chazara 2 (configurable up to 10 stages per curriculum)
- **User Modes**: Child (gamified, parent-managed) and Adult (self-directed)
- **Smart Scheduling**: Per-track daily task generation with pace tracking
- **Multi-track**: `personal` (default), `school`, `tutor` (parent-activated)
- **Offline-first**: Full functionality without network; cloud sync for `cloudBorn` accounts

## Tech Stack

- **Framework**: Flutter 3.38.6+ / Dart 3.10.8+
- **State Management**: Riverpod 3.x (with code generation)
- **Navigation**: auto_route 11.x
- **Databases**: Drift (SQLite) — three databases: User DB v4, Content DB v3, Device Registry DB v1
- **Backend**: Firebase Auth + Firestore + Storage (tier-gated for `cloudBorn` users)
- **Calendar**: kosher_dart (Hebrew dates)
- **Logging**: Talker
- **Testing**: mocktail, flutter_test, integration_test

## Getting Started

### Prerequisites

- Flutter SDK 3.38.6+
- Dart SDK 3.10.8+
- Android Studio or VS Code
- Git

### Installation

```bash
git clone https://github.com/dniasoff/learning-tracker.git
cd learning-tracker/learning_tracker

flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

## Development

### Running tests

```bash
# From repo root — story-based acceptance suite
make ci                       # full local CI
make test-story-X.Y           # individual story
make test-epic-N              # all stories in an epic

# From learning_tracker/ — raw Flutter commands
flutter test                   # unit + widget tests
flutter test --coverage        # with coverage
flutter test integration_test  # integration tests (needs emulator)
```

### Code quality

```bash
dart format .
dart analyze --fatal-infos
```

### Pre-commit hook

```bash
# From repo root
cp hooks/pre-commit .git/hooks/
chmod +x .git/hooks/pre-commit
```

Runs `dart format --set-exit-if-changed` and `dart analyze --fatal-infos`.

### Code generation

```bash
# One-shot
dart run build_runner build --delete-conflicting-outputs

# Watch mode
dart run build_runner watch --delete-conflicting-outputs
```

Generators used: drift, auto_route, freezed, riverpod_generator, json_serializable.

## Testing

### Structure

```text
test/
├── mocks/              # Shared mock repositories and services (mocktail)
├── fixtures/           # Test data factories
├── helpers/            # Test utilities (in-memory database helper)
├── core/               # Core infrastructure tests
├── features/           # Feature-specific tests
├── story_acceptance/   # Per-epic acceptance suites (file per epic)
├── integration/        # End-to-end flows
└── golden/             # UI snapshot tests

integration_test/       # On-device end-to-end tests
```

### Coverage targets

| Layer | Target |
|---|---|
| `lib/core/` | ≥ 80% |
| `lib/features/*/domain/` | ≥ 80% |
| `lib/features/*/data/` | ≥ 70% |
| `lib/features/*/presentation/` | ≥ 60% |

## CI/CD

GitHub Actions pipelines:

- **CI** (every PR to `dev`): format check, static analysis, unit/widget tests, coverage upload.
- **Build** (manual trigger): signed release APK.

Simulate locally with `make ci` from the repo root.

## Architecture

See [`docs/architecture.md`](../docs/architecture.md) for the current-state architecture, and [`docs/planning/architecture-quick-reference.md`](../docs/planning/architecture-quick-reference.md) for key decisions and patterns.

Key patterns:

- **D1** — Generic 4-level content hierarchy (single table for all curricula)
- **D4** — Hybrid push/pull sync with foreground listeners (tier-gated per v2)
- **P2** — Nullable returns for repository pattern
- **P3** — Curriculum-scoped and track-scoped Riverpod family providers
- **P5** — UTC storage, local display for dates

## Project structure

```text
lib/
├── core/               # Cross-cutting concerns
│   ├── database/       # Drift: User DB, Content DB, Device Registry DB
│   ├── navigation/     # auto_route + guards
│   ├── network/        # Sefaria client (dev-time), connectivity
│   ├── providers/      # Core Riverpod providers
│   └── services/       # Cross-curriculum services
└── features/           # 18 feature modules
    ├── auth/
    ├── content_browsing/
    ├── dashboard/
    ├── gamification/
    ├── learning/
    ├── learning_order/
    ├── notifications/
    ├── onboarding/
    ├── parent_mode/
    ├── profiles/
    ├── progress/
    ├── scheduler/
    ├── settings/
    ├── stages/
    ├── sync/
    ├── test_tracking/
    ├── track_setup/
    └── tutor_mode/
```

## Contributing

1. Branch from `dev`.
2. `make ci` must pass before opening a PR.
3. PR against `dev`.

## License

MIT — see [`../LICENSE`](../LICENSE).

## Resources

- [Documentation index](../docs/index.md)
- [Developer handbook](../docs/developer-handbook.md)
- [Architecture quick reference](../docs/planning/architecture-quick-reference.md)
- [Testing quick reference](../docs/planning/testing-quick-reference.md)

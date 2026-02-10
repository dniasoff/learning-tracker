# Torah Learning Tracker

[![CI](https://github.com/YOUR_ORG/YOUR_REPO/actions/workflows/ci.yml/badge.svg)](https://github.com/YOUR_ORG/YOUR_REPO/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/YOUR_ORG/YOUR_REPO/branch/main/graph/badge.svg)](https://codecov.io/gh/YOUR_ORG/YOUR_REPO)

Multi-curriculum Torah learning tracker for daily study management. Supports Mishnayos, Gemara Bavli, Talmud Yerushalmi, Mishna Berurah, and Chumash.

## Features

- **5 Curricula**: Mishnayos, Bavli, Yerushalmi, Mishna Berurah, Chumash
- **Multi-stage Learning**: Learn → Chazara 1 → Chazara 2 (customizable)
- **User Modes**: Child (gamified, parent-managed) & Adult (self-directed)
- **Smart Scheduling**: Automated daily task generation with pace tracking
- **Multi-track**: Personal, school, and tutor tracks
- **Offline-first**: Full functionality offline with cloud sync

## Tech Stack

- **Framework**: Flutter 3.29.4, Dart 3.10.8
- **State Management**: Riverpod 3.x
- **Navigation**: auto_route 11.x
- **Database**: drift (SQLite ORM)
- **Backend**: Firebase Auth + Firestore
- **Logging**: Talker
- **Testing**: mocktail, integration_test

## Getting Started

### Prerequisites

- Flutter SDK 3.29.4+
- Dart SDK 3.10.8+
- Android Studio / VS Code
- Git

### Installation

```bash
# Clone the repository
git clone https://github.com/YOUR_ORG/YOUR_REPO.git
cd YOUR_REPO/learning_tracker

# Install dependencies
flutter pub get

# Run code generation (for drift, auto_route, freezed, riverpod)
dart run build_runner build --delete-conflicting-outputs

# Run the app
flutter run
```

## Development

### Running Tests

```bash
# Run all unit and widget tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run specific test file
flutter test test/core/database/app_database_test.dart

# Run integration tests (requires Android emulator or device)
flutter test integration_test
```

### Code Quality

```bash
# Format code
dart format .

# Analyze code
dart analyze

# Check for unused files
dart run dependency_validator
```

### Pre-commit Hook

Install the pre-commit hook to automatically check formatting and analysis before each commit:

```bash
# From repository root
cd ..  # Go to repo root if in learning_tracker/
cp hooks/pre-commit .git/hooks/
chmod +x .git/hooks/pre-commit
```

The hook runs:
- `dart format --set-exit-if-changed .`
- `dart analyze --fatal-infos`

### Code Generation

This project uses code generation for:
- **drift**: Database DAOs and queries
- **auto_route**: Navigation routing
- **freezed**: Immutable data classes
- **riverpod**: Provider code generation

Run code generation after modifying annotated files:

```bash
# Watch mode (auto-regenerate on file changes)
dart run build_runner watch --delete-conflicting-outputs

# One-time generation
dart run build_runner build --delete-conflicting-outputs
```

## Testing

### Test Structure

```
test/
├── mocks/              # Shared mock repositories and services (mocktail)
├── fixtures/           # Test data factories (content, completion, curriculum)
├── helpers/            # Test utilities (in-memory database helper)
├── core/               # Core infrastructure tests
└── features/           # Feature-specific tests

integration_test/       # End-to-end tests on real devices/emulators
```

### Test Patterns

**Unit Tests**: Test business logic in isolation with mocks
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:learning_tracker/test/mocks/mock_repositories.dart';

void main() {
  late MockAuthRepository mockRepo;

  setUp(() {
    mockRepo = MockAuthRepository();
  });

  test('example test', () async {
    when(() => mockRepo.getCurrentUser()).thenAnswer((_) async => null);
    // ... test logic
  });
}
```

**Widget Tests**: Test UI components
```dart
testWidgets('displays curriculum card', (tester) async {
  await tester.pumpWidget(MyWidget());
  expect(find.text('Mishnayos'), findsOneWidget);
});
```

**Integration Tests**: Test complete flows
```dart
testWidgets('user can sign in and mark completion', (tester) async {
  app.main();
  await tester.pumpAndSettle();
  // ... interaction logic
});
```

### Coverage Goals

- Core (`lib/core/`): ≥80%
- Domain (`lib/features/*/domain/`): ≥80%
- Data (`lib/features/*/data/`): ≥70%
- Presentation (`lib/features/*/presentation/`): ≥60%

## CI/CD

### GitHub Actions

**CI Workflow** (runs on every PR to main):
- Format check (`dart format --set-exit-if-changed`)
- Static analysis (`dart analyze --fatal-infos`)
- Unit and widget tests (`flutter test --coverage`)
- Integration tests (Android emulator)
- Coverage upload to Codecov

**Build Workflow** (manual trigger):
- Builds signed release APK
- Uploads APK as artifact

### Running CI Locally

Simulate CI checks before pushing:

```bash
# Format check
dart format --set-exit-if-changed .

# Analysis
dart analyze --fatal-infos

# Tests
flutter test --coverage

# Integration tests (requires emulator)
flutter test integration_test
```

## Architecture

See [architecture documentation](../_bmad-output/planning-artifacts/architecture-quick-reference.md) for detailed architecture decisions, patterns, and project structure.

**Key Patterns**:
- **D1**: Generic 4-level content hierarchy (single table for all curricula)
- **D2**: Firebase Auth with email/password + Google Sign-In
- **D4**: Hybrid push/pull sync with foreground listeners
- **P2**: Nullable returns for repository pattern
- **P3**: Curriculum-scoped Riverpod family providers
- **P5**: UTC storage, local display for dates

## Project Structure

```
lib/
├── core/               # Cross-cutting concerns
│   ├── database/       # Drift database, DAOs, tables
│   ├── navigation/     # auto_route, guards
│   ├── network/        # Sefaria API client, connectivity
│   ├── providers/      # Core Riverpod providers
│   └── services/       # Cross-curriculum services
└── features/           # Feature modules
    ├── auth/           # Authentication
    ├── content/        # Content browsing, import
    ├── learning/       # Mark completion, history
    ├── scheduler/      # Smart scheduling, daily tasks
    └── ...
```

## Contributing

1. Create a feature branch from `main`
2. Make your changes
3. Ensure tests pass: `flutter test`
4. Ensure code quality: `dart analyze && dart format .`
5. Create a pull request to `main`

CI must pass before merge.

## License

[Add license information]

## Resources

- [Architecture Quick Reference](../_bmad-output/planning-artifacts/architecture-quick-reference.md)
- [Testing Quick Reference](../_bmad-output/planning-artifacts/testing-quick-reference.md)
- [Project Context](../_bmad/bmm/data/project-context-template.md)

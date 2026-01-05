# Story 1.1: Initialize Flutter Project with Architecture Foundations

Status: ready-for-dev

## Story

As a developer,
I want the Flutter project initialized with all architectural foundations (clean architecture structure, state management, navigation, logging),
so that the codebase follows the defined architecture patterns and is ready for feature development.

## Acceptance Criteria

**Given** the project initialization command from architecture document
**When** I run `flutter create --org com.niasoff.mishnayos --platforms=android --android-language kotlin mishnayos_tracker`
**Then** the Flutter project is created with Android-only configuration and Kotlin native code

**And** the feature-first folder structure is created with all core directories (database, navigation, logging, theme, auth, network, utils, constants, providers)

**And** `pubspec.yaml` includes all required dependencies with specified versions (drift, auto_route, riverpod, freezed, dio, talker, firebase, kosher_dart, etc.)

**And** `build.yaml` is configured for build_runner code generation

**And** `analysis_options.yaml` is configured with strict linting rules

**And** `.gitignore` includes generated files (*.g.dart, *.freezed.dart, *.gr.dart)

**And** `config/dev.json` and `config/prod.json` template files are created

**And** Material Design 3 theme is configured with RTL support for Hebrew

**And** Talker logging is configured in providers

**And** the project builds successfully with `flutter run`

## Tasks / Subtasks

- [ ] Initialize Flutter project with specified command (AC: 1)
  - [ ] Run `flutter create --org com.niasoff.mishnayos --platforms=android --android-language kotlin mishnayos_tracker`
  - [ ] Verify Android-only platform, Kotlin native code

- [ ] Create feature-first folder structure (AC: 2)
  - [ ] Create `lib/features/` directory
  - [ ] Create `lib/core/` with subdirectories (database, navigation, logging, theme, auth, network, utils, constants, providers)
  - [ ] Set up placeholder feature directories for all 11 epics

- [ ] Configure pubspec.yaml with all dependencies (AC: 3)
  - [ ] Add drift ^2.30.0, drift_dev ^2.30.0
  - [ ] Add auto_route ^9.3.0+1, auto_route_generator ^9.3.0
  - [ ] Add flutter_riverpod ^3.1.0, riverpod_generator ^4.0.0, riverpod_annotation ^3.0.3
  - [ ] Add freezed ^3.2.3, freezed_annotation, json_serializable
  - [ ] Add dio ^5.9.0
  - [ ] Add talker (latest 4.x-5.x), talker_flutter, talker_dio_logger, talker_riverpod_logger
  - [ ] Add Firebase packages (firebase_core, firebase_auth, cloud_firestore)
  - [ ] Add flutter_secure_storage, flutter_local_notifications, connectivity_plus
  - [ ] Add kosher_dart
  - [ ] Add build_runner to dev_dependencies
  - [ ] Add mocktail to dev_dependencies

- [ ] Configure build.yaml for build_runner (AC: 4)
  - [ ] Create build.yaml with configuration for drift, auto_route, freezed, riverpod_generator

- [ ] Configure analysis_options.yaml with strict linting (AC: 5)
  - [ ] Set up Flutter lints package
  - [ ] Configure strict analysis rules
  - [ ] Set line length to 80

- [ ] Create .gitignore with generated files (AC: 6)
  - [ ] Add *.g.dart, *.freezed.dart, *.gr.dart patterns
  - [ ] Add standard Flutter ignore patterns
  - [ ] Add config files to ignore (config/dev.json, config/prod.json)

- [ ] Create config file templates (AC: 7)
  - [ ] Create config/ directory
  - [ ] Create config/dev.json.example with Firebase config structure
  - [ ] Create config/prod.json.example with Firebase config structure
  - [ ] Document how to use --dart-define-from-file

- [ ] Configure Material Design 3 theme with RTL support (AC: 8)
  - [ ] Create lib/core/theme/app_theme.dart with Material 3 theme
  - [ ] Create lib/core/theme/colors.dart
  - [ ] Create lib/core/theme/typography.dart
  - [ ] Create lib/core/theme/rtl_config.dart for Hebrew RTL support

- [ ] Configure Talker logging in providers (AC: 9)
  - [ ] Create lib/core/logging/talker_config.dart
  - [ ] Create lib/core/providers/talker_provider.dart with Riverpod provider
  - [ ] Set up talker_dio_logger integration
  - [ ] Set up talker_riverpod_logger integration

- [ ] Verify project builds successfully (AC: 10)
  - [ ] Run `flutter pub get`
  - [ ] Run `flutter analyze` (0 issues)
  - [ ] Run `flutter run --dart-define-from-file=config/dev.json` (builds successfully)

## Dev Notes

### Epic Context
This is Story 1.1 of Epic 1 "Project Foundation & Data Infrastructure". This story creates the foundational project structure that all subsequent stories (1.2-1.6 and all other epics) will build upon. **Without this story, no other development can proceed.**

Epic 1 establishes:
- Flutter project with clean architecture
- Database infrastructure (drift SQLite)
- Firebase backend integration
- Hebrew calendar support
- All 4,192 Mishnayos seeded

### Why This Story is Critical
This is the **most important story in the entire project**. It defines:
- Project structure that prevents agent conflicts
- Type-safe code generation stack (drift, auto_route, freezed, riverpod)
- Naming conventions across all layers
- Build and development workflow
- Logging and error tracking foundation

**A mistake here multiplies across ALL future stories.**

### Architecture Patterns and Constraints

**Clean Architecture with Feature-First Organization:**
- Features in `lib/features/<feature_name>/{data,domain,presentation}`
- Shared code in `lib/core/`
- Inner layers NEVER depend on outer layers
- Domain layer has NO dependencies (pure business logic)

**Type-Safe Code Generation Stack:**
All use unified build_runner:
- **drift**: Type-safe SQL queries with compile-time validation
- **auto_route**: Type-safe navigation with compile-time route validation
- **freezed**: Immutable data classes with copyWith
- **riverpod_generator**: Type-safe DI with @riverpod annotation

**Critical Naming Conventions:**
- SQL (drift tables): `snake_case` (e.g., `mishna_completions`, `completed_at`)
- Dart files: `snake_case` (e.g., `mishna_repository.dart`)
- Dart classes: `PascalCase` (e.g., `MishnaRepository`)
- Dart functions/methods: `camelCase` (e.g., `getMishna()`)
- JSON/Firestore fields: `camelCase` (e.g., `mishnaId`, `completedAt`)
- Route paths: `kebab-case` (e.g., `/mishna-browsing`)
- Riverpod providers: noun-based `camelCase` (e.g., `mishnaRepository` generates `mishnaRepositoryProvider`)

**DateTime Handling:**
- ⚠️ **CRITICAL**: ALWAYS store DateTime in UTC, NEVER local time
- drift DateTimeColumn stores UTC
- Firestore Timestamp stores UTC
- Convert to local time ONLY in presentation layer for display

**State Management:**
- ✅ **ALWAYS** use AsyncValue for async operations
- ❌ **NEVER** create custom freezed state classes (Loading/Success/Error)
- Use `ref.watch()` for reading, `ref.read()` for mutations
- Use `ref.invalidate()` to refresh providers after mutations

**Code Generation Workflow:**
- ⚠️ **CRITICAL**: Run `dart run build_runner build --delete-conflicting-outputs` after ANY annotated file changes
- ✅ **NEVER** commit generated files (*.g.dart, *.freezed.dart, *.gr.dart)
- Generated files are in same directory as source
- Must run before testing or running app

### Project Structure Notes

**Complete Directory Structure:**
```
mishnayos_tracker/
├── lib/
│   ├── main.dart (app entry point with Firebase init)
│   ├── app.dart (root widget with ProviderScope)
│   ├── features/
│   │   ├── dashboard/
│   │   ├── mishna_browsing/
│   │   ├── progress_tracking/
│   │   ├── track_management/
│   │   ├── scheduler/
│   │   ├── gamification/
│   │   ├── parent_mode/
│   │   ├── tutor_mode/
│   │   ├── onboarding/
│   │   ├── notifications/
│   │   └── sync/
│   └── core/
│       ├── database/ (drift setup, tables, DAOs)
│       ├── navigation/ (auto_route setup, guards)
│       ├── logging/ (talker config, interceptors)
│       ├── theme/ (Material Design 3, RTL)
│       ├── auth/ (PIN validation, Firebase auth)
│       ├── network/ (dio client, connectivity)
│       ├── utils/ (extensions, helpers, formatters)
│       ├── constants/ (app constants, API constants)
│       └── providers/ (global Riverpod providers)
├── test/ (mirrors lib/ structure)
├── config/
│   ├── dev.json.example
│   └── prod.json.example
├── assets/
│   ├── fonts/ (Hebrew fonts)
│   └── images/
├── pubspec.yaml
├── build.yaml
├── analysis_options.yaml
└── .gitignore
```

**Feature Module Template:**
Each feature follows this pattern:
```
lib/features/<feature_name>/
├── data/
│   ├── models/ (freezed DTOs with json_serializable)
│   ├── repositories/ (repository implementations)
│   └── data_sources/ (drift DAOs, API clients, Firestore)
├── domain/
│   ├── entities/ (freezed domain models)
│   ├── repositories/ (repository interfaces)
│   └── use_cases/ (business logic)
└── presentation/
    ├── screens/ (full-page routes)
    ├── widgets/ (reusable UI components)
    └── providers/ (Riverpod providers for UI state)
```

### Library/Framework Requirements

**Flutter & Dart Versions:**
- Flutter: Latest stable (3.38.1+ as of Jan 2026)
- Dart SDK: ^3.7.0 (null-safe)
- Android: API 21+ minimum (Android 5.0 Lollipop)

**Core Dependencies with Rationale:**

**drift ^2.30.0 (+ drift_dev ^2.30.0):**
- Why: Type-safe SQL queries with compile-time validation prevent runtime errors
- Critical for: Zero data loss requirement (NFR11) - transactions with automatic rollback
- Features: Schema migrations, reactive streams, transaction support
- Integration: Works seamlessly with Riverpod watch queries

**auto_route ^9.3.0+1 (+ auto_route_generator ^9.3.0):**
- Why: Compile-time type-safe navigation catches routing errors early
- Critical for: AI-assisted development - compile-time errors prevent agent mistakes
- Features: Strongly-typed route arguments, route guards (PIN protection), deep linking
- Pattern: Use @AutoRouterConfig annotation on AppRouter class

**flutter_riverpod ^3.1.0 + riverpod_generator ^4.0.0 + riverpod_annotation ^3.0.3:**
- Why: Unified state management and DI - no need for separate get_it
- Critical for: Provider overrides enable testability (80%+ coverage requirement)
- Features: Type-safe providers, compile-time DI, reactive state, scoped dependencies
- Pattern: Use @riverpod annotation with noun-based naming

**freezed ^3.2.3 (+ freezed_annotation + json_serializable):**
- Why: Immutable data classes essential for Riverpod state correctness
- Critical for: copyWith pattern prevents direct mutation
- Features: Union types (for AsyncValue), deep equality, JSON serialization
- Pattern: Use `const factory` constructors

**dio ^5.9.0:**
- Why: Interceptors for global error handling, automatic retry logic
- Critical for: Sefaria API integration with graceful failure (NFR36)
- Features: Request/response transformation, timeout config, retry logic
- Integration: talker_dio_logger for automatic request logging

**talker ~4.x-5.x (+ talker_flutter + talker_dio_logger + talker_riverpod_logger):**
- Why: Comprehensive logging with built-in integrations saves setup time
- Critical for: Production error tracking (NFR16), in-app debugging during 3-year cycle
- Features: In-app log viewer, dio/riverpod auto-logging, log sharing
- Pattern: Use consistent log levels (debug, info, warning, error, critical)

**Firebase packages:**
- firebase_core: Firebase initialization
- firebase_auth: Anonymous Authentication for v1.0 (single-family use)
- cloud_firestore: Cloud backup and multi-device sync
- Why: Automatic backup ensures zero data loss, seamless device transfer

**flutter_secure_storage:**
- Why: Platform-specific secure storage (Android Keystore)
- Critical for: PIN encryption (NFR28-29)
- Usage: Store bcrypt-hashed PINs for parent/tutor modes

**flutter_local_notifications:**
- Why: Local scheduled notifications (no cloud messaging needed)
- Features: Daily reminders, streak protection alerts, reward notifications
- Usage: Android 13+ requires runtime permission

**connectivity_plus:**
- Why: Network state detection for offline-first sync
- Usage: Trigger background sync when connectivity restored

**kosher_dart:**
- Why: Hebrew calendar calculations for bar mitzvah tracking
- Critical for: Accuracy verified against Hebcal.com (NFR37)
- Usage: Track 19 Kislev 5789 (December 7, 2028) deadline

**Testing:**
- mocktail: Null-safe mocking, NO code generation needed
- Rationale: Reduces build_runner overhead (already heavy with drift/auto_route/freezed/riverpod)

### File Structure Requirements

**Development Workflow Files:**

**pubspec.yaml:**
- All dependencies with pinned versions (use ^ for compatible updates)
- Dev dependencies: build_runner, drift_dev, auto_route_generator, freezed, mocktail
- Assets: fonts, images

**build.yaml:**
```yaml
targets:
  $default:
    builders:
      drift_dev:
        enabled: true
      auto_route_generator:
        enabled: true
      freezed:
        enabled: true
      riverpod_generator:
        enabled: true
```

**analysis_options.yaml:**
```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    prefer_single_quotes: true
    always_use_package_imports: true
    avoid_print: true
```

**.gitignore:**
Must include:
```
# Code generation
*.g.dart
*.freezed.dart
*.gr.dart

# Config files with secrets
config/dev.json
config/prod.json

# Standard Flutter
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
.packages
build/
```

**config/dev.json.example and config/prod.json.example:**
```json
{
  "FIREBASE_API_KEY": "your_api_key_here",
  "FIREBASE_PROJECT_ID": "your_project_id",
  "FIREBASE_APP_ID": "your_app_id"
}
```

Usage: `flutter run --dart-define-from-file=config/dev.json`

### Testing Requirements

**Test Structure:**
- Mirror lib/ structure exactly in test/
- Create test/mocks/ for reusable mocktail mocks
- Create test/fixtures/ for test data factories

**Coverage Target:**
- 80%+ on domain layer (use cases, entities)
- 70%+ on data layer (repositories, data sources)
- Widget tests for critical UI flows
- Integration tests for end-to-end scenarios

**Testing Patterns:**
- Use mocktail for mocking (no codegen)
- Use Riverpod ProviderContainer with overrides
- Test AsyncValue states (loading/data/error)
- Dispose containers in tearDown

### Critical Don't-Miss Rules

**❌ ANTI-PATTERNS - NEVER DO THESE:**

1. **NEVER create custom state classes:**
```dart
// BAD
@freezed class DataState { Loading(), Success(data), Error(error) }

// GOOD
@riverpod Future<Data> data(...) async { return fetchData(); }
```

2. **NEVER mutate state directly:**
```dart
// BAD
myList.add(item);
entity.field = newValue;

// GOOD
final updated = entity.copyWith(field: newValue);
final newList = [...myList, item];
```

3. **NEVER store DateTime as local time:**
```dart
// BAD
final now = DateTime.now(); // Local time!

// GOOD
final now = DateTime.now().toUtc(); // UTC!
```

4. **NEVER skip build_runner:**
```dart
// After ANY changes to annotated files, MUST run:
dart run build_runner build --delete-conflicting-outputs
```

5. **NEVER import between feature modules:**
```dart
// BAD
import '../../mishna_browsing/data/repositories/mishna_repository.dart';

// GOOD
final repo = ref.watch(mishnaRepositoryProvider); // from core/providers
```

6. **NEVER commit generated files:**
```
# MUST be in .gitignore
*.g.dart
*.freezed.dart
*.gr.dart
```

### References

**Architecture Source:**
- [Source: _bmad-output/planning-artifacts/architecture.md]
  - Starter Template section (lines 192-316)
  - Core Architectural Decisions (lines 319-569)
  - Implementation Patterns (lines 571-1119)
  - Project Structure (lines 1130-1531)

**Project Context Source:**
- [Source: _bmad-output/planning-artifacts/project-context.md]
  - Critical Implementation Rules (lines 48-498)
  - Development Workflow (lines 270-337)
  - Anti-Patterns (lines 342-404)

**PRD Source:**
- [Source: _bmad-output/planning-artifacts/prd.md]
  - Technical Requirements (lines 300-310)
  - Platform Requirements (lines 516-547)
  - Performance NFRs (lines 857-873)

**Technology Version Research:**
- Flutter 3.38.1+ (Jan 2026): [Flutter SDK archive](https://docs.flutter.dev/install/archive)
- drift ^2.30.0: [drift package on pub.dev](https://pub.dev/packages/drift)
- auto_route ^9.3.0+1: [auto_route package](https://pub.dev/packages/auto_route)
- flutter_riverpod ^3.1.0 + riverpod_generator ^4.0.0: [riverpod packages](https://pub.dev/packages/flutter_riverpod)

## Dev Agent Record

### Agent Model Used

_To be filled by dev agent_

### Debug Log References

_To be filled by dev agent_

### Completion Notes List

_To be filled by dev agent - Document any decisions made, deviations from plan, or issues encountered_

### File List

_To be filled by dev agent - List all files created or modified during implementation_

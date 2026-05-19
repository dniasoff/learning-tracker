---
title: Coding Standards
description: Layering rules, file conventions, placement guide, and enforcement guidance for the Learning Tracker codebase.
date: 2026-05-13
---

# Coding Standards

This document is the authoritative reference for code style, structure, and layering discipline in the Learning Tracker Flutter application. It supplements the [Developer Handbook](developer-handbook.md) (Part 4) and the [Architecture](architecture.md) document.

## Table of Contents

- [Layering Rules](#layering-rules)
- [File Naming Conventions](#file-naming-conventions)
- [File Placement Guide](#file-placement-guide)
- [profileId-in-PK Invariant](#profileid-in-pk-invariant)
- [Enforcement — `make audit`](#enforcement--make-audit)
- [Custom Lints Reference](#custom-lints-reference)

---

## Layering Rules

The dependency direction is strictly `app → features → core`. These five rules are **invariants** — violations must never be committed. Each rule is enforced by a custom lint (pending DNI-386 / DNI-387 landing on `origin/dev`).

### Rule 1 — No `core/` → `features/` imports

`lib/core/` MUST NOT import anything from `lib/features/`.

Core is shared infrastructure (database, logging, navigation, theme, sync gateway, etc.). It cannot depend on feature business logic. Any data a core module needs from a feature must be provided via dependency injection (constructor parameter or Riverpod provider), not by importing the feature directly.

**Lint:** `no-feature-cross-import` (DNI-386)

**Quick grep (must return zero lines in CI):**
```bash
grep -r "import 'package:learning_tracker/features/" \
  lib/core/ --include="*.dart"
```

---

### Rule 2 — No cross-feature deep imports

`lib/features/X/` MUST NOT import directly from `lib/features/Y/<anything-other-than-providers.dart>`.

Features are independent vertical slices. The only permitted cross-feature reference is the feature's public surface file `lib/features/Y/providers.dart`. If that file does not exist yet, the importing feature must go through a core provider or core service instead.

**Lint:** `no-feature-cross-import` (DNI-386)

**Quick grep:**
```bash
# Find imports of one feature's internals from another feature.
# Allowlist: */providers.dart is the only permitted cross-feature import.
grep -rP "import 'package:learning_tracker/features/[^']+/(?!providers\.dart)[^']+'" \
  lib/features/ --include="*.dart" \
  | grep -v "import 'package:learning_tracker/features/\$SELF/"
```

---

### Rule 3 — Firebase symbols confined to auth and sync modules

`FirebaseAuth`, `FirebaseFirestore`, and `FirebaseStorage` MUST only appear inside:

- `lib/core/sync/` — Firestore gateway implementation
- `lib/features/auth/` — authentication repository and providers

All other code receives Firebase instances through injected Riverpod providers (`lib/core/providers/firebase_providers.dart`). No file outside these two trees may import `firebase_auth`, `cloud_firestore`, or `firebase_storage` packages directly.

**Lint:** `no-firebase-outside-core` (DNI-387)

**Quick grep:**
```bash
grep -r "import 'package:firebase_" \
  lib/ --include="*.dart" \
  | grep -v "lib/core/sync/\|lib/features/auth/\|lib/core/providers/firebase_providers"
```

---

### Rule 4 — Raw Talker confined to `core/logging/`

`package:talker/talker.dart` MUST only be imported inside `lib/core/logging/`.

All other code logs through `AppLogger` (`lib/core/logging/logger.dart`). Importing the raw `Talker` instance bypasses PII redaction, log-level filtering, and Crashlytics breadcrumb integration that `AppLogger` provides.

**Lint:** `no-raw-talker` (DNI-387)

**Quick grep:**
```bash
grep -r "import 'package:talker/talker.dart'" \
  lib/ --include="*.dart" \
  | grep -v "lib/core/logging/"
```

---

### Rule 5 — `.displayNameEn` / `.displayNameHe` confined to `core/labels/` and generated files

Direct access to `.displayNameEn` or `.displayNameHe` on `CurriculumId` or related enums MUST only appear in:

- `lib/core/labels/` — the canonical label layer
- Generated files (`*.g.dart`) — auto-generated code that references enum members

All presentation code MUST use `CurriculumLabelRenderer` (`lib/core/labels/curriculum_label_renderer.dart`), which resolves the correct locale-aware string and applies any display overrides. Bypassing it produces inconsistent labels and breaks Hebrew/English locale switching.

**Lint:** `no-curriculum-display-name-bypass` (DNI-386)

**Quick grep:**
```bash
grep -r "\.displayNameEn\|\.displayNameHe" \
  lib/ --include="*.dart" \
  | grep -v "lib/core/labels/\|\.g\.dart"
```

### Hebrew Terms and domainTermLabels

**Hebrew terms in UI widgets**: All presentation code that renders Jewish learning terms (stage names, masechet/perek/daf labels, חזרה, etc.) MUST use `domainTermLabels(ref)` from `lib/core/labels/domain_term_labels.dart`. Never access `HebrewTerms.*` directly in `lib/features/` — this is enforced by audit check 13. Widgets that need `domainTermLabels` must be `ConsumerWidget` or `ConsumerStatefulWidget`.

**Why:** `HebrewTerms.*` are raw constants that ignore the user's Hebrew-terms toggle. `domainTermLabels(ref)` reads `useHebrewTermsProvider` and returns the correct script (Hebrew ↔ transliteration) at runtime, including live re-render when the toggle changes mid-session.

**Audit check 13** (enforced by `make audit`) greps for direct `HebrewTerms.` references in `lib/features/` and fails CI if any are found. The only permitted call sites for `useHebrewTermsProvider` are `lib/core/labels/`, `lib/core/preferences/`, and settings screen files — all other code must go through `domainTermLabels(ref)`.

---

## File Naming Conventions

All Dart files use **snake_case**. The file suffix encodes its architectural role:

| Suffix | Role | Example |
|--------|------|---------|
| `_screen.dart` | Routable screen widget (annotated `@RoutePage()`) | `dashboard_screen.dart` |
| `_widget.dart` | Reusable non-routable widget | `streak_badge_widget.dart` |
| `_provider.dart` | Riverpod provider definitions | `completion_providers.dart` |
| `_repository.dart` | Repository interface (domain layer) | `completion_repository.dart` |
| `_repository_impl.dart` | Repository implementation (data layer) | `completion_repository_impl.dart` |
| `_dao.dart` | Drift DAO | `completion_dao.dart` |
| `_service.dart` | Domain or application service | `streak_service.dart` |
| `_notifier.dart` | Riverpod `Notifier` or `AsyncNotifier` subclass | `profile_notifier.dart` |
| `_model.dart` | Freezed value object / domain entity | `streak_snapshot_model.dart` |
| `_dto.dart` | Data Transfer Object (Firestore / JSON boundary) | `completion_dto.dart` |
| `_mapper.dart` | Converts between layers (DTO ↔ domain) | `completion_mapper.dart` |
| `_test.dart` | Test file | `completion_dao_test.dart` |
| `.g.dart` | Generated file — never edit by hand | `completion_providers.g.dart` |
| `.freezed.dart` | Freezed-generated file — never edit by hand | `streak_snapshot.freezed.dart` |

Additional conventions:

- **No abbreviations** in file names. `authentication_repository.dart`, not `auth_repo.dart`.
- **No `_utils.dart` god-files.** Each utility gets a focused name: `hebrew_calendar_utils.dart`, not `utils.dart`.
- **Acceptance test files** follow the pattern `epic_NN_<slug>_test.dart`. Story-level tests inside the file are tagged with `tags: ['story_NN_M']`.

---

## File Placement Guide

```
lib/
  main.dart                          — App entry point; minimal (wires providers + router)
  app.dart                           — MaterialApp + theme + locale; calls core providers

  core/                              — Shared infrastructure; no feature business logic
    analytics/                       — Analytics events and repository
    constants/                       — App-wide constants (no logic)
    content/                         — Content index and curriculum content loading
    database/                        — Drift database definitions, DAOs, migrations
      daos/                          — One DAO per table group
      tables/                        — Drift Table classes
      user_database.dart             — User DB (schema v1, schemaVersion managed here)
      content_database.dart          — Content DB
      device_registry_database.dart  — Device DB
    enums/                           — Shared enums (CurriculumId, etc.)
    exceptions/                      — Typed exception classes
    labels/                          — CurriculumLabelRenderer + curriculum_label.dart
    logging/                         — AppLogger, Crashlytics service (only Talker import)
    navigation/                      — AppRouter (auto_route)
    network/                         — Sefaria fetchers, HTTP utilities
    preferences/                     — SharedPreferences wrappers and keys
    providers/                       — Cross-cutting Riverpod providers (firebase_providers, etc.)
    services/                        — Cross-cutting application services (aggregators)
    streak/                          — Streak event log and reducer (pure domain logic)
    sync/                            — Firestore gateway interface + impl (only Firebase import)
    theme/                           — AppTheme, colour tokens
    time/                            — Clock abstraction (never use DateTime.now() directly)
    utils/                           — Focused utility files (hebrew_calendar_utils, etc.)
    widgets/                         — Shared UI widgets used by multiple features

  features/                          — One directory per product feature
    <feature_name>/
      data/                          — Repositories (impl), data sources, DTOs, mappers
      domain/                        — Entities, repository interfaces, use cases, services
      presentation/
        providers/                   — Riverpod providers for this feature
        screens/                     — Routable screen widgets
        widgets/                     — Feature-local widgets

test/
  story_acceptance/                  — One file per epic: epic_NN_<slug>_test.dart
  core/                              — Unit tests mirroring lib/core/ structure
  features/                          — Unit / widget tests for feature modules
  integration/                       — Cross-feature integration tests (in-memory DB)
  helpers/                           — TestDatabase, fixture builders
  fixtures/                          — Static JSON / Dart fixture data
  mocks/                             — Mocktail mock classes
```

### Where does a new file go?

| What you are adding | Where it lives |
|---------------------|----------------|
| New screen | `lib/features/<feature>/presentation/screens/<name>_screen.dart` |
| New widget shared across features | `lib/core/widgets/` |
| New widget used by one feature only | `lib/features/<feature>/presentation/widgets/` |
| New Riverpod provider | `lib/features/<feature>/presentation/providers/<name>_provider.dart` |
| New repository interface | `lib/features/<feature>/domain/repositories/<name>_repository.dart` |
| New repository implementation | `lib/features/<feature>/data/repositories/<name>_repository_impl.dart` |
| New Drift DAO | `lib/core/database/daos/<name>_dao.dart` |
| New Drift table | `lib/core/database/tables/<name>.dart` |
| New domain service (cross-feature) | `lib/core/services/<name>_service.dart` |
| New domain service (feature-local) | `lib/features/<feature>/domain/services/<name>_service.dart` |
| New enum used by multiple features | `lib/core/enums/<name>.dart` |
| New utility | `lib/core/utils/<focused_name>_utils.dart` |

---

## profileId-in-PK Invariant

Every user-data table in the user database MUST include `profileId` as part of its composite primary key. This is the enforcement of multi-profile isolation at the data layer.

**Rule:** No user-facing Drift table may use a single-column autoincrement primary key without also specifying `profileId` as part of a composite key override.

**Correct pattern:**
```dart
class CompletionsTable extends Table {
  TextColumn get profileId => text().references(ProfilesTable, #id)();
  TextColumn get contentItemId => text()();
  DateTimeColumn get completedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {profileId, contentItemId, completedAt};
}
```

**Wrong pattern (bare autoincrement — forbidden for user data):**
```dart
class CompletionsTable extends Table {
  IntColumn get id => integer().autoIncrement()();  // WRONG — no profileId
  ...
}
```

Content tables (read-only, shared across profiles) are exempt. The invariant applies to all tables in `user_database.dart`.

**Enforcement:** `make audit` runs a grep that flags any user-DB table without a `profileId` column.

---

## Enforcement — `make audit`

`make audit` (DNI-389) runs all 12 enforcement greps and `custom_lint` locally. Run it before pushing to catch violations early. The greps are also run in CI on every PR.

The full CI matrix (DNI-388) requires all of the following to pass on every PR:

| Step | Command | What it checks |
|------|---------|----------------|
| `analyze` | `dart analyze --fatal-infos` | Static analysis, no warnings |
| `format-check` | `dart format --set-exit-if-changed lib/ test/` | Consistent formatting |
| `audit` | `make audit` | All 12 enforcement greps + custom_lint (see below) |
| `lint` | `custom_lint` | 4 custom lint rules (DNI-386/387) |
| `test` | `flutter test` | Full test suite |
| `coverage-floor` | (coverage tool) | Line coverage ≥ 60%; cannot drop on a PR |

### The 12 enforcement greps

Each grep must return zero matching lines. Violations block the commit.

| # | What it checks | Why |
|---|----------------|-----|
| 1 | `FirebaseAuth.instance.signOut` outside `core/auth/` | Direct sign-out calls bypass the auth gateway and skip session-cleanup hooks (NFR3 / Story 24.3). |
| 2 | `import 'package:talker/talker.dart'` outside `core/logging/` | Raw Talker bypasses PII redaction, log-level filtering, and Crashlytics breadcrumb integration provided by `AppLogger` (NFR24 / Story 24.5). |
| 3 | `.withDefault(const Constant(0))` in `core/database/tables/` | Drift integer columns must not use a silent zero default; use explicit non-null types or nullable columns to surface missing data (Story 25.1). |
| 4 | `hebrewTermsScriptProvider` outside `core/labels/`, `core/preferences/`, or `settings/*_screen.dart` | Script-selection state must flow through the labels layer, not be read ad-hoc in feature code (Story 25.9). |
| 5 | `.displayNameEn` / `.displayNameHe` outside `core/labels/` (non-generated) | Direct field access bypasses the label service, breaking locale switching and the Hebrew/English chokepoint (Story 25.9 / Lint L1). |
| 6 | `DateTime.now()` outside `core/time/` | Raw `DateTime.now()` makes tests non-deterministic; all clock reads must go through `DateTimeFactory` or the `clockProvider` (NFR21 / Story 25.10). |
| 7 | `package:firebase_auth` outside `core/auth/` | Firebase Auth symbols must be isolated to the auth module so the rest of the app stays Firebase-agnostic (NFR3 / Story 25.11). |
| 8 | `debugPrint` or bare `print()` in production code (non-generated) | Debug prints leak to device consoles in production builds; use `AppLogger` instead (NFR24 / Story 25.19). |
| 9 | `currentAccountId = 1` hardcoded in `lib/` | Hardcoded account ID 1 breaks multi-account support; account ID must be resolved from session state (Story 25.21). |
| 10 | Empty catch blocks `catch (_) {}` in non-generated code | Silent swallowing of exceptions hides bugs and makes errors undiagnosable in production (NFR23). |
| 11 | `EdgeInsets.only(left: ...)` or `EdgeInsets.only(right: ...)` in non-generated code | Hardcoded directional insets break RTL (Hebrew) layout; use `EdgeInsetsDirectional` or symmetric padding (NFR16 / UX-DR5). |
| 12 | `package:cloud_firestore` or `package:firebase_storage` outside `core/sync/` or `core/auth/` | Firestore and Storage SDK symbols must stay inside the sync gateway; all other code accesses them through injected providers (NFR3). |

---

## Custom Lints Reference

Four custom lint rules enforce the layering invariants. They are defined in a `custom_lint` package (DNI-386 and DNI-387 — not yet merged to `origin/dev`). Once merged, each lint rule will have its own one-page README inside the lint package.

| Lint ID | Rule name | What it catches | Story |
|---------|-----------|-----------------|-------|
| L1 | `no-curriculum-display-name-bypass` | `.displayNameEn` / `.displayNameHe` accessed outside `core/labels/` or generated files | DNI-386 |
| L2 | `no-feature-cross-import` | `features/X/` importing `features/Y/` sub-paths other than `providers.dart`; also `core/` importing `features/` | DNI-386 |
| L3 | `no-firebase-outside-core` | Firebase SDK symbols (`FirebaseAuth`, `FirebaseFirestore`, `FirebaseStorage`) outside `core/sync/` and `features/auth/` | DNI-387 |
| L4 | `no-raw-talker` | `package:talker/talker.dart` imported outside `core/logging/` | DNI-387 |

Until the custom lints land, the greps in [Layering Rules](#layering-rules) provide equivalent manual enforcement.

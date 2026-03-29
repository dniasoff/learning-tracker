# Story 19.4: Local Calendar Engine

Status: ready-for-dev

## Story

As a learner,
I want my daily calendar program assignments to load instantly from local data,
so that I never wait for a network call or see an error when offline.

## Context

The current `CalendarProgramService` fetches calendar assignments from Sefaria and Hebcal APIs at runtime, caches raw JSON in `CalendarCache`, and maps responses to `CalendarProgramEntry` objects. This design has multiple problems documented in the [calendar cycle computation analysis](../../_bmad-output/planning-artifacts/calendar-cycle-computation-analysis.md):

1. **Offline failure** -- no API means no calendar assignments.
2. **6 of 12 programs are broken** -- apiKey mismatches, missing Hebcal flags, wrong source for Nach Yomi.
3. **24-hour cache** -- stale data after midnight until next API call succeeds.
4. **Complex runtime code** -- two API clients, JSON parsing, cache management, error handling.

The new design replaces all of this with a single `CalendarCycles` table in the `ContentDatabase`, pre-populated by the seed build tool (Story 19.2/19.3). The `LocalCalendarEngine` service does one query: `SELECT sefaria_ref, display_text FROM calendar_cycles WHERE program_id = ? AND date = ?`. Zero network calls. Zero parsing. Instant results.

### Prerequisite Stories

- **19.1**: Two-database split (ContentDatabase exists)
- **19.2**: CalendarCycles table created and populated by seed tool
- **19.3**: Seed database loaded into ContentDatabase at app startup

## Acceptance Criteria

**AC-1: LocalCalendarEngine returns today's assignment for any program**
**Given** the ContentDatabase contains CalendarCycles data covering today's date
**When** `LocalCalendarEngine.getEntry(programId, date)` is called
**Then** it returns a `CalendarProgramEntry` with the correct `sefariaRef`, `displayText`, `programId`, and `displayNameEn`/`displayNameHe`
**And** the result is returned synchronously from the database (no network call)

**AC-2: LocalCalendarEngine returns entries for all 12 programs**
**Given** CalendarCycles data exists for all 12 programs
**When** `LocalCalendarEngine.getTodayPrograms()` is called
**Then** it returns a `List<CalendarProgramEntry>` with exactly 12 entries (one per program)
**And** each entry has a valid `sefariaRef` (non-null, non-empty)

**AC-3: Graceful handling of missing data**
**Given** CalendarCycles data does NOT exist for a specific program on a specific date (e.g., beyond the seeded window)
**When** `LocalCalendarEngine.getEntry(programId, date)` is called
**Then** it returns `null`
**And** `getTodayPrograms()` omits that program from the result list (does not throw)

**AC-4: CalendarProgramService delegates to LocalCalendarEngine**
**Given** the `CalendarProgramService` has been refactored
**When** any consumer calls `getTodayPrograms()`
**Then** it delegates to `LocalCalendarEngine` (no Sefaria/Hebcal API calls)
**And** the existing `CalendarProgramEntry` model is preserved for backward compatibility

**AC-5: Provider layer updated**
**Given** `calendar_providers.dart` has been refactored
**When** `todayCalendarProvider` is resolved
**Then** it uses the new `LocalCalendarEngine` (not the old API-dependent service)
**And** no Dio, Sefaria, or Hebcal providers are required

**AC-6: Old API-dependent code removed**
**Given** the migration is complete
**When** reviewing the codebase
**Then** `CalendarCache` table, `CalendarCacheDao`, `SefariaCalendarClient` (calendar endpoint only), `HebcalApiClient` (calendar endpoint only), and the API-fetching methods in `CalendarProgramService` are removed or deprecated
**And** the `CalendarProgramRegistry` remains as the canonical program definition list

**AC-7: Date range queries supported**
**Given** the ContentDatabase contains CalendarCycles data
**When** `LocalCalendarEngine.getEntriesForRange(programId, startDate, endDate)` is called
**Then** it returns an ordered list of entries for the date range
**And** this enables "upcoming schedule" UI features

## Tasks / Subtasks

### T1: Create CalendarCycleDao for ContentDatabase (AC: 1, 3, 7)

This DAO is the data access layer. It wraps Drift queries against the `CalendarCycles` table in `ContentDatabase`.

- [ ] Create `lib/core/database/daos/calendar_cycle_dao.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/content_database.dart';
import 'package:learning_tracker/core/database/tables/calendar_cycles.dart';

part 'calendar_cycle_dao.g.dart';

/// Read-only DAO for pre-computed calendar cycle lookups.
///
/// Queries the CalendarCycles table in ContentDatabase.
/// This table is populated by the seed build tool and never
/// written to at runtime.
@DriftAccessor(tables: [CalendarCycles])
class CalendarCycleDao extends DatabaseAccessor<ContentDatabase>
    with _$CalendarCycleDaoMixin {
  CalendarCycleDao(super.db);

  /// Get the calendar entry for a specific program on a specific date.
  ///
  /// Returns null if no data exists for this (program, date) pair.
  /// This is the primary query used by LocalCalendarEngine.
  ///
  /// Query: SELECT * FROM calendar_cycles
  ///        WHERE program_id = ? AND date = ?
  Future<CalendarCycleData?> getEntry(String programId, String dateKey) =>
      (select(calendarCycles)
            ..where(
              (t) => t.programId.equals(programId) & t.date.equals(dateKey),
            ))
          .getSingleOrNull();

  /// Get all program entries for a specific date.
  ///
  /// Returns one row per program that has data for this date.
  /// Used by getTodayPrograms() to fetch all 12 programs at once.
  ///
  /// Query: SELECT * FROM calendar_cycles WHERE date = ?
  Future<List<CalendarCycleData>> getEntriesForDate(String dateKey) =>
      (select(calendarCycles)
            ..where((t) => t.date.equals(dateKey)))
          .get();

  /// Get entries for a program across a date range (inclusive).
  ///
  /// Returns entries ordered by date ascending.
  /// Used for "upcoming schedule" UI.
  ///
  /// Query: SELECT * FROM calendar_cycles
  ///        WHERE program_id = ? AND date >= ? AND date <= ?
  ///        ORDER BY date ASC
  Future<List<CalendarCycleData>> getEntriesForRange(
    String programId,
    String startDate,
    String endDate,
  ) =>
      (select(calendarCycles)
            ..where(
              (t) =>
                  t.programId.equals(programId) &
                  t.date.isBiggerOrEqualValue(startDate) &
                  t.date.isSmallerOrEqualValue(endDate),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.date)]))
          .get();
}
```

- [ ] Register `CalendarCycleDao` in `ContentDatabase`'s `@DriftDatabase` annotation (add to `daos:` list)
- [ ] Run `dart run build_runner build --delete-conflicting-outputs` to generate `calendar_cycle_dao.g.dart`
- [ ] Verify the generated code compiles without errors

**Note on CalendarCycles table schema:** The table is expected to already exist from Story 19.2. It has this shape:

```dart
/// Pre-computed calendar program cycles for fully offline operation.
/// Each row maps a date to a Sefaria ref for one calendar program.
class CalendarCycles extends Table {
  /// Program identifier: 'daf_yomi', 'mishna_yomit', etc.
  TextColumn get programId => text()();

  /// Date in 'YYYY-MM-DD' ISO 8601 format.
  TextColumn get date => text()();

  /// Sefaria ref string: 'Menachot.77', 'Mishnah_Tamid.2.1-2', etc.
  TextColumn get sefariaRef => text()();

  /// Human-readable display text: 'Menachot 77', 'OC 168:5-7', etc.
  TextColumn get displayText => text().nullable()();

  @override
  Set<Column> get primaryKey => {programId, date};
}
```

The composite primary key `(programId, date)` provides the index for the main query pattern. An additional index on `date` alone supports `getEntriesForDate()`.

### T2: Create LocalCalendarEngine Service (AC: 1, 2, 3, 7)

This is the core new service. It replaces all API-dependent calendar logic with simple database lookups.

- [ ] Create `lib/core/services/local_calendar_engine.dart`:

```dart
import 'package:learning_tracker/core/database/daos/calendar_cycle_dao.dart';
import 'package:learning_tracker/core/services/calendar_program_registry.dart';
import 'package:learning_tracker/core/services/calendar_program_service.dart';

/// Offline-first calendar engine that reads pre-computed cycle data
/// from the ContentDatabase.
///
/// Replaces the API-dependent CalendarProgramService for all calendar
/// lookups. Every call is a local database read -- zero network calls.
///
/// Usage:
///   final entry = await engine.getEntry('daf_yomi', DateTime.now());
///   // entry.sefariaRef == 'Menachot.77'
///
///   final all = await engine.getTodayPrograms();
///   // 12 CalendarProgramEntry objects
class LocalCalendarEngine {
  final CalendarCycleDao _dao;

  LocalCalendarEngine(this._dao);

  /// Format a DateTime as 'YYYY-MM-DD' for database lookup.
  static String formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Get the calendar entry for a specific program on a specific date.
  ///
  /// Returns null if no data exists (e.g., date is outside the seeded window).
  /// The caller should handle null gracefully (e.g., show "no data available").
  Future<CalendarProgramEntry?> getEntry(
    String programId,
    DateTime date,
  ) async {
    final dateKey = formatDateKey(date);
    final row = await _dao.getEntry(programId, dateKey);
    if (row == null) return null;

    final def = CalendarProgramRegistry.byId(programId);
    if (def == null) return null;

    return CalendarProgramEntry(
      programId: programId,
      displayNameEn: def.displayNameEn,
      displayNameHe: def.displayNameHe,
      todayRef: row.sefariaRef,
      apiSource: 'local', // No longer API-sourced
    );
  }

  /// Get today's calendar entries for ALL registered programs.
  ///
  /// Queries the CalendarCycles table for all programs at once using
  /// a single date filter, then maps each row to a CalendarProgramEntry.
  ///
  /// Programs with no data for today are silently omitted (not errors).
  /// Under normal conditions, this returns exactly 12 entries.
  Future<List<CalendarProgramEntry>> getTodayPrograms([
    DateTime? date,
  ]) async {
    final effectiveDate = date ?? DateTime.now();
    final dateKey = formatDateKey(effectiveDate);
    final rows = await _dao.getEntriesForDate(dateKey);

    final entries = <CalendarProgramEntry>[];
    for (final row in rows) {
      final def = CalendarProgramRegistry.byId(row.programId);
      if (def == null) continue; // Unknown program in DB -- skip silently

      entries.add(
        CalendarProgramEntry(
          programId: row.programId,
          displayNameEn: def.displayNameEn,
          displayNameHe: def.displayNameHe,
          todayRef: row.sefariaRef,
          apiSource: 'local',
        ),
      );
    }

    return entries;
  }

  /// Get entries for a program across a date range (inclusive).
  ///
  /// Useful for "upcoming schedule" or "what's coming this week" UI.
  /// Returns entries ordered by date ascending.
  /// Missing dates within the range are simply absent from the list.
  Future<List<CalendarProgramEntry>> getEntriesForRange(
    String programId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final startKey = formatDateKey(startDate);
    final endKey = formatDateKey(endDate);
    final rows = await _dao.getEntriesForRange(programId, startKey, endKey);

    final def = CalendarProgramRegistry.byId(programId);
    if (def == null) return [];

    return rows
        .map(
          (row) => CalendarProgramEntry(
            programId: programId,
            displayNameEn: def.displayNameEn,
            displayNameHe: def.displayNameHe,
            todayRef: row.sefariaRef,
            apiSource: 'local',
          ),
        )
        .toList();
  }
}
```

- [ ] Verify the `CalendarProgramEntry` model is still usable (check `apiSource` field -- changing from `'sefaria'`/`'hebcal'` to `'local'`). If any downstream code branches on `apiSource`, update it.

**Important:** The `CalendarProgramEntry` class is defined in `calendar_program_service.dart`. It should remain there (or be extracted to its own file) to avoid breaking imports. Do NOT change its constructor signature. The `apiSource` field changes from `'sefaria'`/`'hebcal'` to `'local'` -- search all call sites for `apiSource` to verify nothing branches on the old values.

### T3: Update CalendarProgramService to Delegate (AC: 4)

The existing `CalendarProgramService` is the public API consumed by providers. Rather than replacing it everywhere, refactor it to delegate to `LocalCalendarEngine` internally. This minimizes changes to downstream code.

- [ ] Refactor `lib/core/services/calendar_program_service.dart`:

```dart
import 'package:learning_tracker/core/services/local_calendar_engine.dart';

/// Unified calendar entry combining data from any source.
/// (Unchanged -- same class as before)
class CalendarProgramEntry {
  final String programId;
  final String displayNameEn;
  final String displayNameHe;
  final String todayRef;
  final String apiSource;

  const CalendarProgramEntry({
    required this.programId,
    required this.displayNameEn,
    required this.displayNameHe,
    required this.todayRef,
    required this.apiSource,
  });
}

/// Service that provides calendar program data.
///
/// Previously orchestrated Sefaria + Hebcal API calls with caching.
/// Now delegates entirely to LocalCalendarEngine (offline-first).
class CalendarProgramService {
  final LocalCalendarEngine _engine;

  CalendarProgramService(this._engine);

  /// Get today's calendar programs from local pre-computed data.
  Future<List<CalendarProgramEntry>> getTodayPrograms() =>
      _engine.getTodayPrograms();

  /// Get a specific program's entry for a specific date.
  Future<CalendarProgramEntry?> getEntry(
    String programId,
    DateTime date,
  ) =>
      _engine.getEntry(programId, date);

  /// Get entries for a program across a date range.
  Future<List<CalendarProgramEntry>> getEntriesForRange(
    String programId,
    DateTime startDate,
    DateTime endDate,
  ) =>
      _engine.getEntriesForRange(programId, startDate, endDate);
}
```

- [ ] Remove the old constructor parameters (`SefariaCalendarClient`, `HebcalApiClient`, `AppDatabase`)
- [ ] Remove all private methods: `_fetchSefariaWithCache`, `_fetchHebcalWithCache`, `_mapSefariaEntries`, `_sefariaResponseToJson`
- [ ] Remove imports for: `dart:convert`, `app_database.dart`, `hebcal_api_client.dart`, `sefaria_calendar_response.dart`, `sefaria_calendar_client.dart`

### T4: Update Provider Layer (AC: 5)

Rewire the Riverpod providers to use the new dependency chain.

- [ ] Refactor `lib/core/providers/calendar_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/daos/calendar_cycle_dao.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/services/calendar_program_service.dart';
import 'package:learning_tracker/core/services/local_calendar_engine.dart';

/// Provider for the CalendarCycleDao (reads from ContentDatabase).
final calendarCycleDaoProvider = Provider<CalendarCycleDao>((ref) {
  final contentDb = ref.watch(contentDatabaseProvider);
  return contentDb.calendarCycleDao;
});

/// Provider for the LocalCalendarEngine.
final localCalendarEngineProvider = Provider<LocalCalendarEngine>((ref) {
  final dao = ref.watch(calendarCycleDaoProvider);
  return LocalCalendarEngine(dao);
});

/// Provider for the calendar program service (backward-compatible).
final calendarProgramServiceProvider = Provider<CalendarProgramService>((ref) {
  final engine = ref.watch(localCalendarEngineProvider);
  return CalendarProgramService(engine);
});

/// Today's available calendar programs.
final todayCalendarProvider = FutureProvider<List<CalendarProgramEntry>>((
  ref,
) async {
  final service = ref.watch(calendarProgramServiceProvider);
  return service.getTodayPrograms();
});
```

- [ ] Remove `sefariaCalendarClientProvider` and `hebcalClientProvider`
- [ ] Remove imports for Dio, Sefaria, and Hebcal providers
- [ ] Verify `contentDatabaseProvider` exists in `database_provider.dart` (it should from Story 19.1). If the provider is named differently, adjust the reference.
- [ ] Search for all usages of `sefariaCalendarClientProvider` and `hebcalClientProvider` in the codebase. If any other file imports them, update or remove those imports.

### T5: Remove Old Calendar Cache Infrastructure (AC: 6)

Clean up the API-dependent code that is no longer needed.

- [ ] Delete `lib/core/database/tables/calendar_cache.dart`
- [ ] Delete `lib/core/database/daos/calendar_cache_dao.dart`
- [ ] Delete `lib/core/database/daos/calendar_cache_dao.g.dart`
- [ ] Remove `CalendarCache` from `AppDatabase` (or `UserDatabase`) `@DriftDatabase` tables list
- [ ] Remove `CalendarCacheDao` from `AppDatabase` (or `UserDatabase`) `@DriftDatabase` daos list
- [ ] Search for all imports of `calendar_cache.dart` and `calendar_cache_dao.dart` -- remove them
- [ ] Run `dart run build_runner build --delete-conflicting-outputs` to regenerate database code
- [ ] Run `dart analyze --fatal-infos` to verify no broken imports or references

**Note:** Do NOT delete `SefariaCalendarClient` or `HebcalApiClient` entirely if other features still use them (e.g., text fetching). Only remove the calendar-specific usage. Check each client's call sites before deleting.

### T6: Verify CalendarProgramRegistry Consistency (AC: 1, 2)

The `CalendarProgramRegistry` defines the 12 programs with `id` strings. The `CalendarCycles` table uses `programId` as a string key. These MUST match exactly.

- [ ] Verify that every `CalendarProgramDefinition.id` in the registry matches the `programId` values used in the `CalendarCycles` seed data:

| Registry `id` | Expected `CalendarCycles.programId` |
|---|---|
| `daf_yomi` | `daf_yomi` |
| `yerushalmi_yomi` | `yerushalmi_yomi` |
| `mishna_yomit` | `mishna_yomit` |
| `nach_yomi` | `nach_yomi` |
| `rambam_1_chapter` | `rambam_1_chapter` |
| `rambam_3_chapters` | `rambam_3_chapters` |
| `daf_a_week` | `daf_a_week` |
| `halakhah_yomit` | `halakhah_yomit` |
| `arukh_hashulchan_yomi` | `arukh_hashulchan_yomi` |
| `tanakh_yomi` | `tanakh_yomi` |
| `chofetz_chaim_daily` | `chofetz_chaim_daily` |
| `kitzur_shulchan_aruch_yomi` | `kitzur_shulchan_aruch_yomi` |

- [ ] If the seed tool (Story 19.2/19.3) used different keys (e.g., `programName` instead of `programId`, or Sefaria-style keys like `Daf Yomi` instead of `daf_yomi`), update either the registry or the engine mapping to reconcile. Document which convention was chosen.

- [ ] The `CalendarProgramRegistry.byId()` method is used by `LocalCalendarEngine` to look up display names. Verify it works for all 12 IDs.

### T7: Tests (AC: 1-7)

#### Unit Tests: CalendarCycleDao

- [ ] Create `test/core/database/daos/calendar_cycle_dao_test.dart`:

```dart
// Test setup: create in-memory ContentDatabase, insert fixture rows

void main() {
  group('CalendarCycleDao', () {
    // Setup: insert test rows for multiple programs and dates

    test('getEntry returns row for known (programId, date)', () async {
      // Insert: ('daf_yomi', '2026-03-29', 'Menachot.77', 'Menachot 77')
      // Query: getEntry('daf_yomi', '2026-03-29')
      // Expect: non-null, sefariaRef == 'Menachot.77'
    });

    test('getEntry returns null for unknown date', () async {
      // Query: getEntry('daf_yomi', '2099-01-01')
      // Expect: null
    });

    test('getEntry returns null for unknown program', () async {
      // Query: getEntry('nonexistent_program', '2026-03-29')
      // Expect: null
    });

    test('getEntriesForDate returns all programs for a date', () async {
      // Insert: 3 programs for '2026-03-29'
      // Query: getEntriesForDate('2026-03-29')
      // Expect: list of 3, all with matching date
    });

    test('getEntriesForDate returns empty for date with no data', () async {
      // Query: getEntriesForDate('2099-01-01')
      // Expect: empty list
    });

    test('getEntriesForRange returns ordered entries', () async {
      // Insert: 'daf_yomi' for 5 consecutive dates
      // Query: getEntriesForRange('daf_yomi', '2026-03-25', '2026-03-29')
      // Expect: 5 entries, ordered by date ascending
    });

    test('getEntriesForRange returns partial results for sparse data', () async {
      // Insert: 'daf_yomi' for dates 25, 27, 29 (skip 26, 28)
      // Query: getEntriesForRange('daf_yomi', '2026-03-25', '2026-03-29')
      // Expect: 3 entries (only the dates that exist)
    });
  });
}
```

#### Unit Tests: LocalCalendarEngine

- [ ] Create `test/core/services/local_calendar_engine_test.dart`:

```dart
void main() {
  group('LocalCalendarEngine', () {
    // Setup: in-memory ContentDatabase with fixture data for all 12 programs

    test('getEntry returns CalendarProgramEntry for valid program+date', () async {
      // Expect: non-null entry with correct programId, todayRef, displayNames
    });

    test('getEntry returns null for missing data', () async {
      // Expect: null
    });

    test('getEntry returns null for unknown programId', () async {
      // Program not in CalendarProgramRegistry
      // Expect: null
    });

    test('getTodayPrograms returns all 12 programs', () async {
      // Insert data for all 12 programs for test date
      // Expect: list of 12 entries
    });

    test('getTodayPrograms omits programs with no data', () async {
      // Insert data for only 10 programs
      // Expect: list of 10 (no error)
    });

    test('getTodayPrograms skips unknown programIds in DB', () async {
      // Insert a row with programId = 'fake_program'
      // Expect: it is silently skipped (no crash)
    });

    test('getEntriesForRange returns ordered entries', () async {
      // Insert 7 days of data for daf_yomi
      // Expect: 7 CalendarProgramEntry objects, ordered by date
    });

    test('apiSource is set to local', () async {
      // Expect: entry.apiSource == 'local'
    });

    test('formatDateKey formats correctly', () {
      expect(
        LocalCalendarEngine.formatDateKey(DateTime(2026, 3, 29)),
        equals('2026-03-29'),
      );
      expect(
        LocalCalendarEngine.formatDateKey(DateTime(2026, 1, 5)),
        equals('2026-01-05'),
      );
    });
  });
}
```

#### Unit Tests: CalendarProgramService (Refactored)

- [ ] Create or update `test/core/services/calendar_program_service_test.dart`:

```dart
void main() {
  group('CalendarProgramService (local engine delegate)', () {
    test('getTodayPrograms delegates to LocalCalendarEngine', () async {
      // Mock LocalCalendarEngine, verify delegation
    });

    test('getEntry delegates to LocalCalendarEngine', () async {
      // Mock LocalCalendarEngine, verify delegation
    });
  });
}
```

#### Provider Tests

- [ ] Create `test/core/providers/calendar_providers_test.dart`:

```dart
void main() {
  group('Calendar providers', () {
    test('todayCalendarProvider resolves from ContentDatabase', () async {
      // Create ProviderContainer with contentDatabaseProvider override
      // Insert fixture data
      // Verify todayCalendarProvider returns expected entries
    });

    test('todayCalendarProvider returns empty list when no data', () async {
      // Empty ContentDatabase
      // Verify todayCalendarProvider returns []
    });
  });
}
```

#### Test Fixtures

- [ ] Create or extend `test/fixtures/calendar_fixtures.dart`:

```dart
import 'package:learning_tracker/core/database/content_database.dart';

/// Insert calendar cycle test data for all 12 programs on a given date.
Future<void> seedCalendarCycleFixtures(
  ContentDatabase db, {
  String date = '2026-03-29',
}) async {
  final entries = [
    ('daf_yomi', 'Menachot.77', 'Menachot 77'),
    ('yerushalmi_yomi', 'Jerusalem_Talmud_Berakhot.1.1.1-7', 'Yerushalmi Berakhot 1:1'),
    ('mishna_yomit', 'Mishnah_Tamid.2.1-2', 'Tamid 2:1-2'),
    ('nach_yomi', 'I_Samuel.1', 'I Samuel 1'),
    ('rambam_1_chapter', 'Mishneh_Torah,_Repentance.7', 'Repentance 7'),
    ('rambam_3_chapters', 'Mishneh_Torah,_Leavened_and_Unleavened_Bread.5-7', 'Leavened and Unleavened Bread 5-7'),
    ('daf_a_week', 'Nedarim.75', 'Nedarim 75'),
    ('halakhah_yomit', 'Shulchan_Arukh,_Orach_Chayim.168.17-169.2', 'OC 168:17-169:2'),
    ('arukh_hashulchan_yomi', 'Arukh_HaShulchan,_Orach_Chaim.277.9-279.1', 'OC 277:9-279:1'),
    ('tanakh_yomi', 'Jeremiah.31.32-32.21', 'Jeremiah 31:32-32:21'),
    ('chofetz_chaim_daily', 'Chofetz_Chaim,_Part_One,_The_Prohibition_Against_Lashon_Hara,_Principle_9.1', 'LH 9.1-9.2'),
    ('kitzur_shulchan_aruch_yomi', 'Kitzur_Shulchan_Arukh.118.9-119.2', 'KSA 118:9-119:2'),
  ];

  await db.batch((batch) {
    for (final (programId, ref, display) in entries) {
      batch.insert(
        db.calendarCycles,
        CalendarCyclesCompanion.insert(
          programId: programId,
          date: date,
          sefariaRef: ref,
          displayText: Value(display),
        ),
      );
    }
  });
}
```

## Dev Notes

### Architecture

**Dependencies:**
- Story 19.1 (two-database split) -- ContentDatabase must exist
- Story 19.2 (CalendarCycles table + seed tool) -- table must be defined and populated
- Story 19.3 (seed DB loading) -- ContentDatabase must be loaded at startup

**Dependency direction:**
```
CalendarCycleDao (reads ContentDatabase)
  ↑
LocalCalendarEngine (business logic: date formatting, registry lookup)
  ↑
CalendarProgramService (thin delegate, backward compatibility)
  ↑
calendarProgramServiceProvider / todayCalendarProvider (Riverpod)
  ↑
UI widgets (unchanged)
```

### Current Architecture (Being Replaced)

```
SefariaCalendarClient ──→ CalendarProgramService ──→ calendarProgramServiceProvider
HebcalApiClient ─────────┘     │                          ↓
                                ↓                    todayCalendarProvider
                          CalendarCacheDao                 ↓
                          (CalendarCache table)       UI widgets
                          (AppDatabase)
```

### Target Architecture

```
ContentDatabase
  └─ CalendarCycles table (pre-populated, read-only)
       ↓
  CalendarCycleDao (Drift query: WHERE program_id = ? AND date = ?)
       ↓
  LocalCalendarEngine (date formatting + registry lookup)
       ↓
  CalendarProgramService (thin delegate)
       ↓
  todayCalendarProvider (Riverpod)
       ↓
  UI widgets (unchanged)
```

### Key Design Decisions

1. **Date-keyed lookup, not formula-based.** The analysis in `calendar-cycle-computation-analysis.md` section 5 explains why: Hebrew calendar programs (Chofetz Chaim, Kitzur SA) have variable-length years. A fixed `daysSince(epoch) % cycleLength` formula does not work for them. The date-keyed approach handles ALL 12 programs uniformly with one query pattern.

2. **`apiSource` field set to `'local'`.** All entries now come from local DB, not from any API. This is a semantic change. Search for code that branches on `apiSource == 'sefaria'` or `apiSource == 'hebcal'` and update if found.

3. **CalendarProgramService kept as thin wrapper.** Rather than replacing every import of `CalendarProgramService` across the codebase, keep the class but gut its implementation. It now has one dependency (`LocalCalendarEngine`) instead of three (`SefariaCalendarClient`, `HebcalApiClient`, `AppDatabase`).

4. **CalendarProgramEntry model unchanged.** The constructor and fields are identical. Only `apiSource` values change. This preserves backward compatibility with all UI code that consumes entries.

### Key Files

| File | Action |
|------|--------|
| `lib/core/database/daos/calendar_cycle_dao.dart` | **Create** -- new read-only DAO |
| `lib/core/services/local_calendar_engine.dart` | **Create** -- new service |
| `lib/core/services/calendar_program_service.dart` | **Replace contents** -- gut API logic, delegate to engine |
| `lib/core/providers/calendar_providers.dart` | **Replace contents** -- remove API providers, wire engine |
| `lib/core/services/calendar_program_registry.dart` | **Verify** -- no changes expected, but confirm ID consistency |
| `lib/core/database/tables/calendar_cache.dart` | **Delete** |
| `lib/core/database/daos/calendar_cache_dao.dart` | **Delete** |
| `lib/core/database/daos/calendar_cache_dao.g.dart` | **Delete** |
| `lib/core/database/app_database.dart` (or `user_database.dart`) | **Modify** -- remove CalendarCache + CalendarCacheDao |
| `lib/core/database/content_database.dart` | **Modify** -- add CalendarCycleDao to daos list |
| `test/core/database/daos/calendar_cycle_dao_test.dart` | **Create** |
| `test/core/services/local_calendar_engine_test.dart` | **Create** |
| `test/fixtures/calendar_fixtures.dart` | **Create** |

### Potential Pitfalls

1. **programId mismatch between registry and seed data.** The registry uses IDs like `daf_yomi`. If the seed tool stored them as `Daf Yomi` (Sefaria title.en), every lookup will return null. Check the actual seed data before writing the engine.

2. **ContentDatabase provider name.** Story 19.1 may have named the provider `contentDatabaseProvider` or `contentDbProvider` or exposed it differently. Check `database_provider.dart` for the actual name.

3. **CalendarCycleDao accessor name.** After adding the DAO to ContentDatabase, Drift generates an accessor on the database class (e.g., `db.calendarCycleDao`). The exact name depends on the DAO class name and Drift's naming convention. Verify after code generation.

4. **Migration from CalendarCache.** If there is a Drift migration step that references CalendarCache (e.g., `schemaVersion` bump in AppDatabase), it must be updated. The CalendarCache table no longer exists. If the migration runs `CREATE TABLE calendar_cache`, it will create an orphan table. Review migration code.

5. **Existing tests.** Search for existing tests that mock `CalendarProgramService`, `SefariaCalendarClient`, or `HebcalApiClient`. These tests will break if they construct `CalendarProgramService` with the old 3-argument constructor. Update them to use the new 1-argument constructor.

### References

- [Calendar Cycle Computation Analysis](../../_bmad-output/planning-artifacts/calendar-cycle-computation-analysis.md) -- full technical analysis of all 12 programs, bugs found, schema design
- [Two-Database Drift Architecture](../../_bmad-output/planning-artifacts/two-database-drift-architecture.md) -- ContentDatabase design, CalendarCycleDao specification
- [Seed Database Build Tool Design](../../_bmad-output/implementation-artifacts/seed-database-build-tool-design.md) -- CalendarCycles table schema, seed population
- [Architecture Decisions D9](../../_bmad-output/planning-artifacts/architecture.md) -- D9: Local Calendar Engine decision

## Dev Agent Record

### Agent Model Used

_To be filled during implementation_

### Debug Log References

### Completion Notes List

### File List

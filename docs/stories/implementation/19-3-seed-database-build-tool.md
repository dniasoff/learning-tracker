# Story 19.3: Seed Database Build Tool

Status: done

## Story

As a developer,
I want a CLI build tool that produces a pre-built, compressed SQLite seed database containing all read-only content (text, calendar cycles, programs, test dates),
and a runtime SeedManager that decompresses it on first launch,
so that the app ships with all content bundled and works fully offline from first open.

## Acceptance Criteria

**AC-1: CLI tool produces valid seed.db.gz**
**Given** the developer runs `dart run tool/seed_content_db.dart --build`
**When** the tool completes all phases (programs, text, calendar, finalize)
**Then** `build/seed.db` and `build/seed.db.gz` are produced
**And** the DB contains all 5 tables: TextCache, CalendarCycles, LearningPrograms, TestDates, SeedMetadata
**And** the schema matches the Drift-generated `ContentDatabase` class exactly

**AC-2: TextCache population from Sefaria API**
**Given** hierarchy JSON files exist in `assets/content/hierarchy/`
**When** the tool runs the text-fetch phase
**Then** all ~52,528 leaf items have their Hebrew + English text fetched from Sefaria API
**And** results are inserted into the TextCache table via Drift companions
**And** resume support allows interrupted runs to continue without re-fetching

**AC-3: CalendarCycles population from Sefaria + Hebcal APIs**
**Given** the tool runs the calendar-fetch phase
**When** it iterates through dates 2024-01-01 to 2030-12-31
**Then** all 12 calendar programs have (program_id, date, sefaria_ref, display_text) rows inserted
**And** Sefaria provides 9 programs per date, Hebcal provides 3 (nach_yomi, chofetz_chaim_daily, kitzur_shulchan_aruch_yomi)
**And** Hebcal uses monthly batch requests for efficiency

**AC-4: LearningPrograms and TestDates seeded**
**Given** the tool runs the programs phase
**When** it imports `learningProgramSeeds` and `generateTestDateSeeds()`
**Then** 9 LearningPrograms rows are inserted (including api_source, api_program_key, is_calendar_program fields)
**And** 24 months of TestDates are generated from the build date

**AC-5: SeedMetadata and version sidecar**
**Given** all content has been inserted
**When** the finalize phase runs
**Then** a SeedMetadata row is inserted with version, buildDate, contentHash (SHA-256), row counts, and minAppVersion
**And** `build/seed_version.json` sidecar is written with version + buildDate + contentHash
**And** the DB is VACUUMed before gzip compression

**AC-6: Validate-only mode**
**Given** the developer runs `dart run tool/seed_content_db.dart --validate-only`
**When** `build/seed.db` exists
**Then** the tool opens it with `ContentDatabase`, verifies schema match, verifies row counts (TextCache >= 50000, CalendarCycles >= 10000, LearningPrograms == 9, SeedMetadata == 1), and exits 0 on success

**AC-7: Runtime SeedManager decompresses on first launch**
**Given** the app launches and no `content.db` exists on device
**When** `SeedManager.ensureContentDatabase()` is called
**Then** it reads `assets/seed_version.json` for the bundled version
**And** decompresses `assets/seed.db.gz` to `content.db` using streaming gzip (bounded memory)
**And** returns the path to the ready content.db

**AC-8: Runtime SeedManager skips decompression when up to date**
**Given** `content.db` already exists with `seed_metadata.version >= bundledVersion`
**When** `SeedManager.ensureContentDatabase()` is called
**Then** it returns the existing path immediately without decompression

**AC-9: Runtime SeedManager upgrades on new seed version**
**Given** `content.db` exists with version N and bundled seed has version N+1
**When** `SeedManager.ensureContentDatabase()` is called
**Then** it deletes the old `content.db`, decompresses the new seed, and returns the new path

**AC-10: ContentDatabase opened read-only at runtime**
**Given** `SeedManager` has prepared `content.db`
**When** the app opens `ContentDatabase` from that path
**Then** it uses `PRAGMA query_only = ON` to enforce read-only access at the SQLite level

## Tasks / Subtasks

### T1: Create New Table Definitions (AC: 1, 5)

- [ ] Create `lib/core/database/tables/calendar_cycles.dart`:
  - Columns: `id` (autoIncrement), `programName` (text), `date` (text, ISO 8601), `sefariaRef` (text), `displayNameEn` (text, default ''), `displayNameHe` (text, default '')
  - Primary key: `{id}`; unique key: `{programName, date}`
  - Index on `date` for cross-program daily lookups
- [ ] Create `lib/core/database/tables/seed_metadata.dart`:
  - Columns: `id` (integer, default 1), `version` (integer), `buildDate` (text), `contentHash` (text), `textCacheCount` (integer), `calendarCycleCount` (integer), `minAppVersion` (text, default '1.0.0')
  - Primary key: `{id}`

### T2: Create ContentDatabase Drift Class (AC: 1, 10)

- [ ] Create `lib/core/database/content_database.dart`:
  - `@DriftDatabase` with tables: `TextCache`, `CalendarCycles`, `LearningPrograms`, `TestDates`, `SeedMetadata`
  - Include DAOs: `ContentTextCacheDao`, `ContentCalendarCycleDao`, `ContentLearningProgramDao`, `ContentTestDateDao`
  - `schemaVersion => 1` (no migrations, file-replacement strategy)
  - No Flutter imports -- pure Dart only
- [ ] Run `dart run build_runner build --delete-conflicting-outputs` to generate `content_database.g.dart`

### T3: Create Content DAOs (AC: 10)

- [ ] Create `lib/core/database/daos/content_text_cache_dao.dart`:
  - `getByRef(String sefariaRef)` -> `Future<TextCacheData?>`
  - `getByRefs(List<String> refs)` -> `Future<List<TextCacheData>>`
- [ ] Create `lib/core/database/daos/content_calendar_cycle_dao.dart`:
  - `getEntry(String programName, String date)` -> `Future<CalendarCycleData?>`
  - `getEntriesForDate(String date)` -> `Future<List<CalendarCycleData>>`
  - `getFullCycle(String programName)` -> `Future<List<CalendarCycleData>>`
- [ ] Create `lib/core/database/daos/content_learning_program_dao.dart`:
  - `getAllPrograms()` -> `Future<List<LearningProgramData>>`
  - `getByName(String name)` -> `Future<LearningProgramData?>`
- [ ] Create `lib/core/database/daos/content_test_date_dao.dart`:
  - `getUpcomingForProgram(int programId)` -> `Future<List<TestDateData>>`

### T4: Build Tool -- Scaffold and CLI Argument Parsing (AC: 1, 6)

- [ ] Create `tool/seed_content_db.dart` with argument parsing:
  - `--build` (default), `--validate-only`, `--text-only`, `--calendar-only`, `--programs-only`
  - `--curriculum <name>`, `--resume` (default true), `--no-resume`
  - `--output <path>` (default `build/`), `--seed-version <n>`, `--verbose`
- [ ] Implement phase orchestration:
  - Phase 1: Initialize DB (create `ContentDatabase` with `NativeDatabase(File('build/seed.db'))`)
  - Phase 2: Seed programs + test dates
  - Phase 3: Fetch + insert text content
  - Phase 4: Fetch + insert calendar cycles
  - Phase 5: Finalize (SeedMetadata, VACUUM, gzip, sidecar)
- [ ] Add `--validate-only` path: open existing DB, check schema, check row counts, exit

### T5: Build Tool -- Programs + TestDates Phase (AC: 4)

- [ ] Import `learningProgramSeeds` from `lib/core/database/seed/learning_program_seeds.dart`
- [ ] Insert all 9 rows using Drift batch API with `LearningProgramsCompanion.insert(...)`
- [ ] Set calendar-program fields (`apiSource`, `apiProgramKey`, `isCalendarProgram`) at insert time -- extend `learningProgramSeeds` to include these fields rather than duplicating migration v21 UPDATE logic
- [ ] Call `generateTestDateSeeds(from: buildDate, monthsAhead: 24)` from `lib/core/database/seed/test_date_seeds.dart`
- [ ] Look up `programId` by name for each test date seed, insert into TestDates

### T6: Build Tool -- Text Content Phase (AC: 2)

- [ ] Reuse fetch logic from existing `tool/seed_text_content.dart`:
  - `_fetchBothLanguages(Dio dio, String sefariaRef)` -> `({String he, String en})`
  - `_extractText(dynamic text)` and `_stripHtml(String html)`
  - Same rate limiting: `_maxConcurrent = 5`, 200ms batch delay, 429 retry
- [ ] Read all 7 hierarchy JSONs from `assets/content/hierarchy/`:
  - `bavli.json` (~5,471 leaves), `mishnayos.json` (~4,192), `yerushalmi.json` (~2,211)
  - `chumash.json` (~5,846), `mishna_berurah.json` (~17,397), `nach.json` (~17,360), `mussar.json` (~51)
  - Extract all items where `isLeaf == true`, collect `sefariaRef` values
- [ ] Resume support: on startup, query existing TextCache rows from seed.db to build a set of already-fetched refs; skip those
- [ ] Insert fetched text via Drift batch API, flush every 100 items:
  ```dart
  await db.batch((b) {
    for (final item in fetchedBatch) {
      b.insert(db.textCache, TextCacheCompanion.insert(
        sefariaRef: item.ref,
        hebrewText: item.he,
        englishText: item.en,
        fetchedAt: DateTime.now().toUtc(),
      ), mode: InsertMode.insertOrReplace);
    }
  });
  ```
- [ ] Track errors in `build/seed_errors.log`; fail with non-zero exit code if error rate > 1%

### T7: Build Tool -- Calendar Cycles Phase (AC: 3)

- [ ] Implement Sefaria calendar fetcher:
  - Iterate dates 2024-01-01 through 2030-12-31 (2,557 days)
  - For each date: `GET https://www.sefaria.org/api/calendars?day={D}&month={M}&year={Y}`
  - Extract 9 programs from `calendar_items` by matching `title.en`:
    - `Daf Yomi`, `Daily Mishnah`, `Daily Rambam`, `Daily Rambam (3 Chapters)`, `Yerushalmi Yomi`, `Daf a Week`, `Halakhah Yomit`, `Arukh HaShulchan Yomi`, `Tanakh Yomi`
  - Map to internal program names: `daf_yomi`, `mishnah_yomis`, `rambam_1_chapter`, `rambam_3_chapters`, `yerushalmi_yomi`, `daf_a_week`, `halakhah_yomit`, `arukh_hashulchan_yomi`, `tanakh_yomi`
  - Rate limit: 500ms delay between requests (~21 minutes total)
- [ ] Implement Hebcal calendar fetcher:
  - Batch by month: `GET https://www.hebcal.com/hebcal?v=1&cfg=json&start={start}&end={end}&c=off&dcc=on&dksa=on&nyomi=on`
  - ~84 monthly requests for 7 years
  - Match by `category`: `nachyomi` -> `nach_yomi`, `chofetzChaim` -> `chofetz_chaim_daily`, `kitzurShulchanAruch` -> `kitzur_shulchan_aruch_yomi`
  - Extract Sefaria ref from Hebcal `link` field: parse URL path, URL-decode, strip query params
- [ ] Handle Daf Yomi Cycle 15 (post 2027-06-07):
  - If Sefaria returns no Daf Yomi entry for a date after Jun 7 2027, generate from known fixed sequence (same 2,711 dappim starting at Berakhot 2a on Jun 8 2027)
- [ ] Resume support: query existing CalendarCycles rows to find max date per program; skip already-seeded dates
- [ ] Insert via Drift batch API:
  ```dart
  await db.batch((b) {
    for (final entry in dateBatch) {
      b.insert(db.calendarCycles, CalendarCyclesCompanion.insert(
        programName: entry.programName,
        date: entry.date,  // ISO 8601 string
        sefariaRef: entry.ref,
        displayNameEn: Value(entry.displayEn),
        displayNameHe: Value(entry.displayHe),
      ), mode: InsertMode.insertOrReplace);
    }
  });
  ```

### T8: Build Tool -- Finalize Phase (AC: 5)

- [ ] Compute content hash:
  1. Query all `sefariaRef` from TextCache, sorted alphabetically
  2. Query all `(programName, date)` from CalendarCycles, sorted
  3. Concatenate into a single string, SHA-256 hash
- [ ] Query row counts: `SELECT COUNT(*) FROM text_cache`, `SELECT COUNT(*) FROM calendar_cycles`
- [ ] Insert SeedMetadata:
  ```dart
  await db.into(db.seedMetadata).insert(SeedMetadataCompanion.insert(
    version: seedVersion,
    buildDate: DateTime.now().toUtc().toIso8601String(),
    contentHash: computedHash,
    textCacheCount: textCount,
    calendarCycleCount: cycleCount,
  ));
  ```
- [ ] Execute `VACUUM` to optimize DB file layout
- [ ] Close database
- [ ] Gzip compress:
  ```dart
  final dbBytes = File('build/seed.db').readAsBytesSync();
  final gzipped = gzip.encode(dbBytes);
  File('build/seed.db.gz').writeAsBytesSync(gzipped);
  ```
- [ ] Write `build/seed_version.json`:
  ```json
  {"version": 1, "buildDate": "2026-03-29T12:00:00Z", "contentHash": "a1b2c3..."}
  ```
- [ ] Print summary: file sizes, row counts, total duration

### T9: SeedManager -- Runtime Decompression Service (AC: 7, 8, 9)

- [ ] Create `lib/core/database/seed_manager.dart`:
  ```dart
  class SeedManager {
    Future<String> ensureContentDatabase() async { ... }
    Future<void> repairContentDatabase() async { ... }
  }
  ```
- [ ] Implement `ensureContentDatabase()`:
  1. `contentDbPath = join(appDatabaseDir, 'content.db')`
  2. Read `assets/seed_version.json` -> `bundledVersion`
  3. If content.db exists: open, read `SELECT version FROM seed_metadata WHERE id = 1`
     - If `installedVersion >= bundledVersion`: return path (no-op)
     - Else: close, delete, fall through to decompress
  4. If content.db does not exist: decompress from `assets/seed.db.gz`
  5. Streaming decompression to bound memory:
     ```dart
     final input = await rootBundle.load('assets/seed.db.gz');
     final inputStream = Stream.value(input.buffer.asUint8List());
     final decompressed = inputStream.transform(gzip.decoder);
     final sink = File(contentDbPath).openWrite();
     await decompressed.pipe(sink);
     ```
  6. Return `contentDbPath`
- [ ] Implement `repairContentDatabase()`: unconditionally delete and re-decompress
- [ ] Handle edge cases:
  - Decompression interrupted (partial file): catch IOException, delete partial, re-try once
  - Disk full: catch IOException, show user-facing error
  - Corrupted content.db (version read fails): delete and re-decompress

### T10: Integrate SeedManager into App Startup (AC: 7, 10)

- [ ] Modify `main.dart` to call `SeedManager.ensureContentDatabase()` before creating providers:
  ```dart
  final seedManager = SeedManager();
  final contentDbPath = await seedManager.ensureContentDatabase();
  final contentDb = ContentDatabase(NativeDatabase(File(contentDbPath),
    setup: (db) { db.execute('PRAGMA query_only = ON'); }));
  ```
- [ ] Create Riverpod providers:
  - `contentDatabaseProvider` (overridden in `ProviderScope`)
  - `seedManagerProvider`
- [ ] Update `pubspec.yaml`: add `assets/seed.db.gz` and `assets/seed_version.json` to assets list
- [ ] Add `.gitattributes` entry: `assets/seed.db.gz filter=lfs diff=lfs merge=lfs -text`

### T11: Extend learningProgramSeeds with Calendar Fields (AC: 4)

- [ ] Add `api_source`, `api_program_key`, `is_calendar_program` fields to each seed entry in `lib/core/database/seed/learning_program_seeds.dart`
- [ ] Mapping (from calendar-cycle-computation-analysis.md):
  - `daf_yomi`: sefaria / `Daf Yomi` / true
  - `mishnah_yomis`: sefaria / `Daily Mishnah` / true
  - `nach_yomi`: hebcal / `nachyomi` / true
  - Calendar programs not in current seeds (rambam, daf_a_week, etc.) will need new seed entries or a separate calendar_program_seeds constant

### T12: Add `crypto` dev_dependency (AC: 5)

- [ ] Add `crypto: ^3.0.0` to `dev_dependencies` in `pubspec.yaml` for SHA-256 content hash computation
- [ ] Verify `sqlite3` pure Dart FFI package is available for CLI tool (add to dev_dependencies if needed)

### T13: Tests (AC: 1-10)

- [ ] **Unit: CalendarCycles table definition** -- create in-memory ContentDatabase, verify table exists with correct columns via `PRAGMA table_info(calendar_cycles)`
- [ ] **Unit: SeedMetadata table definition** -- same approach, verify columns and defaults
- [ ] **Unit: SeedManager version comparison** -- test bundled > installed triggers decompress, bundled == installed is no-op, missing content.db triggers decompress
- [ ] **Unit: SeedManager decompression** -- gzip a small test DB, verify SeedManager produces valid SQLite from it
- [ ] **Unit: SeedManager corruption recovery** -- write a corrupt file as content.db, verify SeedManager deletes and re-decompresses
- [ ] **Unit: Content hash computation** -- insert known data, verify SHA-256 output matches expected value
- [ ] **Integration: --programs-only mode** -- run tool with `--programs-only`, open output DB, verify 9 LearningPrograms, expected TestDates, and 1 SeedMetadata row
- [ ] **Integration: --validate-only mode** -- build a known-good seed.db, run `--validate-only`, verify exit 0; corrupt it, verify exit non-zero
- [ ] **Integration: ContentDatabase schema match** -- create ContentDatabase in-memory, extract schema; create from seed.db, compare column-by-column
- [ ] **Smoke test (manual, post-full-build):** open seed.db, spot-check `Berakhot 2a` has non-empty Hebrew/English, verify CalendarCycles for daf_yomi on 2025-01-01 returns expected ref

## Dev Notes

### Architecture

**Part A: CLI Build Tool** (`tool/seed_content_db.dart`)

The tool instantiates `ContentDatabase` (the Drift class) backed by `NativeDatabase(File('build/seed.db'))`. Drift's `onCreate -> Migrator.createAll()` produces the exact schema. The tool populates via Drift Companion classes and batch inserts. This guarantees schema stays in sync -- the same Drift class used at runtime is used to build the seed.

**Part B: Runtime SeedManager** (`lib/core/database/seed_manager.dart`)

Runs at app startup before any content queries. Compares bundled seed version (from tiny JSON sidecar) against installed content.db version. Decompresses only when needed. ContentDatabase is then opened read-only with `PRAGMA query_only = ON`.

### Key Design Decisions (from design doc)

- **Date-keyed CalendarCycles** (not day-index): Hebrew calendar programs (Chofetz Chaim, Kitzur SA) have variable-length years. Date-keyed lookup eliminates all Hebrew calendar math. Query: `SELECT sefaria_ref FROM calendar_cycles WHERE program_name = ? AND date = ?`
- **ContentDatabase schemaVersion = 1 always**: No migrations. Schema changes -> full rebuild + file replacement on device.
- **Simple integer version**: No semver. `bundledVersion > installedVersion` triggers replacement.
- **Streaming decompression**: Avoids loading ~300MB uncompressed DB into memory. Uses `gzip.decoder` transform on a stream, piping to file sink.

### Existing Code to Reuse

**`tool/seed_text_content.dart`** -- The entire Sefaria fetch pipeline is extracted from this file:

```dart
// Rate limiting constants (line 31-32)
const _maxConcurrent = 5;
const _batchFlushSize = 100;

// Hierarchy scanning (lines 74-83)
final hierarchyJson = jsonDecode(File(hierarchyPath).readAsStringSync()) as Map<String, dynamic>;
final allItems = hierarchyJson['items'] as List<dynamic>;
final leafItems = allItems.cast<Map<String, dynamic>>()
    .where((item) => item['isLeaf'] == true).toList();

// API fetch with retry (lines 183-216)
Future<({String he, String en})> _fetchBothLanguages(Dio dio, String sefariaRef) async {
  final encodedRef = Uri.encodeComponent(sefariaRef);
  final response = await dio.get<Map<String, dynamic>>('/api/v3/texts/$encodedRef');
  // ... extract versions by actualLanguage == 'he' / 'en'
}

// HTML stripping (lines 218-229)
String _extractText(dynamic text) { /* flatten nested arrays, strip HTML */ }
String _stripHtml(String html) => html.replaceAll(RegExp('<[^>]*>'), '').trim();
```

The new tool writes to SQLite (via Drift) instead of JSON files. The fetch logic is identical.

**`lib/core/database/seed/learning_program_seeds.dart`** -- 9 program presets as `List<Map<String, Object>>`. Must be extended with calendar fields:

```dart
// Current format (line 4):
const List<Map<String, Object>> learningProgramSeeds = [
  {
    'name': 'oraysa',
    'display_name': 'Oraysa',
    'curriculum_type': 'bavli',
    'stages_config': '[...]',
    // ... needs: 'api_source', 'api_program_key', 'is_calendar_program'
  },
```

**`lib/core/database/seed/test_date_seeds.dart`** -- `generateTestDateSeeds()` currently defaults to 12 months from "now". The build tool calls it with explicit `from` and `monthsAhead: 24`.

**`lib/core/database/tables/text_cache.dart`** -- Existing table (4 columns: sefariaRef, hebrewText, englishText, fetchedAt). Shared between ContentDatabase and current AppDatabase.

**`lib/core/database/tables/calendar_cache.dart`** -- The OLD calendar cache (raw API responses). Replaced by the new CalendarCycles table (pre-processed lookup entries). This file is deprecated after this story.

### Hierarchy JSON Format

```json
{
  "hierarchyConfig": { "curriculumId": "bavli", "levelLabels": [...], "totalItems": 5471 },
  "items": [
    { "curriculumId": "bavli", "level1": "Berakhot", "sefariaRef": "Berakhot", "isLeaf": false },
    { "curriculumId": "bavli", "level1": "Berakhot", "level2": "2", "sefariaRef": "Berakhot 2", "isLeaf": false },
    { "curriculumId": "bavli", "level1": "Berakhot", "level2": "2", "level3": "a",
      "sefariaRef": "Berakhot 2a", "displayNameHe": "...", "displayNameEn": "Berakhot 2a", "isLeaf": true }
  ]
}
```

Only items with `"isLeaf": true` have text content to fetch.

### Sefaria Calendar API Response

```json
{
  "calendar_items": [
    { "title": { "en": "Daf Yomi", "he": "..." }, "ref": "Berakhot 2a", "displayValue": { "en": "Berakhot 2", "he": "..." } }
  ]
}
```

Match by `calendar_items[].title.en` to map to internal program names. See T7 for full mapping.

### Hebcal API -- Ref Extraction from Link URL

```
Input:  https://www.sefaria.org/Chofetz_Chaim%2C_Part_One%2C_...%2C_Principle_9.1?lang=bi&utm_source=...
Steps:  Parse URL path -> URL-decode -> strip query params
Output: Chofetz_Chaim,_Part_One,_The_Prohibition_Against_Lashon_Hara,_Principle_9.1
```

### File Inventory

**New Files:**
| File | Purpose |
|------|---------|
| `lib/core/database/content_database.dart` | ContentDatabase Drift class (5 tables) |
| `lib/core/database/content_database.g.dart` | Generated by build_runner |
| `lib/core/database/tables/calendar_cycles.dart` | CalendarCycles table definition |
| `lib/core/database/tables/seed_metadata.dart` | SeedMetadata table definition |
| `lib/core/database/daos/content_text_cache_dao.dart` | Read-only DAO for text lookups |
| `lib/core/database/daos/content_calendar_cycle_dao.dart` | Read-only DAO for cycle lookups |
| `lib/core/database/daos/content_learning_program_dao.dart` | Read-only DAO for program lookups |
| `lib/core/database/daos/content_test_date_dao.dart` | Read-only DAO for test date lookups |
| `lib/core/database/seed_manager.dart` | First-launch decompression + version check |
| `tool/seed_content_db.dart` | Unified CLI build tool |
| `assets/seed.db.gz` | Pre-built compressed Content DB (Git LFS) |
| `assets/seed_version.json` | Version sidecar for fast comparison |

**Modified Files:**
| File | Change |
|------|--------|
| `lib/core/database/seed/learning_program_seeds.dart` | Add api_source, api_program_key, is_calendar_program fields |
| `pubspec.yaml` | Add seed assets + `crypto` dev_dependency |
| `.gitattributes` | Git LFS tracking for seed.db.gz |
| `lib/main.dart` | SeedManager initialization before database providers |

**Deprecated Files (delete after validation):**
| File | Reason |
|------|--------|
| `tool/seed_text_content.dart` | Superseded by `tool/seed_content_db.dart` |
| `lib/core/database/tables/text_download_status.dart` | All content bundled |
| `lib/core/database/tables/content_download_statuses.dart` | All content bundled |
| `lib/core/database/tables/calendar_cache.dart` | Replaced by calendar_cycles.dart |

### Performance Expectations

| Phase | Duration | Notes |
|-------|----------|-------|
| Programs + TestDates | < 1 second | Pure local insert |
| Text Content (full) | ~3 hours | 52K items at ~5/sec from Sefaria |
| Calendar Cycles (Sefaria) | ~21 minutes | 2,557 dates at 2/sec |
| Calendar Cycles (Hebcal) | ~17 seconds | ~84 monthly batch requests |
| Finalize (VACUUM + gzip) | ~1 minute | 300MB DB |
| **Total full build** | **~3.5 hours** | With resume support |

| Metric | Estimate |
|--------|----------|
| Uncompressed seed.db | 260-340 MB |
| Compressed seed.db.gz | 40-65 MB |
| CalendarCycles rows | ~30,684 (12 programs x 2,557 days) |
| TextCache rows | ~52,528 |
| Device decompression time | 2-5 seconds |

### Dependencies

- No Flutter imports in tool or ContentDatabase (pure Dart required for CLI)
- `drift/native.dart` provides `NativeDatabase` for file-backed SQLite in CLI
- `sqlite3` FFI package needed for CLI (as opposed to `sqlite3_flutter_libs` which is Flutter-only)
- Blocking: Story 19.1 (ContentDatabase/UserDatabase split) if already scoped; otherwise this story creates ContentDatabase as the first step of that split

### Critical Constraints

- `ContentDatabase` class must NOT import any `package:flutter` packages
- The build tool runs as `dart run tool/seed_content_db.dart`, NOT as a Flutter command
- Calendar programs with Hebrew calendar cycles (Chofetz Chaim, Kitzur SA) MUST use date-keyed storage, not day-index
- Daf Yomi Cycle 15 (post Jun 2027) may need hard-coded sequence if Sefaria does not serve future cycle data

### References

- [Source: `docs/stories/implementation/seed-database-build-tool-design.md`]
- [Source: `docs/planning/calendar-cycle-computation-analysis.md`]
- [Source: `docs/planning/architecture-offline-v2.md` — §5 Inherited Unchanged]

## Acceptance Tests

```yaml
story_19_3:
  - id: AT-19.3.1
    title: "ContentDatabase creates all 5 tables"
    test: |
      Create ContentDatabase with NativeDatabase.memory().
      Query PRAGMA table_info() for: text_cache, calendar_cycles, learning_programs, test_dates, seed_metadata.
      Assert all 5 tables exist with expected columns.
    covers: AC-1

  - id: AT-19.3.2
    title: "Programs-only build produces 9 LearningPrograms and TestDates"
    test: |
      Run seed_content_db.dart with --programs-only flag.
      Open build/seed.db with ContentDatabase.
      Assert LearningPrograms count == 9.
      Assert all programs have non-null api_source OR is_calendar_program == false.
      Assert TestDates count >= 48 (4 programs x 12+ months).
      Assert SeedMetadata row exists with version >= 1.
    covers: AC-4, AC-5

  - id: AT-19.3.3
    title: "TextCache batch insert round-trips correctly"
    test: |
      Create in-memory ContentDatabase.
      Insert 100 TextCache rows via batch API with known sefariaRef/hebrewText/englishText values.
      Query back by sefariaRef. Assert all 100 match.
    covers: AC-2

  - id: AT-19.3.4
    title: "CalendarCycles insert and lookup by (programName, date)"
    test: |
      Create in-memory ContentDatabase.
      Insert entries for daf_yomi on dates 2025-01-01 through 2025-01-05.
      Query by (daf_yomi, 2025-01-03). Assert correct sefariaRef returned.
      Query by (daf_yomi, 2099-01-01). Assert null returned.
    covers: AC-3

  - id: AT-19.3.5
    title: "SeedMetadata content hash is deterministic"
    test: |
      Create in-memory ContentDatabase.
      Insert identical TextCache and CalendarCycles data twice (two separate DBs).
      Compute content hash for each. Assert hashes are identical.
    covers: AC-5

  - id: AT-19.3.6
    title: "SeedManager decompresses seed on first launch"
    test: |
      Create a small test seed.db, gzip it, mock rootBundle to serve it.
      Mock seed_version.json with version: 1.
      Ensure no content.db exists in temp dir.
      Call ensureContentDatabase().
      Assert content.db exists and is valid SQLite (open with ContentDatabase).
    covers: AC-7

  - id: AT-19.3.7
    title: "SeedManager skips decompression when version matches"
    test: |
      Place a valid content.db in temp dir with seed_metadata.version = 1.
      Mock seed_version.json with version: 1.
      Call ensureContentDatabase().
      Assert no file write occurred (check file modified timestamp is unchanged).
    covers: AC-8

  - id: AT-19.3.8
    title: "SeedManager re-decompresses on version upgrade"
    test: |
      Place content.db with seed_metadata.version = 1.
      Mock seed_version.json with version: 2.
      Mock seed.db.gz with a DB containing seed_metadata.version = 2.
      Call ensureContentDatabase().
      Open content.db, assert seed_metadata.version == 2.
    covers: AC-9

  - id: AT-19.3.9
    title: "ContentDatabase opens with query_only pragma"
    test: |
      Open ContentDatabase with PRAGMA query_only = ON.
      Attempt INSERT into text_cache.
      Assert SqliteException is thrown (read-only).
    covers: AC-10

  - id: AT-19.3.10
    title: "Validate-only mode detects valid seed.db"
    test: |
      Build a seed.db with --programs-only.
      Run --validate-only.
      Assert exit code 0.
    covers: AC-6

  - id: AT-19.3.11
    title: "SeedManager handles corrupted content.db"
    test: |
      Write random bytes to content.db path.
      Mock seed_version.json with version: 1.
      Mock seed.db.gz with valid content.
      Call ensureContentDatabase().
      Assert content.db is now valid (SeedManager detected corruption and re-decompressed).
    covers: AC-7
```

## Gap Analysis Additions (2026-03-31)

### APK Size Management

The seed DB with ~52K text items + ~30K calendar rows needs sizing analysis and budgeting:

**Size Budget:**
- Compressed seed DB (gzip): **< 80MB** (target: ~30-60MB based on estimates)
- Uncompressed seed DB: **< 400MB**

**Additional Acceptance Criteria:**
- [ ] Measure actual seed DB size after full population (uncompressed and gzip compressed)
- [ ] Document size breakdown: TextCache vs CalendarCycles vs LearningPrograms contribution
- [ ] Add `--size-report` flag to seed tool that outputs size breakdown by table
- [ ] If compressed size exceeds 80MB, investigate text compression strategies (e.g., removing duplicate content where Hebrew and English are identical)
- [ ] Document APK size impact in build output (total APK size before/after seed DB inclusion)

**Implementation for `--size-report`:**
```dart
if (args.contains('--size-report')) {
  final db = File('build/seed.db');
  final gz = File('build/seed.db.gz');
  print('=== Seed DB Size Report ===');
  print('Uncompressed: ${(db.lengthSync() / 1024 / 1024).toStringAsFixed(1)} MB');
  print('Compressed:   ${(gz.lengthSync() / 1024 / 1024).toStringAsFixed(1)} MB');
  print('Ratio:        ${(gz.lengthSync() / db.lengthSync() * 100).toStringAsFixed(1)}%');
  // Per-table breakdown via SQL
  final conn = sqlite3.open('build/seed.db');
  for (final table in ['text_cache', 'calendar_cycles', 'learning_programs', 'seed_metadata']) {
    final count = conn.select('SELECT COUNT(*) as c FROM $table').first['c'];
    final pageCount = conn.select("SELECT SUM(\"pageno\") FROM dbstat WHERE name='$table'").first.values.first;
    print('  $table: $count rows, ~${(pageCount ?? 0) * 4096 / 1024} KB');
  }
  conn.dispose();
}
```

## Dev Agent Record

### Agent Model Used

_Retroactively reconciled 2026-07-13 (AUD-docs-06) — this record was never backfilled at implementation time; sprint-status.yaml already showed `done` while this header still read the template default. No contemporaneous dev-agent record exists for the original implementation._

### Debug Log References

### Completion Notes List

- Re-verified 2026-07-13 against the live tree: the seed build pipeline is shipped under `learning_tracker/tool/` (`seed_content*.dart`, `seed_text_content.dart`, `sefaria_fetch/main.go`, `hebcal_fetch/main.mjs`, `build_cities_db.dart`), producing the bundled `seed.db.gz` `ContentDatabase` consumed at runtime.
- Acceptance coverage: `test/story_acceptance/epic_19_offline_first_test.dart`, group `Story 19.3 — Seed Database Build Tool`, 0 `skip:` markers.
- Status header + sprint-status.yaml were inconsistent (header said `ready-for-dev`, tracker said `done`) — header corrected to match verified reality, not the other way around.

### File List

- `learning_tracker/tool/` (seed pipeline scripts)
- `learning_tracker/test/story_acceptance/epic_19_offline_first_test.dart`

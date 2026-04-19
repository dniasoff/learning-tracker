# Seed Database Build Tool -- Technical Design

**Date:** 2026-03-29
**Status:** Draft
**Scope:** Phase 2 of Offline-First Architecture (per `architecture-offline-v2.md`, §5 Inherited Unchanged)

---

## 1. Overview

The seed database build tool (`tool/seed_content_db.dart`) produces a pre-built, compressed SQLite file (`build/seed.db.gz`) containing all read-only content for the Learning Tracker app. This file ships inside the APK as an asset and is decompressed to `content.db` on first launch or app upgrade.

The tool replaces the current `tool/seed_text_content.dart` (which outputs JSON) with a unified pipeline that writes directly into a Drift-managed SQLite database.

### What the tool produces

| Output | Contents |
|--------|----------|
| `build/seed.db` | Uncompressed SQLite, ~260-340 MB |
| `build/seed.db.gz` | Gzipped for APK bundling, ~45-60 MB |

### What the tool populates

| Table | Rows (est.) | Source |
|-------|-------------|--------|
| TextCache | ~52,528 | Sefaria API (Hebrew + English text) |
| CalendarCycles | ~12,000 | Sefaria/Hebcal APIs (reverse-engineered cycles) |
| LearningPrograms | 9 | Dart constants in `lib/core/database/seed/` |
| TestDates | ~50 | Dart constants in `lib/core/database/seed/` |
| SeedMetadata | 1 | Build tool generates at build time |

---

## 2. Schema Generation Strategy

### The Problem

The Content DB must have tables whose schema exactly matches what the `ContentDatabase` Drift class defines. If the tool creates tables with raw SQL that drifts (no pun intended) from the Drift-generated schema, inserts will fail or the app will crash at runtime.

### Recommended Approach: Option A -- Import ContentDatabase and Use Drift Directly

**The tool instantiates `ContentDatabase` (the Drift class) backed by a native SQLite file, then uses Drift's own `Migrator.createAll()` to build the schema.**

```
ContentDatabase Drift class (lib/core/database/content_database.dart)
  |
  |-- defines tables: TextCache, CalendarCycles, LearningPrograms, TestDates, SeedMetadata
  |-- code-generated: content_database.g.dart
  |
tool/seed_content_db.dart
  |
  |-- imports ContentDatabase
  |-- opens it with NativeDatabase(File('build/seed.db'))
  |-- Drift runs onCreate -> Migrator.createAll()
  |-- tool populates via Drift companions and batch inserts
  |-- closes DB
  |-- gzip compresses the .db file
```

**Why Option A wins:**

| Criterion | Option A (Import Drift class) | Option B (Raw SQL) | Option C (Drift schema migration tooling) |
|-----------|-------------------------------|--------------------|--------------------------------------------|
| Schema stays in sync | Guaranteed -- same class | Manual sync risk | Depends on export step |
| Column types/defaults correct | Guaranteed | Manual sync risk | Guaranteed |
| Indices created correctly | Guaranteed | Manual sync risk | Guaranteed |
| Insertions type-safe | Yes (Companion classes) | No (raw strings) | Yes |
| Build tool complexity | Low | Medium | Medium |
| Dependency on Flutter | **Must avoid** (see below) | None | None |

**Critical constraint: The tool runs as a CLI Dart script, not a Flutter app.** Drift's `NativeDatabase` from `package:drift/native.dart` works in pure Dart (no Flutter). But the `ContentDatabase` class must NOT import any Flutter packages. This is naturally satisfied because Drift table definitions are pure Dart.

### ContentDatabase Class Definition (New File)

A new file `lib/core/database/content_database.dart` defines the Drift database for content-only tables. It does NOT include any user-data tables. It references the same table files (e.g., `tables/text_cache.dart`) that the current `AppDatabase` uses, plus two new tables (`CalendarCycles`, `SeedMetadata`).

The tool imports this class and opens it against a file-backed SQLite database. Drift's `onCreate` callback fires `Migrator.createAll()`, producing the exact schema. The tool then populates data using type-safe Drift Companion classes.

### Schema Version Strategy

`ContentDatabase.schemaVersion` is always `1`. There is no migration infrastructure. When the schema changes, the entire seed.db is rebuilt and the old content.db is replaced on device. This is the explicit design decision from the architecture analysis -- content DB upgrades are file replacement, not migration.

---

## 3. New Tables

### 3.1 CalendarCycles Table

```dart
// lib/core/database/tables/calendar_cycles.dart
class CalendarCycles extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Program identifier matching LearningPrograms.name
  /// e.g., 'daf_yomi', 'mishnah_yomis'
  TextColumn get programName => text()();

  /// Zero-based day index within the cycle
  /// e.g., Daf Yomi cycle has 2,711 entries (0..2710)
  IntColumn get dayIndex => integer()();

  /// The Sefaria ref for this day's learning
  /// e.g., 'Berakhot 2a'
  TextColumn get sefariaRef => text()();

  /// Display name in English
  TextColumn get displayNameEn => text().withDefault(const Constant(''))();

  /// Display name in Hebrew
  TextColumn get displayNameHe => text().withDefault(const Constant(''))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {programName, dayIndex},
  ];
}
```

**Design notes:**

- `programName` is a string key (not an FK integer) because cross-DB references use string identifiers per the architecture decision. The `LocalCalendarEngine` at runtime does: `dayIndex = daysSince(epoch) % cycleLength`, then queries `CalendarCycles` by `(programName, dayIndex)`.
- No `epochDate` column here -- epoch dates are stored as metadata within the `LearningPrograms` row or as constants in the `LocalCalendarEngine` service. The cycles table is a pure lookup table.
- ~12,000 rows total across all 12 programs.

### 3.2 SeedMetadata Table

```dart
// lib/core/database/tables/seed_metadata.dart
class SeedMetadata extends Table {
  /// Always 1 row. Primary key is fixed to 1.
  IntColumn get id => integer().withDefault(const Constant(1))();

  /// Monotonically increasing integer. Compared on app launch to
  /// determine if bundled seed is newer than installed content.db.
  IntColumn get version => integer()();

  /// ISO 8601 UTC timestamp when this seed DB was built.
  TextColumn get buildDate => text()();

  /// SHA-256 hash of the concatenated content, for integrity verification.
  /// Computed over: sorted TextCache refs + CalendarCycles data.
  TextColumn get contentHash => text()();

  /// Total number of TextCache rows, for quick sanity check.
  IntColumn get textCacheCount => integer()();

  /// Total number of CalendarCycles rows.
  IntColumn get calendarCycleCount => integer()();

  /// Minimum Dart SDK version required to read this seed DB.
  /// Future-proofing in case schema changes require newer app version.
  TextColumn get minAppVersion => text().withDefault(const Constant('1.0.0'))();

  @override
  Set<Column> get primaryKey => {id};
}
```

**Version comparison logic:**

```
bundledVersion = read version from assets manifest (a small JSON sidecar, see Section 9)
installedVersion = SELECT version FROM seed_metadata WHERE id = 1

if bundledVersion > installedVersion:
  replace content.db
```

Using a simple integer version (not semver) keeps comparison trivial. The version is incremented manually in the build tool's configuration or automatically by CI based on content changes.

---

## 4. Text Content Population

### 4.1 Approach

Reuse the proven fetch logic from `tool/seed_text_content.dart` but write results directly into SQLite instead of JSON files.

### 4.2 Hierarchy Scanning

The tool reads all 7 hierarchy JSON files from `assets/content/hierarchy/`:

| File | Curriculum | Leaf items (est.) |
|------|-----------|-------------------|
| bavli.json | bavli | 5,471 |
| mishnayos.json | mishnayos | 4,192 |
| yerushalmi.json | yerushalmi | 2,211 |
| chumash.json | chumash | 5,846 |
| mishna_berurah.json | mishna_berurah | 17,397 |
| nach.json | nach | 17,360 |
| mussar.json | mussar | 51 |
| **Total** | | **~52,528** |

For each file, extract all items where `isLeaf == true` and collect their `sefariaRef` values.

### 4.3 Sefaria API Fetching

Identical to existing tool:

- Endpoint: `GET /api/v3/texts/{encodedRef}`
- Extract Hebrew (`actualLanguage == 'he'`) and English (`actualLanguage == 'en'`) from `versions` array
- Strip HTML tags
- Flatten nested text arrays with newline joins

### 4.4 Rate Limiting

- Max 5 concurrent requests (matching existing `_maxConcurrent = 5`)
- 200ms delay between batches
- On HTTP 429: wait 5 seconds, retry once
- On persistent failure: log error, continue (do not block the entire build)

### 4.5 Resume Support

The fetch process takes hours (52K items at ~5/sec = ~3 hours). Resume support is critical.

**Strategy: Progress database + final database**

1. The tool maintains a separate `build/seed_progress.db` SQLite file tracking which refs have been fetched.
2. On each batch completion, successfully fetched texts are inserted into `seed_progress.db`.
3. On resume, the tool queries `seed_progress.db` for already-fetched refs and skips them.
4. After all fetches complete, the tool creates the final `build/seed.db`, copies all text from `seed_progress.db` into the TextCache table via a single transaction.

**Why a separate progress DB instead of writing directly to seed.db?**

The final seed.db should be built in a clean, single-pass transaction for optimal SQLite page layout and minimal file size. The progress DB can be messy -- it just needs to track state.

Alternatively, a simpler approach: write directly to seed.db during fetch, and at the end run `VACUUM` to reclaim space and optimize page layout. This avoids the two-DB complexity. The `VACUUM` adds maybe 30 seconds for a 300 MB database. **Recommend this simpler approach.**

### 4.6 Batch Insert Performance

Use Drift's `batch` API for bulk inserts:

```
await db.batch((b) {
  for (final item in fetchedBatch) {
    b.insert(db.textCache, TextCacheCompanion.insert(...),
      mode: InsertMode.insertOrReplace);
  }
});
```

Flush every 100 items (matching existing `_batchFlushSize`). Within a transaction, SQLite can insert ~50K+ rows/second, so the bottleneck is API fetching, not DB writes.

### 4.7 Error Handling

- Track failed refs in a `build/seed_errors.log` file
- After completion, report: `Completed: {N} fetched, {M} errors out of {total}`
- If error count exceeds threshold (e.g., >1% of total), exit with non-zero code to fail CI
- Failed refs can be retried in a subsequent run (resume support handles this)

---

## 5. Calendar Cycle Population

### 5.1 Approach

Query Sefaria and Hebcal APIs day-by-day through a complete cycle for each of the 12 calendar programs. Record the ordered sequence of refs.

### 5.2 Programs and Their Cycles

| Program | programName key | Source | Cycle Length (days) | Epoch Date | API Endpoint |
|---------|----------------|--------|--------------------:|------------|-------------|
| Daf Yomi | daf_yomi | Sefaria | 2,711 | 2020-01-05 | `/api/calendars?day=D&month=M&year=Y` |
| Mishna Yomit | mishnah_yomis | Sefaria | ~2,088 | TBD (discover) | same |
| Nach Yomi | nach_yomi | Sefaria | ~929 | TBD | same |
| Yerushalmi Yomi | yerushalmi_yomi | Sefaria | ~1,554 | TBD | same |
| Daf a Week | daf_a_week | Sefaria | ~18,977 | TBD | same |
| Rambam 1 Chapter | rambam_1_chapter | Sefaria | ~985 | TBD | same |
| Rambam 3 Chapters | rambam_3_chapters | Sefaria | ~339 | TBD | same |
| Halakhah Yomit | halakhah_yomit | Sefaria | Variable | TBD | same |
| Tanakh Yomi | tanakh_yomi | Sefaria | ~929 | TBD | same |
| Arukh HaShulchan Yomi | arukh_hashulchan | Sefaria | Variable | TBD | same |
| Chofetz Chaim Daily | chofetz_chaim | Hebcal | ~197 | TBD | `/hebcal?...` |
| Kitzur SA Yomi | kitzur_sa_yomi | Hebcal | ~221 | TBD | `/hebcal?...` |

### 5.3 Sefaria Calendar API

**Endpoint:** `GET https://www.sefaria.org/api/calendars?day={D}&month={M}&year={Y}`

**Response structure** (relevant portion):

```json
{
  "calendar_items": [
    {
      "title": { "en": "Daf Yomi", "he": "..." },
      "displayValue": { "en": "Berakhot 2", "he": "..." },
      "ref": "Berakhot 2a",
      "url": "..."
    },
    ...
  ]
}
```

The tool matches `calendar_items[].title.en` against each program's `apiProgramKey` (already stored in `LearningPrograms.apiProgramKey`, e.g., `"Daf Yomi"`).

### 5.4 Hebcal Calendar API

**Endpoint:** `GET https://www.hebcal.com/hebcal?v=1&cfg=json&start={YYYY-MM-DD}&end={YYYY-MM-DD}&daily-learning=1`

The response includes daily learning items. Parse the relevant program entries.

### 5.5 Cycle Discovery Algorithm

For each program:

1. Pick a known start date within the current cycle (e.g., for Daf Yomi, `2020-01-05` = Berakhot 2a)
2. Query the API day-by-day forward
3. Record each day's ref and day index (0-based from epoch)
4. Detect cycle completion: when the ref returns to the first entry (or when a known cycle length is reached)
5. Store all `(programName, dayIndex, sefariaRef, displayNameEn, displayNameHe)` rows

### 5.6 Rate Limiting

- Sefaria calendar API: 2 requests/second (more conservative than text API -- one response per day covers all programs)
- Strategy: fetch one date at a time, extract all program entries from a single response
- This means ~2,711 API calls covers Daf Yomi's full cycle AND simultaneously captures all other Sefaria programs on those same dates
- For programs with longer cycles than Daf Yomi, continue querying additional dates
- Hebcal: similar conservative rate, ~200 days of queries covers both Hebcal programs

**Optimization:** Since each Sefaria calendar API call returns ALL programs for that date, a single pass through the longest cycle's date range populates all Sefaria-sourced programs simultaneously. This reduces total API calls from ~12K (if done per-program) to ~3K (one call per date).

### 5.7 Resume Support

Same as text content: track progress by date range completed. On resume, skip already-fetched date ranges.

### 5.8 Estimated Total Calendar API Calls

| API | Calls | At 2/sec | Duration |
|-----|------:|----------|----------|
| Sefaria (covering longest cycle, all programs) | ~3,000 | ~25 min | |
| Hebcal (covering both programs) | ~400 | ~3 min | |
| **Total** | ~3,400 | | **~30 minutes** |

---

## 6. LearningPrograms and TestDates Population

### 6.1 LearningPrograms

The tool imports `learningProgramSeeds` from `lib/core/database/seed/learning_program_seeds.dart` and inserts all 9 rows using Drift companions.

Additionally, the tool must set the calendar-program fields (`apiSource`, `apiProgramKey`, `isCalendarProgram`) that are currently applied via migration v21. Since ContentDatabase starts from scratch (no migrations), these fields must be set at insert time.

**Enhancement needed:** Extend `learningProgramSeeds` to include `api_source`, `api_program_key`, and `is_calendar_program` fields. Or, apply these values in the build tool after initial insert (matching the migration v21 UPDATE statements).

Recommended: extend the seed constants to be complete, avoiding duplicated logic.

### 6.2 TestDates

The tool imports `generateTestDateSeeds()` from `lib/core/database/seed/test_date_seeds.dart` and inserts the results.

**Consideration:** `generateTestDateSeeds()` currently generates 12 months from "now". For a pre-built seed database, "now" is build time. The function should be called with a fixed start date (e.g., the build date) and a longer horizon (e.g., 24 months) to ensure the seed DB is useful for at least a year before requiring an update.

The tool should call: `generateTestDateSeeds(from: buildDate, monthsAhead: 24)`.

### 6.3 Insert Order

LearningPrograms must be inserted before TestDates, because TestDates references `programId` (looked up by program name). The existing `_seedTestDates()` method in AppDatabase already does this lookup pattern.

---

## 7. SeedMetadata Population

Inserted as the final step after all other tables are populated.

```
SeedMetadataCompanion.insert(
  version: seedVersion,            // integer, e.g., 1
  buildDate: DateTime.now().toUtc().toIso8601String(),
  contentHash: computedHash,       // SHA-256 of sorted refs + text hashes
  textCacheCount: textCount,       // SELECT COUNT(*) FROM text_cache
  calendarCycleCount: cycleCount,  // SELECT COUNT(*) FROM calendar_cycles
  minAppVersion: '1.0.0',
)
```

### Content Hash Computation

The content hash serves as an integrity check. Compute as:

1. Query all `sefariaRef` values from TextCache, sorted alphabetically
2. Query all `(programName, dayIndex)` from CalendarCycles, sorted
3. Concatenate into a single string
4. SHA-256 hash

This allows CI to detect if content changed between builds without comparing entire database files.

---

## 8. Compression

### Approach

After all data is inserted and the database is VACUUMed:

```dart
final dbBytes = File('build/seed.db').readAsBytesSync();
final gzipped = gzip.encode(dbBytes);
File('build/seed.db.gz').writeAsBytesSync(gzipped);
```

### Expected Compression Ratios

SQLite databases containing primarily UTF-8 text (Hebrew + English) compress well with gzip:

| Metric | Estimate | Reasoning |
|--------|----------|-----------|
| Uncompressed DB size | 260-340 MB | ~52K rows of text, plus overhead |
| gzip compression ratio | 5:1 to 7:1 | Text-heavy content compresses well; SQLite page structure has some overhead |
| **Compressed size** | **~40-65 MB** | Fits comfortably in APK |
| Decompression time (device) | 2-5 sec | gzip decode of ~50 MB on modern mobile SoC |

### Decompression on Device

At runtime, the `SeedManager` reads the compressed asset and writes the decompressed bytes to the app's database directory. Dart's `GZipCodec` handles this. Streaming decompression (reading chunks from the asset, writing chunks to disk) avoids loading the full uncompressed DB into memory.

---

## 9. CI Integration

### 9.1 When Does the Tool Run?

The seed build is **slow** (~3-4 hours for text + ~30 min for calendar). It should NOT run on every commit or PR.

| Trigger | When | What |
|---------|------|------|
| **Manual (primary)** | Developer runs locally | `dart run tool/seed_content_db.dart` -- full build |
| **Release pipeline** | Before release builds | CI runs the tool, validates output, stores artifact |
| **Scheduled (optional)** | Weekly or monthly | Rebuild to capture updated TestDates and verify API availability |
| **Content change** | When hierarchy JSONs change | Triggered by path filter in CI |

### 9.2 CI Pipeline Steps

```
1. dart run tool/seed_content_db.dart --validate-only
   - Opens existing build/seed.db
   - Verifies schema matches ContentDatabase class
   - Verifies row counts match expectations
   - Verifies SeedMetadata is present and valid
   - Exits 0 if valid, non-zero if not
   (This runs on every PR that touches content-related code)

2. dart run tool/seed_content_db.dart --build
   - Full build (only on release pipeline or manual trigger)
   - Outputs build/seed.db and build/seed.db.gz

3. Copy build/seed.db.gz -> assets/seed.db.gz
   - The compressed DB is committed to the repo (or stored in Git LFS)
```

### 9.3 Schema Validation

The `--validate-only` flag performs:

1. Open `build/seed.db` with `ContentDatabase` (Drift)
2. If Drift can open it without errors, schema matches
3. Run `PRAGMA table_info(text_cache)` and compare columns with Drift's expected columns
4. Verify row counts: TextCache >= 50,000; CalendarCycles >= 10,000; LearningPrograms == 9; SeedMetadata == 1

### 9.4 Where Is the Output Stored?

**Recommended: Git LFS**

The `seed.db.gz` file (~50 MB) is too large for regular git but fits well in Git LFS:

```
# .gitattributes
assets/seed.db.gz filter=lfs diff=lfs merge=lfs -text
```

**Alternative: Release artifact only**

Store in GitHub Releases or a build artifact bucket. Download during CI release builds. This keeps the repo smaller but adds a download step.

**Recommendation:** Git LFS for simplicity. The file changes infrequently (monthly at most), and having it in the repo means `flutter build` always has access to the asset without extra download steps.

### 9.5 Version Sidecar File

In addition to `assets/seed.db.gz`, ship a small sidecar file `assets/seed_version.json`:

```json
{
  "version": 1,
  "buildDate": "2026-03-29T12:00:00Z",
  "contentHash": "a1b2c3..."
}
```

This allows the `SeedManager` to check version without decompressing the full seed.db.gz. On app launch:

1. Read `seed_version.json` from assets (instant, tiny file)
2. Read `version` from installed `content.db`'s `seed_metadata` table
3. Compare. Only decompress if bundled version is newer.

---

## 10. Tool Command-Line Interface

```
Usage: dart run tool/seed_content_db.dart [options]

Options:
  --build              Full build: fetch + populate + compress (default)
  --validate-only      Validate existing build/seed.db against schema
  --text-only          Only populate TextCache (skip calendar/programs)
  --calendar-only      Only populate CalendarCycles (skip text)
  --programs-only      Only populate LearningPrograms + TestDates
  --curriculum <name>  Only fetch text for one curriculum (e.g., bavli)
  --resume             Resume interrupted fetch (default: true)
  --no-resume          Start fresh, ignoring previous progress
  --output <path>      Output directory (default: build/)
  --seed-version <n>   Seed version number (default: auto-increment)
  --verbose            Verbose logging
```

### Execution Phases

A full `--build` runs these phases in order:

```
Phase 1: Initialize
  - Delete existing build/seed.db (unless --resume)
  - Create ContentDatabase backed by build/seed.db
  - Drift creates schema via onCreate -> createAll()

Phase 2: Seed Programs + TestDates
  - Insert 9 LearningPrograms
  - Insert ~50 TestDates
  - Fast: < 1 second

Phase 3: Fetch + Insert Text Content
  - Scan hierarchy JSONs for leaf items
  - Skip already-inserted refs (resume)
  - Fetch from Sefaria API in batches of 5
  - Insert via Drift batch API
  - Duration: ~3 hours for full corpus

Phase 4: Fetch + Insert Calendar Cycles
  - Query Sefaria/Hebcal APIs day-by-day
  - Insert cycle entries
  - Duration: ~30 minutes

Phase 5: Finalize
  - Insert SeedMetadata (version, hash, counts)
  - Run VACUUM to optimize DB file
  - Close database
  - Gzip compress -> build/seed.db.gz
  - Write build/seed_version.json sidecar
  - Print summary: file sizes, row counts, duration
```

---

## 11. Runtime: SeedManager

The `SeedManager` is a service class that runs before any content queries. It ensures `content.db` exists and is up-to-date.

### 11.1 Class Design

```
lib/core/database/seed_manager.dart

class SeedManager {
  /// Call once during app startup, before creating ContentDatabase provider.
  /// Returns the path to the ready-to-use content.db file.
  Future<String> ensureContentDatabase() async { ... }
}
```

### 11.2 Algorithm

```
ensureContentDatabase():
  1. contentDbPath = join(appDatabaseDir, 'content.db')
  2. bundledVersion = readAssetJson('assets/seed_version.json')['version']

  3. if file exists at contentDbPath:
       a. Open content.db, read: SELECT version FROM seed_metadata WHERE id = 1
       b. if installedVersion >= bundledVersion:
            return contentDbPath  // already up to date
       c. Close content.db
       d. Delete content.db
       e. // Fall through to decompress

  4. // First launch or upgrade
     a. Read 'assets/seed.db.gz' as bytes from Flutter asset bundle
     b. Decompress with GZipCodec (streaming to avoid OOM)
     c. Write decompressed bytes to contentDbPath
     d. return contentDbPath
```

### 11.3 Streaming Decompression

To avoid loading the entire uncompressed DB (~300 MB) into memory:

```dart
final input = await rootBundle.load('assets/seed.db.gz');
final gzipDecoder = GZipDecoder();
// Use dart:io's gzip transform on a stream:
final inputStream = Stream.value(input.buffer.asUint8List());
final decompressed = inputStream.transform(gzip.decoder);
final sink = File(contentDbPath).openWrite();
await decompressed.pipe(sink);
```

This streams chunks from the compressed asset through the gzip decoder to disk, keeping memory usage bounded (~1-2 MB buffer).

### 11.4 Integration with App Startup

```
main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Step 1: Ensure content DB is ready
  final seedManager = SeedManager();
  final contentDbPath = await seedManager.ensureContentDatabase();

  // Step 2: Open databases
  final contentDb = ContentDatabase(NativeDatabase(File(contentDbPath),
      setup: (db) { db.execute('PRAGMA query_only = ON'); }));
  final userDb = UserDatabase(NativeDatabase(...));

  // Step 3: Run app with both databases available
  runApp(ProviderScope(
    overrides: [
      contentDatabaseProvider.overrideWithValue(contentDb),
      userDatabaseProvider.overrideWithValue(userDb),
    ],
    child: const App(),
  ));
}
```

Key detail: the content DB is opened with `PRAGMA query_only = ON` to enforce read-only access at the SQLite level.

### 11.5 Edge Cases

| Scenario | Handling |
|----------|----------|
| First launch, no content.db | Decompress from assets. ~2-5 sec. Show splash screen. |
| App update with new seed version | Delete old content.db, decompress new. ~2-5 sec on update. |
| App update with same seed version | No-op. Instant launch. |
| Decompression interrupted (kill/crash) | Partial content.db file on disk. On next launch, open fails or version read fails. Delete and re-decompress. |
| Disk full during decompression | Catch IOException. Show user-facing error: "Not enough storage space." |
| Corrupted content.db (bit rot) | Query fails at runtime. SeedManager can re-decompress on demand (manual "repair" option in settings). |

### 11.6 Corruption Recovery

Add a method `SeedManager.repairContentDatabase()` that unconditionally re-decompresses from assets. Wire this to a "Repair content database" option in app settings, and call it automatically if `ContentDatabase` throws a `SqliteException` during initialization.

---

## 12. ContentDatabase Drift Class

### 12.1 Table Inventory

```dart
@DriftDatabase(
  tables: [
    TextCache,          // existing table, shared with old AppDatabase
    CalendarCycles,     // new table
    LearningPrograms,   // existing table, shared
    TestDates,          // existing table, shared
    SeedMetadata,       // new table
  ],
  daos: [
    ContentTextCacheDao,
    ContentCalendarCycleDao,
    ContentLearningProgramDao,
    ContentTestDateDao,
  ],
)
class ContentDatabase extends _$ContentDatabase {
  ContentDatabase(super.e);

  @override
  int get schemaVersion => 1;
}
```

### 12.2 Shared Table Files

The existing `tables/text_cache.dart`, `tables/learning_programs.dart`, and `tables/test_dates.dart` are imported by BOTH `ContentDatabase` and `UserDatabase` (the renamed AppDatabase). Drift generates separate `.g.dart` files for each database, so there is no conflict. The table _definitions_ are shared Dart source; the _generated accessors_ are per-database.

Note: During the two-database split (Phase 1 of the offline-first work), `LearningPrograms` and `TestDates` will move from UserDatabase to ContentDatabase. The UserDatabase will no longer include them.

### 12.3 Content DAOs

Content DAOs are read-only wrappers (for the app). The build tool uses Drift's `into().insert()` and `batch()` APIs directly, so it does not need DAOs.

Example content DAO:

```dart
@DriftAccessor(tables: [CalendarCycles])
class ContentCalendarCycleDao extends DatabaseAccessor<ContentDatabase>
    with _$ContentCalendarCycleDaoMixin {
  ContentCalendarCycleDao(super.db);

  /// Get today's learning for a program.
  Future<CalendarCycleData?> getEntry(String programName, int dayIndex) =>
    (select(calendarCycles)
      ..where((t) => t.programName.equals(programName) & t.dayIndex.equals(dayIndex)))
    .getSingleOrNull();

  /// Get full cycle for a program (for UI display of upcoming schedule).
  Future<List<CalendarCycleData>> getFullCycle(String programName) =>
    (select(calendarCycles)
      ..where((t) => t.programName.equals(programName))
      ..orderBy([(t) => OrderingTerm.asc(t.dayIndex)]))
    .get();
}
```

---

## 13. File Inventory

### New Files

| File | Purpose |
|------|---------|
| `lib/core/database/content_database.dart` | ContentDatabase Drift class (5 tables, read-only) |
| `lib/core/database/content_database.g.dart` | Generated by build_runner |
| `lib/core/database/tables/calendar_cycles.dart` | CalendarCycles table definition |
| `lib/core/database/tables/seed_metadata.dart` | SeedMetadata table definition |
| `lib/core/database/daos/content_text_cache_dao.dart` | Read-only DAO for text lookups |
| `lib/core/database/daos/content_calendar_cycle_dao.dart` | Read-only DAO for cycle lookups |
| `lib/core/database/daos/content_learning_program_dao.dart` | Read-only DAO for program lookups |
| `lib/core/database/daos/content_test_date_dao.dart` | Read-only DAO for test date lookups |
| `lib/core/database/seed_manager.dart` | First-launch decompression + version check |
| `tool/seed_content_db.dart` | Unified build tool (replaces seed_text_content.dart) |
| `assets/seed.db.gz` | Pre-built compressed Content DB (Git LFS) |
| `assets/seed_version.json` | Version sidecar for fast comparison |

### Modified Files

| File | Change |
|------|--------|
| `lib/core/database/app_database.dart` | Rename to UserDatabase; remove TextCache, LearningPrograms, TestDates, CalendarCache tables |
| `lib/core/database/seed/learning_program_seeds.dart` | Add api_source, api_program_key, is_calendar_program fields |
| `pubspec.yaml` | Add `assets/seed.db.gz` and `assets/seed_version.json` to assets list |
| `.gitattributes` | Add Git LFS tracking for seed.db.gz |
| `main.dart` | Add SeedManager initialization before database providers |

### Deprecated Files

| File | Disposition |
|------|-------------|
| `tool/seed_text_content.dart` | Superseded by `tool/seed_content_db.dart`; delete after new tool is validated |
| `lib/core/database/tables/text_download_status.dart` | Eliminated (all content bundled) |
| `lib/core/database/tables/content_download_statuses.dart` | Eliminated (all content bundled) |
| `lib/core/database/tables/calendar_cache.dart` | Replaced by calendar_cycles.dart |

---

## 14. Dependency Considerations

### Build Tool Dependencies

The build tool (`tool/seed_content_db.dart`) needs:

| Package | Purpose | Already in pubspec? |
|---------|---------|---------------------|
| `drift` | Database operations | Yes (dependency) |
| `drift/native.dart` | NativeDatabase for file-backed SQLite | Yes (via drift) |
| `sqlite3_flutter_libs` | SQLite native library | Yes (transitive) |
| `dio` | HTTP client for Sefaria/Hebcal | Yes (dependency) |
| `crypto` | SHA-256 for content hash | No -- add to dev_dependencies |
| `dart:convert` | JSON, gzip | Built-in |
| `dart:io` | File I/O | Built-in |

**Important:** The tool must NOT depend on Flutter. All imports must be pure Dart. The existing table definitions and Drift classes are pure Dart (no `package:flutter` imports), so this works naturally.

However, `sqlite3_flutter_libs` provides the native SQLite library for Flutter apps. For the CLI tool, we need `sqlite3` (the pure Dart FFI package) instead. Add `sqlite3: ^2.0.0` to dev_dependencies for the build tool to find the native SQLite library on the developer's machine.

---

## 15. Testing Strategy

### 15.1 Unit Tests for SeedManager

- Test version comparison logic (bundled > installed, bundled == installed, no content.db)
- Test decompression produces valid SQLite file
- Test corruption recovery flow
- Use in-memory databases or temp files

### 15.2 Integration Test for Build Tool

A CI test that:

1. Runs the build tool with `--programs-only` (fast, no API calls)
2. Opens the output with ContentDatabase
3. Verifies LearningPrograms has 9 rows
4. Verifies TestDates has expected rows
5. Verifies SeedMetadata is populated

### 15.3 Schema Match Test

A test that:

1. Creates ContentDatabase in-memory (via `NativeDatabase.memory()`)
2. Extracts `PRAGMA table_info()` for each table
3. Opens an existing `build/seed.db`
4. Compares table schemas column-by-column
5. Fails if any mismatch

This test runs in CI on every PR that touches table definitions.

### 15.4 Content Smoke Test

After a full build:

1. Open `build/seed.db`
2. Spot-check 10 known refs (e.g., `Berakhot 2a`) have non-empty Hebrew and English text
3. Verify CalendarCycles for Daf Yomi day 0 = `Berakhot 2a`
4. Verify row counts within expected ranges

---

## 16. Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Sefaria API changes break text fetch | Low | High | Pin API version (v3); monitor in CI; existing tool already handles this |
| Sefaria rate-limits more aggressively | Medium | Medium | Conservative rate limiting already in design; add exponential backoff |
| Calendar cycle data has irregularities | Medium | Medium | Reverse-engineer full cycle from API; validate against known reference dates |
| Compressed DB exceeds APK size limits | Low | High | APK limit is 150 MB; AAB has no limit with asset delivery. Use AAB. |
| Decompression OOM on low-end devices | Low | High | Streaming decompression (Section 11.3) keeps memory bounded |
| Schema drift between ContentDatabase and seed.db | Low | Critical | Build tool uses ContentDatabase class directly (Section 2); CI schema test |
| Long build time blocks releases | Medium | Medium | Resume support; can run incrementally; cache build artifacts |
| `sqlite3` FFI not available on dev machine | Low | Low | Document setup: `brew install sqlite3` / `apt install libsqlite3-dev` |

---

## 17. Open Questions

| # | Question | Impact | Proposed Resolution |
|---|----------|--------|---------------------|
| 1 | Exact cycle lengths and epoch dates for all 12 programs | Blocks calendar population | Discover by querying APIs during first build; document results |
| 2 | Should CalendarCycles store display names or just refs? | DB size | Include display names -- saves a cross-table join at runtime |
| 3 | Should the tool support incremental content updates (add new refs without full rebuild)? | Dev velocity | Not for v1. Full rebuild is ~3.5 hours and runs infrequently. |
| 4 | Git LFS vs release artifact for seed.db.gz storage | CI complexity | Start with Git LFS; migrate to release artifacts if repo size becomes an issue |
| 5 | Should `sqlite3` native binary be vendored for reproducible builds? | CI reproducibility | Use system sqlite3 initially; vendor if CI issues arise |

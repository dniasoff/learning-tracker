# Seed Content DB — Full Build & Verification Guide

> Run on a machine with Flutter/Dart installed. Working directory: `learning_tracker/`

## Background

The app ships a pre-built SQLite database (`assets/db/content.db.gz`) containing:

| Table | Purpose | Expected rows |
|-------|---------|---------------|
| `learning_programs` | 18 program presets (Oraysa, Daf Yomi, Rambam, etc.) | 18 |
| `test_dates` | Test dates 24 months ahead | ~44 |
| `calendar_cycles` | Daily program assignments (2024-01-01 to 2030-12-31) | ~30,000+ |
| `text_cache` | Hebrew + English texts from Sefaria | ~52,528 |
| `seed_metadata` | Build version, date, content hash | 1 |

The previous build (v2, 2026-04-11) was **incomplete**:
- Calendar cycles only covered 9 Sefaria programs through 2026-09-30 (should be 2030-12-31)
- 3 Hebcal programs missing entirely (Nach Yomi, Chofetz Chaim Daily, Kitzur SA)
- Text cache was empty (0 rows)

---

## Step 1: Fresh Full Build

```bash
cd learning_tracker

# Clean slate, verbose output, size report at end
dart run tool/seed_content_db.dart --build --no-resume --verbose --size-report
```

### What to expect

| Phase | What it does | Duration | Network |
|-------|-------------|----------|---------|
| Phase 2 | Seeds LearningPrograms + TestDates | Instant | None |
| Phase 3 | Fetches ~52,528 texts from Sefaria API | **3-5 hours** | ~52K requests |
| Phase 4 | Fetches calendar cycles (Sefaria + Hebcal) | **20-30 min** | ~2,500 + ~84 requests |
| Phase 5 | Computes SHA-256 hash, writes SeedMetadata | Instant | None |
| Phase 6 | VACUUM, gzip, copy to assets/db/ | Seconds | None |

### If you want to skip the long text fetch initially

Run calendar + programs first to verify Hebcal works, then text separately:

```bash
# Quick run — programs + calendar only (~30 min)
dart run tool/seed_content_db.dart --programs-only --verbose
dart run tool/seed_content_db.dart --calendar-only --verbose --size-report

# Verify Hebcal worked (see Step 2), then:
dart run tool/seed_content_db.dart --text-only --verbose --size-report
```

**Resume support**: If the text fetch is interrupted, re-run with `--resume` (default) to continue where it left off:

```bash
dart run tool/seed_content_db.dart --text-only --resume --verbose
```

---

## Step 2: Verify the Build

### 2a. Built-in validation

```bash
dart run tool/seed_content_db.dart --validate-only
```

This checks:
- All 5 tables exist
- SeedMetadata row present
- LearningPrograms = 18
- TextCache >= 50,000 (if any rows present)
- CalendarCycles >= 10,000 (if any rows present)

### 2b. Manual spot-checks with sqlite3

```bash
sqlite3 build/seed.db
```

**Check row counts:**
```sql
SELECT 'learning_programs', COUNT(*) FROM learning_programs
UNION ALL SELECT 'test_dates', COUNT(*) FROM test_dates
UNION ALL SELECT 'calendar_cycles', COUNT(*) FROM calendar_cycles
UNION ALL SELECT 'text_cache', COUNT(*) FROM text_cache
UNION ALL SELECT 'seed_metadata', COUNT(*) FROM seed_metadata;
```

Expected:
- `learning_programs`: 18
- `test_dates`: ~44
- `calendar_cycles`: **30,000+** (was 9,003 — this is the key fix)
- `text_cache`: **~52,528** (was 0 — this is the other key fix)
- `seed_metadata`: 1

**Check all 12 calendar programs are present:**
```sql
SELECT program_key, COUNT(*), MIN(date_key), MAX(date_key)
FROM calendar_cycles
GROUP BY program_key
ORDER BY program_key;
```

Expected programs (all should have date range 2024-01-01 to 2030-12-31):

| Source | program_key | ~Rows per program |
|--------|------------|-------------------|
| Sefaria | `arukh_hashulchan_yomi` | ~2,557 |
| Sefaria | `daf_a_week` | ~2,557 |
| Sefaria | `daf_yomi` | ~2,557 |
| Sefaria | `halakhah_yomit` | ~2,557 |
| Sefaria | `mishna_yomit` | ~2,557 |
| Sefaria | `rambam_1_chapter` | ~2,557 |
| Sefaria | `rambam_3_chapters` | ~2,557 |
| Sefaria | `tanakh_yomi` | ~2,557 |
| Sefaria | `yerushalmi_yomi` | ~2,557 |
| **Hebcal** | **`nach_yomi`** | ~2,557 |
| **Hebcal** | **`chofetz_chaim_daily`** | ~2,557 |
| **Hebcal** | **`kitzur_shulchan_aruch_yomi`** | ~2,557 |

The last 3 Hebcal programs were **missing in the previous build** — confirm they have rows.

**Check text cache has content for each curriculum:**
```sql
-- Bavli (Talmud)
SELECT COUNT(*) FROM text_cache WHERE sefaria_ref LIKE 'Berakhot%' OR sefaria_ref LIKE 'Shabbat%';

-- Mishnah
SELECT COUNT(*) FROM text_cache WHERE sefaria_ref LIKE 'Mishnah%';

-- Chumash
SELECT COUNT(*) FROM text_cache WHERE sefaria_ref LIKE 'Genesis%' OR sefaria_ref LIKE 'Exodus%';

-- Nach
SELECT COUNT(*) FROM text_cache WHERE sefaria_ref LIKE 'Joshua%' OR sefaria_ref LIKE 'Psalms%';

-- Spot check a specific text has content
SELECT LENGTH(hebrew_text), LENGTH(english_text) FROM text_cache WHERE sefaria_ref = 'Berakhot 2a';
```

Both `hebrew_text` and `english_text` should be non-empty for most refs.

**Check for fetch errors:**
```bash
# The build tool writes failed refs here
cat build/seed_errors.log 2>/dev/null
wc -l build/seed_errors.log 2>/dev/null
```

Error rate must stay under 1% (threshold in tool). A few missing refs is acceptable.

---

## Step 3: Bump the Seed Version

After a successful full build, bump the version so `SeedManager` replaces the old DB on existing installs:

Edit `lib/core/database/seed_version.dart`:
```dart
const int bundledSeedVersion = 3;  // was 2
```

Then re-run the build with the new version:
```bash
dart run tool/seed_content_db.dart --build --resume --seed-version 3 --verbose
```

This updates the `seed_metadata` row without re-fetching everything.

---

## Step 4: Verify the Asset is Bundled

After the build completes, confirm the output was copied:

```bash
# Check the asset exists and is reasonably sized
ls -lh assets/db/content.db.gz

# Previous build was 210KB (nearly empty) — full build should be MUCH larger
# Expected: 30-60 MB compressed (52K texts + 30K calendar rows)
```

Check the sidecar:
```bash
cat build/seed_version.json
```

Should show:
```json
{
  "version": 3,
  "buildDate": "2026-...",
  "contentHash": "...",
  "minAppVersion": "1.0.0"
}
```

---

## Step 5: Verify in APK

After building the app:

```bash
flutter build apk --release
```

Confirm the seed DB is included in the APK:

```bash
# Unzip and check
unzip -l build/app/outputs/flutter-apk/app-release.apk | grep content.db
```

Should show `assets/db/content.db.gz` with the expected file size (~30-60 MB).

### Runtime verification

On first launch (or after clearing app data), `SeedManager` will:
1. Detect no `content.db` exists
2. Decompress `content.db.gz` from assets
3. Log: `SeedManager: Seed extracted (XX.X MB)`

On upgrade from the old build:
1. Detect `bundledSeedVersion (3) > installed (2)`
2. Backup old content.db
3. Extract new seed
4. Verify metadata
5. Delete backup

---

## Troubleshooting

### Hebcal fetch failures (silent in previous build)

The `--verbose` flag surfaces Hebcal errors. Common issues:
- **Rate limiting**: The tool has 200ms delays between monthly batches; shouldn't be a problem
- **API format change**: Check that `response.data['items']` contains objects with `category`, `date`, `link`, `title` keys
- **Network timeout**: Hebcal receive timeout is 60s; increase if needed

If Hebcal programs still show 0 rows after a `--calendar-only --verbose` run, check the console output for error messages.

### Text fetch takes too long

At ~5 concurrent requests with 200ms batch delay, expect ~10 texts/second = ~52,528 / 10 = ~87 minutes minimum. In practice, with network variance and rate limiting retries, **3-5 hours** is normal.

Use `--resume` to safely restart if interrupted.

### Build produces small content.db.gz

If the compressed output is under 1 MB, something went wrong — the text phase likely didn't run or failed silently. Check:
- `build/seed_errors.log` for failed refs
- Console output for Phase 3 progress
- Run `--validate-only` to see row counts

### Daf Yomi Cycle 15 (post 2027-06-07)

The `_dafYomiSequence` list in the tool is currently empty, so Daf Yomi entries after 2027-06-07 won't have refs. This is acceptable for now — the Sefaria API covers through Cycle 14 end. A future update will populate the sequence for Cycle 15.

---

## Appendix A: Verifying Programs Are Visible in the App

The seed DB has programs, but **can the user actually see them?** Here's how the chain works and what to verify at each link.

### How programs surface to users

```
content.db.gz (asset) 
  → SeedManager extracts to content.db on first launch
    → ContentDatabase.openReadOnly(file) 
      → contentDatabaseProvider (Riverpod)
        → ProgramSelectionStep reads contentLearningProgramDao.getProgramsByCurriculumType(curriculum)
          → Displays program cards in Add Track flow (Step 2)
```

The user flow is: **Add Track → pick curriculum → program selection step → pick program or self-paced**.

### The 18 seeded programs and which curriculum screens they appear on

| Curriculum | Programs shown | Calendar-linked? |
|-----------|---------------|-----------------|
| Bavli (`bavli`) | Oraysa, Dirshu Kinyan Torah, Dirshu Amud HaYomi, Daf Yomi, Daf a Week | Daf Yomi, Daf a Week |
| Mishnayos (`mishnayos`) | Mishnah Yomis | Yes |
| Nach (`nach`) | Nach Yomi | Yes |
| Yerushalmi (`yerushalmi`) | Dirshu Kinyan Yerushalmi, Yerushalmi Yomi | Yerushalmi Yomi |
| Mishna Berurah (`mishna_berurah`) | Dirshu Daf HaYomi B'Halacha, Halakhah Yomit, Arukh HaShulchan Yomi, Kitzur SA Yomi | Last 3 calendar-linked |
| Mussar (`mussar`) | Dirshu Kinyan Chochma, Chofetz Chaim Daily | Chofetz Chaim Daily |
| Torah (`torah`) | Rambam - 1 Chapter, Rambam - 3 Chapters | Yes (both) |
| Tanach (`tanach`) | Tanakh Yomi | Yes |
| **Chumash (`chumash`)** | **NONE — auto-skips to self-paced** | — |

### What to test in the app

1. **Clear app data** (or fresh install) to force SeedManager to re-extract
2. Open Talker/debug logs — confirm you see:
   - `SeedManager: Seed extracted (XX.X MB)` or `Content DB up to date`
   - No `SeedManager initialization failed` error
3. **Add a Bavli track** — Step 2 should show 4 program cards (Oraysa, Dirshu KT, Dirshu AH, Daf Yomi)
4. **Add a Mishnayos track** — Step 2 should show Mishnah Yomis
5. **Add a Nach track** — Step 2 should show Nach Yomi
6. **Add a Chumash track** — Step 2 should auto-skip (no programs seeded for chumash)

### Known gap: read-only DB blocks upsert

`ContentDatabase.openReadOnly()` sets `PRAGMA query_only = ON` **before** Drift's `beforeOpen` callback runs. The `beforeOpen` callback tries to `INSERT OR REPLACE` programs, which will **fail silently** (caught by `catch (_)`). This is fine as long as the seed DB already contains the programs from the build tool. But it means:

- If the seed DB is missing programs (build issue), the runtime upsert **cannot fix it**
- The only fix is rebuilding the seed DB correctly and shipping a new version

### Fixed: all 12 calendar programs now have seed entries

All 12 `CalendarProgramRegistry` entries now have matching `LearningProgram` rows in the seed data. The 9 new entries were added to `learning_program_seeds.dart` and the registry's `curriculumType` mismatch (`'mishnaBerurah'` → `'mishna_berurah'`) was fixed.

### If programs don't appear at all

If Step 2 auto-skips for a curriculum that SHOULD have programs (e.g., Bavli), the issue is likely:

1. **SeedManager failed silently** — check Talker logs for errors during startup
2. **content.db.gz too small** — the 210KB build has programs but double-check with sqlite3
3. **ContentDatabase provider not initialized** — would throw `UnimplementedError` (check logs)
4. **`getProgramsByCurriculumType()` returns empty** — curriculum_type mismatch between CurriculumId.storageKey and seed data

To debug, add a temporary log in `ProgramSelectionStep.initState()`:
```dart
_programsFuture.then((programs) {
  debugPrint('ProgramSelectionStep: ${widget.curriculumId.storageKey} → ${programs.length} programs');
  for (final p in programs) {
    debugPrint('  - ${p.name} (${p.displayName})');
  }
});
```

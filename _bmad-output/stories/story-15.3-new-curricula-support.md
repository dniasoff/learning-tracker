# Story 15.3 — New Curricula Support: Nach, Mussar, Halacha (DNI-111)

## Story Overview

Add three new curriculum types to the learning tracker: **Nach** (Prophets & Writings), **Mussar** (ethical/character works), and **Mishna Berurah** (already exists — see note below).

> **Important discovery:** `mishna_berurah` is already fully implemented in the codebase — it has an enum value in `CurriculumId`, a fetcher at `tool/lib/sefaria/mishna_berurah_fetcher.dart`, bundled JSON at `assets/content/mishna_berurah.json` (17,397 leaf items), hierarchy defaults, theme color, and content repository support. **This story should therefore focus on adding `nach` and `mussar` only.** The requirements doc's mention of "Mishna Berurah" may have been written before that curriculum was added.

### Content Hierarchies

| Curriculum | Level 1 | Level 2 | Level 3 | Level 4 | Leaf Unit | Est. Leaf Count |
|---|---|---|---|---|---|---|
| Nach | Section (Nevi'im/Ketuvim) | Sefer (Book) | Perek (Chapter) | — | Chapter | ~370 chapters |
| Mussar | Sefer | Section/Gate | Chapter | — | Chapter | ~500-800 chapters |

---

## Acceptance Criteria

- [ ] **AC1:** `CurriculumId` enum includes `nach` and `mussar` values with correct `storageKey`, `displayNameEn`, and `displayNameHe`
- [ ] **AC2:** Bundled content JSON exists at `assets/content/nach.json` and `assets/content/mussar.json` with valid schema (hierarchyConfig + items array)
- [ ] **AC3:** `CurriculumDefaults.hierarchyConfigs` includes entries for `nach` and `mussar` with correct level labels
- [ ] **AC4:** `CurriculumDefaults.defaultDailyTargets` includes entries for `nach` and `mussar`
- [ ] **AC5:** `ContentRepositoryImpl._getFilename()` maps the new enum values to their JSON filenames
- [ ] **AC6:** `AppTheme` defines distinct colors for `nach` and `mussar` and `getCurriculumColor()` handles them
- [ ] **AC7:** Onboarding curriculum selection screen shows all curricula including the two new ones
- [ ] **AC8:** Sefaria fetcher tools exist for nach and mussar (`tool/lib/sefaria/nach_fetcher.dart`, `tool/lib/sefaria/mussar_fetcher.dart`)
- [ ] **AC9:** `tool/seed_content.dart` includes the new fetchers in its pipeline
- [ ] **AC10:** `TextContentConfig.downloadUrl()` works for the new curricula (it already uses `curriculumStorageKey` generically — no change needed)
- [ ] **AC11:** All existing acceptance tests continue to pass (`make ci`)
- [ ] **AC12:** New story acceptance tests validate content loading for nach and mussar

---

## Architecture & Design Notes

### How Curricula Are Wired

The curriculum system is **enum-driven**. Adding a new curriculum requires touching every `switch` on `CurriculumId` — the Dart analyzer enforces exhaustiveness. Key touchpoints:

1. **`lib/core/enums/curriculum_id.dart`** — The `CurriculumId` enum. Every curriculum is a value here with a `storageKey` string, `displayNameEn`, and `displayNameHe`. All database columns and JSON content reference the `storageKey`.

2. **`lib/core/constants/curriculum_defaults.dart`** — `hierarchyConfigs` map (level labels per curriculum) and `defaultDailyTargets` map.

3. **`lib/core/theme/app_theme.dart`** — Color constants and `getCurriculumColor()` switch.

4. **`lib/features/content_browsing/data/repositories/content_repository_impl.dart`** — `_getFilename()` switch mapping enum to JSON filename.

5. **`assets/content/<key>.json`** — Bundled JSON loaded by `ContentRepositoryImpl` via Flutter's `rootBundle`.

6. **`tool/lib/sefaria/<name>_fetcher.dart`** — Fetcher class extending `SefariaFetcherBase`, used by `tool/seed_content.dart` to generate the bundled JSON.

7. **`tool/seed_content.dart`** — CLI entry point that runs all fetchers.

### Content Item Model

All curricula share the same `ContentItem` model (`lib/core/network/sefaria/models/content_item.dart`) with up to 4 hierarchy levels (`level1` through `level4`). Container nodes have `isLeaf: false`; trackable units have `isLeaf: true`.

### No Database Migration Needed

The `content_items` table uses `curriculumId` as a string column matching `CurriculumId.storageKey`. New curricula are stored with their new storage key strings — no schema migration is required.

### UI Auto-Discovery

The onboarding screen (`lib/features/onboarding/presentation/screens/onboarding_screen.dart`) iterates over `CurriculumId.values` (line 309), so new enum values automatically appear in the curriculum selection list. No UI code changes are needed beyond the enum and theme color additions.

---

## Content Data

### Nach (Prophets & Writings)

**Sefaria API:**
- Shape endpoint: `GET /api/shape/Tanakh` returns all Tanakh books
- Filter out Torah books (Genesis–Deuteronomy) which belong to `chumash`
- Remaining books are Nevi'im (Prophets) and Ketuvim (Writings)

**Sefaria Nach books (21 books):**

Nevi'im Rishonim: Joshua, Judges, I Samuel, II Samuel, I Kings, II Kings
Nevi'im Acharonim: Isaiah, Jeremiah, Ezekiel, Hosea, Joel, Amos, Obadiah, Jonah, Micah, Nahum, Habakkuk, Zephaniah, Haggai, Zechariah, Malachi
Ketuvim: Psalms, Proverbs, Job, Song of Songs, Ruth, Lamentations, Ecclesiastes, Esther, Daniel, Ezra, Nehemiah, I Chronicles, II Chronicles

**Hierarchy (3 levels):**
```
level1: Section — "Nevi'im" or "Ketuvim"
level2: Sefer   — e.g., "Joshua", "Psalms"
level3: Perek   — chapter number (leaf node)
```

**Sefaria refs:** `"Joshua 1"`, `"Psalms 23"`, etc.

**Storage key:** `nach`

**JSON structure example:**
```json
{
  "hierarchyConfig": {
    "curriculumId": "nach",
    "levelLabels": ["Section", "Sefer", "Perek"],
    "maxLevels": 3,
    "totalItems": 370
  },
  "items": [
    {
      "curriculumId": "nach",
      "level1": "Nevi'im",
      "displayNameHe": "נביאים",
      "displayNameEn": "Nevi'im",
      "sefariaRef": "Nevi'im",
      "sortOrder": 0,
      "isLeaf": false
    },
    {
      "curriculumId": "nach",
      "level1": "Nevi'im",
      "level2": "Joshua",
      "displayNameHe": "יהושע",
      "displayNameEn": "Joshua",
      "sefariaRef": "Joshua",
      "sortOrder": 1,
      "isLeaf": false
    },
    {
      "curriculumId": "nach",
      "level1": "Nevi'im",
      "level2": "Joshua",
      "level3": "1",
      "displayNameHe": "יהושע 1",
      "displayNameEn": "Joshua 1",
      "sefariaRef": "Joshua 1",
      "sortOrder": 2,
      "isLeaf": true
    }
  ]
}
```

### Mussar (Ethical/Character Works)

**Sefaria API:**
Mussar works on Sefaria are individual books, not a unified category with a shape endpoint. Each must be fetched individually.

**Core Mussar seforim available on Sefaria:**
- Mesillat Yesharim (Path of the Just) — 26 chapters
- Orchot Tzaddikim (Ways of the Righteous) — 28 gates
- Chovot HaLevavot (Duties of the Heart) — 10 gates, subdivided into chapters
- Shaarei Teshuvah (Gates of Repentance) — 4 gates, subdivided into sections
- Pele Yoetz — alphabetical entries
- Tomer Devorah — 10 chapters

**Hierarchy (3 levels):**
```
level1: Sefer    — e.g., "Mesillat Yesharim"
level2: Section  — e.g., "Gate 1" or "Chapter 1" (varies by sefer)
level3: Chapter  — subsection number (leaf node, where applicable)
```

For seforim without subsections (e.g., Mesillat Yesharim where each chapter is a single unit), level2 is the leaf.

**Sefaria refs:**
- `"Mesillat Yesharim 1"` (chapter)
- `"Orchot Tzaddikim, Introduction"`, `"Orchot Tzaddikim, Gate of Truth"`
- `"Duties of the Heart, First Treatise on Unity 1"`

**Storage key:** `mussar`

**Special considerations:**
- Unlike Talmud/Nach which have uniform structure, Mussar seforim each have unique internal organization
- The fetcher will need per-book logic to handle Sefaria's varying response formats
- Start with the most popular 4-6 seforim; more can be added later
- Shape endpoint: `GET /api/shape/<book_title>` for each individual book

---

## Implementation Steps

### Step 1: Extend the CurriculumId enum

**File:** `lib/core/enums/curriculum_id.dart`

Add two new enum values:
```dart
nach('nach'),
mussar('mussar'),
```

Add `displayNameEn` and `displayNameHe` cases:
- Nach: `'Nach'` / `'נ"ך'`
- Mussar: `'Mussar'` / `'מוסר'`

This will cause exhaustiveness errors across the codebase — fix each in subsequent steps.

### Step 2: Add hierarchy defaults and daily targets

**File:** `lib/core/constants/curriculum_defaults.dart`

```dart
CurriculumId.nach: CurriculumHierarchyDefaults(
  level1Label: 'Section',
  level2Label: 'Sefer',
  level3Label: 'Perek',
  maxLevels: 3,
),
CurriculumId.mussar: CurriculumHierarchyDefaults(
  level1Label: 'Sefer',
  level2Label: 'Section',
  level3Label: 'Chapter',
  maxLevels: 3,
),
```

Daily targets:
```dart
CurriculumId.nach: 1,   // 1 perek per day
CurriculumId.mussar: 1, // 1 chapter per day
```

### Step 3: Add theme colors

**File:** `lib/core/theme/app_theme.dart`

Add color constants:
```dart
static const Color curriculumNach = Color(0xFF1ABC9C);       // Teal
static const Color curriculumMussar = Color(0xFF9B59B6);     // Violet
```

Add cases to `getCurriculumColor()`.

### Step 4: Update ContentRepositoryImpl filename mapping

**File:** `lib/features/content_browsing/data/repositories/content_repository_impl.dart`

Add cases to `_getFilename()`:
```dart
case CurriculumId.nach:
  return 'nach.json';
case CurriculumId.mussar:
  return 'mussar.json';
```

### Step 5: Fix all remaining exhaustiveness errors

Run `dart analyze` and fix every `switch` on `CurriculumId` that is now non-exhaustive. Expected files include but are not limited to:
- `lib/core/widgets/curriculum_indicator.dart` (uses `getCurriculumColorByKey` — no direct switch, should work)
- Any other file with a direct `switch (curriculum)` on the enum

### Step 6: Create Nach fetcher

**File:** `tool/lib/sefaria/nach_fetcher.dart`

- Extend `SefariaFetcherBase`
- `curriculumId` returns `CurriculumId.nach.storageKey`
- `fetchAllContent()`:
  1. Call `fetchShape('Tanakh')` (same as `ChumashFetcher`)
  2. Filter OUT the 5 Torah books (Genesis–Deuteronomy)
  3. Group remaining into Nevi'im and Ketuvim sections
  4. For each book: add section container (level1), book container (level1+level2), then chapter leaves (level1+level2+level3)
  5. Chapter is the leaf unit (`isLeaf: true`)

Reference: `ChumashFetcher` at `tool/lib/sefaria/chumash_fetcher.dart` already parses the same Tanakh shape API.

**Nevi'im books (in Sefaria order):** Joshua, Judges, I Samuel, II Samuel, I Kings, II Kings, Isaiah, Jeremiah, Ezekiel, Hosea, Joel, Amos, Obadiah, Jonah, Micah, Nahum, Habakkuk, Zephaniah, Haggai, Zechariah, Malachi

**Ketuvim books (in Sefaria order):** Psalms, Proverbs, Job, Song of Songs, Ruth, Lamentations, Ecclesiastes, Esther, Daniel, Ezra, Nehemiah, I Chronicles, II Chronicles

### Step 7: Create Mussar fetcher

**File:** `tool/lib/sefaria/mussar_fetcher.dart`

- Extend `SefariaFetcherBase`
- `curriculumId` returns `CurriculumId.mussar.storageKey`
- `fetchAllContent()`:
  1. Define a list of Mussar book titles (Sefaria index names)
  2. For each book, call `fetchBookShape(title)` to get chapter counts
  3. Build hierarchy: sefer (level1) -> section/gate (level2) -> chapter (level3, leaf)
  4. For simple books (no subsections), level2 is the leaf

**Initial Mussar seforim and their Sefaria index names:**
| Sefer | Sefaria Index | Structure |
|---|---|---|
| Mesillat Yesharim | `Mesillat Yesharim` | 26 chapters (flat — chapter is leaf at level2) |
| Orchot Tzaddikim | `Orchot Tzaddikim` | ~28 gates (flat — gate is leaf at level2) |
| Chovot HaLevavot | `Duties of the Heart` | 10 treatises -> chapters (level2=treatise, level3=chapter leaf) |
| Shaarei Teshuvah | `Shaarei Teshuvah` | 4 gates -> sections |
| Tomer Devorah | `Tomer Devorah` | 10 chapters (flat) |

For flat books (Mesillat Yesharim, Orchot Tzaddikim, Tomer Devorah), use 2 hierarchy levels and make level2 the leaf:
```json
{ "level1": "Mesillat Yesharim", "level2": "1", "isLeaf": true }
```

For books with subsections (Chovot HaLevavot, Shaarei Teshuvah), use 3 levels with level3 as leaf.

### Step 8: Update seed_content.dart

**File:** `tool/seed_content.dart`

Add imports and fetcher entries:
```dart
import 'lib/sefaria/nach_fetcher.dart';
import 'lib/sefaria/mussar_fetcher.dart';

// In fetchers list:
(NachFetcher(dio: dio), 'nach.json'),
(MussarFetcher(dio: dio), 'mussar.json'),
```

### Step 9: Generate bundled JSON

Run:
```bash
cd learning_tracker
dart run tool/seed_content.dart
```

This generates `assets/content/nach.json` and `assets/content/mussar.json`.

The `pubspec.yaml` asset declaration at `assets/content/` (line 93) uses a directory wildcard, so new JSON files are automatically included — no pubspec change needed.

### Step 10: Run build_runner for code generation

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Step 11: Validate

```bash
make analyze
make format-check
make ci
```

---

## Dev Notes

### Sefaria API Specifics

- **Base URL:** `https://www.sefaria.org`
- **Shape API:** `GET /api/shape/<category_or_title>` — returns chapter counts per book
- **Text API:** `GET /api/v3/texts/<ref>` — returns Hebrew + English text (already handled by `SefariaFetcherBase.fetchText()`)
- **Rate limiting:** Sefaria has no documented rate limit but be respectful; the seed script runs serially per fetcher
- **Nach via Tanakh:** The existing `ChumashFetcher` already calls `/api/shape/Tanakh` and filters to Torah. `NachFetcher` will call the same endpoint and filter to everything else.
- **Mussar books:** Each fetched individually via `/api/shape/<title>`. Some return a flat list of chapter lengths; others return nested structures. The fetcher must handle both.

### Sefaria Ref Format for Nach

Sefaria references for Nach follow the pattern `"<Book> <Chapter>"`:
- `"Joshua 1"`, `"Joshua 2"`, ..., `"Joshua 24"`
- `"Psalms 1"`, ..., `"Psalms 150"`
- `"Song of Songs 1"`, ..., `"Song of Songs 8"`

For text display, the ref `"Joshua 1"` fetches the entire chapter.

### Sefaria Ref Format for Mussar

Varies by book:
- `"Mesillat Yesharim 1"` — chapter number
- `"Duties of the Heart, First Treatise on Unity 1"` — treatise name + chapter
- `"Orchot Tzaddikim, Gate of Truth"` — gate name

The fetcher must use the `fetchBookShape()` response to determine the correct ref format for each book.

### Existing Pattern to Follow

The `MishnaBerurahFetcher` (`tool/lib/sefaria/mishna_berurah_fetcher.dart`) is the best reference for a 3-level fetcher. The `ChumashFetcher` shows how to parse `fetchShape('Tanakh')` and will share the exact same API call as `NachFetcher`.

---

## Test Plan

### Unit Tests

1. **NachFetcher test** (`test/tool/sefaria/nach_fetcher_test.dart`):
   - Mock Dio responses with sample Tanakh shape data
   - Verify Torah books are excluded
   - Verify correct hierarchy: Section -> Sefer -> Perek
   - Verify leaf count matches expected chapter total
   - Verify sefariaRef format is correct

2. **MussarFetcher test** (`test/tool/sefaria/mussar_fetcher_test.dart`):
   - Mock Dio responses for each Mussar book
   - Verify hierarchy for flat books (2-level) and nested books (3-level)
   - Verify leaf count matches expected totals

3. **ContentRepositoryImpl test** — verify `_getFilename()` returns correct filenames for new curricula

4. **CurriculumDefaults test** — verify hierarchy configs exist for new curricula

### Integration Tests

5. **Content loading test**: Load `nach.json` and `mussar.json` through `ContentRepositoryImpl`, verify:
   - `getContentForCurriculum()` returns non-empty list
   - `getHierarchyConfig()` returns correct level labels
   - `filterByLevel()` works for each hierarchy level
   - `search()` finds items by English and Hebrew name

### Story Acceptance Tests

6. **File:** `test/story_acceptance/epic_15_new_curricula_test.dart`
   - `group('Story 15.3: New Curricula Support')`:
     - Nach enum value exists with correct storageKey `'nach'`
     - Mussar enum value exists with correct storageKey `'mussar'`
     - Hierarchy defaults configured for both
     - Theme colors assigned for both
     - Content JSON loadable for both (mock rootBundle)
     - Daily targets configured for both
     - `CurriculumId.values.length` is 7 (5 existing + 2 new)

### Manual Testing

7. Run `dart run tool/seed_content.dart` and verify:
   - `assets/content/nach.json` generated with ~370 leaf items
   - `assets/content/mussar.json` generated with expected leaf count
   - JSON passes schema validation (built into seed script)

8. Launch app, go through onboarding:
   - All 7 curricula appear in selection
   - Selecting nach/mussar imports successfully
   - Content browsing shows correct hierarchy

---

## Files to Create/Modify

### Files to Modify

| File | Change |
|---|---|
| `lib/core/enums/curriculum_id.dart` | Add `nach` and `mussar` enum values with display names |
| `lib/core/constants/curriculum_defaults.dart` | Add hierarchy configs and daily targets for nach, mussar |
| `lib/core/theme/app_theme.dart` | Add color constants and switch cases for nach, mussar |
| `lib/features/content_browsing/data/repositories/content_repository_impl.dart` | Add `_getFilename()` cases for nach, mussar |
| `tool/seed_content.dart` | Add NachFetcher and MussarFetcher to fetcher pipeline |
| Any file with non-exhaustive `switch` on `CurriculumId` | Add missing cases (dart analyze will find these) |

### Files to Create

| File | Purpose |
|---|---|
| `tool/lib/sefaria/nach_fetcher.dart` | Sefaria fetcher for Nach content (extends SefariaFetcherBase) |
| `tool/lib/sefaria/mussar_fetcher.dart` | Sefaria fetcher for Mussar content (extends SefariaFetcherBase) |
| `assets/content/nach.json` | Bundled Nach content (generated by seed_content.dart) |
| `assets/content/mussar.json` | Bundled Mussar content (generated by seed_content.dart) |
| `test/story_acceptance/epic_15_new_curricula_test.dart` | Story acceptance tests |

### Files Requiring No Change (auto-work)

| File | Why |
|---|---|
| `pubspec.yaml` | `assets/content/` directory wildcard already covers new JSON files |
| `lib/features/onboarding/presentation/screens/onboarding_screen.dart` | Iterates `CurriculumId.values` — new values appear automatically |
| `lib/core/constants/text_content_config.dart` | Uses `curriculumStorageKey` generically — works for any key |
| `lib/core/network/sefaria/models/content_item.dart` | Generic model, no curriculum-specific logic |
| `lib/core/network/sefaria/models/curriculum_hierarchy_config.dart` | Generic model |
| `lib/core/network/sefaria/curriculum_content_fetcher.dart` | Abstract interface, no changes |
| Database tables/DAOs | String-based curriculum_id columns accept any value |

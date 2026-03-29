# Local Calendar Cycle Computation -- Deep Technical Analysis

**Date:** 2026-03-29
**Status:** Research Complete
**Author:** Analyst (automated research)

---

## 1. Sefaria Calendar API Analysis

### Endpoint

`GET https://www.sefaria.org/api/calendars?year=Y&month=M&day=D`

### Response Structure

```json
{
  "date": "2026-03-29",
  "timezone": "America/Halifax",
  "calendar_items": [
    {
      "title": { "en": "Daf Yomi", "he": "..." },
      "ref": "Menachot.77",
      "url": "Menachot.77",
      "category": "Talmud",
      "order": 3,
      "description": "..."
    }
  ]
}
```

Each entry has: `title.en`, `title.he`, `ref` (Sefaria ref string), `url`, `category`, `order`, optional `description`.

### Programs Returned by Sefaria (14 entries, only 10 are ours)

| # | Sefaria `title.en` | Our `apiKey` in Registry | Our `id` | Match? |
|---|--------------------|-----------------------------|----------|--------|
| 1 | Parashat Hashavua | -- | -- | Not tracked |
| 2 | Haftarah | -- | -- | Not tracked |
| 3 | **Daf Yomi** | `Daf Yomi` | `daf_yomi` | EXACT MATCH |
| 4 | 929 | -- | -- | Not tracked |
| 5 | **Daily Mishnah** | `Mishnah Yomit` | `mishna_yomit` | **MISMATCH** |
| 6 | **Daily Rambam** | `Daily Rambam 1 Chapter` | `rambam_1_chapter` | **MISMATCH** |
| 7 | **Daily Rambam (3 Chapters)** | `Daily Rambam 3 Chapters` | `rambam_3_chapters` | **MISMATCH** |
| 8 | **Daf a Week** | `Daf a Week` | `daf_a_week` | EXACT MATCH |
| 9 | **Halakhah Yomit** | `Halakhah Yomit` | `halakhah_yomit` | EXACT MATCH |
| 10 | **Arukh HaShulchan Yomi** | `Arukh HaShulchan Yomi` | `arukh_hashulchan_yomi` | EXACT MATCH |
| 11 | **Tanakh Yomi** | `Tanakh Yomi` | `tanakh_yomi` | EXACT MATCH |
| 12 | Chok LeYisrael | -- | -- | Not tracked |
| 13 | Tanya Yomi | -- | -- | Not tracked |
| 14 | **Yerushalmi Yomi** | `Yerushalmi Yomi` | `yerushalmi_yomi` | EXACT MATCH |

### CRITICAL BUG: Nach Yomi Is NOT on Sefaria

The registry defines `nach_yomi` with `apiSource: 'sefaria'` and `apiKey: 'Nach Yomi'`. However, Sefaria's `/calendars` endpoint **never returns a "Nach Yomi" entry**. Verified across multiple dates (Jan 2025, Mar 2026, Jun 2025). Nach Yomi is available only from **Hebcal** (category: `nachyomi`).

**Required fix:** Change `nach_yomi` in `CalendarProgramRegistry` from `apiSource: 'sefaria'` to `apiSource: 'hebcal'`, with `apiKey` updated to match Hebcal's category.

### CRITICAL BUG: Three apiKey Mismatches

The `_mapSefariaEntries` method in `CalendarProgramService` does `CalendarProgramRegistry.byApiKey(item.title.en)`. These three programs will never match:

| Our `apiKey` | Sefaria `title.en` | Result |
|---|---|---|
| `Mishnah Yomit` | `Daily Mishnah` | **Never matches** |
| `Daily Rambam 1 Chapter` | `Daily Rambam` | **Never matches** |
| `Daily Rambam 3 Chapters` | `Daily Rambam (3 Chapters)` | **Never matches** |

**Required fix:** Update the `apiKey` values in `CalendarProgramRegistry` to match the exact `title.en` strings from Sefaria.

---

## 2. Hebcal API Analysis

### Endpoint

`GET https://www.hebcal.com/hebcal?v=1&cfg=json&start=DATE&end=DATE&...flags...`

### Required Flags (per-program opt-in)

| Flag | Program |
|------|---------|
| `F=on` | Daf Yomi |
| `myomi=on` | Mishnah Yomit |
| `nyomi=on` | Nach Yomi |
| `dr1=on` | Daily Rambam 1 Chapter |
| `dr3=on` | Daily Rambam 3 Chapters |
| `dcc=on` | Chofetz Chaim Daily |
| `dksa=on` | Kitzur Shulchan Aruch Yomi |
| `dps=on` | Daily Psalms (not tracked by us) |

### CRITICAL BUG: Hebcal Client Missing Flags

The current `HebcalApiClient.fetchDailyLearning()` does NOT pass `dcc=on` or `dksa=on`. This means **Chofetz Chaim and Kitzur Shulchan Aruch entries are never fetched**. The two Hebcal-only programs in the registry are completely non-functional.

### Response Structure

```json
{
  "items": [
    {
      "title": "Hilchos LH 9.1-9.2",
      "date": "2026-03-29",
      "hdate": "11 Nisan 5786",
      "category": "chofetzChaim",
      "hebrew": "...",
      "link": "https://www.sefaria.org/Chofetz_Chaim%2C_...",
      "memo": "Part One, The Prohibition Against Lashon Hara 9.1-9.2"
    }
  ]
}
```

### Hebcal Category to Our ID Mapping

| Hebcal `category` | Our `id` | Our `apiKey` | Match Method |
|---|---|---|---|
| `dafyomi` | `daf_yomi` | `Daf Yomi` | Not by apiKey -- need category mapping |
| `mishnayomi` | `mishna_yomit` | `Mishnah Yomit` | Not by apiKey |
| `nachyomi` | `nach_yomi` | `Nach Yomi` | Not by apiKey |
| `dailyRambam1` | `rambam_1_chapter` | -- | Not by apiKey |
| `dailyRambam3` | `rambam_3_chapters` | -- | Not by apiKey |
| `chofetzChaim` | `chofetz_chaim_daily` | `Chofetz Chaim` | Not by apiKey |
| `kitzurShulchanAruch` | `kitzur_shulchan_aruch_yomi` | `Kitzur Shulchan Aruch` | Not by apiKey |

**Note:** The current Hebcal mapping code uses `CalendarProgramRegistry.byApiKey(item.title)` where `item.title` is the reading title (e.g., "Hilchos LH 9.1-9.2"), NOT the program name. This cannot work. The correct approach is to match by `item.category`.

### Extracting Sefaria Ref from Hebcal

Hebcal's `link` field contains a Sefaria URL. The ref can be extracted by URL-decoding the path component:
- `https://www.sefaria.org/Chofetz_Chaim%2C_Part_One%2C_...%2C_Principle_9.1?lang=bi&...`
- Decoded path: `Chofetz_Chaim,_Part_One,_The_Prohibition_Against_Lashon_Hara,_Principle_9.1`

For Kitzur, the link uses: `https://www.sefaria.org/Kitzur_Shulchan_Arukh.118.9-119:2?lang=bi&...`

The `memo` field on Chofetz Chaim provides a human-readable description but is not a valid Sefaria ref. The `link` field is the reliable source for refs.

---

## 3. Cycle Computation Feasibility -- Program by Program

### 3.1 Daf Yomi

| Property | Value |
|----------|-------|
| **Deterministic?** | Yes -- fixed sequence, no skips |
| **Epoch** | 2020-01-05 (Cycle 14 start, Berakhot 2) |
| **End date** | 2027-06-07 (Niddah 73, last day) |
| **Cycle length** | 2,711 days |
| **Computation** | `daysSince(2020-01-05) % 2711` -> lookup in ordered list |
| **Irregularities** | None. Every calendar day gets exactly one daf. |
| **Validation** | Confirmed: Jan 4, 2020 = Niddah 73 (end of Cycle 13), Jan 5 = Berakhot 2 (start of Cycle 14), Jun 7 2027 = Niddah 73 (end of Cycle 14). Jun 8 2027 onward: Sefaria stops returning Daf Yomi (inter-cycle gap or needs next cycle data). |

### 3.2 Yerushalmi Yomi

| Property | Value |
|----------|-------|
| **Deterministic?** | Yes -- fixed sequence |
| **Epoch** | 2022-11-14 (Cycle 1 start, Berakhot 1:1:1-7) |
| **Cycle length** | ~1,554 days (estimated, first cycle not yet completed as of 2026) |
| **Computation** | Lookup table. Cycle 1 is the first ever, so no prior data to verify wrap-around. |
| **Irregularities** | Unknown for cycle transitions -- this is the first cycle. The sequence within the cycle is deterministic. |
| **Ref format** | `Jerusalem_Talmud_Berakhot.1.1.1-7` -- halakhah-level granularity |

### 3.3 Mishna Yomit (Daily Mishnah)

| Property | Value |
|----------|-------|
| **Deterministic?** | Yes -- fixed sequence through all 6 orders of Mishnah |
| **Cycle length** | ~2,088 mishnayos / ~1,044 days (2 mishnayos per day) |
| **Computation** | Lookup table. Each day maps to 2 consecutive mishnayos. |
| **Ref format** | `Mishnah_Tamid.2.1-2` (chapter.mishnah range) |
| **Irregularities** | None known. Pure sequential cycle. |

### 3.4 Nach Yomi

| Property | Value |
|----------|-------|
| **Deterministic?** | Yes -- one chapter per day through all Nevi'im and Ketuvim |
| **Source** | Hebcal only (NOT Sefaria) |
| **Cycle length** | 929 days (929 chapters of Nach) |
| **Computation** | `daysSince(epoch) % 929` -> lookup |
| **Ref format** | Single book chapter: `I_Samuel.1`, `Judges.18`, etc. |
| **Irregularities** | None. Simple sequential through the canon. |

### 3.5 Rambam 1 Chapter

| Property | Value |
|----------|-------|
| **Deterministic?** | Yes -- one chapter per day through all of Mishneh Torah |
| **Cycle length** | 985 days (985 chapters in Mishneh Torah including Sefer HaMadda through Shoftim) |
| **Computation** | Lookup table |
| **Ref format** | `Mishneh_Torah,_Repentance.7` |
| **Irregularities** | None known. |

### 3.6 Rambam 3 Chapters

| Property | Value |
|----------|-------|
| **Deterministic?** | Yes -- three chapters per day |
| **Cycle length** | ~339 days (985 / 3, with some days covering partial chapters at book boundaries) |
| **Computation** | Lookup table (the exact grouping of 3 chapters per day is not always neat at book boundaries) |
| **Ref format** | `Mishneh_Torah,_Leavened_and_Unleavened_Bread.5-7` (range of chapters) |
| **Irregularities** | Some days may have 2 or 4 chapters depending on how book boundaries align. Must be captured empirically. |

### 3.7 Daf a Week

| Property | Value |
|----------|-------|
| **Deterministic?** | Yes -- same daf order as Daf Yomi, one per week |
| **Cycle length** | 2,711 weeks (same number of dappim) |
| **Computation** | `weeksSince(epoch)` -> lookup. Same sequence as Daf Yomi but weekly. |
| **Ref format** | `Nedarim.75` (same as Daf Yomi) |
| **Note** | This is a MUCH longer cycle (~52 years). The entire current cycle fits in the lookup table. |
| **Irregularities** | Need to verify: does the week advance on Shabbat or Sunday? Observed: Nedarim 74 on Mar 25 (Wed) and Mar 28 (Sat), Nedarim 75 on Mar 29 (Sun). Likely advances on Sunday (start of Jewish week). |

### 3.8 Halakhah Yomit

| Property | Value |
|----------|-------|
| **Deterministic?** | Yes -- but variable segment sizes |
| **Why "variable"?** | Each day covers a different number of se'ifim (sub-sections) of Shulchan Aruch, Orach Chayim. Some days cover 2 se'ifim, others 3-4. The day-to-ref mapping is NOT a simple formula. |
| **Cycle scope** | Progresses through Shulchan Aruch, Orach Chayim (and possibly other sections). |
| **Computation** | MUST be a lookup table. Cannot compute from formula because segment boundaries are editorial decisions. |
| **Ref format** | `Shulchan_Arukh,_Orach_Chayim.168.5-7` (siman.se'if range) |
| **Sample progression** | Mar 25: 168:5-7, Mar 26: 168:8-10, Mar 27: 168:11-13, Mar 28: 168:14-16, Mar 29: 168:17-169:2 |
| **Can it be pre-computed?** | YES. The sequence is deterministic for a given cycle. It just needs to be captured day-by-day from the API. |

### 3.9 Arukh HaShulchan Yomi

| Property | Value |
|----------|-------|
| **Deterministic?** | Yes -- but variable segment sizes (same pattern as Halakhah Yomit) |
| **Why "variable"?** | Each day covers a variable number of se'ifim of Arukh HaShulchan. |
| **Computation** | MUST be a lookup table. |
| **Ref format** | `Arukh_HaShulchan,_Orach_Chaim.277.3-8` |
| **Sample progression** | Mar 25: 275:15-276:5, Mar 26: 276:6-12, Mar 27: 276:13-277:2, Mar 28: 277:3-8, Mar 29: 277:9-279:1 |
| **Can it be pre-computed?** | YES. Same approach as Halakhah Yomit. |

### 3.10 Tanakh Yomi

| Property | Value |
|----------|-------|
| **Deterministic?** | Yes |
| **Cycle length** | ~929 entries (covers all of Tanakh) |
| **Ref format** | `Jeremiah.31.32-32.21` (verse-level ranges, not whole chapters) |
| **Irregularities** | Segment sizes vary (some days are 30 verses, others 50+). Lookup table required. |

### 3.11 Chofetz Chaim Daily

| Property | Value |
|----------|-------|
| **Deterministic?** | Yes -- annual Hebrew calendar cycle |
| **Epoch** | 1 Tishrei (Rosh Hashanah) each year |
| **Cycle type** | Hebrew year-aligned, NOT fixed Gregorian length |
| **Cycle length** | Variable: 354 days (regular), 355 (maleh), 383 (leap), 384 (leap maleh), 385 (leap shalem) |
| **Computation** | NOT `daysSince(epoch) % fixedLength`. Tied to Hebrew calendar. Must map Hebrew date to reading. |
| **Verified** | 1 Tishrei 5785 (Oct 3, 2024) = Hakdamah 1-4. 1 Tishrei 5786 (Sep 23, 2025) = Hakdamah 1-4. 1 Tishrei 5787 (Sep 12, 2026) = Hakdamah 1-4. |
| **Ref format** | Sefaria ref extracted from Hebcal link: `Chofetz_Chaim,_Part_One,_The_Prohibition_Against_Lashon_Hara,_Principle_9.1` |
| **Key complexity** | Hebrew leap years have ~30 extra days. The readings must stretch to cover the full year. The specific day-to-reading mapping changes between regular and leap years. |

### 3.12 Kitzur Shulchan Aruch Yomi

| Property | Value |
|----------|-------|
| **Deterministic?** | Yes -- annual Hebrew calendar cycle |
| **Epoch** | 1 Tishrei each year |
| **Cycle type** | Hebrew year-aligned, same as Chofetz Chaim |
| **Verified** | 1 Tishrei 5785 (Oct 3, 2024) = 133:17-21. 1 Tishrei 5787 (Sep 12, 2026) = 133:17-21. Same reading on 1 Tishrei across years. |
| **Note on starting chapter** | Starts at chapter 133 (Hilchot Rosh Hashanah) on 1 Tishrei, progresses through the remaining chapters, wraps to chapter 1, and arrives back at 133 by the next 1 Tishrei. Content aligns with time of year (learning relevant laws as holidays approach). |
| **Key complexity** | Same Hebrew leap year issue as Chofetz Chaim. |

---

## 4. Halakhah Yomit and Arukh HaShulchan -- "Variable" Cycles Explained

### Why They Were Flagged as Variable

Both programs cover texts (Shulchan Aruch and Arukh HaShulchan respectively) where each day's assignment spans a variable number of se'ifim (subsections). Unlike Daf Yomi where one daf = one page of fixed size, here the editorial allocation of se'ifim-per-day varies.

**Example -- Halakhah Yomit over 5 days:**
| Date | Ref | Se'ifim covered |
|------|-----|-----------------|
| Mar 25 | OC 168:5-7 | 3 se'ifim |
| Mar 26 | OC 168:8-10 | 3 se'ifim |
| Mar 27 | OC 168:11-13 | 3 se'ifim |
| Mar 28 | OC 168:14-16 | 3 se'ifim |
| Mar 29 | OC 168:17-169:2 | 4 se'ifim (crosses siman boundary) |

**Example -- Arukh HaShulchan Yomi over 5 days:**
| Date | Ref | Se'ifim covered |
|------|-----|-----------------|
| Mar 25 | OC 275:15-276:5 | 8 se'ifim (crosses siman) |
| Mar 26 | OC 276:6-12 | 7 se'ifim |
| Mar 27 | OC 276:13-277:2 | 5 se'ifim (crosses siman) |
| Mar 28 | OC 277:3-8 | 6 se'ifim |
| Mar 29 | OC 277:9-279:1 | 9+ se'ifim (crosses 2 simanim) |

### Can They Be Pre-Computed?

**YES, absolutely.** The day-to-ref mapping is deterministic within a cycle -- the same sequence repeats every cycle. The "variability" is in the segment sizes, not in unpredictability. The mapping was decided editorially when the program was created and does not change.

### Special Handling Needed

These programs require the **lookup table approach** (not formula-based). Each day index in the cycle maps to one specific ref string. The ref string itself encodes the variable segment boundaries. No special runtime logic is needed beyond the lookup.

### Cycle Length

Both programs are multi-year cycles through their respective texts:
- **Halakhah Yomit**: Covers Shulchan Aruch, Orach Chayim (697 simanim). At ~3 se'ifim/day, estimated ~1,400-1,800 days per cycle.
- **Arukh HaShulchan**: Covers Arukh HaShulchan, Orach Chaim. At ~6-8 se'ifim/day, estimated ~800-1,200 days per cycle.

Exact lengths must be captured empirically by iterating through the full cycle via API.

---

## 5. CalendarCycles Table Schema

### Recommended: One Row Per (program, date) -- Flat Lookup Table

```sql
CREATE TABLE calendar_cycles (
  program_id   TEXT    NOT NULL,  -- e.g. 'daf_yomi', 'halakhah_yomit'
  date         TEXT    NOT NULL,  -- ISO 8601: '2026-03-29'
  sefaria_ref  TEXT    NOT NULL,  -- e.g. 'Menachot.77', 'Shulchan_Arukh,_Orach_Chayim.168.5-7'
  display_text TEXT,              -- Human-readable: 'Menachot 77', 'OC 168:5-7'
  PRIMARY KEY (program_id, date)
);

CREATE INDEX idx_calendar_cycles_date ON calendar_cycles(date);
```

### Why Date-Keyed (Not day-index-keyed)

1. **Hebrew calendar programs (Chofetz Chaim, Kitzur SA)** have variable-length years. A day-index from a fixed epoch does not work because leap years insert extra days. Using Gregorian dates directly eliminates all Hebrew calendar math at query time.

2. **Query pattern is always "give me the ref for program X on date Y"**. A date key answers this with a single indexed lookup: `SELECT sefaria_ref FROM calendar_cycles WHERE program_id = ? AND date = ?`.

3. **No runtime cycle math needed.** No `daysSince(epoch) % cycleLength`, no Hebrew date conversion, no modular arithmetic. Pure key-value lookup.

4. **Uniform treatment of all 12 programs.** Fixed-length cycles (Daf Yomi), variable-segment cycles (Halakhah Yomit), and Hebrew-calendar cycles (Chofetz Chaim) all use the same table and same query.

### Why Not day-index Based?

A `day_index` column with `daysSince(epoch) % cycleLength` would work for simple cycles (Daf Yomi, Nach Yomi) but fails for:
- Chofetz Chaim / Kitzur SA (Hebrew year cycles, no fixed Gregorian length)
- Cross-cycle transitions where a new cycle starts

The date-keyed approach is slightly larger in storage but eliminates all edge cases.

### Row Count Estimate

| Program | Days to cover | Notes |
|---------|---------------|-------|
| daf_yomi | 2,711 | One cycle |
| yerushalmi_yomi | ~1,554 | First cycle (through ~2027) |
| mishna_yomit | ~1,044 | One cycle |
| nach_yomi | 929 | One cycle |
| rambam_1_chapter | 985 | One cycle |
| rambam_3_chapters | ~339 | One cycle |
| daf_a_week | ~2,711 | Same count, weekly (but store daily for week lookups) |
| halakhah_yomit | ~1,500 | Estimated |
| arukh_hashulchan_yomi | ~1,000 | Estimated |
| tanakh_yomi | ~929 | Estimated |
| chofetz_chaim_daily | ~384 | One Hebrew year (max leap year length) |
| kitzur_shulchan_aruch_yomi | ~384 | One Hebrew year |

**Practical approach:** Instead of storing exactly one cycle per program, store ALL dates from a generous window -- e.g., **2024-01-01 through 2030-12-31** (7 years, 2,557 days). This covers:
- Multiple full cycles of short programs (each row is small)
- Full current cycles of long programs (Daf Yomi, Yerushalmi)
- Multiple Hebrew year cycles for Chofetz Chaim / Kitzur

Total rows: 12 programs x 2,557 days = **~30,684 rows**

With ~100 bytes per row average, this is about **3 MB** uncompressed. Negligible in the context of a 260+ MB content database.

### Alternative Considered: JSON Array Per Program

```sql
-- REJECTED
CREATE TABLE calendar_cycles (
  program_id TEXT PRIMARY KEY,
  epoch_date TEXT,
  refs_json  TEXT  -- JSON array of all refs in order
);
```

This would require parsing a large JSON array at query time and computing the day index. It saves row count but adds complexity and is slower for lookups. Not recommended.

---

## 6. Reverse-Engineering Tool Design

### Architecture

The seed tool (`tool/seed_content_db.dart`) should include a `CalendarCycleSeeder` component that:

1. Iterates through every date in the target window (2024-01-01 to 2030-12-31)
2. For each date, fetches the calendar data from the appropriate API
3. Extracts the ref for each program
4. Inserts into the `calendar_cycles` table

### Sefaria Fetching Strategy

```
For each date in range:
  GET https://www.sefaria.org/api/calendars?year=Y&month=M&day=D
  Parse calendar_items
  For each of our 10 Sefaria programs:
    Find entry by title.en
    Extract ref
    Insert (program_id, date, ref, display_text)
```

**API key mapping (corrected):**

| Our program_id | Sefaria title.en to match |
|---|---|
| daf_yomi | `Daf Yomi` |
| yerushalmi_yomi | `Yerushalmi Yomi` |
| mishna_yomit | `Daily Mishnah` |
| rambam_1_chapter | `Daily Rambam` |
| rambam_3_chapters | `Daily Rambam (3 Chapters)` |
| daf_a_week | `Daf a Week` |
| halakhah_yomit | `Halakhah Yomit` |
| arukh_hashulchan_yomi | `Arukh HaShulchan Yomi` |
| tanakh_yomi | `Tanakh Yomi` |

**Note:** Nach Yomi is NOT on Sefaria. Only 9 programs come from Sefaria.

### Hebcal Fetching Strategy

```
For each date in range:
  GET https://www.hebcal.com/hebcal?v=1&cfg=json&start=DATE&end=DATE&c=off&dcc=on&dksa=on&nyomi=on
  Parse items
  For each of our 3 Hebcal programs (nach_yomi, chofetz_chaim_daily, kitzur_shulchan_aruch_yomi):
    Find entry by category
    Extract ref from link URL (for Chofetz Chaim and Kitzur) or construct from title (for Nach Yomi)
    Insert (program_id, date, ref, display_text)
```

**Hebcal category mapping:**

| Our program_id | Hebcal category |
|---|---|
| nach_yomi | `nachyomi` |
| chofetz_chaim_daily | `chofetzChaim` |
| kitzur_shulchan_aruch_yomi | `kitzurShulchanAruch` |

### Optimization: Batch Date Ranges for Hebcal

Hebcal supports `start=DATE&end=DATE` ranges. Instead of one request per day, batch into monthly chunks:

```
GET /hebcal?start=2024-01-01&end=2024-01-31&c=off&dcc=on&dksa=on&nyomi=on
```

This returns all items for the entire month in one request. For 7 years: ~84 requests instead of ~2,557.

Sefaria does NOT support date ranges -- each request returns one day's calendar. No batching possible.

### Rate Limiting

| API | Rate limit | Strategy |
|-----|-----------|----------|
| Sefaria | Undocumented, but known to throttle at ~2-3 req/sec | 500ms delay between requests |
| Hebcal | Generous, rarely throttles | 200ms delay between requests |

### Time Estimate

| API | Dates | Requests | Rate | Time |
|-----|-------|----------|------|------|
| Sefaria | 2,557 days | 2,557 | 2/sec | ~21 minutes |
| Hebcal | 2,557 days | ~84 (monthly) | 5/sec | ~17 seconds |
| **Total** | | | | **~22 minutes** |

### Validation Strategy

After seeding, run these checks:

1. **Completeness**: For each program, verify no date gaps in the expected range. Query: `SELECT date FROM calendar_cycles WHERE program_id = ? ORDER BY date` and check for missing dates.

2. **Continuity**: For sequential programs (Daf Yomi, Rambam), verify the sequence is monotonically advancing -- no repeated or skipped entries.

3. **Cross-source validation**: For programs available on BOTH Sefaria and Hebcal (Daf Yomi, Mishna Yomit, Rambam), fetch from both and compare refs. Any discrepancy indicates a bug.

4. **Cycle boundary validation**: Verify that known epoch dates return the expected first entry (e.g., 2020-01-05 = Berakhot 2 for Daf Yomi).

5. **Hebrew year boundary for Chofetz Chaim**: Verify 1 Tishrei entries match "Hakdamah 1-4" across multiple years.

6. **Row count sanity**: Total should be approximately 12 programs x 2,557 days = ~30,684. Allow for some programs not appearing on certain dates (Daf Yomi disappears at cycle boundaries from Sefaria).

### Handling Missing Entries

Some programs may not appear on certain dates in the Sefaria response (e.g., Daf Yomi disappears after the cycle ends on Jun 7, 2027). The seeder should:
- Log missing entries as warnings (not errors)
- Insert `NULL` or skip the row for that (program, date) pair
- The app should handle NULL gracefully: "No scheduled learning for this program today"

### Ref Extraction from Hebcal Links

For Chofetz Chaim and Kitzur SA, the Sefaria ref must be extracted from the Hebcal `link` field:

```
Input:  https://www.sefaria.org/Chofetz_Chaim%2C_Part_One%2C_The_Prohibition_Against_Lashon_Hara%2C_Principle_9.1?lang=bi&utm_source=hebcal.com&utm_medium=api
Output: Chofetz_Chaim,_Part_One,_The_Prohibition_Against_Lashon_Hara,_Principle_9.1
```

Steps:
1. Parse URL, extract path (after `sefaria.org/`)
2. URL-decode (`%2C` -> `,`)
3. Strip query parameters
4. Replace `%20` with spaces (if any)

For Nach Yomi, the link also points to Sefaria:
```
Input:  https://www.sefaria.org/I_Samuel.1?lang=bi&...
Output: I_Samuel.1
```

---

## 7. Cycle Transition Risk

### Known Cycle End Dates

| Program | Current cycle ends | Next cycle starts | Risk |
|---------|-------------------|-------------------|------|
| **Daf Yomi** | **2027-06-07** (Niddah 73) | 2027-06-08 (Berakhot 2, Cycle 15) | **HIGH** -- ends within bundled window. Must include Cycle 15 data. |
| **Yerushalmi Yomi** | ~2027 (estimated, Cycle 1) | Unknown -- Cycle 1 is the first | **MEDIUM** -- may end within bundled window. No Cycle 2 data yet exists. |
| **Mishna Yomit** | Cycle ~1,044 days. Multiple cycles within 7-year window. | Restarts at Berakhot 1:1 | **LOW** -- short cycle, well understood |
| **Nach Yomi** | 929-day cycle. Multiple cycles within window. | Restarts at Joshua 1 | **LOW** |
| **Rambam 1 Chapter** | 985-day cycle | Restarts at Yesodei HaTorah 1 | **LOW** |
| **Rambam 3 Chapters** | ~339-day cycle | Restarts | **LOW** |
| **Daf a Week** | ~52-year cycle | Will not end in our lifetime | **NONE** |
| **Halakhah Yomit** | ~1,500-day cycle (estimated) | Unknown exact date | **MEDIUM** -- may end within window |
| **Arukh HaShulchan** | ~1,000-day cycle (estimated) | Unknown exact date | **MEDIUM** -- may end within window |
| **Tanakh Yomi** | ~929 entries | Unknown exact boundary | **LOW** |
| **Chofetz Chaim** | Every 1 Tishrei | Every 1 Tishrei | **NONE** -- annual reset, captured by date range |
| **Kitzur SA** | Every 1 Tishrei | Every 1 Tishrei | **NONE** -- annual reset, captured by date range |

### Critical: Daf Yomi Cycle 14 -> 15 Transition

The current Daf Yomi cycle ends on **2027-06-07**. If the seed database covers through 2030, it MUST include Cycle 15 data. However, Sefaria may not serve Cycle 15 data for future dates until closer to the transition. This needs verification:

**Test:** Query Sefaria for 2027-06-08. If it returns Berakhot 2, Cycle 15 data is available. If the Daf Yomi entry is absent (as observed), we may need to:
1. Hard-code the Daf Yomi sequence (it's identical every cycle -- same 2,711 dappim in the same order)
2. Generate Cycle 15 entries locally: epoch 2027-06-08, same sequence as Cycle 14

### Yerushalmi Yomi -- First Cycle Ever

The Yerushalmi Yomi program started November 14, 2022. This is the first cycle in history. When it ends (~2027), there is no guarantee the next cycle will follow the same sequence or timing. The second cycle details may be announced closer to the transition.

**Mitigation:** The seed database should cover as far as the API provides data. For dates beyond the API's knowledge, leave the entries empty and handle gracefully in the app.

### Hebrew Calendar Programs -- Leap Year Differences

Chofetz Chaim and Kitzur SA follow the Hebrew calendar year. Hebrew leap years insert an extra month (Adar II, ~30 days). The reading schedule adjusts to fill the longer year.

**Impact on seeding:** The seed tool MUST capture each actual Gregorian date's reading rather than assuming a fixed mapping. Two different Hebrew years (regular vs. leap) will have different readings on the same day-of-cycle-index because the cycle length differs.

**This is why date-keyed storage is essential.** By storing (program, Gregorian date) -> ref, we automatically capture leap year variations. The app never needs to know whether a Hebrew year is leap or regular.

---

## 8. Summary of Bugs Found During Research

| # | Severity | Component | Issue |
|---|----------|-----------|-------|
| 1 | **CRITICAL** | `CalendarProgramRegistry` | `nach_yomi` has `apiSource: 'sefaria'` but Nach Yomi does not exist on Sefaria. Should be `apiSource: 'hebcal'`. |
| 2 | **CRITICAL** | `CalendarProgramRegistry` | `apiKey: 'Mishnah Yomit'` does not match Sefaria's `title.en: 'Daily Mishnah'`. |
| 3 | **CRITICAL** | `CalendarProgramRegistry` | `apiKey: 'Daily Rambam 1 Chapter'` does not match Sefaria's `title.en: 'Daily Rambam'`. |
| 4 | **CRITICAL** | `CalendarProgramRegistry` | `apiKey: 'Daily Rambam 3 Chapters'` does not match Sefaria's `title.en: 'Daily Rambam (3 Chapters)'`. |
| 5 | **CRITICAL** | `HebcalApiClient` | Missing `dcc=on` and `dksa=on` flags. Chofetz Chaim and Kitzur SA are never fetched. |
| 6 | **HIGH** | `CalendarProgramService` | Hebcal item matching uses `byApiKey(item.title)` where `item.title` is the reading title (e.g., "Menachot 77"), not the program name. Should match by `item.category`. |
| 7 | **MEDIUM** | `HebcalApiClient` | Missing `nyomi=on` flag for Nach Yomi (if we move it to Hebcal source). Currently requests `nyomi=on` but never maps it. |

These bugs mean that today, **only 6 of 12 programs actually work** at runtime:
- Working: Daf Yomi, Yerushalmi Yomi, Daf a Week, Halakhah Yomit, Arukh HaShulchan Yomi, Tanakh Yomi
- Broken (apiKey mismatch): Mishna Yomit, Rambam 1 Chapter, Rambam 3 Chapters
- Broken (wrong source): Nach Yomi
- Broken (missing flags): Chofetz Chaim, Kitzur SA

---

## 9. Key Architectural Decisions

### D-CAL-1: Date-Keyed Lookup Table Over Formula Computation

**Decision:** Store pre-computed (program_id, date) -> sefaria_ref mappings rather than computing from epoch + cycle length at runtime.

**Rationale:** Three programs (Chofetz Chaim, Kitzur SA, and to a lesser extent Halakhah Yomit) cannot be computed from a simple formula. Using a uniform date-keyed table eliminates all special-case logic.

### D-CAL-2: 7-Year Seeding Window (2024-2030)

**Decision:** Seed all dates from 2024-01-01 through 2030-12-31.

**Rationale:** Covers the current cycle of every program including Daf Yomi Cycle 14 (ends Jun 2027) and the start of Cycle 15. Provides 4+ years of runway before any content update is needed.

### D-CAL-3: Nach Yomi Moves to Hebcal Source

**Decision:** Change `nach_yomi` from `apiSource: 'sefaria'` to `apiSource: 'hebcal'`.

**Rationale:** Sefaria does not serve Nach Yomi data. Hebcal does, and already returns it with the `nyomi=on` flag.

### D-CAL-4: Sefaria is Primary, Hebcal is Supplementary

**Decision:** Use Sefaria for 9 programs, Hebcal for 3 programs (nach_yomi, chofetz_chaim_daily, kitzur_shulchan_aruch_yomi).

**Rationale:** Sefaria returns richer data (proper refs, categories) for most programs. Hebcal fills the gaps for programs Sefaria doesn't cover. Avoid double-fetching programs available on both.

### D-CAL-5: Hard-Code Daf Yomi Cycle 15

**Decision:** If Sefaria does not return Daf Yomi data for dates after Jun 7 2027, generate Cycle 15 entries using the known fixed sequence (same 2,711 dappim, starting from Berakhot 2 on Jun 8 2027).

**Rationale:** The Daf Yomi sequence is identical every cycle. No API call is needed to know what comes after Niddah 73.

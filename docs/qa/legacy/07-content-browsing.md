# Content Browsing -- Manual Test Scenarios

**Document:** 07
**Feature Area:** Hierarchy navigation, Hebrew/English text display, search, offline browsing, performance
**Created:** 2026-04-13
**FRs Covered:** FR1, FR2, FR3, FR4, FR5, FR6, FR7, NFR4, NFR5, NFR7, NFR22, NFR42, NFR43, NFR44

---

## Prerequisites

Before running these scenarios:

1. Complete onboarding (document 03) with at least **Mishnayos** activated
2. Content database is bundled and available (FR6 -- no runtime download needed)
3. At least one curriculum is active
4. For multi-curriculum scenarios, activate 2+ curricula (e.g., Mishnayos and Bavli)
5. Device language is set to English (for verifying bilingual display)

---

## What & Why

### Why Content Browsing Matters

The content browser is the user's window into all Torah content the app tracks.
It is the entry point for ad-hoc completions (tested in document 04), for
understanding where you are in a curriculum, and for exploring what lies ahead.
If the hierarchy is broken, items are missing, or text does not render, the
learner loses trust in the entire system.

### Hierarchy Structure

Each curriculum organizes its content into a tree of 1-4 levels. The generic
hierarchy model means every curriculum uses the same browsing UI, but the
level labels and depth differ:

| Curriculum | Levels | Hierarchy | Approx. Items |
|---|---|---|---|
| Mishnayos | 4 | seder > masechta > perek > mishna | 4,192 |
| Gemara Bavli | 3 | masechta > daf > amud | ~5,422 |
| Gemara Yerushalmi | 3 | masechta > daf > halacha | varies |
| Mishna Berurah | 3 | siman > seif > seif katan | 697 simanim |
| Chumash | 4 | sefer > parsha > perek > pasuk | 5,845 |
| Mishneh Torah | varies | sefer > section > chapter | varies |
| Tanach | varies | sefer > perek > pasuk | varies |
| Nach | varies | sefer > perek > pasuk | varies |
| Mussar | varies | sefer > section > paragraph | varies |

The browser must handle all depths gracefully: a 1-level curriculum should
not show empty intermediate screens, and a 4-level curriculum should not
require excessive drilling.

### Hebrew and English Text

All content is sourced from Sefaria and includes both Hebrew and English text.
Hebrew text is right-to-left (RTL). The app must handle bidirectional layout
correctly -- Hebrew flowing right-to-left and English flowing left-to-right,
sometimes in the same view. Nikud (vowel marks) on Hebrew text must display
correctly and should be stripped when searching so that a search for "בראשית"
matches "בְּרֵאשִׁית".

### Bundled Content

All content is bundled with the app at build time (FR6). There is no runtime
download or import step. This means the content browser must work immediately
after install, including on first launch, with no network dependency.

---

## Test Scenarios

### Format

Each scenario follows this structure:

| Field | Description |
|---|---|
| **ID** | Unique identifier (CONTENT-XX) |
| **Priority** | P0 (must pass), P1 (should pass), P2 (nice to verify) |
| **Title** | Short description |
| **Preconditions** | State required before starting |
| **Steps** | Numbered actions to perform |
| **Expected** | What should happen |
| **Pass/Fail** | Checkbox for recording result |

---

### Hierarchy Navigation -- Basic (P0)

---

#### CONTENT-01 | P0 | Browse 4-level curriculum (Mishnayos) top to leaf

**Preconditions:** Mishnayos curriculum is activated. App is on home or curriculum list screen.

**Steps:**
1. Navigate to the content browser
2. Select "Mishnayos" from the curriculum list
3. Observe the first level displayed (sedarim)
4. Tap a seder (e.g., "Seder Zeraim")
5. Observe the second level (masechtos)
6. Tap a masechta (e.g., "Berachos")
7. Observe the third level (perakim)
8. Tap a perek (e.g., "Perek 1")
9. Observe the fourth level (mishnayos -- leaf items)

**Expected:**
- Each level displays the correct label for that hierarchy depth (seder, masechta, perek, mishna)
- Each level shows all children of the selected parent, in Sefaria sort order
- Navigation breadcrumb or back button allows returning to any previous level
- The leaf level (mishna) shows individual content items
- No empty or missing levels

**Pass/Fail:** [ ]

---

#### CONTENT-02 | P0 | Browse 3-level curriculum (Gemara Bavli) top to leaf

**Preconditions:** Bavli curriculum is activated.

**Steps:**
1. Navigate to the content browser
2. Select "Gemara Bavli"
3. Observe the first level (masechtos)
4. Tap a masechta (e.g., "Berachos")
5. Observe the second level (dapim)
6. Tap a daf (e.g., "Daf 2")
7. Observe the third level (amudim -- leaf items)

**Expected:**
- Only 3 levels are shown -- no empty fourth level
- Level labels are correct for Bavli (masechta, daf, amud)
- Leaf items are displayed at the third level
- Navigation works identically to the 4-level case

**Pass/Fail:** [ ]

---

#### CONTENT-03 | P0 | Level labels match curriculum configuration (FR7)

**Preconditions:** At least two curricula with different hierarchy depths are activated (e.g., Mishnayos 4-level and Bavli 3-level).

**Steps:**
1. Open the content browser for Mishnayos
2. Note the level labels at each tier (seder, masechta, perek, mishna)
3. Go back and open the content browser for Bavli
4. Note the level labels at each tier (masechta, daf, amud)

**Expected:**
- Labels are curriculum-specific, not generic ("Level 1", "Level 2")
- Mishnayos shows: Seder, Masechta, Perek, Mishna
- Bavli shows: Masechta, Daf, Amud
- Labels are consistent across the app (browser, breadcrumbs, detail views)

**Pass/Fail:** [ ]

---

#### CONTENT-04 | P0 | Back navigation through hierarchy levels

**Preconditions:** Drilled down to leaf level in any curriculum.

**Steps:**
1. From a leaf item view, tap the back button or breadcrumb
2. Verify you return to the parent level (e.g., perek list)
3. Tap back again
4. Verify you return to the grandparent level (e.g., masechta list)
5. Continue tapping back until you reach the curriculum list
6. Verify you arrive at the top-level curriculum selection

**Expected:**
- Each back navigation returns to the exact parent level with scroll position preserved
- No levels are skipped
- The breadcrumb trail (if present) updates correctly at each level
- Returning to a previously visited level shows the same items (no data loss)

**Pass/Fail:** [ ]

---

### Hierarchy Navigation -- Data Integrity (P0)

---

#### CONTENT-05 | P0 | All items present at each level -- no missing children

**Preconditions:** Mishnayos is activated. You have a reference for expected item counts (e.g., Seder Zeraim has 11 masechtos).

**Steps:**
1. Navigate to Mishnayos > Seder Zeraim
2. Count the number of masechtos displayed
3. Navigate into Masechta Berachos
4. Count the number of perakim displayed
5. Navigate into Perek 1
6. Count the number of mishnayos displayed

**Expected:**
- Seder Zeraim shows exactly 11 masechtos
- Berachos shows exactly 9 perakim
- Perek 1 shows the correct number of mishnayos (expected: 5 in Berachos Perek 1)
- No items are duplicated or missing

**Pass/Fail:** [ ]

---

#### CONTENT-06 | P0 | Items displayed in correct Sefaria sort order (FR28)

**Preconditions:** Any curriculum is activated. Default learning order is set (no custom reordering).

**Steps:**
1. Navigate to Mishnayos > Seder Zeraim
2. Verify the masechtos are in traditional order (Berachos, Peah, Demai, Kilayim, Sheviis, Terumos, Maasros, Maaser Sheni, Challah, Orlah, Bikkurim)
3. Navigate into Berachos > Perek 1
4. Verify mishnayos are in numerical order (Mishna 1, Mishna 2, ...)

**Expected:**
- Items at every level follow the natural Sefaria sort order
- No items are out of sequence
- The order matches the traditional Torah learning order

**Pass/Fail:** [ ]

---

### Hebrew and English Text Display (P0)

---

#### CONTENT-07 | P0 | Hebrew text displays correctly with RTL layout (NFR42)

**Preconditions:** Any curriculum is activated. Navigate to a leaf item with Hebrew text.

**Steps:**
1. Navigate to a content item (e.g., Mishnayos Berachos 1:1)
2. View the Hebrew text

**Expected:**
- Hebrew text flows right-to-left
- Letters are rendered correctly with no boxes, question marks, or replacement characters
- Nikud (vowel marks) display correctly if present in the source text
- Text is readable and properly sized for the device

**Pass/Fail:** [ ]

---

#### CONTENT-08 | P0 | English text displays alongside Hebrew (FR3)

**Preconditions:** Same leaf item as CONTENT-07.

**Steps:**
1. View the content item that shows both Hebrew and English text
2. Observe the layout of both text blocks

**Expected:**
- English text is present and readable
- English text flows left-to-right (standard LTR)
- Hebrew and English text are visually distinct (separate sections, different alignment, or labeled)
- Both texts refer to the same content item
- No text is truncated or cut off

**Pass/Fail:** [ ]

---

#### CONTENT-09 | P1 | Bidirectional text rendering (NFR43)

**Preconditions:** Navigate to a content item that contains mixed Hebrew and English text within the same field (e.g., a translation note).

**Steps:**
1. View the content item
2. Look for any inline mixing of Hebrew and English characters
3. Verify the text reads naturally in both directions

**Expected:**
- Hebrew segments flow right-to-left within the line
- English segments flow left-to-right within the line
- Words do not overlap, reverse, or display in garbled order
- Punctuation appears in the correct position relative to each script

**Pass/Fail:** [ ]

---

#### CONTENT-10 | P1 | Hebrew text renders clearly on various screen sizes (NFR44)

**Preconditions:** Access to devices or emulators of different screen sizes (5" phone, 7" tablet, 10" tablet).

**Steps:**
1. Open a content item with Hebrew text on a 5" phone
2. Verify readability
3. Open the same content item on a larger screen (tablet or emulator)
4. Verify readability and layout scaling

**Expected:**
- Hebrew text is legible on all screen sizes without zooming
- Font size scales appropriately (not too small on phones, not too large on tablets)
- Line breaks occur at natural word boundaries, not mid-word
- No horizontal scrolling is required to read full lines

**Pass/Fail:** [ ]

---

### Sefaria Attribution (P1)

---

#### CONTENT-11 | P1 | Sefaria attribution is visible (FR4)

**Preconditions:** Navigate to any content item with text.

**Steps:**
1. View the content text for any item
2. Look for Sefaria attribution (footer, header, or dedicated section)

**Expected:**
- A Sefaria attribution notice is visible somewhere in the content display
- The attribution is clear and credits Sefaria as the content source
- The attribution does not obstruct the content text

**Pass/Fail:** [ ]

---

### Search and Filtering (P1)

---

#### CONTENT-12 | P1 | Search for a content item by name

**Preconditions:** Content browser is open. At least one curriculum is activated.

**Steps:**
1. Locate the search field or search icon in the content browser
2. Type a search term (e.g., "Berachos")
3. Observe the search results

**Expected:**
- Results appear as you type (or after submitting the query)
- Results include all items matching the search term across the active hierarchy
- "Berachos" returns the masechta in Mishnayos, Bavli, and Yerushalmi (if activated)
- Results are navigable -- tapping a result takes you to that item in the hierarchy

**Pass/Fail:** [ ]

---

#### CONTENT-13 | P1 | Search with nikud stripping -- voweled input matches unvoweled content

**Preconditions:** Content browser with search is available. Hebrew keyboard available.

**Steps:**
1. Open the search field
2. Type a Hebrew term WITH nikud (e.g., "בְּרָכוֹת" with vowel marks)
3. Observe the results
4. Clear the search
5. Type the same term WITHOUT nikud ("ברכות")
6. Observe the results

**Expected:**
- Both searches return the same results
- Nikud is stripped from the search query before matching
- The search is nikud-insensitive -- the presence or absence of vowel marks does not affect results
- Results include "Berachos" / "ברכות" items

**Pass/Fail:** [ ]

---

#### CONTENT-14 | P1 | Search returns results across multiple curricula

**Preconditions:** At least two curricula are activated that share a common term (e.g., "Berachos" appears in Mishnayos and Bavli).

**Steps:**
1. Open search
2. Type "Berachos"
3. Review the results

**Expected:**
- Results include matches from all activated curricula
- Each result is labeled with its curriculum (e.g., "Mishnayos > Berachos", "Bavli > Berachos")
- The user can distinguish which curriculum each result belongs to

**Pass/Fail:** [ ]

---

#### CONTENT-15 | P2 | Search with no results -- empty state

**Preconditions:** Content browser with search is available.

**Steps:**
1. Open search
2. Type a nonsensical string that matches nothing (e.g., "xyzxyzxyz")
3. Observe the result

**Expected:**
- An empty state message is shown (e.g., "No results found")
- No crash or error
- The message is user-friendly, not a technical error
- The search field remains active for a new query

**Pass/Fail:** [ ]

---

#### CONTENT-16 | P2 | Search with partial match

**Preconditions:** Content browser with search is available.

**Steps:**
1. Open search
2. Type a partial term (e.g., "Ber" instead of "Berachos")
3. Observe the results

**Expected:**
- Results include items that start with or contain the partial term
- "Ber" matches "Berachos", "Bereshis", and any other items beginning with "Ber"
- Results narrow as the user types more characters

**Pass/Fail:** [ ]

---

### Curriculum Activation and Deactivation (P0)

---

#### CONTENT-17 | P0 | Activated curriculum appears in content browser (FR5)

**Preconditions:** At least one curriculum is activated during onboarding or settings.

**Steps:**
1. Open the content browser
2. Verify the activated curriculum appears in the list

**Expected:**
- The activated curriculum is listed and browsable
- All hierarchy levels and content items are accessible
- The curriculum is fully functional immediately (no loading or import step)

**Pass/Fail:** [ ]

---

#### CONTENT-18 | P0 | Deactivated curriculum is hidden but progress is preserved (FR5)

**Preconditions:** A curriculum has some completions recorded. The user deactivates it.

**Steps:**
1. Note the completion count for the curriculum (e.g., 15 items completed in Bavli)
2. Deactivate the curriculum via settings
3. Open the content browser
4. Verify the deactivated curriculum is no longer listed
5. Reactivate the curriculum
6. Open the content browser and navigate into the reactivated curriculum
7. Check completion status of previously completed items

**Expected:**
- Deactivated curriculum does NOT appear in the content browser
- After reactivation, the curriculum reappears with all previous completions intact
- Bookmark position is preserved
- No data loss from deactivation/reactivation cycle

**Pass/Fail:** [ ]

---

### Offline Browsing (P0)

---

#### CONTENT-19 | P0 | Browse content fully offline (NFR22, FR6)

**Preconditions:** App is installed and has been opened at least once. Content is bundled.

**Steps:**
1. Enable airplane mode on the device (no Wi-Fi, no mobile data)
2. Open the app
3. Navigate to the content browser
4. Browse through a full hierarchy: curriculum > level 1 > level 2 > leaf item
5. View the Hebrew and English text of a leaf item

**Expected:**
- All browsing works identically to online mode
- Hierarchy levels load without delay or error
- Content text (Hebrew and English) displays correctly
- No "no connection" error or loading spinner appears during browsing
- The experience is indistinguishable from online browsing (NFR23)

**Pass/Fail:** [ ]

---

### Performance (P1)

---

#### CONTENT-20 | P1 | List scrolling maintains 60fps (NFR7)

**Preconditions:** Navigate to a level with many items (e.g., Bavli masechtos list or Mishnayos perek list for a large masechta).

**Steps:**
1. Open a list with 20+ items
2. Scroll rapidly up and down through the list
3. Observe the scroll smoothness (or use developer tools to measure frame rate)

**Expected:**
- Scrolling is smooth with no visible jank or stuttering
- Frame rate stays at or near 60fps
- Items render as they scroll into view without blank flashes
- Large lists (hundreds of items) scroll as smoothly as small lists

**Pass/Fail:** [ ]

---

#### CONTENT-21 | P1 | Navigation between levels responds within 200ms (NFR4)

**Preconditions:** Content browser is open at any level.

**Steps:**
1. Tap a hierarchy item to drill into the next level
2. Measure the time from tap to the next level being fully displayed (visual estimate or profiler)
3. Repeat for 3-4 different levels and curricula

**Expected:**
- Each navigation responds within 200ms
- No loading spinner appears for hierarchy navigation (content is local)
- The transition animation (if any) is smooth and does not delay content display

**Pass/Fail:** [ ]

---

## Bavli Seder Zeraim — Intentionally Brochos-only

The Babylonian Talmud has Gemara for only 37 of the 63 tractates in Mishnayos.
Seder Zeraim's sole Bavli tractate is Brochos (Berakhot). The `bavli.json`
hierarchy intentionally includes only Brochos under Seder Zeraim; Bikkurim,
Peah, and the rest of Zeraim exist under Mishnayos, Yerushalmi, and perek_yomi
— not under Bavli. This is correct and expected; it is not a bug.

---

## Cross-Feature References

| Feature Area | Document | Relationship to Content Browsing |
|---|---|---|
| **Learning & Completions** | 04 - Learning & Completions | Content browser is the entry point for ad-hoc completions. Items browsed here can be marked complete with stage and track selection. |
| **Onboarding** | 03 - Onboarding | Curriculum activation during onboarding determines which curricula appear in the content browser. |
| **Dashboard & Progress** | 08 - Dashboard & Progress | Dashboard links to per-curriculum progress views that use the same hierarchy structure. |
| **Scheduling** | 06 - Scheduling & Review | The scheduler references content items and their hierarchy positions to generate daily tasks. |
| **Settings** | 13 - Settings | Curriculum activation/deactivation is managed in settings, directly affecting what the content browser shows. |
| **Sync & Offline** | 14 - Sync & Offline | Content is bundled (FR6), so browsing is fully offline. Completion data syncs but content does not. |

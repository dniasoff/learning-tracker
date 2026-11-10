# Shnayim Mikra v'Echad Targum: product and implementation proposal

**Bead:** `learning-tracker-l84`  
**Status:** Accepted proposal; calendar/data spike and first two implementation phases completed.

## Recommendation

Add **Shnayim Mikra v'Echad Targum** as its own learning-list curriculum (`shnayim_mikra`), alongside Chumash. It has a different learning unit and completion contract from ordinary Chumash: each assigned weekly portion is read twice in Hebrew and once in a selected commentary/translation. Give the learner a configurable practice mode and source, but keep both under the one curriculum so one weekly cycle, progress history, streak, and points account for the whole mitzvah.

Do not model the three readings as ordinary stage/review events for Chumash. Use a dedicated reader/progress unit backed by Shnayim Mikra events. Chumash's existing 1-completion-per-pasuk behavior and stage schedule should remain independent.

## 1. Modes and curriculum shape

### Initial modes

1. **Pasuk by pasuk (recommended default).** For each verse show/check off: Mikra reading 1, Mikra reading 2, then the selected third reading (Onkelos by default). Advance only after the three actions are complete. Persist the three substeps independently so a learner can stop and resume within a verse. A pasuk counts complete when all three substeps are recorded.
2. **Aliyah by aliyah.** For the current aliyah, read its full Hebrew section twice, then its Onkelos (or chosen alternative) section once. The user marks each pass complete. Record the aliyah as complete only after all three passes; parsha progress is complete after all aliyot.
3. **Parsha by parsha.** Read the full assigned parsha twice, then its selected third reading once, and mark the three passes. Keep a visible outline and allow marking an aliyah or the whole pass complete. This is a larger session and should warn that pass completion is whole-unit, not inferred from opening the text.
4. **Daily aliyah pacing (optional pace setting).** Split the current parsha across Sunday–Friday: assign aliyot 1–5 to Sunday–Thursday and aliyot 6–7 together on Friday. Each day's item is a due subtask of this week's parsha; the user may do more than one in a day. Track three readings per aliyah according to the chosen reading mode.

Expose **mode** (pasuk / aliyah / whole-parsha) and **pace** (self-paced / daily aliyah) as settings on the one Shnayim Mikra curriculum, not as separate list entries. Offer **Onkelos / Rashi** as the third-reading source setting, with Onkelos as the default and clear labeling that Rashi is an alternative minhag/custom. Keep the selected source consistent across the three-reading workflow. Preserve the user's settings when changing pace or source. Release 1 includes both Onkelos and Rashi, as confirmed by the user. Store Rashi per comment ref, show an explicit “No Rashi on this pasuk” state for verses without comments, and never fabricate or silently substitute commentary.

### Curriculum/list placement

Add the curriculum to `CurriculumId`, the canonical curriculum order/default configuration, picker, localization, and hierarchy/content routing. Display it distinctly from Chumash (for example, “Shnayim Mikra” / “שנים מקרא”), with a subtitle explaining the current week's parsha and reading mode. It should not appear as a second Chumash track choice or be implemented by silently changing Chumash's completion semantics.

## 2. Weekly parsha cycle and due date

### Source and regional schedule

`kosher_dart` is already a dependency and its `JewishCalendar` contains parsha-cycle calculation and an Israel/diaspora setting. Prototype that as the runtime source of the parsha read for the upcoming Shabbos; use the existing `HebrewCalendarUtils` only for Hebrew date conversion/labels, and confirm the package's parsha result for both regions against a trusted calendar fixture before treating it as authoritative. The library handles calendar-year patterns and paired portions; do not recreate its double-parsha logic from the current hand-maintained chapter-start list.

The inspected app already has an offline calendar pattern: `calendar_cycles` maps `program_key + date_key` to refs, `LocalCalendarEngine` reads it, and the content seed is built locally. There is **no weekly parsha program in the runtime calendar registry**. Add a dedicated program key (or two region-keyed variants) to the seed/lookup path, keyed by Shabbos date, and cache the result in content.db so the current and near-future cycle work offline. If kosher_dart cannot produce the required region/Yom-Tov behavior reliably, use an explicit tested parsha calendar seed generated from an authoritative source rather than a runtime network dependency.

Use the Shnayim Mikra track's own Eretz Yisrael / Chutz la'aretz parsha minhag. Initialize it from the learner's explicit `yom_tov_days` setting (1 / 2); fall back to legacy `in_israel` only for profiles without that setting. Do not change it when location changes.

### Yom Tov and paired portions

A Shabbos with a festival reading is not a regular weekly parsha. Do not display a made-up parsha when the calendar reports no weekly sedra. The calendar resolver should identify the next regular weekly reading; a week with a paired parsha is one combined assignment, completed once. Cover Israel/diaspora divergence after holidays (including when they reunite), all paired portions, and the annual transition around Simchas Torah with golden fixtures. A local rule should state whether a festival's own Torah reading is out of scope.

### Deadline

Deadline is **before Shabbos begins**. With coordinates, use the start instant of the same Sacred-Time lock window (candle lighting using the learner's configured minhag); without a location, fall back to the final instant of Friday in the learner's local calendar. Flip overdue/catch-up at that exact instant. Afterward, keep unfinished work available through Simchas Torah while surfacing the new week's assignment independently; unfinished work does not block the new week. A no-parsha/festival week should not create a false overdue item. Give the app one explicit weekly deadline rule rather than a separate rolling/deadline `ScheduleSpec` for every pasuk. Existing `ScheduleSpec` governs review-stage timing; it is not a weekly calendar assignment contract.

## 3. Text data, references, and offline availability

### Sources

- Use existing Hebrew Chumash leaves from the shipped Sefaria-derived curriculum hierarchy/text seed. Canonical atomic refs are chapter/verse refs such as `Genesis 1:1`; ensure a helper converts that representation to the dot form used by the current Chumash text cache (the current `text_cache` seed uses refs like `Genesis 1.1`).
- Fetch/cache both third-reading sources at seed-build time, not on device. Verified live Sefaria v3 refs are `Onkelos Genesis 1:1` (Hebrew-script Aramaic) and `Rashi on Genesis 1:1:1` (the first comment on that verse). The public-domain Hebrew Onkelos versions cover all five books. The Hebrew Rashi endpoint supplies comment-level refs, including multiple comments on some pesukim and no comment on many others. Store Hebrew text and an English rendering only if the selected version supplies one; run both through existing Sefaria cleaning/HTML decoding. **Local-source limitation:** the documented Mongo dump and generated `book_text_cache.json` are absent in both the story worktree and main checkout. These figures were checked against Sefaria's live v3 Texts API; repeat coverage/version checks against the local dump in the seed-build bead before implementation.
- Runtime reader is offline-first. Include required Onkelos text in `assets/db/content.db.xz` and generated gzip asset through the normal seed pipeline; never fetch per pasuk during ordinary reading. If any version cannot be bundled, identify that limitation before launch instead of silently depending on network. Optional online refresh is a future product decision.

### Shape and size

`text_cache` currently stores one row per ref with Hebrew and English text; `TextCacheRepository` resolves exact refs, child verses, then `daily_content`. It has no commentary/reading-role column. Prefer a dedicated table such as `parallel_text` with primary key `(source_key, sefaria_ref)`, Hebrew-script text and optional English text, rather than overloading `text_cache` with a fake Chumash curriculum key. Alternatively, after a spike, extend text_cache to support language/version keys if that benefits other parallel-text features too.

The checked-in Chumash ref manifest and hierarchy contain **5,846** pesukim (the `ChumashFetcher` comment saying 5,845 is stale). The live Sefaria v3 scan returned non-empty Onkelos text for all 5,846 refs. Rashi coverage returned 7,816 Hebrew comments across 5,669 verse positions: 3,900 pesukim have at least one comment, 2,098 have multiple comments, 1,769 returned positions have no comment, and 177 manifest pesukim have no returned Rashi position (1,946 total with no Rashi in this scan). Use an explicit “No Rashi on this pasuk” state; treat the Rashi reading step as not applicable so the learner can still complete that pasuk/aliyah/parsha. Do not fabricate a comment or substitute Onkelos. Both selected Hebrew editions report Public Domain in the live API; Numbers Rashi resolves to its corrected-vocalization edition. Seed two source-keyed text sets; preserve individual Rashi comment refs. The local seed source is unavailable here, so the measurements below are a reproducible live-payload simulation in a copy of the shipped content DB, not a local-Mongo seed build. See measured DB deltas below.

## 4. Reader, learning-list, progress, streak, and points

### Reader behavior

Build a dedicated Shnayim Mikra reader over the existing Chumash text and the parallel-text repository. Preserve Hebrew/English display and font/Nikud preferences. Show a persistent parsha/aliyah/pasuk breadcrumb and explicit current pass label (“First Mikra”, “Second Mikra”, “Onkelos” or “Rashi”). For pasuk mode, keep all three texts grouped in a verse card. For aliyah/parsha mode, expose one pass at a time across the whole selected unit, with a clear action to mark the pass finished; do not mark completion merely because the text was opened or scrolled. The current text reader is a single-ref Chumash viewer and its completion action marks the current ref, so extend it behind a distinct route/reader flow rather than trying to repurpose that button without changing its contract.

Show weekly progress as completed substeps and completed pesukim/aliyot (for example, “18/42 pesukim: 2 readings + Onkelos complete”), with accessible partial state. Allow resuming the first incomplete task and reviewing completed text. Mark a pasuk or aliyah done only after the required readings for that mode; completing the entire assigned parsha marks the weekly unit done.

### Learning list and gamification

The home learning list should show one Shnayim Mikra card with the assigned parsha, regional calendar label where useful, due status, and progress. Daily aliyah pace may display today's aliyah and “x of 6/7 aliyot this week” while still rolling up to the one weekly parsha. Keep the previous assignment available as overdue/catch-up and show the next assignment only as preview, not as due work.

Emit completion events through the existing learner-state write path, attributed to the Shnayim Mikra curriculum and existing child/tutor actor/source rules. Key pass and unit-completion events by the weekly cycle (Shabbos date, parsha, and Israel/diaspora minhag), so the same parsha can be completed again in a later year and catch-up retains its own cycle state. Persist each pass as its own idempotent, voidable pass-source event so readers on another device resume at the same pass; record Onkelos/Rashi on pass three so a source change requires the newly selected commentary. Exclude pass markers from counted learning, points, streaks, and Chumash. Award points only on unit completion, once per verse per assignment cycle across reading modes; a later cycle can earn again. Streak credit follows the existing once-per-civil-day rule. Never count Shnayim Mikra's Chumash pesukim as ordinary Chumash completion unless the learner separately records that curriculum.

Award points once per completed meaningful unit using existing point configuration/ledger flow, not once per rendered segment or scroll. Proposed unit: one pasuk (after all 3 reads) in pasuk mode, one aliyah (after its 3 passes) in aliyah/daily-aliyah mode, and one parsha (after its 3 passes) in parsha mode; total credit should be normalized so choosing finer-grained mode doesn't multiply points. Streak should count one day with Shnayim Mikra progress according to existing per-curriculum streak semantics, not each pass as a separate streak. If the current streak contract only counts top-level learn events, use one qualifying completion event per day and treat finer events as supporting detail.

## 5. Persistence, authorization, localization, and verification

### Models, storage, and rules

- Add `CurriculumId.shnayimMikra` and localized labels; audit exhaustive curriculum maps, activation defaults, Firestore curriculum validation, track/scope repositories, hierarchy/index loading, points defaults, and all curriculum switch statements.
- Persist mode, third-reading source, pace, and Israel/diaspora on the curriculum's existing governed settings/config path. If per-curriculum settings are not extensible without broadening a strict storage codec, add the minimal versioned setting model and backward-compatible defaulting path; do not weaken strict decoders.
- Add completion unit/pass identity with a strict storage codec and Firestore rules allowlist/type checks, actor/owner/tutor authorization, undo/void semantics, and sync conflict/idempotency rules. If using event refs, make a canonical reversible encoding and validate it at boundaries; avoid free-form embedded marker strings that can collide with real refs.
- Add a content DB migration for parallel text, regenerate Drift/schema artifacts and seed metadata, extend seed extraction, and verify a fresh seed plus upgrade path. The app's shipped content database is read-only at runtime; this is a seed/build change, not a client-side cache write.
- Child mode: the parent chooses curriculum, region, source and mode in the parent-controlled setup/settings surface; the learner sees the assigned workflow and can complete it using existing child actor attribution. Keep existing tutor permission and profile-scope checks. Do not add a child path that can change parent-governed configuration or circumvent event rules.
- Add English and Hebrew ARB strings for the curriculum name/description, mode/source/pace choices, pass labels, progress, due/overdue/festival states, and accessibility labels. Regenerate localization output. Verify right-to-left ordering for Hebrew mixed text and pass labels.

### Targeted coverage

No full test suite is proposed for a story lane. Add targeted tests only:

- Calendar resolver: both regions, annual boundary, Yom Tov/no regular parsha, paired portions, Israel/diaspora divergence and reunion, stable current-week assignment on setting change.
- Data/reader: canonical Sefaria refs, all three passes and mode order, partial/resume state, missing/empty parallel text, offline read, correct pasuk/aliyah totals, no accidental Chumash completion.
- Model/rules: codec round-trip and rejection of unknown keys, idempotent completion/void and sync, child/tutor actor permissions, points awarded once, streak increments once per active day.
- UI/l10n: list card and due state, Hebrew/RTL mode/source labels, parent settings versus child completion.

## 6. Proposed phased delivery (separate reviewable beads)

Create/sequence these implementation beads after this planning bead is accepted; dependencies follow true code dependencies, not artificial serial ordering:

1. **Calendar/data spike:** prove kosher_dart's Israel/diaspora/Yom-Tov behavior against fixtures, reconcile current Chumash parsha/aliyah asset discrepancies, validate Sefaria refs/version availability, and measure incremental DB size. No app UI.
2. **Content model and seed:** canonical Chumash aliyah/parsha mapping plus a source-keyed parallel-text table; content DB schema, deterministic Onkelos and Rashi seed, and offline lookup. Store each Rashi comment separately and expose absent-comment positions explicitly.
3. **Curriculum and governed settings:** curriculum ID/picker/defaults; mode/source/pace/region persistence and backward-compatible defaults; child/tutor configuration boundaries.
4. **Weekly assignment and learning-list projection:** region-specific parsha cycle, weekly due/overdue/catch-up projection, Yom Tov handling, one learning-list card.
5. **Reader and completion model:** three pass workflows, unit completion/resume, event model/codec/rules/sync/void semantics, points and streak integration.
6. **Localization and targeted acceptance:** en/he strings, RTL review, targeted regressions across calendar, data, reader, state/rules, child/tutor, list and progress.

Bead 1 is a gating fact-finding deliverable; beads 2–6 can be split/parallelized once its interfaces are agreed. Keep each implementation bead narrow enough for one review round where possible; do not include a full-suite run on every bead.

## Phase 2 implementation findings

- Added checked-in deterministic source input at `learning_tracker/tool/data/shnayim_mikra_seed.json`, generated from the Sefaria v3 Texts API response captured 2026-11-10. All records retain canonical Sefaria refs after the seed step prefixes Onkelos/Rashi, source keys, Hebrew text, selected version title, and license. The seed builder makes no network calls and verifies all 5,846 Onkelos verse refs exactly match the checked-in Chumash manifest; it also verifies 7,816 Rashi comment refs and Public Domain status.
- Exact selected Sefaria versions (all Public Domain):

| Book | Onkelos | Rashi |
|---|---|---|
| Genesis | `Onkelos Genesis` | `Pentateuch with Rashi's commentary by M. Rosenbaum and A.M. Silbermann, 1929-1934` |
| Exodus | `Onkelos Exodus` | `Pentateuch with Rashi's commentary by M. Rosenbaum and A.M. Silbermann, 1929-1934` |
| Leviticus | `Onkelos Leviticus` | `Pentateuch with Rashi's commentary by M. Rosenbaum and A.M. Silbermann, 1929-1934` |
| Numbers | `Onkelos Numbers` | `Pentateuch with Rashi's commentary by M. Rosenbaum and A.M. Silbermann -- corrected vocalization` |
| Deuteronomy | `Onkelos Deuteronomy` | `Pentateuch with Rashi's commentary by M. Rosenbaum and A.M. Silbermann, 1929-1934` |

- Added the source-keyed `parallel_text` schema and repository (verse-level Onkelos; comment-level Rashi, numerically ordered; empty Rashi result represents no commentary), plus `parsha_aliyot` for weekly kosher_dart portion enum keys and region-specific Vezot readings. The seed migration moves Content DB schema 5→6; bundled seed version 15→16 forces existing installs to replace from the updated offline asset. Seed metadata now records both row counts and the hash covers the new keys/boundaries.
- Built the updated bundled asset from a copy of the shipped seed using the committed deterministic builder: 13,662 parallel-text rows and 405 aliyah ranges. The resulting DB is 459,599,872 raw bytes / 64,895,800 xz bytes; relative to the spike baseline, +6,168,576 raw / +815,324 compressed bytes after canonical ref prefixes and text cleaning. Build used `--shnayim-mikra-only`; existing Chumash text and calendar rows were preserved.
- Targeted validation passed: seed builder completed and schema/metadata were inspected (schema v6, seed v16, 5,846 Onkelos, 7,816 Rashi, 405 aliyah rows); parallel-text repository tests and the 5787–5788 calendar/aliyah fixture tests all pass. `flutter pub get` and `dart run build_runner build -d` completed. The full test suite was not run.

## Phase 3 curriculum and governed settings findings

- Added `CurriculumId.shnayimMikra` (`shnayim_mikra`) with English/Hebrew display names, a single Parsha curriculum level, daily target fallback, and visual/setup/siyum/pace mappings so existing curriculum utilities remain exhaustive.
- Added strict governed learner settings: `shnayim_mikra_mode` (`pasuk`, `aliyah`, `parsha`), `shnayim_mikra_pace` (`self`, `daily_aliyah`), `shnayim_mikra_source` (`onkelos`, `rashi`), and the explicit `shnayim_mikra_parsha_schedule` (`eretz_yisrael`, `chutz_laaretz`). New track creation initializes the schedule once through `shnayimMikraScheduleFromLegacyYomTovFlag`; this is the small adapter to replace when the separate one-day/two-day Yom Tov minhag setting lands. The schedule is stored with Shnayim Mikra preferences and never follows later location changes. Legacy tracks without the explicit field use the adapter only until initialized.
- Added one `learnerSettings` governed edit action. Firestore recognizes the new keys and validates allowed values; the existing `learnerSettings` rule requires a parent actor, so child-mode writes are denied. The settings fields are not exposed in child mode; the parent settings surface can wire the edit action in the UI phase.
- Targeted validation passed: curriculum ID/defaults, strict learner settings codec, storage schema golden, governed settings action, existing learner settings command, curriculum picker, and progress/siyum tests (93 tests passed). Targeted Dart analysis reported no issues; the Firestore rules test file passes `node --check`. The Firestore emulator rules matrix was updated but not executed in this worktree.

## Phase 4 weekly assignment and learning-list projection findings

- Added `ShnayimMikraWeeklyAssignment` using `kosher_dart`'s `JewishCalendar.getParshah()` and the governed Shnayim Mikra track minhag. It skips `Parsha.NONE` festival Shabbosos, keeps paired portions as one enum/key, and selects the next regular Shabbos assignment.
- Each assignment has a stable `YYYY-MM-DD:PARSHA_ENUM:MINHAG` key, a Friday civil due date, and a region-correct Simchas Torah catch-up limit. The assignment is overdue starting Shabbos and remains eligible through Simchas Torah inclusive. Projection keeps available previous assignments separate from the next week's assignment.
- Added an active-learner schedule provider that derives date/time from `LearnerZone` using the learner's stored IANA time zone. The week itself follows the explicit Shnayim Mikra minhag schedule; location is used only as the temporary creation default and is not read again once the value is stored. The learning screen now includes a weekly assignment slot for an active Shnayim Mikra track.
- Phase 4's slot currently presents assignment and catch-up count; reader navigation, completion-derived progress and localized strings are delivered in the following phases. The completion keys are already accepted by the projection so phase 5 can remove completed assignments from catch-up.
- Targeted tests cover every regular 5787–5788 fixture row in both regions, festival skipping, a paired sedra, Friday due/Simchas Torah grace, and a new weekly assignment alongside overdue catch-up. The Learning screen and calendar/content tests passed. Whole-tree format and `flutter analyze --fatal-infos` gates passed before the phase push.

## Phase 5 reader and completion projection findings

- Extracted the shared `SegmentWithGlosses` reader widget and reused it for the three-pass Shnayim Mikra reader. The reader loads Chumash verses, aliyah boundaries, and Onkelos/Rashi from the bundled content DB; it displays the whole selected unit twice in Hebrew, then the chosen third reading. Rashi comments display in reference order, and pesukim without Rashi show an explicit empty-comment message.
- Added pass planning for pasuk-by-pasuk, aliyah-by-aliyah, and parsha-by-parsha. Daily aliyah pacing assigns aliyah 1–5 Sunday–Thursday and aliyot 6–7 Friday using the learner's local date. The weekly slot now opens both the current parsha and overdue catch-up parshiyos through the existing grace date.
- A unit completion records its Chumash verse refs under the independent `shnayim_mikra` curriculum. A dedicated learner-state corpus mirrors Chumash leaves under that curriculum ID, so Shnayim Mikra progress, points, and streaks remain separate from ordinary Chumash. All modes record the same verse refs, normalizing points to one first-learning award per pasuk **per weekly assignment cycle** (cycle key includes Shabbos date, parsha enum, and Eretz Yisrael/Chutz la'aretz schedule). Repeating a pasuk in a later cycle can earn once again; duplicate completion within the same cycle cannot. The existing streak projection counts a distinct learning date once.
- Pass markers and unit completion are keyed to the same weekly assignment cycle. Pass-three markers also persist the selected commentary source so changing Onkelos/Rashi mid-unit resumes at the correct source-specific pass. Reopening a current or catch-up reader uses only that assignment's completed refs and pass markers; another year's same parsha begins fresh without erasing the older assignment's history.
- Targeted tests cover the reading-unit order and daily-aliyah boundaries, the independent Chumash-derived corpus and event/point separation, parallel-text seed lookup, weekly assignment behavior, and the existing text-reader widget. Whole-tree gates and the required `CurriculumId.values` test-file sweep are run before the phase push.

## Phase 6 settings and release findings

- The release gate is removed only after the three-pass reader, weekly assignment card, and settings flow are present. Shnayim Mikra appears in learning-track selection, while Browse remains limited to curricula with standalone content trees; Shnayim Mikra reuses Chumash text through its dedicated workflow.
- Adding a new Shnayim Mikra track appends its initial parsha minhag to the same governed activation action. It reads `yom_tov_days` once (`1` → Eretz Yisrael, `2` → Chutz la'aretz), falls back to legacy `in_israel` only when the explicit field is absent, and preserves an already stored value on re-add. Later location or Yom Tov setting changes do not rewrite this per-track choice.
- The learning-list settings control is shown for adult profiles and for child profiles after the parent PIN is authenticated. It is hidden during a tutored session. The governed learnerSettings writer and Firestore parent-only rule remain the authorization boundary. The settings dialog edits mode, pace, third-reading source, and Eretz Yisrael/Chutz la'aretz schedule; mode/source/schedule labels are localized in English and Hebrew.
- Focused release coverage verifies CurriculumId selection/decoding, the activation action's initial schedule patch, and the parent/child/tutor editor-visibility rule. No full test suite is run.

## Decisions confirmed by user

1. **Parsha schedule:** Store an independent Shnayim Mikra minhag setting, Eretz Yisrael or Chutz la'aretz, editable in that track's parent settings. Initialize it once from explicit `yom_tov_days` (1 → Eretz Yisrael, 2 → Chutz la'aretz), using legacy `in_israel` only when the explicit setting is absent; never change it when location or Yom Tov days change. No setup question.
2. **Reading source:** Release 1 offers both Onkelos and Rashi; the learner chooses one as the third reading.
3. **Deadline:** Due before Shabbos. Remain overdue and available for catch-up through Simchas Torah; the next week's assignment is not blocked.

## Phase 1 calendar and content spike findings

### Calendar fixture

- `kosher_dart 2.0.20` exposes `JewishCalendar.getParshah()` and a mutable `inIsrael` flag; the method returns `Parsha.NONE` on festival Shabbosos with no weekly reading. This is the calendar API for the stored per-track schedule region, not the learner's current travel/location.
- Added `learning_tracker/test/fixtures/calendar/parsha_cycle_5787_5788.json` from Hebcal's REST calendar output for years 5787 and 5788 (`yt=H`, `i=on/off`; CC BY 4.0) and `learning_tracker/test/features/scheduler/domain/services/parsha_cycle_fixture_test.dart`. The fixture has 212 Shabbat/region rows, 56 weekly parsha forms (including doubles), and festival Vezot aliyot for Israel and diaspora.
- Cases include festival readings, the 5787 Shavuot split (Nasso / no weekly parsha, then Beha'alotcha / Nasso), diaspora Chukat-Balak, reunion at Pinchas, and 5788 double portions. The aliyah fixture covers 405 boundaries and maps continuously across all 5,846 Chumash refs when festival Vezot is included. A local Python consistency check found no missing ref endpoints or enum names.
- The committed calendar fixture test was run on the Flutter-enabled host after `PATH=/home/daniel/development/flutter/bin:$PATH` was supplied; it passed. Phase 2's combined focused validation reran the calendar/aliyah fixture test successfully alongside repository coverage.

### Sefaria coverage and source constraint

- The local Sefaria Mongo dump at `/home/daniel/repos/sefaria_dump/dump` and generated `book_text_cache.json` were absent in both the story worktree and main checkout. Phase 1 therefore validated against Sefaria's live versioned texts API; Phase 2 captured that response as a checked-in deterministic seed input, so seed builds are offline and reproducible. API references and semantics: [Texts v3](https://developers.sefaria.org/reference/get-v3-texts) and [Sefaria text references](https://developers.sefaria.org/docs/text-references).
- The checked-in manifest has 5,846 Chumash verse refs. The selected Hebrew Public Domain Onkelos editions returned non-empty text for all 5,846. The selected Public Domain Hebrew Rashi editions returned 7,816 comment strings over 5,669 positioned pesukim: 3,900 pesukim have comments, 2,098 have multiple comments, and 1,946 have none or no position. Rashi refs are comment-grained (for example, `Rashi on Genesis 1:1:1`); Onkelos refs are verse-grained (for example, `Onkelos Genesis 1:1`).
- The content DB simulation appended a source-keyed `parallel_text` table to a copy of the shipped 453,431,296-byte raw DB. It stored Onkelos as 5,846 rows (1,282,345 UTF-8 text bytes) and Rashi as 7,816 comment rows (combined Hebrew text 3,730,191 UTF-8 bytes). The measured xz sizes below use the repository's `xz -9 --extreme` setting. These are live-API payload measurements, before seed cleaning and with no English text, rather than a local-Mongo build.

### Measured DB size deltas

| Seed additions | Rows | Raw DB delta | xz `-9 --extreme` delta | Resulting raw DB | Resulting xz |
|---|---:|---:|---:|---:|---:|
| Onkelos only | 5,846 | 1,830,912 B (1.75 MiB) | 260,780 B (255 KiB) | 455,262,208 B | 64,341,256 B |
| Onkelos + Rashi | 13,662 | 5,185,536 B (4.94 MiB) | 805,600 B (787 KiB) | 458,616,832 B | 64,886,076 B |

The baseline shipped DB is 453,431,296 raw bytes / 64,080,476 xz bytes. The simulation creates `parallel_text(source_key, sefaria_ref, hebrew_text, english_text)` with a composite primary key, inserts only the chosen Hebrew Public Domain text, and compresses the complete resulting DB with the same `xz -9 --extreme` options as the seed builder. Actual local-seed figures may differ after text cleaning and because the local source dump was unavailable.

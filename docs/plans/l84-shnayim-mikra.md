# Shnayim Mikra v'Echad Targum: product and implementation proposal

**Bead:** `learning-tracker-l84`  
**Status:** Planning proposal only; no production changes in this step.

## Recommendation

Add **Shnayim Mikra v'Echad Targum** as its own learning-list curriculum (`shnayim_mikra`), alongside Chumash. It has a different learning unit and completion contract from ordinary Chumash: each assigned weekly portion is read twice in Hebrew and once in a selected commentary/translation. Give the learner a configurable practice mode and source, but keep both under the one curriculum so one weekly cycle, progress history, streak, and points account for the whole mitzvah.

Do not model the three readings as ordinary stage/review events for Chumash. Use a dedicated reader/progress unit backed by Shnayim Mikra events. Chumash's existing 1-completion-per-pasuk behavior and stage schedule should remain independent.

## 1. Modes and curriculum shape

### Initial modes

1. **Pasuk by pasuk (recommended default).** For each verse show/check off: Mikra reading 1, Mikra reading 2, then the selected third reading (Onkelos by default). Advance only after the three actions are complete. Persist the three substeps independently so a learner can stop and resume within a verse. A pasuk counts complete when all three substeps are recorded.
2. **Aliyah by aliyah.** For the current aliyah, read its full Hebrew section twice, then its Onkelos (or chosen alternative) section once. The user marks each pass complete. Record the aliyah as complete only after all three passes; parsha progress is complete after all aliyot.
3. **Parsha by parsha.** Read the full assigned parsha twice, then its selected third reading once, and mark the three passes. Keep a visible outline and allow marking an aliyah or the whole pass complete. This is a larger session and should warn that pass completion is whole-unit, not inferred from opening the text.
4. **Daily aliyah pacing (optional pace setting).** Split the current parsha across Sunday–Friday: assign aliyot 1–5 to Sunday–Thursday and aliyot 6–7 together on Friday. Each day's item is a due subtask of this week's parsha; the user may do more than one in a day. Track three readings per aliyah according to the chosen reading mode.

Expose **mode** (pasuk / aliyah / whole-parsha) and **pace** (self-paced / daily aliyah) as settings on the one Shnayim Mikra curriculum, not as separate list entries. Offer **Onkelos / Rashi** as the third-reading source setting, with Onkelos as the default and clear labeling that Rashi is an alternative minhag/custom. Keep the selected source consistent across the three-reading workflow. Preserve the user's settings when changing pace or source. Do not offer Rashi in the first implementation until source licensing/content coverage and a reliable selectable Sefaria ref mapping are verified.

### Curriculum/list placement

Add the curriculum to `CurriculumId`, the canonical curriculum order/default configuration, picker, localization, and hierarchy/content routing. Display it distinctly from Chumash (for example, “Shnayim Mikra” / “שנים מקרא”), with a subtitle explaining the current week's parsha and reading mode. It should not appear as a second Chumash track choice or be implemented by silently changing Chumash's completion semantics.

## 2. Weekly parsha cycle and due date

### Source and regional schedule

`kosher_dart` is already a dependency and its `JewishCalendar` contains parsha-cycle calculation and an Israel/diaspora setting. Prototype that as the runtime source of the parsha read for the upcoming Shabbos; use the existing `HebrewCalendarUtils` only for Hebrew date conversion/labels, and confirm the package's parsha result for both regions against a trusted calendar fixture before treating it as authoritative. The library handles calendar-year patterns and paired portions; do not recreate its double-parsha logic from the current hand-maintained chapter-start list.

The inspected app already has an offline calendar pattern: `calendar_cycles` maps `program_key + date_key` to refs, `LocalCalendarEngine` reads it, and the content seed is built locally. There is **no weekly parsha program in the runtime calendar registry**. Add a dedicated program key (or two region-keyed variants) to the seed/lookup path, keyed by Shabbos date, and cache the result in content.db so the current and near-future cycle work offline. If kosher_dart cannot produce the required region/Yom-Tov behavior reliably, use an explicit tested parsha calendar seed generated from an authoritative source rather than a runtime network dependency.

Persist the learner's Israel/diaspora choice with curriculum configuration; do not infer it from device locale or location. Ask once during setup, allow editing later, and recalculate only future assignments when changed. Keep the active week's assignment stable if the setting is changed midweek, or explicitly migrate it as a user-confirmed reset.

### Yom Tov and paired portions

A Shabbos with a festival reading is not a regular weekly parsha. Do not display a made-up parsha when the calendar reports no weekly sedra. The calendar resolver should identify the next regular weekly reading; a week with a paired parsha is one combined assignment, completed once. Cover Israel/diaspora divergence after holidays (including when they reunite), all paired portions, and the annual transition around Simchas Torah with golden fixtures. A local rule should state whether a festival's own Torah reading is out of scope.

### Deadline

Recommended first version: deadline is **before the assigned Shabbos begins** in the learner's chosen home time zone, using the existing date-only due/overdue pipeline for the displayed date and not requiring candle-lighting-time location data. Mark overdue after Shabbos begins and keep the prior parsha available as catch-up without rolling it into this week's completion. A no-parsha/festival week should not create a false overdue item. Give the app one explicit weekly deadline rule rather than a separate rolling/deadline ScheduleSpec for every pasuk. Existing `ScheduleSpec` governs review-stage timing; it is not a weekly calendar assignment contract.

Whether the user wants a grace window until Simchas Torah, or a grace window after the current Shabbos, needs a product decision; see open questions.

## 3. Text data, references, and offline availability

### Sources

- Use existing Hebrew Chumash leaves from the shipped Sefaria-derived curriculum hierarchy/text seed. Canonical atomic refs are chapter/verse refs such as `Genesis 1:1`; ensure a helper converts that representation to the dot form used by the current Chumash text cache (the current `text_cache` seed uses refs like `Genesis 1.1`).
- Fetch/cache the third reading from Sefaria's text source at seed-build time, not on device. The expected Sefaria refs are `Onkelos Genesis 1:1` for Onkelos and `Rashi on Genesis 1:1` for Rashi; validate actual canonical refs and Hebrew/English version availability against the local Mongo dump / source data. Store the Aramaic Onkelos text in the Hebrew-script field and an English rendering only if the selected Sefaria version provides it. Apply the existing Sefaria text cleaning/HTML decoding rules.
- Runtime reader is offline-first. Include required Onkelos text in `assets/db/content.db.xz` and generated gzip asset through the normal seed pipeline; never fetch per pasuk during ordinary reading. If any version cannot be bundled, identify that limitation before launch instead of silently depending on network. Optional online refresh is a future product decision.

### Shape and size

`text_cache` currently stores one row per ref with Hebrew and English text; `TextCacheRepository` resolves exact refs, child verses, then `daily_content`. It has no commentary/reading-role column. Prefer a dedicated table such as `parallel_text` with primary key `(source_key, sefaria_ref)`, Hebrew-script text and optional English text, rather than overloading `text_cache` with a fake Chumash curriculum key. Alternatively, after a spike, extend text_cache to support language/version keys if that benefits other parallel-text features too.

There are about 5,845 Chumash pesukim in the current Sefaria fetcher. Bundling one Onkelos row per pasuk means roughly 5.8K new records; supporting Rashi too means another roughly 5.8K. The compressed size is not measured yet. Before committing seed data, report the actual incremental compressed/uncompressed database size for Hebrew-only Onkelos and for Onkelos plus Rashi, and choose the supported scope against the APK budget. Seed from the documented local Sefaria Mongo pipeline, extend its deterministic extract/validation, and bump the content DB schema/seed metadata as required.

## 4. Reader, learning-list, progress, streak, and points

### Reader behavior

Build a dedicated Shnayim Mikra reader over the existing Chumash text and the parallel-text repository. Preserve Hebrew/English display and font/Nikud preferences. Show a persistent parsha/aliyah/pasuk breadcrumb and explicit current pass label (“First Mikra”, “Second Mikra”, “Onkelos” or “Rashi”). For pasuk mode, keep all three texts grouped in a verse card. For aliyah/parsha mode, expose one pass at a time across the whole selected unit, with a clear action to mark the pass finished; do not mark completion merely because the text was opened or scrolled. The current text reader is a single-ref Chumash viewer and its completion action marks the current ref, so extend it behind a distinct route/reader flow rather than trying to repurpose that button without changing its contract.

Show weekly progress as completed substeps and completed pesukim/aliyot (for example, “18/42 pesukim: 2 readings + Onkelos complete”), with accessible partial state. Allow resuming the first incomplete task and reviewing completed text. Mark a pasuk or aliyah done only after the required readings for that mode; completing the entire assigned parsha marks the weekly unit done.

### Learning list and gamification

The home learning list should show one Shnayim Mikra card with the assigned parsha, regional calendar label where useful, due status, and progress. Daily aliyah pace may display today's aliyah and “x of 6/7 aliyot this week” while still rolling up to the one weekly parsha. Keep the previous assignment available as overdue/catch-up and show the next assignment only as preview, not as due work.

Emit completion events through the existing learner-state write path, attributed to the Shnayim Mikra curriculum and existing child/tutor actor/source rules. Events must distinguish verse/aliyah/parsha unit and pass/source so repeats are idempotent across devices and can be reversed correctly; current `LearningEvent` has `curriculum_id`, `ref`, `level`, `stage`, but no explicit pass/source role beyond its general event source. Decide and document a stable event-ref or explicit event-subtype contract in the first model bead. Do not record three indistinguishable completions against the same Sefaria ref, and do not let a completion count toward ordinary Chumash.

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
2. **Content model and seed:** canonical Chumash aliyah/parsha mapping plus parallel-text source key; content DB schema, deterministic Onkelos seed and offline lookup. Rashi is either included after the spike proves feasible or left disabled with a documented follow-up.
3. **Curriculum and governed settings:** curriculum ID/picker/defaults; mode/source/pace/region persistence and backward-compatible defaults; child/tutor configuration boundaries.
4. **Weekly assignment and learning-list projection:** region-specific parsha cycle, weekly due/overdue/catch-up projection, Yom Tov handling, one learning-list card.
5. **Reader and completion model:** three pass workflows, unit completion/resume, event model/codec/rules/sync/void semantics, points and streak integration.
6. **Localization and targeted acceptance:** en/he strings, RTL review, targeted regressions across calendar, data, reader, state/rules, child/tutor, list and progress.

Bead 1 is a gating fact-finding deliverable; beads 2–6 can be split/parallelized once its interfaces are agreed. Keep each implementation bead narrow enough for one review round where possible; do not include a full-suite run on every bead.

## Open questions for the user

1. **Which region should be the initial default: Israel or diaspora, with the learner able to change it later?**
2. **Should Rashi be offered alongside Onkelos in the first release, or should the first release support Onkelos only and add Rashi after content coverage is verified?**
3. **Should the deadline be before this week's Shabbos, or should an unfinished parsha stay in grace/catch-up through Simchas Torah?**

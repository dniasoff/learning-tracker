# Addendum: Sub-tracks PRD

## 1. Existing capabilities this change builds on

| Capability | Where it lives (file:line from extract-code-reality.md) | What already exists | Gap for this PRD | Related FRs |
|---|---|---|---|---|
| Track model | `learning_tracker/lib/features/tracks/setup/domain/entities/curriculum_track.dart:17-33,85-107`; `learning_tracker/lib/features/learning/domain/entities/completion_entity.dart:61-72` | One track per profile and curriculum; lifecycle and reorder metadata; completion has a `trackType` string. | No stored position or sequence, and no track-type enum; sub-track order and pointer need modeling. | FR-5–13 |
| Completion event log | `learning_tracker/lib/features/learning/domain/entities/completion_entity.dart:46-94`; `docs/firestore-collection-layout.md:99-116`; `learning_tracker/lib/features/progress/domain/services/lifetime_tree_builder.dart:74-105`; `learning_tracker/lib/features/progress/presentation/providers/lifetime_knowledge_providers.dart:566-577` | Events have source and `completedAt`; repeated acts are separate records; purged events are filtered from lifetime state. | Add date-state semantics, source behavior for sub-tracks, and distinct-progress/event-history queries required by the PRD. | FR-2–4, 14, 16, 27–28, 30–32 |
| Bulk backfill sentinel | `learning_tracker/lib/features/onboarding/domain/services/bulk_prior_completion_service.dart:239-253,294-317`; `learning_tracker/lib/features/progress/domain/services/pace_calculator.dart:28-40`; `learning_tracker/lib/features/scheduler/domain/services/daily_task_projection_service.dart:383-409` | Bulk prior marks use UTC `2000-01-01`; `bulkBaseline` marks count for achievement/lifetime but are excluded from velocity and scheduled work. This maps to the PRD's “before tracking” date state. | General event capture and reports need a consistent date-state representation. Verify no tap-dated setup backfill is in production before planning migration. | FR-3, 14, 19, 28–30 |
| Derived schedule and reorder amnesty | `learning_tracker/lib/features/scheduler/domain/services/daily_task_projection_service.dart:76-95,207-239,300-349,383-418` | Schedule is projected from curriculum order, activation, goals, completions, and study-day settings; `lastReorderAt` supports overdue amnesty. | Recompute when sub-track ground, rates, windows, or events change, while retaining the existing main-track task behavior. | FR-4, 8, 10–12, 19–22 |
| Tri-state checkbox | `learning_tracker/lib/features/onboarding/presentation/screens/bulk_mark_screen.dart:590-599`; `learning_tracker/lib/features/progress/presentation/widgets/lifetime_folder_styled_widgets.dart:493-500,545-579` | Partial state exists in bulk marking and lifetime marking-scope rows. | Extend cascade rendering to all corpus nodes, ground selection, and sub-track detail. | FR-3, 9, 10, 15 |
| Goals | `learning_tracker/lib/features/scheduler/domain/models/goal_entity.dart:83-110`; `learning_tracker/lib/data/repositories/firestore_goal_repository.dart:18-23` | Per-curriculum goals can have deadline, pace, or no goal; multiple goals per curriculum are allowed. | PRD requires exactly one deadline-bearing whole-corpus goal for the main track; no such constraint exists. | FR-19–21 |
| `sacred_time` zmanim windows | `learning_tracker/lib/features/sacred_time/domain/services/zmanim_window_service.dart:1-27`; `learning_tracker/lib/features/sacred_time/data/services/sacred_time_preferences.dart:4-16`; `learning_tracker/lib/features/sacred_time/presentation/providers/sacred_windows_provider.dart:11-27` | `kosher_dart` computes windows from location, Israel flag, candle-lighting/tzais boundaries; a current lock state is provided when windows are available. | Apply capture locking and catch-up semantics to this feature; location is currently global across profiles. | FR-23–25 |
| Tutor grants and routing | `learning_tracker/lib/data/firestore/repository_providers.dart:142-199`; `learning_tracker/lib/features/learning/domain/entities/learning_ledger_entry.dart:132-146` | Tutor grants route reads/writes to the learner owner's profile; completion `markedBy` identifies a profile. | No tutor-account attribution on completions; provide tutor editing and multi-talmid views per PRD. | FR-4, 8–13, 26–27 |
| Firestore paths | `docs/planning/architecture/architecture-learning-tracker-2026-07-30/ARCHITECTURE-SPINE.md:6-9,34-42`; `docs/firestore-collection-layout.md:90-110`; `learning_tracker/lib/data/repositories/firestore_curriculum_track_repository.dart:132-136`; `learning_tracker/lib/data/repositories/firestore_goal_repository.dart:131-136` | Current profile-scoped paths include `curriculum_tracks/{curriculumId}`, `completions`, `learning_ledger`, and `goals/{goalId}` under `users/{uid}/learner_profiles/{profileId}`. | Persist sub-track records and any required event fields in the current profile-scoped layout; older `data-models.md` diagrams do not describe current paths. | FR-2–14, 19–21, 23–32 |

## 2. Technical notes carried from the brainstorm

- Keep the plan and backlog derived rather than stored; recompute after any input that changes them. (FR-4, 8, 10–12, 19–22)
- Represent learning as an append-only event log and query distinct learnt mishnayos separately from total learning events. (FR-2–4, 14, 16, 27–28, 30–32)
- Infer event source from the capture context; a sub-track row supplies its own source without another prompt. (FR-2–3, 26–28, 30–32)
- Compute tri-state status through the corpus hierarchy and share that behavior across browser, ground picker, sub-track progress, and backfill. (FR-3, 9–10, 15)
- Calculate each sub-track's forecast capacity over the remaining active weeks before the deadline, prorating a partial window. (FR-19)
- Model each sub-track with ordered ground, one current pointer, a type, window, rate, and weeks; share ordering/position concepts with the main track where appropriate. (FR-5–13)
- Use `kosher_dart` for Shabbos/Yom Tov lock windows and Israel-vs-diaspora rules; the brainstorm also mentions optional support for weeks pre-fill. (FR-6, 23–25)
- Use `flutter_local_notifications` for the motzei reminder. (FR-25)
- Enforce write-locking at the capture boundary while allowing reads; bias toward remaining locked if lock state cannot be established. (FR-23–25)
- Clone and shift the prior school-year sub-track for “Add next year”; compute eligible academic years in the picker. (FR-5, 7)
- Generate PDF output for the reports. (FR-31–32)
- Setup-day backfill is already stored with the 2000-01-01 sentinel (`bulk_prior_completion_service`); verify no tap-dated backfill exists in production before planning any migration. (FR-3, 14, 30)

## 3. Forecast computation notes

FR-19 applies only to the whole-corpus goal on the main track. For each active sub-track, calculate **capacity** as its weekly rate multiplied by its active weeks remaining before the deadline, prorating a partial window. Its **path** is all entered ground from its current position to the end of its order, including mishnayos already learnt; the sub-track must pass through them all. **Shortfall** is the unlearnt ground on that path beyond what capacity can reach. **Expected new ground** is `max(0, capacity − path length)`, representing capacity beyond entered ground. Subtract expected new ground from main-track remaining and add shortfall. Main-track remaining excludes ground assigned to active sub-tracks, so do not subtract their capacity again. Count a mishna's shortfall at most once across sub-tracks; if another active sub-track holding it is forecast to reach it, it is not shortfall. Divide the adjusted remaining ground by the main track's remaining study days (using its existing study-day setting, defaulting to all seven) to get the daily target. A sub-track with no entered ground has a path length of zero, so its full capacity is expected new ground. This expresses FR-19 in implementation terms.

## 4. Rejected alternatives (rationale)

- Infer calendars from observed velocity — parked for simplicity until manual estimates prove inadequate.
- Confidence intervals and widening forecast bands — cut for simplicity.
- Streak-safety logic — cut; streaks do not apply to sub-track learning.
- Per-scope or sub-track deadlines — rejected; one deadline belongs to the main track.
- Collision dialogs, dedupe, or automatic credit choices — replaced by recording chazara as another event.
- Warm/cold chazara prompts — offered but not adopted for simplicity.
- Annual totals instead of rate × weeks — offered but not adopted.
- Imported or hardcoded school calendars and country-specific term dates — rejected because each school differs.
- Separate sub-track exclusion checkboxes — not used; the existing main-track study-day setting supplies the daily-target denominator, while sub-track capacity is based on its configured active weeks.
- Multiple masechtos on the main track — reversed to preserve the existing planner.
- Independent positions and rows per masechta — withdrawn; each track has one ordered position.
- Unified main/sub-track row UI — withdrawn; the main track produces tasks, while a sub-track presents a position.
- Estimates in main-track goal settings — withdrawn; estimates belong on sub-track forms.
- School-year numbering and a “current school year” setting — removed because numbering varies by country.
- “Free tick” as a source — rejected; it describes capture method, not who or where.
- Completions as a set — withdrawn in favor of an event log supporting lifetime history.
- A separate backfill flow — dropped; backfill uses the free-tick surface.
- Shabbos “self-healing” without special handling — rejected after user pushback.
- Arbitrary school-sub-track date windows — rejected in favor of September–July defaults with editable start and end months.
- Main-track rework — out of scope; retain the planner and task generation.

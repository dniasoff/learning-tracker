# Code reality (gpt-6-luna, 2026-09-30)

## 1. Track model

**NOT PRESENT:** a personal/school/tutor track-kind enum. Product rules explicitly say there are no track types; the live track model is keyed by `(profile, curriculum)`, one per curriculum. It stores curriculum, lifecycle state, activation date, optional pace-reset date, and reorder timestamp. It does **not** store sequence or current position; progress-shaped fields are decode-only passthroughs. Completions still contain a plain `trackType: 'personal'` string. A track covers a curriculum; **NOT PRESENT:** a one-masechta-per-track restriction. [Product rules](docs/product-rules.md:122-130) · [track entity](learning_tracker/lib/features/tracks/setup/domain/entities/curriculum_track.dart:17-33) · [progress fields](learning_tracker/lib/features/tracks/setup/domain/entities/curriculum_track.dart:85-107) · [completion entity](learning_tracker/lib/features/learning/domain/entities/completion_entity.dart:61-72)

## 2. Completion storage

Completions are event records, not a done/not-done set: each record identifies a curriculum, leaf reference, stage, source, and `completedAt`; it has no `createdAt`. Repeated learning is represented across stages (including review/chazara stages); the collection layout describes one event per discrete act. Retraction uses a purge timestamp. **Lifetime state** is computed by `LifetimeTreeBuilder` from completion refs plus learning-ledger scope marks; the provider filters purged entries before building the learned-ref set. [completion entity](learning_tracker/lib/features/learning/domain/entities/completion_entity.dart:46-94) · [collection layout](docs/firestore-collection-layout.md:99-116) · [tree builder](learning_tracker/lib/features/progress/domain/services/lifetime_tree_builder.dart:74-105) · [provider](learning_tracker/lib/features/progress/presentation/providers/lifetime_knowledge_providers.dart:566-577)

## 3. Backfill

Bulk prior marks use the fixed UTC `2000-01-01` sentinel for `completedAt`, not the historical date actually learned. They are tagged `bulkInTrack`: no streak or points, but achievement and lifetime credit. Pace calculations count them as `bulkBaseline` and subtract them from required velocity; the scheduler skips pre-anchor completions when generating scheduled work. [bulk service](learning_tracker/lib/features/onboarding/domain/services/bulk_prior_completion_service.dart:239-253) · [sentinel write](learning_tracker/lib/features/onboarding/domain/services/bulk_prior_completion_service.dart:294-317) · [pace baseline](learning_tracker/lib/features/progress/domain/services/pace_calculator.dart:28-40) · [scheduler exclusion](learning_tracker/lib/features/scheduler/domain/services/daily_task_projection_service.dart:383-409)

## 4. Scheduling / pace

The schedule is projected from ordered curriculum items, track activation, goals, completions, and study-day settings; no stored daily plan is used as source of truth for today/overdue. Deadline-only goals can derive pace from remaining scope and study days. Reorder timestamps drive an overdue “amnesty” cutoff, so earlier overdue items can be filtered after reorder. [projection inputs and anchor](learning_tracker/lib/features/scheduler/domain/services/daily_task_projection_service.dart:76-95) · [deadline pace derivation](learning_tracker/lib/features/scheduler/domain/services/daily_task_projection_service.dart:300-349) · [projection schedule](learning_tracker/lib/features/scheduler/domain/services/daily_task_projection_service.dart:383-418) · [reorder cutoff](learning_tracker/lib/features/scheduler/domain/services/daily_task_projection_service.dart:207-239)

## 5. Partial-completion rendering

**Present:** tri-state/indeterminate checkboxes in the bulk-mark hierarchy and lifetime marking scope rows; partially selected containers show a dash. [bulk-mark screen](learning_tracker/lib/features/onboarding/presentation/screens/bulk_mark_screen.dart:590-599) · [lifetime scope row](learning_tracker/lib/features/progress/presentation/widgets/lifetime_folder_styled_widgets.dart:493-500) · [checkbox state](learning_tracker/lib/features/progress/presentation/widgets/lifetime_folder_styled_widgets.dart:545-579)

## 6. Goals / deadlines

Goals are per curriculum and support deadline, pace, or none, with target date, pace rate/period, and granularity. Multiple goals per curriculum are allowed; **NOT PRESENT:** a one-goal-per-track constraint. [goal model](learning_tracker/lib/features/scheduler/domain/models/goal_entity.dart:83-110) · [goal repository](learning_tracker/lib/data/repositories/firestore_goal_repository.dart:18-23)

## 7. Shabbos / yom tov

`kosher_dart` computes Shabbos/Yom Tov blocked windows using location and Israel setting, with candle-lighting/tzais boundaries. Location is stored in app-global SharedPreferences, shared across profiles; when available, six months of windows feed a current-window lock/silence state. [window service](learning_tracker/lib/features/sacred_time/domain/services/zmanim_window_service.dart:1-27) · [location preferences](learning_tracker/lib/features/sacred_time/data/services/sacred_time_preferences.dart:4-16) · [window provider](learning_tracker/lib/features/sacred_time/presentation/providers/sacred_windows_provider.dart:11-27)

## 8. Storage backend / collection layout

The requested architecture spine describes current user data as Firestore-first (partially rewired), with local Drift for bundled content and device registry. Current profile-scoped paths include `curriculum_tracks/{curriculumId}`, `completions`, `learning_ledger`, and `goals/{goalId}` under `users/{uid}/learner_profiles/{profileId}`. The requested `data-models.md` Firestore diagram describes an older, different layout; use the current collection-layout doc and spine for present paths. [architecture spine](docs/planning/architecture/architecture-learning-tracker-2026-07-30/ARCHITECTURE-SPINE.md:6-9) · [current storage status](docs/planning/architecture/architecture-learning-tracker-2026-07-30/ARCHITECTURE-SPINE.md:34-42) · [collection layout](docs/firestore-collection-layout.md:90-110) · [track/goals paths](learning_tracker/lib/data/repositories/firestore_curriculum_track_repository.dart:132-136) · [goal path](learning_tracker/lib/data/repositories/firestore_goal_repository.dart:131-136)

## 9. Tutor / parent / child accounts

**Present:** learner profiles (including child/adult modes) and tutor grants. Tutor sessions can route reads/writes to the child owner’s profile namespace. Completion records identify `markedBy` as a learner-profile ID; **NOT PRESENT:** a separate completion field attributing the act to a tutor/parent account. [profile path and tutor routing](learning_tracker/lib/data/firestore/repository_providers.dart:142-199) · [ledger attribution](learning_tracker/lib/features/learning/domain/entities/learning_ledger_entry.dart:132-146)
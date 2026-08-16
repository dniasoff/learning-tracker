/// Story acceptance tests for Story 26.6 (DNI-349) — scheduler providers.
///
/// AC4: firstTaskInTrackForCategoryProvider exists in scheduler_providers.dart
///      and accepts (trackId, category: TrackTaskCategory).
/// AC5: TrackTaskCategory enum has values: review, dueToday, overdue.
///
/// Note: AC1-AC3 tested TrackCard / TrackCardViewModel which have been removed
/// as confirmed dead code (zero call sites outside their own directory).
@Tags(['epic_26'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:test/test.dart';

/// Minimal [DailyTask] fixture — mirrors the `_task()` helper in
/// scheduler_providers_test.dart, trimmed to the fields
/// firstTaskInTrackForCategory actually branches on.
DailyTask _task({
  CurriculumId curriculum = CurriculumId.mishnayos,
  String ref = 'Mishnah_Berakhot_1.1',
  DailyTaskPriority priority = DailyTaskPriority.newLearning,
  bool isOverdue = false,
}) {
  return DailyTask(
    curriculumId: curriculum,
    contentItemSefariaRef: ref,
    stageOrder: 1,
    priority: priority,
    isOverdue: isOverdue,
    reason: 'test reason',
    stageName: 'Learn',
    trackLabel: 'personal',
  );
}

/// A container whose [allDailyTasksProvider] is overridden with a fixed
/// [tasks] list — firstTaskInTrackForCategory's only dependency.
ProviderContainer _withTasks(List<DailyTask> tasks) {
  return ProviderContainer(
    overrides: [
      allDailyTasksProvider.overrideWith((ref) => Future.value(tasks)),
    ],
  );
}

void main() {
  // ── AC4: firstTaskInTrackForCategoryProvider in scheduler_providers ──────────
  //
  // AUD-t-story-acceptance R7: the old version of this group asserted
  // `source.contains('firstTaskInTrackForCategory')` — a string match that
  // would still pass even if the provider's body were gutted, its bucket
  // logic broken, or its (trackId, category:) parameters silently dropped.
  // The tests below call the REAL generated provider (via a
  // `ProviderContainer` with `allDailyTasksProvider` overridden, the same
  // technique `scheduler_providers_test.dart` uses for its full bucket-logic
  // suite) and assert the OBSERVABLE EFFECT: the provider genuinely accepts
  // `(trackId, category:)` and selects the correct task from
  // `allDailyTasksProvider`. Strictly stronger than the text match — it
  // fails if the provider is renamed, its parameters change shape, or its
  // selection logic regresses. (Exhaustive bucket-selection coverage —
  // review/dueToday/overdue crossed with match/no-match/wrong-track — lives
  // in scheduler_providers_test.dart; these two are a representative
  // acceptance-level smoke, not a duplicate of that suite.)
  group(
    'Story 26.6 AC4 — firstTaskInTrackForCategoryProvider in scheduler_providers',
    tags: ['story_26_6'],
    () {
      test('accepts (trackId, category:) and returns the first dueToday task '
          'for that track from allDailyTasksProvider', () async {
        final container = _withTasks([
          _task(
            ref: 'other_track_task',
            curriculum: CurriculumId.bavli,
            priority: DailyTaskPriority.newLearning,
          ),
          _task(ref: 'today_task', priority: DailyTaskPriority.todayProgram),
          _task(
            ref: 'chazara_task',
            priority: DailyTaskPriority.scheduledChazara,
          ),
        ]);
        addTearDown(container.dispose);

        final task = await container.read(
          firstTaskInTrackForCategoryProvider(
            curriculumId: CurriculumId.mishnayos,
            category: TrackTaskCategory.dueToday,
          ).future,
        );

        expect(
          task?.contentItemSefariaRef,
          'today_task',
          reason:
              'must select the dueToday-bucket task for the mishnayos curriculum, '
              'ignoring the review-bucket task on the same curriculum and the '
              'task belonging to a different curriculum',
        );
      });

      test(
        'review bucket returns null when the track has no review-priority '
        'tasks (provider genuinely evaluates the bucket, not a stub)',
        () async {
          final container = _withTasks([
            _task(priority: DailyTaskPriority.newLearning),
          ]);
          addTearDown(container.dispose);

          final task = await container.read(
            firstTaskInTrackForCategoryProvider(
              curriculumId: CurriculumId.mishnayos,
              category: TrackTaskCategory.review,
            ).future,
          );

          expect(task, isNull);
        },
      );
    },
  );

  // ── AC5: TrackTaskCategory enum has correct values ───────────────────────────
  group(
    'Story 26.6 AC5 — TrackTaskCategory enum has review / dueToday / overdue',
    tags: ['story_26_6'],
    () {
      test('TrackTaskCategory has exactly 3 values', () {
        expect(TrackTaskCategory.values.length, 3);
      });
    },
  );
}

/// Story acceptance tests for Story 26.6 (DNI-349) —
/// TrackCard + 5 subcomponents + TrackCardViewModel.
///
/// AC1: lib/features/dashboard/presentation/widgets/track_card/ contains
///      TrackCard, TrackCardHeader, NextTaskBreadcrumb, TrackStatGrid,
///      LifetimeLearningLine, TrackContinueButton.
/// AC2: TrackCardViewModel is a freezed value type importable from
///      lib/features/dashboard/domain/models/track_card_view_model.dart.
/// AC3: All 4 TrackCardShape values exist and resolve:
///      programCalendar / deadlineGoal / velocityGoal / momentum.
/// AC4: firstTaskInTrackForCategoryProvider exists in scheduler_providers.dart
///      and accepts (trackId, category: TrackTaskCategory).
/// AC5: TrackTaskCategory enum has values: review, dueToday, overdue.
@Tags(['epic_26'])
library;

import 'dart:io';

import 'package:learning_tracker/features/dashboard/domain/models/track_card_view_model.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/track_card/track_card.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:test/test.dart';

void main() {
  // ── AC1: Directory and file presence ────────────────────────────────────────
  group(
    'Story 26.6 AC1 — track_card/ directory contains all 6 files',
    tags: ['story_26_6'],
    () {
      const base =
          'learning_tracker/lib/features/dashboard/presentation/widgets/track_card';
      const files = [
        'track_card.dart',
        'track_card_header.dart',
        'next_task_breadcrumb.dart',
        'track_stat_grid.dart',
        'lifetime_learning_line.dart',
        'track_continue_button.dart',
      ];

      for (final name in files) {
        test('$name exists', () {
          final candidates = [
            File(
              'lib/features/dashboard/presentation/widgets/track_card/$name',
            ),
            File('$base/$name'),
          ];
          final file = candidates.firstWhere(
            (f) => f.existsSync(),
            orElse: () => candidates.first,
          );
          expect(
            file.existsSync(),
            isTrue,
            reason:
                '$name must exist in track_card/. '
                'Looked for ${candidates.map((f) => f.path).join(", ")}',
          );
        });
      }
    },
  );

  // ── AC2: TrackCardViewModel importable and is a freezed type ────────────────
  group(
    'Story 26.6 AC2 — TrackCardViewModel is a freezed value type',
    tags: ['story_26_6'],
    () {
      test('TrackCardViewModel class is importable', () {
        expect(TrackCardViewModel, isNotNull);
      });

      test('TrackCard widget is importable', () {
        expect(TrackCard, isNotNull);
      });

      test('TrackCardHeader widget is importable', () {
        expect(TrackCardHeader, isNotNull);
      });

      test('NextTaskBreadcrumb widget is importable', () {
        expect(NextTaskBreadcrumb, isNotNull);
      });

      test('TrackStatGrid widget is importable', () {
        expect(TrackStatGrid, isNotNull);
      });

      test('LifetimeLearningLine widget is importable', () {
        expect(LifetimeLearningLine, isNotNull);
      });

      test('TrackContinueButton widget is importable', () {
        expect(TrackContinueButton, isNotNull);
      });

      test('NextTaskData is a freezed type', () {
        expect(NextTaskData, isNotNull);
      });

      test('LifetimeLearningData is a freezed type', () {
        expect(LifetimeLearningData, isNotNull);
      });
    },
  );

  // ── AC3: All 4 TrackCardShape values exist ───────────────────────────────────
  group(
    'Story 26.6 AC3 — TrackCardShape has all 4 data-shape variants',
    tags: ['story_26_6'],
    () {
      test('TrackCardShape.programCalendar exists', () {
        expect(TrackCardShape.programCalendar, isNotNull);
      });

      test('TrackCardShape.deadlineGoal exists', () {
        expect(TrackCardShape.deadlineGoal, isNotNull);
      });

      test('TrackCardShape.velocityGoal exists', () {
        expect(TrackCardShape.velocityGoal, isNotNull);
      });

      test('TrackCardShape.momentum exists', () {
        expect(TrackCardShape.momentum, isNotNull);
      });

      test('TrackCardShape has exactly 4 values', () {
        expect(TrackCardShape.values.length, 4);
      });
    },
  );

  // ── AC4: firstTaskInTrackForCategoryProvider in scheduler_providers ──────────
  group(
    'Story 26.6 AC4 — firstTaskInTrackForCategoryProvider in scheduler_providers',
    tags: ['story_26_6'],
    () {
      test(
        'firstTaskInTrackForCategoryProvider provider function is importable',
        () {
          // Compile-time check: the import at the top of this file already
          // references scheduler_providers.dart which defines the provider.
          expect(firstTaskInTrackForCategoryProvider, isNotNull);
        },
      );

      test(
        'scheduler_providers.dart source declares firstTaskInTrackForCategory',
        () {
          final candidates = [
            File(
              'lib/features/scheduler/presentation/providers/scheduler_providers.dart',
            ),
            File(
              'learning_tracker/lib/features/scheduler/presentation/providers/scheduler_providers.dart',
            ),
          ];
          final file = candidates.firstWhere(
            (f) => f.existsSync(),
            orElse: () => candidates.first,
          );
          final source = file.existsSync() ? file.readAsStringSync() : '';
          expect(
            source.contains('firstTaskInTrackForCategory'),
            isTrue,
            reason:
                'firstTaskInTrackForCategoryProvider must be declared in '
                'scheduler_providers.dart',
          );
        },
      );
    },
  );

  // ── AC5: TrackTaskCategory enum has correct values ───────────────────────────
  group(
    'Story 26.6 AC5 — TrackTaskCategory enum has review / dueToday / overdue',
    tags: ['story_26_6'],
    () {
      test('TrackTaskCategory.review exists', () {
        expect(TrackTaskCategory.review, isNotNull);
      });

      test('TrackTaskCategory.dueToday exists', () {
        expect(TrackTaskCategory.dueToday, isNotNull);
      });

      test('TrackTaskCategory.overdue exists', () {
        expect(TrackTaskCategory.overdue, isNotNull);
      });

      test('TrackTaskCategory has exactly 3 values', () {
        expect(TrackTaskCategory.values.length, 3);
      });
    },
  );
}

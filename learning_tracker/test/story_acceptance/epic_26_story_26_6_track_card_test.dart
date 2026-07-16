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

import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:test/test.dart';

import '../helpers/lib_source.dart';

void main() {
  // ── AC4: firstTaskInTrackForCategoryProvider in scheduler_providers ──────────
  group(
    'Story 26.6 AC4 — firstTaskInTrackForCategoryProvider in scheduler_providers',
    tags: ['story_26_6'],
    () {
      test(
        'scheduler_providers.dart source declares firstTaskInTrackForCategory',
        () {
          final source = readLibSource(
            'features/scheduler/presentation/providers/scheduler_providers.dart',
          );
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
      test('TrackTaskCategory has exactly 3 values', () {
        expect(TrackTaskCategory.values.length, 3);
      });
    },
  );
}

/// Story acceptance tests for Story 26.7 (DNI-350) —
/// dashboardModelProvider composition; centralized onTrackChanged invalidation.
///
/// AC1: dashboardModelProvider exists in dashboard_model_provider.dart and
///      composes leaf providers into typed sub-models (DashboardModel,
///      DashboardHeaderModel, DashboardTasksModel, DashboardTracksModel,
///      DashboardLifetimeModel).
/// AC2: onTrackChanged() is the single exported helper in
///      after_track_change_invalidation.dart; invalidateAfterTrackDataChange
///      is a deprecated alias.
/// AC3: add_track_flow_screen.dart and add_track_flow.dart no longer contain
///      parallel ad-hoc invalidation lists — they call onTrackChanged instead.
/// AC4: The centralized invalidation function covers progressOverviewStats,
///      allDailyTasks, dashboardActiveCurriculaStream, dashboardStreak,
///      dashboardGlobalPoints, and per-curriculum / per-track providers.
@Tags(['epic_26'])
library;

import 'dart:io';

import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_model_provider.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/after_track_change_invalidation.dart';
import 'package:test/test.dart';

// ── helpers ───────────────────────────────────────────────────────────────────

/// Reads [path] relative to the learning_tracker/ app root when run from the
/// Flutter project directory, with a fallback for the worktree path.
String _src(String path) {
  final candidates = ['lib/$path', 'learning_tracker/lib/$path'];
  for (final c in candidates) {
    if (File(c).existsSync()) return File(c).readAsStringSync();
  }
  return File(candidates.first).readAsStringSync(); // surface the error
}

// ── tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── AC1: dashboardModelProvider composition point ──────────────────────────
  group(
    'Story 26.7 AC1 — dashboardModelProvider composes leaf providers',
    tags: ['story_26_7'],
    () {
      test('dashboardModelProvider is importable and non-null', () {
        expect(dashboardModelProvider, isNotNull);
      });

      test('DashboardModel class is importable', () {
        // Instantiating DashboardModel would require live providers; the
        // compile-time import above is sufficient to assert the class exists.
        expect(DashboardModel, isNotNull);
      });

      test('DashboardHeaderModel class is importable', () {
        expect(DashboardHeaderModel, isNotNull);
      });

      test('DashboardTasksModel class is importable', () {
        expect(DashboardTasksModel, isNotNull);
      });

      test('DashboardTracksModel class is importable', () {
        expect(DashboardTracksModel, isNotNull);
      });

      test('DashboardLifetimeModel class is importable', () {
        expect(DashboardLifetimeModel, isNotNull);
      });

      test('dashboard_model_provider.dart exists on disk', () {
        final candidates = [
          File(
            'lib/features/dashboard/presentation/providers/dashboard_model_provider.dart',
          ),
          File(
            'learning_tracker/lib/features/dashboard/presentation/providers/dashboard_model_provider.dart',
          ),
        ];
        final exists = candidates.any((f) => f.existsSync());
        expect(
          exists,
          isTrue,
          reason:
              'dashboard_model_provider.dart must exist in '
              'features/dashboard/presentation/providers/',
        );
      });
    },
  );

  // ── AC2: onTrackChanged is the single exported helper ─────────────────────
  group(
    'Story 26.7 AC2 — onTrackChanged is the canonical invalidation helper',
    tags: ['story_26_7'],
    () {
      test(
        'onTrackChanged is importable from after_track_change_invalidation',
        () {
          // Importing onTrackChanged directly verifies it is exported.
          expect(onTrackChanged, isNotNull);
        },
      );

      test('after_track_change_invalidation.dart declares onTrackChanged', () {
        final src = _src(
          'features/tracks/setup/presentation/providers/after_track_change_invalidation.dart',
        );
        expect(
          src,
          contains('Future<void> onTrackChanged('),
          reason:
              'onTrackChanged must be the primary public function in '
              'after_track_change_invalidation.dart',
        );
      });

      test(
        'invalidateAfterTrackDataChange is deprecated in favour of onTrackChanged',
        () {
          final src = _src(
            'features/tracks/setup/presentation/providers/after_track_change_invalidation.dart',
          );
          expect(
            src,
            contains('@Deprecated('),
            reason:
                'invalidateAfterTrackDataChange must be annotated @Deprecated',
          );
        },
      );
    },
  );

  // ── AC3: parallel invalidation lists deleted from add-track screens ────────
  group(
    'Story 26.7 AC3 — no parallel ad-hoc invalidation lists in add-track screens',
    tags: ['story_26_7'],
    () {
      test(
        'add_track_flow_screen.dart does not contain parallel invalidation list',
        () {
          final src = _src(
            'features/tracks/setup/presentation/screens/add_track_flow_screen.dart',
          );
          // The parallel list always contained dashboardCompletionPercentage +
          // dashboardLastCompletion + progressOverviewStats + allDailyTasks
          // as consecutive separate ref.invalidate() calls. After this story
          // they are replaced by a single onTrackChanged() call.
          final hasParallelList =
              src.contains(
                'ref.invalidate(dashboardCompletionPercentageProvider',
              ) &&
              src.contains('ref.invalidate(progressOverviewStatsProvider)');
          expect(
            hasParallelList,
            isFalse,
            reason:
                'add_track_flow_screen.dart must not have a parallel ad-hoc '
                'invalidation list — use onTrackChanged() instead',
          );
        },
      );

      test('add_track_flow.dart does not contain parallel invalidation list', () {
        // add_track_flow.dart was deleted by DNI-353 (26.10). If the file no
        // longer exists, the constraint is trivially satisfied.
        final candidates = [
          'lib/features/tracks/setup/presentation/screens/add_track_flow.dart',
          'learning_tracker/lib/features/tracks/setup/presentation/screens/add_track_flow.dart',
        ];
        final exists = candidates.any((c) => File(c).existsSync());
        if (!exists) return; // file deleted — constraint satisfied
        final src = _src(
          'features/tracks/setup/presentation/screens/add_track_flow.dart',
        );
        final hasParallelList =
            src.contains(
              'ref.invalidate(dashboardCompletionPercentageProvider',
            ) &&
            src.contains('ref.invalidate(progressOverviewStatsProvider)');
        expect(
          hasParallelList,
          isFalse,
          reason:
              'add_track_flow.dart must not have a parallel ad-hoc '
              'invalidation list — use onTrackChanged() instead',
        );
      });

      test('add_track_flow_screen.dart calls onTrackChanged', () {
        final src = _src(
          'features/tracks/setup/presentation/screens/add_track_flow_screen.dart',
        );
        expect(
          src,
          contains('onTrackChanged('),
          reason:
              'add_track_flow_screen.dart must delegate to onTrackChanged()',
        );
      });

      test('add_track_flow.dart calls onTrackChanged', () {
        // add_track_flow.dart was deleted by DNI-353 (26.10). If the file no
        // longer exists, the constraint is trivially satisfied.
        final candidates = [
          'lib/features/tracks/setup/presentation/screens/add_track_flow.dart',
          'learning_tracker/lib/features/tracks/setup/presentation/screens/add_track_flow.dart',
        ];
        final exists = candidates.any((c) => File(c).existsSync());
        if (!exists) return; // file deleted — constraint satisfied
        final src = _src(
          'features/tracks/setup/presentation/screens/add_track_flow.dart',
        );
        expect(
          src,
          contains('onTrackChanged('),
          reason: 'add_track_flow.dart must delegate to onTrackChanged()',
        );
      });
    },
  );

  // ── AC4: centralized list covers the expected providers ────────────────────
  group(
    'Story 26.7 AC4 — onTrackChanged covers the full provider set',
    tags: ['story_26_7'],
    () {
      late String src;

      setUp(() {
        src = _src(
          'features/tracks/setup/presentation/providers/after_track_change_invalidation.dart',
        );
      });

      for (final providerName in [
        'progressOverviewStatsProvider',
        'allDailyTasksProvider',
        'dashboardActiveCurriculaStreamProvider',
        'dashboardStreakProvider',
        'dashboardGlobalPointsProvider',
        'dashboardActiveTracksStreamProvider',
        'dashboardChildNextRewardProvider',
        'dashboardCompletionPercentageProvider',
        'dashboardLastCompletionProvider',
        // trackProgressProvider deleted by DNI-351 (26.8)
        'programCalendarPositionProvider',
        'lifetimeTotalsAcrossAllCurriculaProvider',
        'globalLifetimeCurriculaProvider',
        'activeTracksProvider',
      ]) {
        test('onTrackChanged invalidates $providerName', () {
          expect(
            src,
            contains(providerName),
            reason:
                '$providerName must appear in the centralized '
                'onTrackChanged invalidation list',
          );
        });
      }
    },
  );
}

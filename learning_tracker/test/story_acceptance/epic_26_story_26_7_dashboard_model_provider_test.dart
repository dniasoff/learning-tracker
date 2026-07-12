/// Story acceptance tests for Story 26.7 (DNI-350) —
/// centralized onTrackChanged invalidation.
///
/// AC1 (dashboardModelProvider composition) was REMOVED per AUD-dashboard-05
///      (2026-07-03 standards audit): dashboard_model_provider.dart was a
///      143-line composition layer that dashboard_screen.dart / dashboard_body
///      .dart never actually consumed — they kept watching the leaf providers
///      (dashboardActiveTracksStreamProvider, dashboardUserModeProvider,
///      dashboardStreakProvider, activeProfileProvider, etc.) directly. The
///      only reference to dashboardModelProvider left in the tree was this
///      test file, so the finding's recommendation ("delete
///      dashboard_model_provider.dart and its dedicated test") was applied:
///      the provider file was deleted and this AC's test group was removed
///      with it. AC2-AC4 below test the centralized onTrackChanged
///      invalidation helper, which is real, live behavior unrelated to the
///      dead composition layer, so they are unaffected and remain.
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
  // ── AC1 (dashboardModelProvider composition) removed per AUD-dashboard-05:
  //    dashboard_model_provider.dart was deleted as dead code — see the file
  //    header comment above for the evidence and rationale. Its dedicated
  //    "dashboardModelProvider composes leaf providers" group used to live
  //    here; it was removed rather than left pointing at unreachable code.

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

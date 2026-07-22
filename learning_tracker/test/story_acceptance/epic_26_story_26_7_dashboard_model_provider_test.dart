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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart'
    hide expect, group, setUp, tearDown, test;
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart'
    show clockProvider;
import 'package:learning_tracker/features/tracks/setup/presentation/providers/after_track_change_invalidation.dart';
import 'package:test/test.dart';

import '../helpers/drift_memory.dart';
import '../helpers/lib_source.dart';
import '../helpers/pump_app.dart';

// ── helpers ───────────────────────────────────────────────────────────────────

/// Reads [path] relative to `lib/`, trying both the app-root and repo-root
/// cwd via the shared [readLibSource] lookup (AUD-t-story-acceptance-08).
String _src(String path) => readLibSource(path);

/// Path to `add_track_flow.dart`, relative to `lib/`. The file was deleted
/// by DNI-353 (26.10) — the two AC3 tests below both need to detect that
/// deletion and treat the constraint they assert as trivially satisfied.
/// Sharing this check collapses what was previously two byte-identical
/// existence-check blocks into one call (AUD-t-story-acceptance-08 AC3).
const _addTrackFlowLibPath =
    'features/tracks/setup/presentation/screens/add_track_flow.dart';

bool _addTrackFlowDeleted() => !libFileExists(_addTrackFlowLibPath);

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
      // AUD-t-story-acceptance R7 (behavioral): the old version of this
      // test asserted `src.contains('Future<void> onTrackChanged(')` — a
      // string match that would still pass even if the function body were
      // gutted to a no-op, or never actually wired into a real call site.
      // This calls the REAL `onTrackChanged` — captured as a `WidgetRef`
      // from a pumped widget, the same technique
      // dashboard_screen_test.dart uses to prove its own re-read-on-sync
      // invalidation effect — and asserts the OBSERVABLE EFFECT: a leaf
      // provider it is documented to invalidate
      // (`dashboardGlobalPointsProvider`) actually rebuilds. Strictly
      // stronger — it fails if the invalidation call is deleted, commented
      // out, or the provider name is typo'd, none of which the old
      // text-match could catch as long as the literal substring
      // `Future<void> onTrackChanged(` remained anywhere in the file. The
      // second half proves the deprecated `invalidateAfterTrackDataChange`
      // alias still forwards to the same live implementation, not a
      // stripped-down or forgotten copy.
      testWidgets('onTrackChanged (and its deprecated alias) invalidate '
          'dashboardGlobalPointsProvider', (tester) async {
        final db = inMemoryDb();
        addTearDown(db.close);
        await seedProfileZero(db);

        var globalPointsBuilds = 0;
        final container = ProviderContainer(
          overrides: [
            userDatabaseProvider.overrideWithValue(db),
            clockProvider.overrideWith((ref) => DateTime.utc(2026, 1, 1)),
            dashboardGlobalPointsProvider.overrideWith((ref) {
              globalPointsBuilds++;
              return Stream.value(0);
            }),
          ],
        );
        addTearDown(container.dispose);

        // Keep the provider alive + force the initial build — mirrors
        // dashboard_screen_test.dart's `dailyTasksBuilds` re-read guard.
        final sub = container.listen(
          dashboardGlobalPointsProvider,
          (previous, next) {},
          fireImmediately: true,
        );
        addTearDown(sub.close);

        late WidgetRef capturedRef;
        await tester.pumpWidget(
          pumpApp(
            container: container,
            child: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        await tester.pump();

        final buildsAfterMount = globalPointsBuilds;
        expect(
          buildsAfterMount,
          1,
          reason: 'sanity: exactly one build before any invalidation',
        );

        await onTrackChanged(capturedRef, 0);
        // Force the now-invalidated provider to actually rebuild: Riverpod
        // defers an invalidated-but-still-listened provider's recompute to
        // its own scheduler rather than rebuilding synchronously inside
        // invalidate() itself, so a bare `read` (not just a pump) is what
        // flushes it deterministically.
        container.read(dashboardGlobalPointsProvider);
        await tester.pump();

        expect(
          globalPointsBuilds,
          greaterThan(buildsAfterMount),
          reason:
              'onTrackChanged must invalidate dashboardGlobalPointsProvider '
              'so the dashboard re-reads fresh points after a track change',
        );

        final buildsBeforeAlias = globalPointsBuilds;
        // ignore: deprecated_member_use
        await invalidateAfterTrackDataChange(capturedRef, 0);
        container.read(dashboardGlobalPointsProvider);
        await tester.pump();

        expect(
          globalPointsBuilds,
          greaterThan(buildsBeforeAlias),
          reason:
              'invalidateAfterTrackDataChange must still forward to the '
              'real onTrackChanged implementation, not a dead/no-op alias',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
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

      test(
        'add_track_flow.dart does not contain parallel invalidation list',
        () {
          // add_track_flow.dart was deleted by DNI-353 (26.10). If the file no
          // longer exists, the constraint is trivially satisfied.
          if (_addTrackFlowDeleted())
            return; // file deleted — constraint satisfied
          final src = _src(_addTrackFlowLibPath);
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
        },
      );

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
        if (_addTrackFlowDeleted())
          return; // file deleted — constraint satisfied
        final src = _src(_addTrackFlowLibPath);
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/sync/providers/sync_status_providers.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:learning_tracker/features/gamification/domain/models/streak_recovery_info.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

void main() {
  group('DashboardScreen', () {
    Widget buildTestWidget() {
      return ProviderScope(
        overrides: [
          // DashboardScreen now listens to syncStatusProvider (auto-refresh on
          // launch-pull completion). Stub it so the test never reaches the real
          // sync/auth/Firebase provider graph. `localOnly` never transitions to
          // `synced`, so the auto-refresh listener stays dormant here.
          syncStatusProvider.overrideWith(
            (ref) => const SyncStatus.localOnly(),
          ),
          dashboardActiveCurriculaProvider.overrideWith(
            (ref) => Future.value([]),
          ),
          dashboardActiveCurriculaStreamProvider.overrideWith(
            (ref) => Stream.value(<CurriculumId>[]),
          ),
          dashboardUserModeProvider.overrideWith(
            (ref) => Future.value(ProfileMode.adult),
          ),
          dashboardStreakProvider.overrideWith(
            (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
          ),
          dashboardGlobalPointsProvider.overrideWith((ref) => Stream.value(0)),
          allDailyTasksProvider.overrideWith((ref) => Future.value([])),
          dashboardStreakRecoveryProvider.overrideWith(
            (ref) => Future.value(
              const StreakRecoveryInfo(wasRecovered: false, currentStreak: 0),
            ),
          ),
          dashboardActiveTracksStreamProvider.overrideWith(
            (ref) => Stream.value(<CurriculumTrack>[]),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: DashboardScreen(),
        ),
      );
    }

    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(Scaffold), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('shows greeting in active dashboard when tracks exist', (
      tester,
    ) async {
      final fakeTrack = CurriculumTrack(
        id: 1,
        profileId: 0,
        curriculumId: CurriculumId.mishnayos.storageKey,
        state: 'active',
        stateChangedAt: DateTime.utc(2026, 1, 1),
        activatedAt: DateTime.utc(2026, 1, 1),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncStatusProvider.overrideWith(
              (ref) => const SyncStatus.localOnly(),
            ),
            dashboardActiveCurriculaProvider.overrideWith(
              (ref) => Future.value([CurriculumId.mishnayos]),
            ),
            dashboardActiveCurriculaStreamProvider.overrideWith(
              (ref) => Stream.value([CurriculumId.mishnayos]),
            ),
            dashboardUserModeProvider.overrideWith(
              (ref) => Future.value(ProfileMode.adult),
            ),
            dashboardStreakProvider.overrideWith(
              (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
            ),
            dashboardGlobalPointsProvider.overrideWith(
              (ref) => Stream.value(0),
            ),
            allDailyTasksProvider.overrideWith((ref) => Future.value([])),
            dashboardStreakRecoveryProvider.overrideWith(
              (ref) => Future.value(
                const StreakRecoveryInfo(wasRecovered: false, currentStreak: 0),
              ),
            ),
            dashboardActiveTracksStreamProvider.overrideWith(
              (ref) => Stream.value([fakeTrack]),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: DashboardScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Greeting block: time-of-day chip ("Good morning" / "Good afternoon" /
      // "Good evening") and the name on a separate line. Assertion checks
      // both the name and that one of the three greetings is present, since
      // the test runs at any time of day.
      // textContaining tolerates the bidi first-strong isolate (U+2068…U+2069)
      // the greeting wraps the name in so "!" sits correctly in RTL.
      expect(find.textContaining('Learner!'), findsOneWidget);
      final greetingFound =
          tester.any(find.text('Good morning')) ||
          tester.any(find.text('Good afternoon')) ||
          tester.any(find.text('Good evening'));
      expect(greetingFound, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('shows empty dashboard with no active curricula', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      // With no active curricula, the streak widget should still render
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    // Auto-refresh-on-launch-pull regression guard.
    //
    // The launch sync pull writes fresh data into Drift and THEN emits
    // SyncStatus.synced. The dashboard's data providers (e.g. allDailyTasks)
    // are one-shot FutureProviders that resolved against the PRE-pull DB, so
    // without an explicit invalidation they show stale/empty data until the
    // user pulls-to-refresh. The screen listens to syncStatusProvider and
    // re-reads the providers when the status transitions INTO `synced`. This
    // test drives that transition and asserts the one-shot provider rebuilt.
    testWidgets('re-reads dashboard data when sync transitions to synced', (
      tester,
    ) async {
      // A controllable status source. The real syncStatusProvider reads the
      // orchestrator (null in tests → always localOnly), so we override both the
      // stream provider (driven by this controller) and the derived
      // syncStatusProvider (forwards the stream's latest value). Pushing onto
      // the controller rebuilds syncStatusProvider, which is what
      // DashboardScreen's ref.listen observes.
      final statusController = StreamController<SyncStatus>.broadcast();
      addTearDown(statusController.close);

      // Counts how many times the one-shot daily-tasks provider builds. The
      // first build is the normal mount; a second build proves the transition
      // to `synced` invalidated it (auto-refresh fired).
      var dailyTasksBuilds = 0;

      final container = ProviderContainer(
        overrides: [
          syncStatusStreamProvider.overrideWith(
            (ref) => statusController.stream,
          ),
          syncStatusProvider.overrideWith(
            (ref) => ref
                .watch(syncStatusStreamProvider)
                .maybeWhen(
                  data: (status) => status,
                  orElse: () =>
                      SyncStatus.syncing(startedAt: DateTimeFactory.nowUtc()),
                ),
          ),
          dashboardActiveCurriculaProvider.overrideWith(
            (ref) => Future.value([]),
          ),
          dashboardActiveCurriculaStreamProvider.overrideWith(
            (ref) => Stream.value(<CurriculumId>[]),
          ),
          dashboardUserModeProvider.overrideWith(
            (ref) => Future.value(ProfileMode.adult),
          ),
          dashboardStreakProvider.overrideWith(
            (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
          ),
          dashboardGlobalPointsProvider.overrideWith((ref) => Stream.value(0)),
          allDailyTasksProvider.overrideWith((ref) {
            dailyTasksBuilds++;
            return Future.value([]);
          }),
          dashboardStreakRecoveryProvider.overrideWith(
            (ref) => Future.value(
              const StreakRecoveryInfo(wasRecovered: false, currentStreak: 0),
            ),
          ),
          dashboardActiveTracksStreamProvider.overrideWith(
            (ref) => Stream.value(<CurriculumTrack>[]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: DashboardScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      final buildsBeforeSync = dailyTasksBuilds;
      expect(
        buildsBeforeSync,
        greaterThanOrEqualTo(1),
        reason: 'allDailyTasks should build once on initial mount',
      );

      // Simulate the launch pull completing: Drift is now fresh and the
      // orchestrator emits `synced`.
      statusController.add(
        SyncStatus.synced(lastSyncedAt: DateTimeFactory.nowUtc()),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        dailyTasksBuilds,
        greaterThan(buildsBeforeSync),
        reason:
            'transition to synced must invalidate allDailyTasks so the '
            'dashboard re-reads fresh data without a manual pull-to-refresh',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });
}

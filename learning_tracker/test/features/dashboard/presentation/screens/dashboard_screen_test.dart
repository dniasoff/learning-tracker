import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:learning_tracker/features/gamification/domain/models/streak_recovery_info.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

void main() {
  group('DashboardScreen', () {
    Widget buildTestWidget() {
      return ProviderScope(
        overrides: [
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
          dashboardGlobalPointsProvider.overrideWith((ref) => Future.value(0)),
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
              (ref) => Future.value(0),
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
      expect(find.text('Learner!'), findsOneWidget);
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
  });
}

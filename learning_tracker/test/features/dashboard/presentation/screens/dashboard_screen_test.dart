import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:learning_tracker/features/gamification/domain/models/streak_recovery_info.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

void main() {
  group('DashboardScreen', () {
    Widget buildTestWidget({Locale? locale}) {
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
              (ref) => Stream.value(<CurriculumTrackEntity>[]),
          ),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const DashboardScreen(),
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

    // RTL regression guard (TQ-3). DashboardScreen is the app's home/hotspot
    // screen in a bilingual RTL-first app, yet none of this file's pumps
    // previously exercised Locale('he') — a Hebrew-layout regression on the
    // dashboard's own scaffold could ship undetected by its own test file.
    // Reuses the locale-pump pattern from active_tracks_carousel_rtl_test.dart.
    testWidgets('renders without error or overflow under Locale(he) (RTL)', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(locale: const Locale('he')));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(Scaffold), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('shows greeting in active dashboard when tracks exist', (
      tester,
    ) async {
      final fakeTrack = CurriculumTrackEntity(
        curriculumId: CurriculumId.mishnayos,
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
            localizationsDelegates: AppLocalizations.localizationsDelegates,
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

    // Removed: this case asserted the deleted Drift launch-pull invalidation
    // path; there is no Firestore-local-query equivalent in DashboardScreen.
  });
}

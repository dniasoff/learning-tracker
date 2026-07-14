import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/database/seed_manager.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/learning/presentation/screens/learning_screen.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

import '../../../../helpers/drift_memory.dart';

void main() {
  // AUD-t-learning-01: see the matching file-level doc comment in
  // learning_screen_l1_test.dart for why a single, never-queried, in-memory
  // db is safely shared read-only across every test in this file.
  final testUserDb = inMemoryDb();
  tearDownAll(() async {
    await testUserDb.close();
  });

  group('LearningScreen', () {
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
          allDailyTasksProvider.overrideWith((ref) => Future.value([])),
          // AUD-t-learning-01: LearningScreen also watches these two
          // providers unconditionally; left un-overridden,
          // coarsePacedTrackIdsProvider falls through to the real
          // userDatabaseProvider (see the matching comment in
          // learning_screen_l1_test.dart).
          coarsePacedTrackIdsProvider.overrideWith(
            (ref) => Future.value(const <int>{}),
          ),
          contentIndexProvider.overrideWith(
            (ref) => Future.value(ContentIndex.fromCurricula(const {})),
          ),
          userDatabaseProvider.overrideWithValue(testUserDb),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: LearningScreen(),
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

    testWidgets('shows key UI elements', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      // With no active curricula, the empty state is shown
      expect(find.text('No active tracks'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    // V2-R5 C3 regression: AppErrorView.build must never render raw exception
    // strings. This test directly verifies AppErrorView renders "Something went
    // wrong" (not the raw internal message) for an InternalException.
    testWidgets('AppErrorView shows generic message for InternalException (not raw '
        'exception string)', (tester) async {
      const rawMsg = 'internal error detail that must not appear in UI';
      // Directly render AppErrorView — this is what _DailyTasksSection's
      // error branch now emits after the V2-R5 C3 fix.
      //
      // AUD-core-sync-27: uses [SeedManagerException] (a real InternalException
      // leaf genuinely thrown in production — lib/core/database/seed_manager.dart)
      // instead of the removed MergeException, which was never thrown anywhere
      // in lib/ (dead scaffolding from the W7.2 backlog item; the merge-failure
      // telemetry it was meant to carry is fired via inline AppLogger/analytics
      // calls instead — W7.5/W7.6). Any InternalException leaf exercises the
      // SAME category-generic-message behavior under test here.
      // Not `const` — SeedManagerException's constructor is non-const
      // (unlike the removed MergeException's), so this widget subtree
      // cannot be a const expression.
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AppErrorView(
              error: SeedManagerException(rawMsg),
              onRetry: null,
            ),
          ),
        ),
      );
      await tester.pump();

      // AppErrorView must be present and show generic "Something went wrong"
      expect(find.byType(AppErrorView), findsOneWidget);
      expect(find.text('Something went wrong'), findsOneWidget);
      // Raw exception message must NOT appear anywhere in the UI
      expect(find.text(rawMsg), findsNothing);
      expect(find.textContaining(rawMsg), findsNothing);
    });
  });
}

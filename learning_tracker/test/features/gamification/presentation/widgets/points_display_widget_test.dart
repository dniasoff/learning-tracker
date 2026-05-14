import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/points_providers.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/points_display_widget.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // DNI-328 flipped the Hebrew-terms default to false. These tests assert on
  // Hebrew labels, so seed the preference to true for the default profile.
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'hebrew_terms_script_p0': true,
    });
  });

  group('PointsDisplayWidget', () {
    testWidgets('shows total points with breakdown in child mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            globalPointsProvider.overrideWith((_) async => 25),
            curriculumBreakdownProvider.overrideWith(
              (_) async => {CurriculumId.mishnayos: 15, CurriculumId.bavli: 10},
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: PointsDisplayWidget(userMode: UserMode.child),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('25'), findsOneWidget);
      expect(find.text('Total Points'), findsOneWidget);
      expect(find.text('משניות: 15'), findsOneWidget);
      expect(find.text('תלמוד בבלי: 10'), findsOneWidget);
    });

    testWidgets('is hidden in adult mode', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            globalPointsProvider.overrideWith((_) async => 25),
            curriculumBreakdownProvider.overrideWith(
              (_) async => {CurriculumId.mishnayos: 25},
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: PointsDisplayWidget(userMode: UserMode.adult),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('25'), findsNothing);
      expect(find.text('Total Points'), findsNothing);
    });
  });

  group('PointsPopupWidget', () {
    testWidgets('shows correct point value in child mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PointsPopupWidget(pointsEarned: 10, userMode: UserMode.child),
          ),
        ),
      );

      expect(find.text('+10 points!'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('is hidden in adult mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PointsPopupWidget(pointsEarned: 10, userMode: UserMode.adult),
          ),
        ),
      );

      expect(find.text('+10 points!'), findsNothing);
    });
  });
}

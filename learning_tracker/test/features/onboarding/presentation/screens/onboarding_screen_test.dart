import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Widget createTestWidget() {
    return const ProviderScope(child: MaterialApp(home: OnboardingScreen()));
  }

  group('OnboardingScreen Slim Flow', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('starts at profile creation phase', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Profile creation shows name field and mode selector
      expect(find.text("What's your name?"), findsOneWidget);
      expect(find.text('Adult'), findsOneWidget);
      expect(find.text('Child'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Continue disabled with empty name', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Continue'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('child mode changes prompt text', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Switch to child mode
      await tester.tap(find.text('Child'));
      await tester.pumpAndSettle();

      expect(find.text("What is your child's name?"), findsOneWidget);
    });

    testWidgets('resumes at language selection from saved state', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'onboarding_phase': 'languageSelection',
        'onboarding_profile_id': 1,
        'onboarding_profile_name': 'Test',
        'onboarding_profile_mode': 'adult',
        'onboarding_language': 'he',
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should show language selection
      expect(
        find.text('Choose your preferred language for content'),
        findsOneWidget,
      );
      expect(find.text('עברית (Hebrew with nikud)'), findsOneWidget);
    });

    testWidgets('language selection shows all supported languages', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'onboarding_phase': 'languageSelection',
        'onboarding_profile_id': 1,
        'onboarding_profile_name': 'Test',
        'onboarding_profile_mode': 'adult',
        'onboarding_language': 'he',
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('English'), findsOneWidget);
      expect(find.text('Français'), findsOneWidget);
    });

    testWidgets('childAwareText returns adult text in adult mode', (
      tester,
    ) async {
      final result = childAwareText(
        'Choose your curricula',
        "Choose {name}'s curricula",
        'David',
      );
      expect(result, 'Choose your curricula');
    });

    testWidgets('childAwareText returns child text in child mode', (
      tester,
    ) async {
      final result = childAwareText(
        'Choose your curricula',
        "Choose {name}'s curricula",
        'David',
        isChildMode: true,
      );
      expect(result, "Choose David's curricula");
    });
  });
}

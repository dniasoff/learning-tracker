import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/onboarding/domain/services/curriculum_import_service.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fake import service that controls when import completes via a completer.
class _FakeImportService implements CurriculumImportService {
  _FakeImportService({this.shouldFail = false});

  final bool shouldFail;

  @override
  Stream<CurriculumImportProgress> importAll(
    List<CurriculumId> selectedCurricula,
  ) async* {
    final results = <CurriculumImportResult>[];
    for (var i = 0; i < selectedCurricula.length; i++) {
      final id = selectedCurricula[i];
      results.add(
        CurriculumImportResult(
          curriculumId: id,
          success: !shouldFail,
          itemCount: shouldFail ? 0 : 10,
          error: shouldFail ? 'Network error' : null,
        ),
      );
      yield CurriculumImportProgress(
        current: i + 1,
        total: selectedCurricula.length,
        currentCurriculum: id,
        results: List.unmodifiable(results),
      );
    }
  }

  @override
  Future<CurriculumImportResult> importSingle(CurriculumId curriculum) async {
    return CurriculumImportResult(
      curriculumId: curriculum,
      success: !shouldFail,
      itemCount: 10,
    );
  }
}

/// Fake import service that never completes (stays in importing state).
class _HangingImportService implements CurriculumImportService {
  @override
  Stream<CurriculumImportProgress> importAll(
    List<CurriculumId> selectedCurricula,
  ) async* {
    // Yield one progress event then hang forever
    yield CurriculumImportProgress(
      current: 0,
      total: selectedCurricula.length,
      currentCurriculum: selectedCurricula.first,
      results: const [],
    );
    // Never complete - stays in importing phase
    await Completer<void>().future;
  }

  @override
  Future<CurriculumImportResult> importSingle(CurriculumId curriculum) async {
    await Completer<void>().future;
    throw StateError('unreachable');
  }
}

void main() {
  Widget createTestWidget({CurriculumImportService? importService}) {
    return ProviderScope(
      overrides: [
        if (importService != null)
          curriculumImportServiceProvider.overrideWithValue(importService),
      ],
      child: const MaterialApp(home: OnboardingScreen()),
    );
  }

  group('OnboardingScreen Widget Tests', () {
    setUp(() {
      // Pre-seed SharedPreferences so the screen resumes at the selection
      // phase (skipping profile creation and language selection).
      SharedPreferences.setMockInitialValues({
        'onboarding_phase': 'selection',
        'onboarding_profile_id': 1,
        'onboarding_profile_name': 'Test',
        'onboarding_profile_mode': 'adult',
        'onboarding_selected_curricula': '[]',
        'onboarding_language': 'he',
      });
    });

    testWidgets('displays curricula with names', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // First few should be visible via their English display names
      expect(find.text('Mishnayos'), findsOneWidget);
      expect(find.text('Talmud Bavli'), findsOneWidget);
      expect(find.text('Talmud Yerushalmi'), findsOneWidget);

      // Scroll down to see items below the initial viewport
      await tester.scrollUntilVisible(find.text('Mishna Berurah'), 100);
      expect(find.text('Mishna Berurah'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Chumash'), 100);
      expect(find.text('Chumash'), findsOneWidget);
    });

    testWidgets('displays curriculum names for visible curricula', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // At least some visible curriculum names are shown
      expect(find.text('Mishnayos'), findsOneWidget);
      expect(find.text('Talmud Bavli'), findsOneWidget);
    });

    testWidgets('displays instruction text in selection phase', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.textContaining('Choose Your'), findsOneWidget);
    });

    testWidgets('checkmark toggles on tap', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Initially no check icons (unselected state shows empty containers)
      expect(find.byIcon(Icons.check), findsNothing);

      // Tap first curriculum
      await tester.tap(find.text('Mishnayos'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsOneWidget);

      // Tap again to deselect
      await tester.tap(find.text('Mishnayos'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('Continue button disabled when no curriculum selected', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // The Continue button is an InkWell inside an AnimatedContainer.
      // When no curriculum is selected, onTap is null.
      final continueText = find.text('Continue');
      expect(continueText, findsOneWidget);

      final inkWell = find.ancestor(
        of: continueText,
        matching: find.byType(InkWell),
      );
      final widget = tester.widget<InkWell>(inkWell.first);
      expect(widget.onTap, isNull);
    });

    testWidgets('Continue button enabled after selecting a curriculum', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mishnayos'));
      await tester.pumpAndSettle();

      final continueText = find.text('Continue');
      final inkWell = find.ancestor(
        of: continueText,
        matching: find.byType(InkWell),
      );
      final widget = tester.widget<InkWell>(inkWell.first);
      expect(widget.onTap, isNotNull);
    });

    testWidgets('shows instruction text', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.textContaining('Choose Your'), findsOneWidget);
      expect(
        find.text('You can add or remove curricula anytime.'),
        findsOneWidget,
      );
    });

    testWidgets('multiple curricula can be selected', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mishnayos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Talmud Bavli'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsNWidgets(2));
    });

    testWidgets('shows LinearProgressIndicator during import phase', (
      tester,
    ) async {
      final hangingService = _HangingImportService();
      await tester.pumpWidget(createTestWidget(importService: hangingService));
      await tester.pumpAndSettle();

      // Select a curriculum and tap Continue
      await tester.tap(find.text('Mishnayos'));
      await tester.pumpAndSettle();

      // Find the Continue text and tap its InkWell ancestor
      final continueText = find.text('Continue');
      final inkWell = find.ancestor(
        of: continueText,
        matching: find.byType(InkWell),
      );
      await tester.tap(inkWell.first);
      await tester.pump();

      // Should show importing phase with progress indicator
      expect(find.text('Importing curricula...'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsWidgets);
    });

    testWidgets('shows Retry Failed button on import failure', (tester) async {
      final failingService = _FakeImportService(shouldFail: true);
      await tester.pumpWidget(createTestWidget(importService: failingService));
      await tester.pumpAndSettle();

      // Select a curriculum and tap Continue
      await tester.tap(find.text('Mishnayos'));
      await tester.pumpAndSettle();

      // Find the Continue text and tap its InkWell ancestor
      final continueText = find.text('Continue');
      final inkWell = find.ancestor(
        of: continueText,
        matching: find.byType(InkWell),
      );
      await tester.tap(inkWell.first);
      await tester.pumpAndSettle();

      // Should show error phase with Retry Failed button
      expect(find.text('Some imports failed'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Retry Failed'), findsOneWidget);
    });
  });
}

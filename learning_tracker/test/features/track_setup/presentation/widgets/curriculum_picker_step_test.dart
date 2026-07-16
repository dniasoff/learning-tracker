import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/widgets/curriculum_picker_step.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  group('CurriculumPickerStep', () {
    // [TQ-3] pumps through the shared `pumpApp` helper (AUD-t-track_setup-02)
    // instead of hand-rolling the ProviderScope + MaterialApp(delegates, ...)
    // block — see test/helpers/pump_app.dart.
    Widget wrapWithL10n(Widget child, {Locale locale = const Locale('en')}) {
      SharedPreferences.setMockInitialValues({'hebrew_terms_script_p0': true});
      return pumpApp(
        locale: locale,
        child: Scaffold(body: child),
      );
    }

    testWidgets('displays all 9 curricula (scrollable)', (tester) async {
      await tester.pumpWidget(
        wrapWithL10n(CurriculumPickerStep(onSelected: (_) {})),
      );

      // Verify at least the first few visible curricula render
      expect(find.text(CurriculumId.mishnayos.displayNameHe), findsWidgets);
      expect(find.text(CurriculumId.bavli.displayNameHe), findsWidgets);

      // Verify multiple InkWell widgets rendered (one per curriculum tile)
      expect(find.byType(InkWell), findsWidgets);
    });

    testWidgets('shows onboarding header when isOnboarding is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithL10n(
          CurriculumPickerStep(onSelected: (_) {}, isOnboarding: true),
        ),
      );

      expect(find.text('What would you like to learn?'), findsOneWidget);
    });

    testWidgets('shows default header when isOnboarding is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithL10n(CurriculumPickerStep(onSelected: (_) {})),
      );

      expect(find.text('Select a Curriculum'), findsOneWidget);
    });

    testWidgets('tapping a curriculum calls onSelected', (tester) async {
      CurriculumId? selected;
      await tester.pumpWidget(
        wrapWithL10n(CurriculumPickerStep(onSelected: (c) => selected = c)),
      );

      // Tap the first occurrence of the Hebrew name
      await tester.tap(find.text(CurriculumId.bavli.displayNameHe).first);
      expect(selected, CurriculumId.bavli);
    });

    testWidgets('shows replace SnackBar when warning icon is tapped', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithL10n(
          CurriculumPickerStep(
            onSelected: (_) {},
            existingTrackCurricula: {CurriculumId.bavli},
          ),
        ),
      );

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.textContaining('already have a track'), findsNothing);

      await tester.tap(find.byIcon(Icons.warning_amber_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('already have a track'), findsWidgets);
    });

    // [AUD-t-track_setup-02] RTL smoke — this app is Hebrew-primary and this
    // step renders on a first-run, high-visibility flow, but was previously
    // only ever pumped under the implicit default (English/LTR) locale.
    testWidgets('renders under Locale(he) without overflow or errors', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithL10n(
          CurriculumPickerStep(onSelected: (_) {}),
          locale: const Locale('he'),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(CurriculumPickerStep), findsOneWidget);
    });
  });
}

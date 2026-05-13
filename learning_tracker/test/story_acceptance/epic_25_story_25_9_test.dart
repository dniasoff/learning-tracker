/// Story acceptance tests for Epic 25 / Story 25.9 (DNI-330) —
/// core/labels rebuild: three new modes, ContentIndex consumer,
/// `CurriculumLabels.curriculumName(useHebrew:)` static API deleted.
///
/// Uses widget tests rather than the pure-Dart story_acceptance pattern
/// because the AC explicitly demands `Directionality.of(context)` consumption
/// and Riverpod-overridden Hebrew-terms preference reads.
@Tags(['epic_25', 'story_25_9'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/services/calendar_program_service.dart';
import 'package:learning_tracker/core/services/learning_program_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(
  Widget child, {
  bool hebrewTermsScript = false,
  TextDirection ambient = TextDirection.ltr,
}) {
  SharedPreferences.setMockInitialValues({
    'hebrew_terms_script_p0': hebrewTermsScript,
  });
  return ProviderScope(
    child: MaterialApp(
      home: Directionality(
        textDirection: ambient,
        child: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  group('AC1 — CurriculumLabel.trackType(TrackType.personal)', () {
    testWidgets('en + Hebrew-terms OFF → transliterated English name', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const CurriculumLabel.trackType(TrackType.personal),
          hebrewTermsScript: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Personal'), findsOneWidget);
    });

    testWidgets('Hebrew-terms ON → Hebrew script with RTL directionality', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const CurriculumLabel.trackType(TrackType.personal),
          hebrewTermsScript: true,
        ),
      );
      await tester.pumpAndSettle();
      final textWidget = tester.widget<Text>(find.byType(Text));
      expect(textWidget.data, equals('אישי'));
      // Direction is forced to RTL on Hebrew strings regardless of ambient,
      // matching the AC: "the rendered text is the Hebrew script with RTL
      // directionality."
      final renderedDirection =
          textWidget.textDirection ??
          Directionality.of(tester.element(find.byType(Text)));
      expect(renderedDirection, equals(TextDirection.rtl));
    });
  });

  group('AC2 — CurriculumLabel.calendarProgram', () {
    const entry = CalendarProgramEntry(
      programId: 'daf_yomi',
      displayNameEn: 'Daf Yomi',
      displayNameHe: 'דף יומי',
      todayRef: 'Bava Kamma 50',
      apiSource: 'local',
    );

    testWidgets('Hebrew terms OFF → English form', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CurriculumLabel.calendarProgram(entry),
          hebrewTermsScript: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Daf Yomi'), findsOneWidget);
    });

    testWidgets('Hebrew terms ON → Hebrew form + RTL', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CurriculumLabel.calendarProgram(entry),
          hebrewTermsScript: true,
        ),
      );
      await tester.pumpAndSettle();
      final t = tester.widget<Text>(find.byType(Text));
      expect(t.data, equals('דף יומי'));
      expect(t.textDirection, equals(TextDirection.rtl));
    });
  });

  group('AC3 — CurriculumLabel.learningProgram', () {
    const program = LearningProgramData(
      id: 1,
      name: 'daf_yomi',
      displayName: 'Daf Yomi',
      description: '',
      curriculumType: 'bavli',
      isActive: true,
      hasTests: false,
      stagesConfig: '{}',
      testConfig: '{}',
      apiSource: 'hebcal',
      apiProgramKey: 'dafyomi',
      isCalendarProgram: true,
    );

    testWidgets('Hebrew terms OFF → English displayName', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CurriculumLabel.learningProgram(program),
          hebrewTermsScript: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Daf Yomi'), findsOneWidget);
    });

    testWidgets('Hebrew terms ON → Hebrew from CalendarProgramRegistry + RTL', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const CurriculumLabel.learningProgram(program),
          hebrewTermsScript: true,
        ),
      );
      await tester.pumpAndSettle();
      final t = tester.widget<Text>(find.byType(Text));
      expect(t.data, equals('דף יומי'));
      expect(t.textDirection, equals(TextDirection.rtl));
    });
  });

  group('AC4 — Directionality.of(context) drives English text direction', () {
    testWidgets(
      'CurriculumLabel.curriculum: English renders without forcing RTL',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const CurriculumLabel.curriculum(CurriculumId.mishnayos),
            hebrewTermsScript: false,
          ),
        );
        await tester.pumpAndSettle();
        final t = tester.widget<Text>(find.byType(Text));
        expect(t.data, equals('Mishnayos'));
        // English strings inherit the ambient Directionality (LTR) — they
        // do NOT force RTL.
        expect(t.textDirection, isNot(equals(TextDirection.rtl)));
      },
    );

    testWidgets(
      'Hebrew script forces RTL even under ambient LTR Directionality',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const CurriculumLabel.curriculum(CurriculumId.mishnayos),
            hebrewTermsScript: true,
            ambient: TextDirection.ltr,
          ),
        );
        await tester.pumpAndSettle();
        final t = tester.widget<Text>(find.byType(Text));
        expect(t.data, equals('משניות'));
        expect(t.textDirection, equals(TextDirection.rtl));
      },
    );
  });

  group('AC5 — trackTypeLabelText pure-string helper', () {
    testWidgets('returns Hebrew when toggle on', (tester) async {
      String? captured;
      await tester.pumpWidget(
        _wrap(
          Consumer(
            builder: (context, ref, _) {
              captured = trackTypeLabelText(ref, trackType: TrackType.personal);
              return const SizedBox.shrink();
            },
          ),
          hebrewTermsScript: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(captured, equals('אישי'));
    });

    testWidgets('returns English when toggle off', (tester) async {
      String? captured;
      await tester.pumpWidget(
        _wrap(
          Consumer(
            builder: (context, ref, _) {
              captured = trackTypeLabelText(ref, trackType: TrackType.personal);
              return const SizedBox.shrink();
            },
          ),
          hebrewTermsScript: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(captured, equals('Personal'));
    });
  });

  group('AC6 — TrackType exposes a Hebrew display name', () {
    test('TrackType.personal.displayNameHe == "אישי"', () {
      expect(TrackType.personal.displayNameHe, equals('אישי'));
    });
  });
}

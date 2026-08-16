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
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/services/calendar_program_service.dart';
import 'package:learning_tracker/features/scheduler/domain/services/learning_program_service.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

import '../helpers/pump_app.dart';

Widget _wrap(
  Widget child, {
  bool hebrewTermsScript = false,
  TextDirection ambient = TextDirection.ltr,
}) {
  return pumpApp(
    child: Directionality(
      textDirection: ambient,
      child: Scaffold(body: child),
    ),
    overrides: [useHebrewTermsProvider.overrideWithValue(hebrewTermsScript)],
  );
}

void main() {
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

  // ── AUD-t-story-acceptance-28 — shared pumpApp wiring ─────────────────
  //
  // `_wrap` used to build its own MaterialApp without localization
  // delegates. It only worked because none of the widgets under test above
  // call `AppLocalizations.of(context)`. This regression test pumps a
  // widget that DOES, so any future ad hoc MaterialApp wrapper missing the
  // delegates fails loudly here instead of silently at the next widget that
  // reads a translated string.
  group('AUD-t-story-acceptance-28 — pumpApp l10n wiring', () {
    testWidgets(
      'a widget calling AppLocalizations.of(context) resolves without a '
      'missing-delegate error',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            Builder(
              builder: (context) =>
                  Text(AppLocalizations.of(context)!.appTitle),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Torah Learning Tracker'), findsOneWidget);
      },
    );
  });
}

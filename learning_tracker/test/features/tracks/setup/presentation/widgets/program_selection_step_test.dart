/// Regression tests for TS-1:
/// The "Starts:" calendar row on _FeaturedProgramCard must NOT use the
/// program's own display name as the value. It should show "DAILY CALENDAR"
/// (or a real start date), never the name string.
///
/// The test imports [programStartsLabel] — a pure function extracted from
/// program_selection_step.dart in the fix. If the function does not exist yet
/// (i.e. the file is in pre-fix state) the test will fail to compile, which
/// counts as a RED failure; once the function is introduced and returns the
/// correct value the test goes GREEN.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/scheduler/domain/services/learning_program_service.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/widgets/program_selection_step.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  LearningProgramData makeProgram({
    required String name,
    required String displayName,
    required bool isCalendarProgram,
  }) => LearningProgramData(
    id: 1,
    name: name,
    displayName: displayName,
    description: 'desc',
    curriculumType: 'bavli',
    isActive: true,
    hasTests: false,
    stagesConfig: '[]',
    testConfig: '{}',
    apiSource: isCalendarProgram ? 'sefaria' : null,
    apiProgramKey: isCalendarProgram ? name : null,
    isCalendarProgram: isCalendarProgram,
  );

  group('TS-1 — programStartsLabel never returns the program display name', () {
    test('calendar program: returns DAILY CALENDAR, not the display name', () {
      final program = makeProgram(
        name: 'daf_yomi',
        displayName: 'Daf Yomi',
        isCalendarProgram: true,
      );

      final label = programStartsLabel(l10n, program);

      expect(
        label,
        isNot(contains('Daf Yomi')),
        reason: 'Starts: label must NOT echo the program name (TS-1)',
      );
      expect(label, equals('DAILY CALENDAR'));
    });

    test(
      'non-calendar program: returns empty string, not the display name',
      () {
        final program = makeProgram(
          name: 'dirshu',
          displayName: 'Dirshu Amud HaYomi',
          isCalendarProgram: false,
        );

        final label = programStartsLabel(l10n, program);

        expect(
          label,
          isNot(contains('Dirshu Amud HaYomi')),
          reason: 'Starts: label must NOT echo the program name (TS-1)',
        );
        expect(label, isEmpty);
      },
    );

    test('Mishnah Yomit calendar program: label is DAILY CALENDAR', () {
      final program = makeProgram(
        name: 'mishna_yomit',
        displayName: 'Mishnah Yomit',
        isCalendarProgram: true,
      );

      final label = programStartsLabel(l10n, program);

      expect(label, isNot(contains('Mishnah Yomit')));
      expect(label, equals('DAILY CALENDAR'));
    });
  });
}

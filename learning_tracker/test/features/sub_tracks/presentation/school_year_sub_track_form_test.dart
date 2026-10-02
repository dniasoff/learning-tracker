/// Story 2.4 (DNI-495) AC-4..AC-8, AC-10 and the edge cases: the school-year
/// sub-track form, driven end to end through the real Story 2.1
/// `SubTrackCommands` over the C0 in-memory ports.
@Tags(['sub_tracks'])
library;

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/domain/learner_state/sub_track_validator.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/screens/school_year_sub_track_form_screen.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/screens/sub_track_goal_setup_flow.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/academic_year_picker.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/sub_tracks/sub_track_harness.dart';

const _existingId = '01JHARN0000000000000000001';

final _launches = <CurriculumId>[];

/// What the stubbed goal setup flow reports (AC-6).
var _goalOutcome = SubTrackGoalSetupOutcome.cancelled;

List<Override> _overrides(SubTrackHarness h, {bool parentSession = true}) => [
  ...h.overrides(parentSession: parentSession),
  subTrackGoalSetupLauncherProvider.overrideWithValue((
    context,
    ref,
    curriculum,
  ) async {
    _launches.add(curriculum);
    return _goalOutcome;
  }),
];

/// Pumps a launcher page that pushes the form, so a save can pop it.
Future<void> _pumpForm(
  WidgetTester tester,
  SubTrackHarness h, {
  String? subTrackId,
  bool parentSession = true,
  Locale locale = const Locale('en'),
  ThemeData? theme,
  Size size = const Size(430, 1800),
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    pumpApp(
      overrides: _overrides(h, parentSession: parentSession),
      retry: (_, _) => null,
      locale: locale,
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      child: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SchoolYearSubTrackFormScreen(
                    curriculumId: subTrackTestCurriculum,
                    subTrackId: subTrackId,
                  ),
                ),
              ),
              child: const Text('open-form'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open-form'));
  await tester.pumpAndSettle();
}

Finder _chip(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(ChoiceChip));

Future<void> _enter(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(ValueKey(key)), text);
  await tester.pump();
}

Future<void> _save(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const ValueKey('subTrackFormSave')));
  await tester.tap(find.byKey(const ValueKey('subTrackFormSave')));
  await tester.pump();
  await settleCommands(tester);
  await tester.pumpAndSettle();
}

bool _formOpen() => find.byType(SchoolYearSubTrackForm).evaluate().isNotEmpty;

void main() {
  late SubTrackHarness h;

  setUp(_launches.clear);

  tearDown(() async => h.dispose());

  group('AC-4 fields and defaults', () {
    testWidgets('renders every field with the school-year defaults', (
      tester,
    ) async {
      h = SubTrackHarness();
      await _pumpForm(tester, h);

      expect(find.text('School year'), findsOneWidget);
      expect(find.text('Sub-track name'), findsOneWidget);
      expect(find.text('Academic year'), findsOneWidget);
      expect(find.text('Start month'), findsOneWidget);
      expect(find.text('End month'), findsOneWidget);
      expect(find.text('September'), findsOneWidget);
      expect(find.text('July'), findsOneWidget);
      expect(find.text('Mishnayos per week'), findsOneWidget);
      // 10 a week over the curriculum's 5 study days.
      expect(find.text('~2 mishnayos / school day'), findsOneWidget);
      expect(find.text('Weeks per year'), findsOneWidget);
      expect(find.widgetWithText(TextField, '39'), findsOneWidget);
      expect(
        find.text('Prefilled — edit if the school year is shorter'),
        findsOneWidget,
      );
      expect(find.text('Learns on shabbos / yom tov'), findsOneWidget);
      expect(
        find.text('Include this source on the catch-up card after shabbos'),
        findsOneWidget,
      );
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      expect(
        find.text(
          "You can add ground later — the school's masechtos don't need to be "
          'known yet.',
        ),
        findsOneWidget,
      );
      expect(find.text('Save sub-track'), findsOneWidget);
    });

    testWidgets('has no exclusion checkbox and no bein-hazmanim switch', (
      tester,
    ) async {
      h = SubTrackHarness();
      await _pumpForm(tester, h);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(find.byType(SwitchListTile), findsOneWidget);
      expect(
        find.textContaining(RegExp('hazmanim', caseSensitive: false)),
        findsNothing,
      );
    });

    testWidgets('the rate stepper moves by one and never below 1', (
      tester,
    ) async {
      h = SubTrackHarness();
      await _pumpForm(tester, h);
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(find.widgetWithText(TextField, '11'), findsOneWidget);
      await _enter(tester, 'subTrackFormRate', '1');
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
      expect(find.widgetWithText(TextField, '1'), findsOneWidget);
    });
  });

  group('AC-5 academic-year picker', () {
    testWidgets('without a deadline: current year plus two, Active then Open', (
      tester,
    ) async {
      h = SubTrackHarness();
      await _pumpForm(tester, h);
      expect(find.text('2026–27'), findsOneWidget);
      expect(find.text('2027–28'), findsOneWidget);
      expect(find.text('2028–29'), findsOneWidget);
      expect(find.text('2029–30'), findsNothing);
      expect(
        find.descendant(of: _chip('2026–27'), matching: find.text('Active')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _chip('2028–29'), matching: find.text('Open')),
        findsOneWidget,
      );
    });

    testWidgets('with a deadline: through the deadline year', (tester) async {
      h = SubTrackHarness(deadline: '2030-06-01');
      await _pumpForm(tester, h);
      expect(find.text('2029–30'), findsOneWidget);
      expect(find.text('2030–31'), findsNothing);
    });

    testWidgets('a used year is visible, disabled and announced disabled', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      h = SubTrackHarness(seed: [storedSchoolYear(_existingId)]);
      await _pumpForm(tester, h);
      expect(
        find.descendant(of: _chip('2026–27'), matching: find.text('Used')),
        findsOneWidget,
      );
      expect(tester.widget<ChoiceChip>(_chip('2026–27')).onSelected, isNull);
      final node = tester.getSemantics(_chip('2026–27'));
      final data = node.getSemanticsData();
      expect(data.flagsCollection.isEnabled, Tristate.isFalse);

      await tester.tap(_chip('2026–27'), warnIfMissed: false);
      await tester.pump();
      expect(tester.widget<ChoiceChip>(_chip('2026–27')).selected, isFalse);
      semantics.dispose();
    });

    testWidgets("editing keeps the track's own year selectable", (
      tester,
    ) async {
      h = SubTrackHarness(seed: [storedSchoolYear(_existingId)]);
      await _pumpForm(tester, h, subTrackId: _existingId);
      final chip = tester.widget<ChoiceChip>(_chip('2026–27'));
      expect(chip.selected, isTrue);
      expect(chip.onSelected, isNotNull);
      expect(find.text('Used'), findsNothing);
    });
  });

  group('AC-6 no deadline', () {
    testWidgets('shows the note and a goal link; saving stays allowed', (
      tester,
    ) async {
      h = SubTrackHarness();
      await _pumpForm(tester, h);
      expect(
        find.text(
          "Without a deadline, a sub-track can't lower the daily target.",
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Set a deadline'));
      await tester.tap(find.text('Set a deadline'));
      await tester.pump();
      expect(_launches, [CurriculumId.mishnayos]);

      await _enter(tester, 'subTrackFormName', 'Cheder');
      await tester.tap(_chip('2026–27'));
      await _save(tester);
      expect(h.commands.creates, hasLength(1));
      expect(_formOpen(), isFalse);
    });

    testWidgets('a goal that could not be saved is reported; values stay', (
      tester,
    ) async {
      h = SubTrackHarness();
      _goalOutcome = SubTrackGoalSetupOutcome.failed;
      addTearDown(() => _goalOutcome = SubTrackGoalSetupOutcome.cancelled);
      await _pumpForm(tester, h);
      await _enter(tester, 'subTrackFormName', 'Cheder');
      await tester.ensureVisible(find.text('Set a deadline'));
      await tester.tap(find.text('Set a deadline'));
      await tester.pump();
      await tester.pump();
      expect(find.text("Couldn't save the goal."), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Cheder'), findsOneWidget);
      expect(_formOpen(), isTrue);
    });

    testWidgets('a saved goal is confirmed', (tester) async {
      h = SubTrackHarness();
      _goalOutcome = SubTrackGoalSetupOutcome.saved;
      addTearDown(() => _goalOutcome = SubTrackGoalSetupOutcome.cancelled);
      await _pumpForm(tester, h);
      await tester.ensureVisible(find.text('Set a deadline'));
      await tester.tap(find.text('Set a deadline'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Goal saved'), findsOneWidget);
    });

    testWidgets('is absent when the curriculum has a deadline', (tester) async {
      h = SubTrackHarness(deadline: '2028-06-01');
      await _pumpForm(tester, h);
      expect(find.text('Set a deadline'), findsNothing);
    });
  });

  group('AC-7 validation and create', () {
    testWidgets('an empty name errors on blur, not before', (tester) async {
      h = SubTrackHarness();
      await _pumpForm(tester, h);
      await tester.tap(find.byKey(const ValueKey('subTrackFormName')));
      await tester.pump();
      expect(find.text('Enter a name'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('subTrackFormWeeks')));
      await tester.pump();
      expect(find.text('Enter a name'), findsOneWidget);
    });

    testWidgets('a non-positive rate errors on blur and clears on fix', (
      tester,
    ) async {
      h = SubTrackHarness();
      await _pumpForm(tester, h);
      await _enter(tester, 'subTrackFormRate', '0');
      await tester.tap(find.byKey(const ValueKey('subTrackFormWeeks')));
      await tester.pump();
      expect(find.text('Enter a number greater than 0'), findsOneWidget);
      await _enter(tester, 'subTrackFormRate', '4');
      expect(find.text('Enter a number greater than 0'), findsNothing);
    });

    testWidgets('save shows every error and calls no command', (tester) async {
      h = SubTrackHarness();
      await _pumpForm(tester, h);
      await _enter(tester, 'subTrackFormWeeks', '-1');
      await _save(tester);
      expect(find.text('Enter a name'), findsOneWidget);
      expect(find.text('Choose an academic year'), findsOneWidget);
      expect(find.text('Enter a number greater than 0'), findsOneWidget);
      expect(h.commands.creates, isEmpty);
      expect(_formOpen(), isTrue);
    });

    testWidgets('an overlapping window blocks save inline', (tester) async {
      h = SubTrackHarness(
        seed: [storedSchoolYear(_existingId, windowEnd: '2027-09-30')],
      );
      await _pumpForm(tester, h);
      await _enter(tester, 'subTrackFormName', 'Next year');
      await tester.tap(_chip('2027–28'));
      await _save(tester);
      expect(
        find.text('These months overlap another school sub-track'),
        findsOneWidget,
      );
      expect(h.commands.creates, isEmpty);
    });

    testWidgets('a reversed window blocks save inline', (tester) async {
      h = SubTrackHarness();
      await _pumpForm(tester, h);
      await _enter(tester, 'subTrackFormName', 'Cheder');
      await tester.tap(_chip('2026–27'));
      await tester.tap(find.text('September'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('August').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('July'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('June').last);
      await tester.pumpAndSettle();
      // Start August (2027), end June (2027): reversed.
      expect(
        find.text('The end month must come after the start month'),
        findsOneWidget,
      );
    });

    testWidgets('a valid save creates through createSubTrack and closes', (
      tester,
    ) async {
      h = SubTrackHarness(deadline: '2028-06-01');
      await _pumpForm(tester, h);
      await _enter(tester, 'subTrackFormName', '  Cheder  ');
      await tester.tap(_chip('2027–28'));
      await _enter(tester, 'subTrackFormRate', '12');
      await tester.tap(find.byType(Switch));
      await _save(tester);

      expect(_formOpen(), isFalse);
      final draft = h.commands.creates.single;
      expect(draft.name, 'Cheder');
      expect(draft.type, SubTrackType.schoolYear);
      expect(draft.academicYear, 2027);
      expect(draft.windowStart, '2027-09-01');
      expect(draft.windowEnd, '2028-07-31');
      expect(draft.ratePerWeek, 12);
      expect(draft.weeksPerYear, 39);
      expect(draft.learnsOnShabbos, isTrue);
      expect(draft.ground, isEmpty);

      final stored = (await tester.runAsync(h.stored))!.single;
      expect(stored.curriculumId, subTrackTestCurriculum);
      expect(stored.academicYear, 2027);
      expect(stored.windowEnd, '2028-07-31');
      expect(h.repo.entries, hasLength(1));
    });

    testWidgets('a failed save keeps every value and retries', (tester) async {
      h = SubTrackHarness();
      await _pumpForm(tester, h);
      await _enter(tester, 'subTrackFormName', 'Cheder');
      await tester.tap(_chip('2026–27'));
      h.commands.nextError = Exception('network');
      await _save(tester);

      expect(_formOpen(), isTrue);
      expect(find.text("Couldn't save the sub-track."), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Cheder'), findsOneWidget);
      expect(tester.widget<ChoiceChip>(_chip('2026–27')).selected, isTrue);
      expect(await tester.runAsync(h.stored), isEmpty);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await settleCommands(tester);
      await tester.pumpAndSettle();
      expect(h.commands.creates, hasLength(2));
      expect(_formOpen(), isFalse);
      expect(await tester.runAsync(h.stored), hasLength(1));
    });

    testWidgets('a lost parent session at save keeps values (childLimit)', (
      tester,
    ) async {
      h = SubTrackHarness();
      await _pumpForm(tester, h);
      await _enter(tester, 'subTrackFormName', 'Cheder');
      await tester.tap(_chip('2026–27'));
      h.commands.nextResult = const CaptureResult.childLimit();
      await _save(tester);
      expect(_formOpen(), isTrue);
      expect(find.text("Couldn't save the sub-track."), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Cheder'), findsOneWidget);
    });

    testWidgets('shared AD-45 violations from the command show inline', (
      tester,
    ) async {
      h = SubTrackHarness();
      await _pumpForm(tester, h);
      await _enter(tester, 'subTrackFormName', 'Cheder');
      await tester.tap(_chip('2026–27'));
      h.commands.nextResult = const CaptureResult.rejected(
        CaptureRejection.invalid,
        violations: [
          SubTrackViolation(SubTrackLimit.schoolYearDuplicate, subject: 'x'),
        ],
      );
      await _save(tester);
      expect(
        find.text('This academic year already has a school sub-track'),
        findsOneWidget,
      );
      expect(_formOpen(), isTrue);
    });

    testWidgets('a calendar-program curriculum is refused by the command', (
      tester,
    ) async {
      h = SubTrackHarness(calendarProgramId: 'daf_yomi');
      await _pumpForm(tester, h);
      await _enter(tester, 'subTrackFormName', 'Cheder');
      await tester.tap(_chip('2026–27'));
      await _save(tester);
      expect(
        find.text(
          "This track follows a calendar program, so it can't have sub-tracks.",
        ),
        findsOneWidget,
      );
      expect(await tester.runAsync(h.stored), isEmpty);
    });
  });

  group('AC-8 edit', () {
    testWidgets('only the changed fields go through editSubTrack', (
      tester,
    ) async {
      h = SubTrackHarness(seed: [storedSchoolYear(_existingId)]);
      await _pumpForm(tester, h, subTrackId: _existingId);
      expect(find.text('Edit school year'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'School'), findsOneWidget);
      await _enter(tester, 'subTrackFormRate', '12');
      await _save(tester);

      final (id, edit) = h.commands.edits.single;
      expect(id, _existingId);
      expect(edit.ratePerWeek, 12);
      expect(edit.name, isNull);
      expect(edit.academicYear, isNull);
      expect(edit.windowStart, isNull);
      expect(edit.windowEnd, isNull);
      expect(edit.weeksPerYear, isNull);
      expect(edit.learnsOnShabbos, isNull);
      expect((await tester.runAsync(h.stored))!.single.ratePerWeek, 12);
      expect(h.repo.entries.single.$2.after.keys, [
        'sub_tracks/$_existingId.rate_per_week',
      ]);
    });

    testWidgets('an unchanged edit writes nothing and closes', (tester) async {
      h = SubTrackHarness(seed: [storedSchoolYear(_existingId)]);
      await _pumpForm(tester, h, subTrackId: _existingId);
      await _save(tester);
      expect(h.commands.edits, isEmpty);
      expect(h.repo.entries, isEmpty);
      expect(_formOpen(), isFalse);
    });

    testWidgets('an open-ended row stays open on an unchanged save', (
      tester,
    ) async {
      h = SubTrackHarness(seed: [storedSchoolYear(_existingId, openEnd: true)]);
      await _pumpForm(tester, h, subTrackId: _existingId);
      expect(find.text('No end month'), findsOneWidget);
      await _save(tester);
      expect(h.commands.edits, isEmpty);
      expect(h.repo.entries, isEmpty);
      expect((await tester.runAsync(h.stored))!.single.windowEnd, isNull);
      expect(_formOpen(), isFalse);
    });

    testWidgets('a bounded row offers no open end month', (tester) async {
      h = SubTrackHarness(seed: [storedSchoolYear(_existingId)]);
      await _pumpForm(tester, h, subTrackId: _existingId);
      expect(find.text('No end month'), findsNothing);
    });

    testWidgets("another curriculum's row is not found, never edited", (
      tester,
    ) async {
      h = SubTrackHarness(
        seed: [storedSchoolYear(_existingId, curriculumId: 'bavli')],
      );
      await _pumpForm(tester, h, subTrackId: _existingId);
      expect(find.byType(SchoolYearSubTrackForm), findsNothing);
      expect(find.text('Save sub-track'), findsNothing);
      expect(h.commands.edits, isEmpty);
    });

    testWidgets('an ongoing row is not found on the school-year form', (
      tester,
    ) async {
      h = SubTrackHarness(seed: [storedOngoing(_existingId)]);
      await _pumpForm(tester, h, subTrackId: _existingId);
      expect(find.byType(SchoolYearSubTrackForm), findsNothing);
      expect(find.text('Save sub-track'), findsNothing);
      expect(h.commands.edits, isEmpty);
    });
  });

  group('AC-3 parent session', () {
    testWidgets('a child session gets no form', (tester) async {
      h = SubTrackHarness();
      await _pumpForm(tester, h, parentSession: false);
      expect(find.byType(SchoolYearSubTrackForm), findsNothing);
      expect(find.text('Save sub-track'), findsNothing);
    });
  });

  group('AC-10 layouts', () {
    testWidgets('dark theme renders with no exception', (tester) async {
      h = SubTrackHarness();
      await _pumpForm(
        tester,
        h,
        theme: AppTheme.themeFor(brightness: Brightness.dark),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Save sub-track'), findsOneWidget);
    });

    testWidgets('maximum text scale keeps 48dp targets without overflow', (
      tester,
    ) async {
      h = SubTrackHarness();
      await _pumpForm(tester, h, textScale: 2, size: const Size(360, 3200));
      expect(tester.takeException(), isNull);
      for (final icon in [Icons.add, Icons.remove]) {
        final size = tester.getSize(
          find.ancestor(
            of: find.byIcon(icon),
            matching: find.byType(IconButton),
          ),
        );
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
      final chipSize = tester.getSize(_chip('2026–27'));
      expect(chipSize.height, greaterThanOrEqualTo(48));
    });

    testWidgets('tablet: a ≤600px form next to a capacity-only summary', (
      tester,
    ) async {
      h = SubTrackHarness(seed: [storedSchoolYear(_existingId)]);
      await _pumpForm(tester, h, size: const Size(1100, 1400));
      expect(find.byType(SubTrackSummaryPanel), findsOneWidget);
      expect(
        tester.getSize(find.byType(ListView).first).width,
        lessThanOrEqualTo(600),
      );
      expect(find.text('Sub-tracks'), findsOneWidget);
      // No deadline → capacity is not computed: the rate plan only.
      expect(find.text('10/wk × 39 weeks'), findsOneWidget);
    });

    testWidgets('narrow phone: no summary panel', (tester) async {
      h = SubTrackHarness();
      await _pumpForm(tester, h);
      expect(find.byType(SubTrackSummaryPanel), findsNothing);
    });

    testWidgets('Hebrew renders right-to-left with Hebrew labels', (
      tester,
    ) async {
      h = SubTrackHarness();
      await _pumpForm(tester, h, locale: const Locale('he'));
      expect(tester.takeException(), isNull);
      expect(find.text('שם תת-המסלול'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(AcademicYearPicker))),
        TextDirection.rtl,
      );
    });
  });
}

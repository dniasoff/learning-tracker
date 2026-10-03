// DNI-507 (Story 3.4) T1: the Adjust selection service — the opening
// selection follows the card's planner output (AC-1), the Up to… rows
// start at the group's first planned leaf and continue in the track's
// order (AC-2, AC-6), a confirmed picker merges into one group only and
// never duplicates a leaf across days (AC-2, AC-5), and Record builds one
// adjusted action of the ticked leaves (AC-3, AC-4).
@Tags(['learning'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/learning/domain/commands/catch_up_commands.dart';
import 'package:learning_tracker/features/learning/domain/models/catch_up_selection.dart';
import 'package:learning_tracker/features/learning/domain/services/catch_up_selection_service.dart';

import '../../../../helpers/learner_state/catch_up_adjust_fixtures.dart';

void main() {
  final thursday = adjustDays[0];
  final friday = adjustDays[1];
  final shabbos = adjustDays[2];
  const main = LearningEvent.sourceMain;

  group('catchUpSelectionOf (AC-1)', () {
    test('one section per covered day, main then sub-tracks, all ticked', () {
      final card = adjustCard({
        friday: adjustDay(
          subs: {
            adjustSchool: [beitzah(1, 1)],
          },
        ),
        shabbos: adjustDay(
          main: [
            newTask(beitzah(2, 7)),
            newTask(beitzah(2, 8)),
            reviewTask(beitzah(1, 5)),
          ],
          subs: {
            adjustRebbe: beitzahRun(3, 1, 3),
            adjustSchool: [beitzah(1, 2)],
          },
        ),
      });
      final s = adjustSelectionOf(card);
      expect(s.days.map((d) => d.day.date), [friday, shabbos]);
      expect(s.days[0].groups.map((g) => g.key.source), [adjustSchool]);
      expect(s.days[1].groups.map((g) => g.key.source), [
        main,
        adjustRebbe,
        adjustSchool,
      ]);
      final mainGroup = s.days[1].groups[0];
      expect(mainGroup.subTrackName, isNull);
      expect(mainGroup.rows, [
        CatchUpRow(beitzah(2, 7), stage: 1, planned: true),
        CatchUpRow(beitzah(2, 8), stage: 1, planned: true),
        CatchUpRow(beitzah(1, 5), stage: 3, planned: true),
      ]);
      expect(mainGroup.extensionStage, 1);
      expect(s.days[1].groups[1].subTrackName, 'Rebbe');
      expect(s.days[1].groups[1].extensionStage, isNull);
      for (final d in s.days) {
        for (final g in d.groups) {
          expect(g.included, {for (final r in g.rows) r.ref});
          expect(g.rows.every((r) => r.planned), isTrue);
        }
      }
      expect(s.count, 8);
    });

    test('the rows are the planner output, not a recomputed amount; a '
        'leaf listed twice is one row', () {
      final card = adjustCard({
        shabbos: adjustDay(
          main: [newTask(beitzah(2, 7)), newTask(beitzah(2, 7))],
          subs: {
            adjustRebbe: [beitzah(3, 2)],
          },
        ),
      });
      final s = adjustSelectionOf(card);
      expect(s.days.single.groups[0].rows.map((r) => r.ref), [beitzah(2, 7)]);
      expect(s.days.single.groups[1].rows.map((r) => r.ref), [beitzah(3, 2)]);
    });

    test('a review-only main group extends at its first row stage', () {
      final s = adjustSelectionOf(
        adjustCard({
          shabbos: adjustDay(main: [reviewTask(beitzah(1, 1))]),
        }),
      );
      expect(s.days.single.groups.single.extensionStage, 3);
    });

    test('at most the card\'s three days, skipping a day with nothing', () {
      final s = adjustSelectionOf(
        adjustCard({
          thursday: adjustDay(main: [newTask(beitzah(2, 1))]),
          friday: adjustDay(),
          shabbos: adjustDay(main: [newTask(beitzah(2, 2))]),
        }),
      );
      expect(s.days.map((d) => d.day.date), [thursday, shabbos]);
    });
  });

  group('catchUpPickerRows (AC-2, AC-6)', () {
    final card = adjustCard({
      friday: adjustDay(subs: {adjustRebbe: beitzahRun(3, 1, 2)}),
      shabbos: adjustDay(
        main: [newTask(beitzah(2, 7)), newTask(beitzah(2, 8))],
        subs: {adjustRebbe: beitzahRun(3, 3, 4)},
      ),
    });
    final s = adjustSelectionOf(card);
    final path = beitzahRun(3, 1, 10);

    test('start at the group\'s first planned leaf and continue in the '
        'track order after the last planned leaf', () {
      final rows = catchUpPickerRows(
        s,
        adjustKey(adjustRebbe, shabbos),
        trackOrder: path,
      )!;
      expect(rows.rows.map((r) => r.ref), beitzahRun(3, 3, 10));
      expect(rows.rows.take(2).every((r) => r.planned), isTrue);
      expect(rows.rows.skip(2).any((r) => r.planned), isFalse);
      expect(rows.rows.every((r) => r.stage == null), isTrue);
      expect(rows.included, beitzahRun(3, 3, 4));
      expect(rows.hasFurther, isTrue);
    });

    test('the main track\'s added leaves carry its extension stage', () {
      final rows = catchUpPickerRows(
        s,
        adjustKey(main, shabbos),
        trackOrder: [beitzah(2, 6), ...beitzahRun(2, 7, 10)],
      )!;
      expect(rows.rows.map((r) => (r.ref, r.stage)), [
        (beitzah(2, 7), 1),
        (beitzah(2, 8), 1),
        (beitzah(2, 9), 1),
        (beitzah(2, 10), 1),
      ]);
    });

    test('no planned leaf in the track order: every leaf may follow', () {
      final rows = catchUpPickerRows(
        s,
        adjustKey(main, shabbos),
        trackOrder: [beitzah(4, 1)],
      )!;
      expect(rows.rows.map((r) => r.ref), [
        beitzah(2, 7),
        beitzah(2, 8),
        beitzah(4, 1),
      ]);
    });

    test('leaves already ticked in the track are shown as recorded', () {
      final rows = catchUpPickerRows(
        s,
        adjustKey(adjustRebbe, shabbos),
        trackOrder: path,
        recorded: {beitzah(3, 6)},
      )!;
      expect(rows.recorded, {beitzah(3, 6)});
    });

    test('AC-6: nothing after the planned leaves: no further leaf', () {
      final atEnd = catchUpPickerRows(
        s,
        adjustKey(adjustRebbe, shabbos),
        trackOrder: beitzahRun(3, 3, 4),
      )!;
      expect(atEnd.hasFurther, isFalse);
      final onlyRecorded = catchUpPickerRows(
        s,
        adjustKey(adjustRebbe, shabbos),
        trackOrder: beitzahRun(3, 3, 5),
        recorded: {beitzah(3, 5)},
      )!;
      expect(onlyRecorded.hasFurther, isFalse);
    });

    test('an unknown group has no rows', () {
      expect(
        catchUpPickerRows(
          s,
          adjustKey(adjustSchool, shabbos),
          trackOrder: path,
        ),
        isNull,
      );
    });
  });

  group('applyCatchUpPicker (AC-2, AC-5)', () {
    final card = adjustCard({
      friday: adjustDay(subs: {adjustRebbe: beitzahRun(3, 1, 2)}),
      shabbos: adjustDay(subs: {adjustRebbe: beitzahRun(3, 3, 4)}),
    });
    final base = adjustSelectionOf(card);
    final path = beitzahRun(3, 1, 10);
    final fri = adjustKey(adjustRebbe, friday);
    final sat = adjustKey(adjustRebbe, shabbos);

    test('a later target and an untick merge into that group only', () {
      final rows = catchUpPickerRows(base, sat, trackOrder: path)!;
      final next = applyCatchUpPicker(base, rows, [
        beitzah(3, 3),
        beitzah(3, 5),
        beitzah(3, 6),
      ]);
      final g = next.group(sat)!;
      expect(g.rows.map((r) => r.ref), beitzahRun(3, 3, 6));
      expect(g.included, {beitzah(3, 3), beitzah(3, 5), beitzah(3, 6)});
      expect(next.group(fri), same(base.group(fri)));
      expect(next.count, 5);
    });

    test('reopening starts from the planned start with the current ticks', () {
      final first = applyCatchUpPicker(
        base,
        catchUpPickerRows(base, sat, trackOrder: path)!,
        [beitzah(3, 3), beitzah(3, 6)],
      );
      final again = catchUpPickerRows(first, sat, trackOrder: path)!;
      expect(again.rows.first.ref, beitzah(3, 3));
      expect(again.included, [beitzah(3, 3), beitzah(3, 6)]);
    });

    test('an earlier target keeps planned rows, unticked, and drops added '
        'ones', () {
      final wide = applyCatchUpPicker(
        base,
        catchUpPickerRows(base, sat, trackOrder: path)!,
        beitzahRun(3, 3, 7),
      );
      final narrow = applyCatchUpPicker(
        wide,
        catchUpPickerRows(wide, sat, trackOrder: path)!,
        [beitzah(3, 3)],
      );
      final g = narrow.group(sat)!;
      expect(g.rows.map((r) => r.ref), beitzahRun(3, 3, 4));
      expect(g.included, {beitzah(3, 3)});
    });

    test('Up to… on an earlier day takes a later day\'s leaves; repeated '
        'edits never duplicate a leaf', () {
      // Friday through 3:5: Shabbos's 3:3 and 3:4 now belong to Friday.
      var s = applyCatchUpPicker(
        base,
        catchUpPickerRows(base, fri, trackOrder: path)!,
        beitzahRun(3, 1, 5),
      );
      List<String> shown(CatchUpSelection x, int day) => [
        for (final r in x.view[day].groups.single.rows) r.ref,
      ];
      expect(shown(s, 0), beitzahRun(3, 1, 5));
      expect(shown(s, 1), isEmpty);
      expect(s.count, 5);
      // Shabbos's picker no longer offers them.
      final satRows = catchUpPickerRows(s, sat, trackOrder: path)!;
      expect(satRows.rows.map((r) => r.ref), beitzahRun(3, 6, 10));
      expect(satRows.included, isEmpty);
      // Shabbos includes through 3:7 (its own leaves start after Friday's).
      s = applyCatchUpPicker(s, satRows, beitzahRun(3, 6, 7));
      expect(shown(s, 1), beitzahRun(3, 6, 7));
      // Friday narrows back to its plan: 3:3 and 3:4 return to Shabbos.
      s = applyCatchUpPicker(
        s,
        catchUpPickerRows(s, fri, trackOrder: path)!,
        beitzahRun(3, 1, 2),
      );
      expect(shown(s, 0), beitzahRun(3, 1, 2));
      expect(shown(s, 1), [...beitzahRun(3, 3, 4), ...beitzahRun(3, 6, 7)]);
      final leaves = catchUpAdjustedAction(s, card.window)!.leaves;
      expect({for (final l in leaves) l.ref}, hasLength(leaves.length));
      expect(leaves, hasLength(6));
    });

    test('an unknown group leaves the selection as it was', () {
      final rows = CatchUpPickerRows(
        key: adjustKey(adjustSchool, shabbos),
        rows: const [],
        recorded: const {},
        included: const [],
      );
      expect(applyCatchUpPicker(base, rows, const []), same(base));
    });
  });

  group('catchUpAdjustedAction (AC-3, AC-4, AC-5)', () {
    test('records the ticked leaves of each section on its day', () {
      final card = adjustCard({
        shabbos: adjustDay(
          main: [for (final r in beitzahRun(2, 7, 10)) newTask(r, stage: 2)],
          subs: {adjustRebbe: beitzahRun(3, 1, 10)},
        ),
      });
      final s = adjustSelectionOf(
        card,
      ).toggle(adjustKey(adjustRebbe, shabbos), beitzah(3, 3));
      final action = catchUpAdjustedAction(s, card.window)!;
      expect(action.mode, CatchUpMode.adjusted);
      expect(action.lock, card.window.lock);
      expect(action.lockedDaysOffered, 1);
      expect(action.leaves, hasLength(13));
      expect(action.leaves.where((l) => l.ref == beitzah(3, 3)), isEmpty);
      expect(action.leaves.every((l) => l.learnedOn == shabbos), isTrue);
      expect(
        [
          for (final l in action.leaves)
            if (l.source == main) l.stage,
        ],
        [2, 2, 2, 2],
      );
      expect(
        action.leaves
            .where((l) => l.source == adjustRebbe)
            .every((l) => l.stage == null),
        isTrue,
      );
    });

    test('each leaf is dated to its section and recorded once', () {
      final card = adjustCard({
        thursday: adjustDay(subs: {adjustRebbe: beitzahRun(3, 1, 2)}),
        friday: adjustDay(subs: {adjustRebbe: beitzahRun(3, 2, 3)}),
        shabbos: adjustDay(main: [newTask(beitzah(2, 1))]),
      });
      final action = catchUpAdjustedAction(
        adjustSelectionOf(card),
        card.window,
      )!;
      expect(action.lockedDaysOffered, 3);
      expect(
        [for (final l in action.leaves) (l.ref, l.learnedOn)],
        [
          (beitzah(3, 1), thursday),
          (beitzah(3, 2), thursday),
          (beitzah(3, 3), friday),
          (beitzah(2, 1), shabbos),
        ],
      );
    });

    test('AC-4: nothing ticked is no action', () {
      final card = adjustCard({
        shabbos: adjustDay(
          subs: {
            adjustRebbe: [beitzah(3, 1)],
          },
        ),
      });
      final s = adjustSelectionOf(
        card,
      ).toggle(adjustKey(adjustRebbe, shabbos), beitzah(3, 1));
      expect(catchUpAdjustedAction(s, card.window), isNull);
    });
  });
}

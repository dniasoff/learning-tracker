// DNI-507 (Story 3.4) T1: the Adjust panel's selection model — one
// section per locked day, per-source groups, a live count, and
// earliest-day ownership of a leaf (AC-1, AC-4, AC-5).
@Tags(['learning'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/learning/domain/models/catch_up_selection.dart';

import '../../../../helpers/learner_state/catch_up_adjust_fixtures.dart';

void main() {
  final shabbos = adjustDays[2];
  final friday = adjustDays[1];
  final thursday = adjustDays[0];
  final rebbeShabbos = adjustKey(adjustRebbe, shabbos);
  final mainShabbos = adjustKey(LearningEvent.sourceMain, shabbos);

  group('CatchUpGroupKey', () {
    test('equal by curriculum, source and day; main is the main track', () {
      expect(rebbeShabbos, adjustKey(adjustRebbe, shabbos));
      expect(rebbeShabbos.hashCode, adjustKey(adjustRebbe, shabbos).hashCode);
      expect(rebbeShabbos, isNot(adjustKey(adjustRebbe, friday)));
      expect(rebbeShabbos, isNot(adjustKey(adjustSchool, shabbos)));
      expect(mainShabbos.isMain, isTrue);
      expect(rebbeShabbos.isMain, isFalse);
    });
  });

  group('CatchUpGroupSelection', () {
    test('keeps only included leaves that are rows, unmodifiable', () {
      final g = CatchUpGroupSelection(
        key: rebbeShabbos,
        rows: [CatchUpRow(beitzah(3, 1), planned: true)],
        included: {beitzah(3, 1), beitzah(9, 9)},
      );
      expect(g.included, {beitzah(3, 1)});
      expect(
        () => g.rows.add(CatchUpRow(beitzah(3, 2))),
        throwsUnsupportedError,
      );
      expect(() => g.included.add(beitzah(3, 2)), throwsUnsupportedError);
    });

    test('plannedRows are the planner rows only, in order', () {
      final g = CatchUpGroupSelection(
        key: rebbeShabbos,
        rows: [
          CatchUpRow(beitzah(3, 1), planned: true),
          CatchUpRow(beitzah(3, 2), planned: true),
          CatchUpRow(beitzah(3, 3)),
        ],
        included: const {},
      );
      expect(g.plannedRows.map((r) => r.ref), [beitzah(3, 1), beitzah(3, 2)]);
    });
  });

  group('AC-1 / AC-4: count and toggles', () {
    final selection = adjustSelectionOf(
      adjustCard({
        shabbos: adjustDay(
          main: [for (final r in beitzahRun(2, 7, 10)) newTask(r)],
          subs: {adjustRebbe: beitzahRun(3, 1, 3)},
        ),
      }),
    );

    test('the live count is every ticked row', () {
      expect(selection.count, 7);
      final next = selection.toggle(rebbeShabbos, beitzah(3, 3));
      expect(next.count, 6);
      expect(next.toggle(rebbeShabbos, beitzah(3, 3)).count, 7);
    });

    test('unticking every row leaves a zero count', () {
      var s = selection;
      for (final day in s.view) {
        for (final g in day.groups) {
          for (final r in g.rows) {
            s = s.toggle(g.key, r.ref);
          }
        }
      }
      expect(s.count, 0);
      expect(s.view.single.groups, hasLength(2));
    });

    test('editing one group never changes another group', () {
      final next = selection.toggle(rebbeShabbos, beitzah(3, 1));
      expect(next.group(mainShabbos), same(selection.group(mainShabbos)));
      expect(next.group(rebbeShabbos)!.included, {
        beitzah(3, 2),
        beitzah(3, 3),
      });
      // The original is immutable.
      expect(selection.group(rebbeShabbos)!.included, hasLength(3));
    });

    test('a toggle on an unknown group or row is ignored', () {
      expect(
        selection.toggle(adjustKey(adjustSchool, shabbos), beitzah(3, 1)),
        same(selection),
      );
      expect(selection.toggle(rebbeShabbos, beitzah(5, 5)), same(selection));
    });

    test('replace with an unknown key returns the selection', () {
      final stray = CatchUpGroupSelection(
        key: adjustKey(adjustSchool, shabbos),
        rows: const [],
        included: const {},
      );
      expect(selection.replace(stray), same(selection));
    });
  });

  group('AC-5: a leaf appears in at most one section, the earliest', () {
    test('a later section hides a leaf an earlier section shows', () {
      final base = adjustSelectionOf(
        adjustCard({
          friday: adjustDay(subs: {adjustRebbe: beitzahRun(3, 1, 2)}),
          shabbos: adjustDay(subs: {adjustRebbe: beitzahRun(3, 3, 4)}),
        }),
      );
      // Friday's group now also shows 3:3 (as Up to… would add it).
      final friKey = adjustKey(adjustRebbe, friday);
      final fri = base.group(friKey)!;
      final selection = base.replace(
        fri.copyWith(
          rows: [...fri.rows, CatchUpRow(beitzah(3, 3))],
          included: {...fri.included, beitzah(3, 3)},
        ),
      );
      final view = selection.view;
      expect(view[0].groups.single.rows.map((r) => r.ref), beitzahRun(3, 1, 3));
      expect(view[1].groups.single.rows.map((r) => r.ref), [beitzah(3, 4)]);
      expect(view[1].groups.single.claimedEarlier, {
        beitzah(3, 1),
        beitzah(3, 2),
        beitzah(3, 3),
      });
      expect(view[1].groups.single.isIncluded(beitzah(3, 3)), isFalse);
      expect(selection.count, 4);
      // Shabbos's stored group is untouched: removing 3:3 from Friday
      // gives it back to Shabbos, never to both.
      expect(selection.group(rebbeShabbos)!.included, {
        beitzah(3, 3),
        beitzah(3, 4),
      });
      final undone = selection.replace(fri);
      expect(
        undone.view[1].groups.single.rows.map((r) => r.ref),
        beitzahRun(3, 3, 4),
      );
      expect(undone.count, 4);
    });

    test('a toggle on a leaf an earlier section owns is ignored', () {
      final base = adjustSelectionOf(
        adjustCard({
          friday: adjustDay(subs: {adjustRebbe: beitzahRun(3, 1, 2)}),
          shabbos: adjustDay(subs: {adjustRebbe: beitzahRun(3, 2, 3)}),
        }),
      );
      expect(base.toggle(rebbeShabbos, beitzah(3, 2)), same(base));
      expect(base.count, 3);
    });

    test('ownership is per source: main and a sub-track both keep a leaf', () {
      final selection = adjustSelectionOf(
        adjustCard({
          friday: adjustDay(main: [newTask(beitzah(3, 1))]),
          shabbos: adjustDay(
            subs: {
              adjustRebbe: [beitzah(3, 1)],
            },
          ),
        }),
      );
      expect(selection.count, 2);
    });

    test('chained three days: every repeated leaf stays on its earliest '
        'day, planner order kept in each group', () {
      final selection = adjustSelectionOf(
        adjustCard({
          thursday: adjustDay(
            main: [newTask(beitzah(2, 1)), newTask(beitzah(2, 2))],
            subs: {adjustRebbe: beitzahRun(3, 1, 3)},
          ),
          friday: adjustDay(
            main: [newTask(beitzah(2, 2)), newTask(beitzah(2, 3))],
            subs: {adjustRebbe: beitzahRun(3, 3, 5)},
          ),
          shabbos: adjustDay(
            main: [newTask(beitzah(2, 3)), newTask(beitzah(2, 4))],
            subs: {
              adjustRebbe: [...beitzahRun(3, 5, 6), beitzah(3, 1)],
            },
          ),
        }),
      );
      final view = selection.view;
      expect(view.map((d) => d.day.date), adjustDays);
      List<String> refs(int day, int group) => [
        for (final r in view[day].groups[group].rows) r.ref,
      ];
      expect(refs(0, 0), [beitzah(2, 1), beitzah(2, 2)]);
      expect(refs(1, 0), [beitzah(2, 3)]);
      expect(refs(2, 0), [beitzah(2, 4)]);
      expect(refs(0, 1), beitzahRun(3, 1, 3));
      expect(refs(1, 1), beitzahRun(3, 4, 5));
      expect(refs(2, 1), [beitzah(3, 6)]);
      final all = [
        for (final d in view)
          for (final g in d.groups)
            for (final r in g.includedRows) (g.key.source, r.ref),
      ];
      expect(all.toSet(), hasLength(all.length));
      expect(selection.count, 10);
    });
  });
}

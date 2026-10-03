// DNI-507 (Story 3.4) T2 / T6: the catch-up card's in-place Adjust panel —
// day sections with per-source groups, every planned row ticked, a live
// Record count, collapse discarding edits (AC-1), Up to… through the
// shared picker (AC-2, AC-5), the zero state (AC-4),
// an exhausted sub-track ground (AC-6) and the inline load retry (AC-7).
@Tags(['learning'])
library;

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/catch_up_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/learner_state/catch_up_adjust_rig.dart';
import '../../../../helpers/learner_state/catch_up_card_harness.dart';

const _main = LearningEvent.sourceMain;

final _card = find.byType(CatchUpCardView);

String _recordText(WidgetTester tester) {
  return tester
      .widgetList<Text>(
        find.descendant(of: adjustRecord, matching: find.byType(Text)),
      )
      .map((t) => t.data)
      .join();
}

bool _recordEnabled(WidgetTester tester) =>
    tester.widget<ButtonStyleButton>(adjustRecord).onPressed != null;

Future<void> _tapRow(WidgetTester tester, String source, String leaf) async {
  await tester.ensureVisible(adjustRow(source, leaf));
  await tester.tap(adjustRow(source, leaf));
  await settleAdjust(tester);
}

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  group('AC-1: the card expands in place into the Adjust panel', () {
    testWidgets('one Shabbos section, Home and Rebbe groups, all ticked', (
      tester,
    ) async {
      final rig = AdjustRig();
      await pumpAdjustCard(tester, rig.overrides());
      expect(adjustPanel, findsNothing);
      final route = ModalRoute.of(tester.element(_card));
      await openAdjust(tester);
      expect(adjustPanel, findsOneWidget);
      // In place: the same route, inside the card.
      expect(ModalRoute.of(tester.element(adjustPanel)), same(route));
      expect(find.descendant(of: _card, matching: adjustPanel), findsOneWidget);
      expect(
        find.byKey(const ValueKey('catchUpAdjustDay-$catchUpShabbos')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: adjustPanel, matching: find.text('Shabbos')),
        findsOneWidget,
      );
      expect(find.text('Home · Main track'), findsOneWidget);
      expect(find.text('Rebbe (learns on shabbos)'), findsOneWidget);
      for (final leaf in rigMainPlan) {
        expect(
          tester
              .widget<Checkbox>(
                find.descendant(
                  of: adjustRow(_main, leaf),
                  matching: find.byType(Checkbox),
                ),
              )
              .value,
          isTrue,
        );
      }
      for (final leaf in rigRun(3, 1, 10)) {
        expect(adjustRow(rigRebbe, leaf), findsOneWidget);
      }
      // Leaves past the plan are not rows until Up to… adds them.
      expect(adjustRow(rigRebbe, rigLeaf(3, 11)), findsNothing);
      expect(_recordText(tester), 'Record 14 mishnayos');
      expect(_recordEnabled(tester), isTrue);
      await unmountAdjust(tester);
    });

    testWidgets('the Record count is live', (tester) async {
      final rig = AdjustRig();
      await pumpAdjustCard(tester, rig.overrides());
      await openAdjust(tester);
      await _tapRow(tester, rigRebbe, rigLeaf(3, 3));
      expect(_recordText(tester), 'Record 13 mishnayos');
      expect(
        tester
            .widget<Checkbox>(
              find.descendant(
                of: adjustRow(rigRebbe, rigLeaf(3, 3)),
                matching: find.byType(Checkbox),
              ),
            )
            .value,
        isFalse,
      );
      await _tapRow(tester, rigRebbe, rigLeaf(3, 3));
      expect(_recordText(tester), 'Record 14 mishnayos');
      await unmountAdjust(tester);
    });

    testWidgets('Record hands one adjusted action of the ticked leaves', (
      tester,
    ) async {
      final rig = AdjustRig();
      await pumpAdjustCard(tester, rig.overrides());
      await openAdjust(tester);
      await _tapRow(tester, rigRebbe, rigLeaf(3, 3));
      await tester.ensureVisible(adjustRecord);
      await tester.tap(adjustRecord);
      await settleAdjust(tester);
      final action = rig.recorded.single;
      expect(action.leaves, hasLength(13));
      expect(action.leaves.any((l) => l.ref == rigLeaf(3, 3)), isFalse);
      expect(action.leaves.every((l) => l.learnedOn == catchUpShabbos), isTrue);
      await unmountAdjust(tester);
    });

    testWidgets('collapsing discards the edits and records nothing', (
      tester,
    ) async {
      final rig = AdjustRig();
      await pumpAdjustCard(tester, rig.overrides());
      await openAdjust(tester);
      await _tapRow(tester, rigRebbe, rigLeaf(3, 3));
      expect(_recordText(tester), 'Record 13 mishnayos');
      // Cancel collapses.
      await tester.ensureVisible(adjustCancel);
      await tester.tap(adjustCancel);
      await settleAdjust(tester);
      expect(adjustPanel, findsNothing);
      await openAdjust(tester);
      expect(_recordText(tester), 'Record 14 mishnayos');
      // The Adjust… pill collapses too.
      await _tapRow(tester, _main, rigLeaf(2, 7));
      await openAdjust(tester);
      expect(adjustPanel, findsNothing);
      await openAdjust(tester);
      expect(_recordText(tester), 'Record 14 mishnayos');
      expect(rig.recorded, isEmpty);
      expect(_card, findsOneWidget);
      await unmountAdjust(tester);
    });

    testWidgets('Adjust… is disabled while no adjusted record is provided', (
      tester,
    ) async {
      final rig = AdjustRig();
      await pumpAdjustCard(
        tester,
        rig.overrides(actions: const CatchUpCardActions()),
      );
      expect(tester.widget<ButtonStyleButton>(adjustButton).onPressed, isNull);
      await unmountAdjust(tester);
    });
  });

  group('AC-2: Up to… opens the shared picker for the group and day', () {
    final sheet = find.byKey(const Key('upToPickerSheet'));
    final confirm = find.byKey(const Key('upToRecord'));
    Finder pickerRow(int i) => find.byKey(Key('upToRow-$i'));

    Future<void> openUpTo(WidgetTester tester, String source) async {
      final button = find.descendant(
        of: adjustUpTo(source),
        matching: find.byType(TextButton),
      );
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    String confirmText(WidgetTester tester) => tester
        .widget<Text>(find.descendant(of: confirm, matching: find.byType(Text)))
        .data!;

    testWidgets('starts at the first planned leaf with the plan ticked; a '
        'later leaf and an untick return to the panel without a write', (
      tester,
    ) async {
      final rig = AdjustRig();
      await pumpAdjustCard(tester, rig.overrides());
      await openAdjust(tester);
      await openUpTo(tester, rigRebbe);
      expect(sheet, findsOneWidget);
      expect(find.text('Rebbe · up to…'), findsOneWidget);
      expect(
        find.descendant(of: pickerRow(0), matching: find.text('Beitzah 3:1')),
        findsOneWidget,
      );
      expect(confirmText(tester), 'Include 10 mishnayos');
      // Include through 3:12, then skip 3:3.
      await tester.scrollUntilVisible(
        pickerRow(11),
        100,
        scrollable: find.descendant(
          of: find.byKey(const Key('upToPickerList')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(
        find.descendant(of: pickerRow(11), matching: find.byType(InkWell)),
      );
      await tester.pump();
      expect(confirmText(tester), 'Include 12 mishnayos');
      await tester.scrollUntilVisible(
        pickerRow(2),
        -100,
        scrollable: find.descendant(
          of: find.byKey(const Key('upToPickerList')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.byKey(const Key('upToRowTick-2')));
      await tester.pump();
      expect(confirmText(tester), 'Include 11 mishnayos');
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      expect(rig.recorded, isEmpty);
      expect(adjustRow(rigRebbe, rigLeaf(3, 12)), findsOneWidget);
      expect(
        tester
            .widget<Checkbox>(
              find.descendant(
                of: adjustRow(rigRebbe, rigLeaf(3, 3)),
                matching: find.byType(Checkbox),
              ),
            )
            .value,
        isFalse,
      );
      expect(_recordText(tester), 'Record 15 mishnayos');
      // Reopening starts from the planned start with the current ticks.
      await openUpTo(tester, rigRebbe);
      expect(
        find.descendant(of: pickerRow(0), matching: find.text('Beitzah 3:1')),
        findsOneWidget,
      );
      expect(confirmText(tester), 'Include 11 mishnayos');
      await tester.tap(find.byKey(const Key('upToCancel')));
      await tester.pumpAndSettle();
      await unmountAdjust(tester);
    });

    testWidgets('an earlier target drops the added leaves; Record writes '
        'each leaf once, added main leaves at the planner stage', (
      tester,
    ) async {
      final rig = AdjustRig();
      await pumpAdjustCard(tester, rig.overrides());
      await openAdjust(tester);
      await openUpTo(tester, _main);
      // Main: 2:7–2:10 planned, then 2:11 and 2:12.
      await tester.tap(
        find.descendant(of: pickerRow(5), matching: find.byType(InkWell)),
      );
      await tester.pump();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(_recordText(tester), 'Record 16 mishnayos');
      // Narrow back to 2:8: 2:9 and 2:10 stay as skipped planned rows,
      // 2:11 and 2:12 leave the panel.
      await openUpTo(tester, _main);
      await tester.tap(
        find.descendant(of: pickerRow(1), matching: find.byType(InkWell)),
      );
      await tester.pump();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(adjustRow(_main, rigLeaf(2, 11)), findsNothing);
      expect(adjustRow(_main, rigLeaf(2, 10)), findsOneWidget);
      expect(_recordText(tester), 'Record 12 mishnayos');
      // Wide again, then Record.
      await openUpTo(tester, _main);
      await tester.tap(
        find.descendant(of: pickerRow(4), matching: find.byType(InkWell)),
      );
      await tester.pump();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      await tester.ensureVisible(adjustRecord);
      await tester.tap(adjustRecord);
      await settleAdjust(tester);
      final leaves = rig.recorded.single.leaves;
      expect(leaves, hasLength(15));
      expect({for (final l in leaves) (l.source, l.ref)}, hasLength(15));
      final added = leaves.singleWhere((l) => l.ref == rigLeaf(2, 11));
      expect(added.source, _main);
      expect(added.stage, 1);
      await unmountAdjust(tester);
    });

    testWidgets('Cancel or platform back closes the picker and changes '
        'nothing', (tester) async {
      final rig = AdjustRig();
      await pumpAdjustCard(tester, rig.overrides());
      await openAdjust(tester);
      await openUpTo(tester, rigRebbe);
      await tester.tap(find.byKey(const Key('upToRowTick-0')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('upToCancel')));
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      expect(_recordText(tester), 'Record 14 mishnayos');
      await openUpTo(tester, rigRebbe);
      await tester.tap(find.byKey(const Key('upToRowTick-0')));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      expect(adjustPanel, findsOneWidget);
      expect(_recordText(tester), 'Record 14 mishnayos');
      expect(rig.recorded, isEmpty);
      await unmountAdjust(tester);
    });
  });

  group('AC-4: nothing ticked', () {
    testWidgets('Record stays visible, disabled, with 0; nothing written', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final rig = AdjustRig();
      await pumpAdjustCard(tester, rig.overrides());
      await openAdjust(tester);
      for (final leaf in rigMainPlan) {
        await _tapRow(tester, _main, leaf);
      }
      for (final leaf in rigRun(3, 1, 10)) {
        await _tapRow(tester, rigRebbe, leaf);
      }
      expect(adjustRecord, findsOneWidget);
      expect(_recordText(tester), 'Record 0 mishnayos');
      expect(_recordEnabled(tester), isFalse);
      final node = tester.getSemantics(adjustRecord);
      expect(node.label, contains('Record 0 mishnayos'));
      expect(node.flagsCollection.isEnabled, Tristate.isFalse);
      await tester.tap(adjustRecord, warnIfMissed: false);
      await settleAdjust(tester);
      expect(rig.recorded, isEmpty);
      // The card is still pending.
      expect(_card, findsOneWidget);
      semantics.dispose();
      await unmountAdjust(tester);
    });
  });

  group('AC-6: a flagged sub-track whose ground has nothing further', () {
    testWidgets('shows the empty-ground copy and disables Up to…', (
      tester,
    ) async {
      final rig = AdjustRig(state: rigState(rebbePath: rigRun(3, 1, 10)));
      await pumpAdjustCard(tester, rig.overrides());
      await openAdjust(tester);
      expect(
        find.text("No more mishnayos in this track's ground"),
        findsOneWidget,
      );
      final upTo = find.descendant(
        of: adjustUpTo(rigRebbe),
        matching: find.byType(TextButton),
      );
      expect(tester.widget<TextButton>(upTo).onPressed, isNull);
      // The main track continues, so its group has no such copy.
      expect(
        find.byKey(
          const ValueKey('catchUpAdjustNoMore-$catchUpShabbos-$_main'),
        ),
        findsNothing,
      );
      await unmountAdjust(tester);
    });
  });

  group('AC-7: the panel data fails to load', () {
    testWidgets('inline retry, Record disabled, the card stays; retry '
        'recovers', (tester) async {
      final rig = AdjustRig()..failSlices = true;
      await pumpAdjustCard(tester, rig.overrides());
      await openAdjust(tester);
      expect(
        find.byKey(const ValueKey('catchUpAdjustLoadError')),
        findsOneWidget,
      );
      expect(find.text("What you can adjust couldn't load."), findsOneWidget);
      expect(_recordEnabled(tester), isFalse);
      expect(_card, findsOneWidget);
      final retry = find.byKey(const ValueKey('catchUpAdjustRetry'));
      expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));
      rig.failSlices = false;
      await tester.tap(retry);
      await settleAdjust(tester);
      expect(
        find.byKey(const ValueKey('catchUpAdjustLoadError')),
        findsNothing,
      );
      expect(adjustRow(rigRebbe, rigLeaf(3, 1)), findsOneWidget);
      expect(_recordEnabled(tester), isTrue);
      await unmountAdjust(tester);
    });
  });
}

// DNI-507 (Story 3.4) T2 / T6: the catch-up card's in-place Adjust panel —
// day sections with per-source groups, every planned row ticked, a live
// Record count, collapse discarding edits (AC-1), the zero state (AC-4),
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

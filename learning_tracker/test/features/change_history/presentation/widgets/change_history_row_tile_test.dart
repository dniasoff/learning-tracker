/// DNI-513 AC-3 – AC-6: one Change history row — actor avatar, name, role
/// and time; the plain-language sentence; the AD-39 bell only on rows that
/// notified the parent; the muted *Undone* tag; the lock label; and Undo
/// only when Story 4.6 supplies it and the row allows it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/features/change_history/domain/models/change_history_row.dart';
import 'package:learning_tracker/features/change_history/presentation/widgets/change_history_row_tile.dart';

import '../../../../helpers/change_history_rows.dart';

Future<void> _pump(
  WidgetTester tester,
  ChangeHistoryRow row, {
  VoidCallback? onTap,
  VoidCallback? onUndo,
}) async {
  await tester.pumpWidget(
    historyRowApp(
      ChangeHistoryRowTile(row: row, onTap: onTap ?? () {}, onUndo: onUndo),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows avatar initials, name, role, time and the sentence '
      '(AC-3)', (tester) async {
    await _pump(tester, governedHistoryRow());
    expect(find.text('RC'), findsOneWidget);
    expect(find.text('Rav Cohen'), findsOneWidget);
    expect(find.text('Tutor'), findsOneWidget);
    expect(find.textContaining('4:10'), findsOneWidget);
    expect(find.text('Changed the deadline to Nov 3'), findsOneWidget);
  });

  testWidgets('the bell shows only when the row notified the parent '
      '(AC-5)', (tester) async {
    await _pump(tester, governedHistoryRow());
    expect(find.byKey(const ValueKey('changeHistoryBell')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Parent notified')), findsOneWidget);

    await _pump(tester, governedHistoryRow(notifiesParent: false));
    expect(find.byKey(const ValueKey('changeHistoryBell')), findsNothing);
  });

  testWidgets('an action with further parts says how many (AC-2)', (
    tester,
  ) async {
    await _pump(
      tester,
      governedHistoryRow(
        others: [
          GovernedPart(
            entity: GovernedEntity.subTrack,
            change: GovernedChangeKind.removed,
            fields: const ['ended_at'],
          ),
          GovernedPart(
            entity: GovernedEntity.subTrack,
            change: GovernedChangeKind.removed,
            fields: const ['ended_at'],
          ),
        ],
      ),
    );
    expect(find.text('+2 more changes in this action'), findsOneWidget);
  });

  testWidgets('Undo shows only when supplied and the row allows it', (
    tester,
  ) async {
    var undone = 0;
    await _pump(tester, governedHistoryRow(), onUndo: () => undone++);
    await tester.tap(find.text('Undo'));
    expect(undone, 1);
    expect(
      tester.getSize(find.widgetWithText(TextButton, 'Undo')).height,
      greaterThanOrEqualTo(48),
    );

    await _pump(tester, governedHistoryRow());
    expect(find.text('Undo'), findsNothing, reason: 'Story 4.6 not wired');

    await _pump(tester, governedHistoryRow(isRevert: true), onUndo: () {});
    expect(find.text('Undo'), findsNothing, reason: 'an undo is final');
  });

  testWidgets('an undone action carries the Undone tag and no Undo (AC-4)', (
    tester,
  ) async {
    await _pump(
      tester,
      governedHistoryRow(undoneBy: historyRowParentStamp),
      onUndo: () {},
    );
    expect(find.text('Undone'), findsOneWidget);
    expect(find.text('Undo'), findsNothing);
  });

  testWidgets('a lock-ignored record is labelled and offers no Undo (AC-6)', (
    tester,
  ) async {
    await _pump(tester, learningHistoryRow(lockIgnored: true), onUndo: () {});
    expect(
      find.text('kept, not counted — recorded during Shabbos/Yom Tov'),
      findsOneWidget,
    );
    expect(find.text('Undo'), findsNothing);
  });

  testWidgets('a voided record says who removed it (E-3)', (tester) async {
    await _pump(
      tester,
      learningHistoryRow(voidedBy: historyRowParentStamp, voidedCount: 1),
    );
    expect(find.textContaining('Removed by Abba'), findsOneWidget);
  });

  testWidgets('tapping the row opens its details', (tester) async {
    var taps = 0;
    await _pump(tester, governedHistoryRow(), onTap: () => taps++);
    await tester.tap(find.byType(ChangeHistoryRowTile));
    expect(taps, 1);
  });
}

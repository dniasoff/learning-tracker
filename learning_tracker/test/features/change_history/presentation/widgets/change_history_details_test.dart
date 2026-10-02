/// DNI-513 AC-10: the details of one Change history row (tablet pane and
/// phone sheet) — who, when, the bell, every part of the action, and its
/// undo, void and lock state; Undo only when supplied and allowed.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/features/change_history/domain/models/change_history_row.dart';
import 'package:learning_tracker/features/change_history/presentation/widgets/change_history_details.dart';

import '../../../../helpers/change_history_rows.dart';

Future<void> _pump(
  WidgetTester tester,
  ChangeHistoryRow row, {
  VoidCallback? onUndo,
}) async {
  await tester.pumpWidget(
    historyRowApp(ChangeHistoryDetails(row: row, onUndo: onUndo)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('who, when, the bell and every part of the action', (
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
            subjectName: 'Rebbe track',
          ),
        ],
      ),
    );
    expect(find.text('Change details'), findsOneWidget);
    expect(find.text('CHANGED BY'), findsOneWidget);
    expect(find.text('Rav Cohen (Tutor)'), findsOneWidget);
    expect(find.text('WHEN'), findsOneWidget);
    expect(find.textContaining('Sun, Nov 1'), findsOneWidget);
    expect(find.text('Parent notified'), findsOneWidget);
    expect(find.text('WHAT CHANGED'), findsOneWidget);
    // The headline and the primary part.
    expect(find.text('Changed the deadline to Nov 3'), findsNWidgets(2));
    expect(find.text('Removed Rebbe track'), findsOneWidget);
  });

  testWidgets('an undone action says who undid it and when (AC-4)', (
    tester,
  ) async {
    await _pump(
      tester,
      governedHistoryRow(undoneBy: historyRowParentStamp),
      onUndo: () {},
    );
    expect(find.textContaining('Undone by Abba · Mon, Nov 2'), findsOneWidget);
    expect(find.text('Undo'), findsNothing);
  });

  testWidgets('learning shows its date state, removal and lock state', (
    tester,
  ) async {
    await _pump(
      tester,
      learningHistoryRow(
        learnedOn: '2026-10-30',
        lockIgnored: true,
        voidedBy: historyRowParentStamp,
        voidedCount: 1,
      ),
    );
    expect(find.text('Learned Berakhot 1:1 · Main track'), findsNWidgets(2));
    expect(find.text('Oct 30'), findsOneWidget);
    expect(find.textContaining('Removed by Abba'), findsOneWidget);
    expect(
      find.text('kept, not counted — recorded during Shabbos/Yom Tov'),
      findsOneWidget,
    );
    expect(find.text('Parent notified'), findsNothing);
  });

  testWidgets('Undo shows only when supplied and the row allows it', (
    tester,
  ) async {
    var undone = 0;
    await _pump(tester, governedHistoryRow(), onUndo: () => undone++);
    await tester.tap(find.text('Undo'));
    expect(undone, 1);

    await _pump(tester, governedHistoryRow());
    expect(find.text('Undo'), findsNothing);
  });
}

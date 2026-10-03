/// DNI-513 AC-10 (UX-DR-160/162/163/164): at ≥ 840dp the timeline and the
/// selected change's details sit side by side, selection updates the
/// details in place and focus order is list then details; below the
/// breakpoint a single pane opens details in a sheet.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/features/change_history/presentation/widgets/change_history_details.dart';
import 'package:learning_tracker/features/change_history/presentation/widgets/change_history_row_tile.dart';

import '../../../helpers/change_history_fixtures.dart';
import '../../../helpers/fake_history_ports.dart';
import 'change_history_harness.dart';

FakeHistoryPorts _repo() => FakeHistoryPorts(
  entries: [
    historyEntry(
      1,
      minutes: 60,
      actor: historyTutor,
      entity: GovernedEntity.mainTrackOrder,
    ),
    historyEntry(2, minutes: 30, entity: GovernedEntity.mainTrackStudyDays),
  ],
);

final _pane = find.byKey(const ValueKey('changeHistoryDetailPane'));

NumericFocusOrder? _orderAbove(WidgetTester tester, Finder finder) {
  final order = find.ancestor(
    of: finder,
    matching: find.byType(FocusTraversalOrder),
  );
  final widget = tester.widget<FocusTraversalOrder>(order.first);
  return widget.order as NumericFocusOrder?;
}

void main() {
  testWidgets('at 840dp the list and the details sit side by side; a tap '
      'updates the details in place', (tester) async {
    await pumpChangeHistory(
      tester,
      changeHistoryOverrides(repository: _repo()),
      size: const Size(840, 900),
    );
    expect(_pane, findsOneWidget);
    expect(find.text('Select a change to see its details.'), findsOneWidget);

    await tester.tap(find.text('Changed the learning order'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    final details = find.descendant(
      of: _pane,
      matching: find.byType(ChangeHistoryDetails),
    );
    expect(details, findsOneWidget);
    expect(
      find.descendant(of: details, matching: find.text('Rav Cohen (Tutor)')),
      findsOneWidget,
    );
    final selected = tester.widget<ChangeHistoryRowTile>(
      find.byKey(ValueKey('action:${historyId(1)}')),
    );
    expect(selected.selected, isTrue);

    await tester.tap(find.text('Changed the study days').first);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: details, matching: find.text('Abba (Parent)')),
      findsOneWidget,
    );

    // The list is side by side with, and before, the details.
    final listBox = tester.getRect(
      find.byKey(const ValueKey('changeHistoryTimeline')),
    );
    final paneBox = tester.getRect(_pane);
    expect(listBox.right, lessThanOrEqualTo(paneBox.left));
    expect(
      _orderAbove(
        tester,
        find.byKey(const ValueKey('changeHistoryTimeline')),
      )?.order,
      1,
    );
    expect(_orderAbove(tester, _pane)?.order, 2);
  });

  testWidgets('below 840dp one pane; a tap opens the details in a sheet', (
    tester,
  ) async {
    await pumpChangeHistory(
      tester,
      changeHistoryOverrides(repository: _repo()),
      size: const Size(839, 900),
    );
    expect(_pane, findsNothing);
    await tester.tap(find.text('Changed the learning order'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Change details'), findsOneWidget);
  });
}

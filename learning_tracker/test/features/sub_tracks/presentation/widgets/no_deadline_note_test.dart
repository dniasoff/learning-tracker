import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/no_deadline_note.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  testWidgets('explains the no-deadline limit and links to goal setup', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      pumpApp(
        child: Scaffold(body: NoDeadlineNote(onOpenGoalSetup: () => opened++)),
      ),
    );
    expect(
      find.text(
        "Without a deadline, a sub-track can't lower the daily target.",
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Set a deadline'));
    expect(opened, 1);
    expect(
      tester.getSize(find.byType(TextButton)).height,
      greaterThanOrEqualTo(48),
    );
  });
}

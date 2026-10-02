// DNI-496 (Story 2.5): the Add sub-track type chooser (screens.md #04).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/add_sub_track_chooser.dart';

import '../../../../helpers/pump_app.dart';

Future<AddSubTrackChoice?> _choose(
  WidgetTester tester, {
  bool schoolYearAvailable = false,
  String? tap,
}) async {
  AddSubTrackChoice? choice;
  await tester.pumpWidget(
    pumpApp(
      child: Builder(
        builder: (context) => TextButton(
          onPressed: () async => choice = await showAddSubTrackChooser(
            context,
            schoolYearAvailable: schoolYearAvailable,
          ),
          child: const Text('add'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('add'));
  await tester.pumpAndSettle();
  if (tap != null) {
    await tester.tap(find.text(tap));
    await tester.pumpAndSettle();
  }
  return choice;
}

void main() {
  testWidgets('offers Ongoing and resolves to it', (tester) async {
    expect(await _choose(tester, tap: 'Ongoing'), AddSubTrackChoice.ongoing);
  });

  testWidgets('School year appears only when its form is available', (
    tester,
  ) async {
    await _choose(tester);
    expect(find.text('School year'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    expect(
      await _choose(tester, schoolYearAvailable: true, tap: 'School year'),
      AddSubTrackChoice.schoolYear,
    );
  });
}

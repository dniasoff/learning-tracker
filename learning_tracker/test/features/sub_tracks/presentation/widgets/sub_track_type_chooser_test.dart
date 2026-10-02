import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_type_chooser.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  testWidgets('School year runs; Ongoing without a form stays disabled', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var schoolYear = 0;
    await tester.pumpWidget(
      pumpApp(
        child: Scaffold(
          body: SubTrackTypeChooser(onSchoolYear: () => schoolYear++),
        ),
      ),
    );
    await tester.tap(find.text('School year'));
    expect(schoolYear, 1);
    final ongoing = find.ancestor(
      of: find.text('Ongoing'),
      matching: find.byType(ListTile),
    );
    expect(tester.widget<ListTile>(ongoing).enabled, isFalse);
    expect(
      tester.getSemantics(ongoing).getSemanticsData().flagsCollection.isEnabled,
      Tristate.isFalse,
    );
    semantics.dispose();
  });

  testWidgets('show() closes the sheet before opening the chosen form', (
    tester,
  ) async {
    var ongoing = 0;
    await tester.pumpWidget(
      pumpApp(
        child: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => SubTrackTypeChooser.show(
                context,
                onSchoolYear: () {},
                onOngoing: () => ongoing++,
              ),
              child: const Text('add'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('add'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ongoing'));
    await tester.pumpAndSettle();
    expect(ongoing, 1);
    expect(find.byType(SubTrackTypeChooser), findsNothing);
  });
}

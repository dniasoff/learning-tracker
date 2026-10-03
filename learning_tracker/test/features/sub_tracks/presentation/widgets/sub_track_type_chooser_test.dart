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

  // DNI-496 (Story 2.5) AC-5: the five-ongoing limit state (UX-DR-36,
  // UX-DR-103, UX-DR-158).
  var ongoingOpened = 0;
  Future<void> openWith(WidgetTester tester, int inUse) async {
    ongoingOpened = 0;
    await tester.pumpWidget(
      pumpApp(
        child: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => SubTrackTypeChooser.show(
                context,
                onSchoolYear: () {},
                onOngoing: () => ongoingOpened++,
                ongoingInUse: inUse,
              ),
              child: const Text('add'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('add'));
    await tester.pumpAndSettle();
  }

  Finder ongoingTile() =>
      find.ancestor(of: find.text('Ongoing'), matching: find.byType(ListTile));

  for (final n in [0, 4]) {
    testWidgets('$n in use: Ongoing is enabled with the usage line', (
      tester,
    ) async {
      await openWith(tester, n);
      expect(
        find.text('You can have up to 5 ongoing sub-tracks. $n in use.'),
        findsOneWidget,
      );
      expect(tester.widget<ListTile>(ongoingTile()).enabled, isTrue);
    });
  }

  testWidgets('5 in use: Ongoing stays visible, disabled and announced', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await openWith(tester, 5);
    await tester.tap(find.text('Ongoing'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(ongoingOpened, 0, reason: 'a disabled Ongoing cannot be chosen');
    expect(find.byType(SubTrackTypeChooser), findsOneWidget);
    expect(
      find.text('You can have up to 5 ongoing sub-tracks. 5 in use.'),
      findsOneWidget,
    );
    final tile = ongoingTile();
    expect(tester.widget<ListTile>(tile).enabled, isFalse);
    final opacity = tester.widget<Opacity>(
      find.ancestor(of: tile, matching: find.byType(Opacity)).first,
    );
    expect(opacity.opacity, 0.4);
    expect(tester.getSize(tile).height, greaterThanOrEqualTo(48));
    expect(
      tester.getSemantics(tile).getSemanticsData().flagsCollection.isEnabled,
      Tristate.isFalse,
    );
    // School year stays available at the ongoing cap.
    expect(
      tester
          .widget<ListTile>(
            find.ancestor(
              of: find.text('School year'),
              matching: find.byType(ListTile),
            ),
          )
          .enabled,
      isTrue,
    );
    semantics.dispose();
  });

  testWidgets('no count given: no usage line', (tester) async {
    await tester.pumpWidget(
      pumpApp(
        child: Scaffold(
          body: SubTrackTypeChooser(onSchoolYear: () {}, onOngoing: () {}),
        ),
      ),
    );
    expect(find.textContaining('ongoing sub-tracks'), findsNothing);
    expect(tester.widget<ListTile>(ongoingTile()).enabled, isTrue);
  });
}

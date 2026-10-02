// DNI-496 (Story 2.5): the Add sub-track type chooser (screens.md #04) and
// its five-track limit state (AC-5, UX-DR-36, UX-DR-103, UX-DR-158).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/add_sub_track_chooser.dart';

import '../../../../helpers/pump_app.dart';

Future<AddSubTrackChoice?> _choose(
  WidgetTester tester, {
  int inUse = 0,
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
            ongoingInUse: inUse,
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

  for (final n in [0, 4]) {
    testWidgets('$n in use: Ongoing is enabled with the usage line', (
      tester,
    ) async {
      await _choose(tester, inUse: n);
      expect(
        find.text('You can have up to 5 ongoing sub-tracks. $n in use.'),
        findsOneWidget,
      );
      final tile = tester.widget<ListTile>(
        find.byKey(const ValueKey('addSubTrackOngoing')),
      );
      expect(tile.enabled, isTrue);
    });
  }

  testWidgets('5 in use: Ongoing stays visible, disabled and announced', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final choice = await _choose(tester, inUse: 5, tap: 'Ongoing');
    expect(choice, isNull, reason: 'a disabled Ongoing cannot be chosen');
    final ongoing = find.byKey(const ValueKey('addSubTrackOngoing'));
    expect(ongoing, findsOneWidget);
    expect(
      find.text('You can have up to 5 ongoing sub-tracks. 5 in use.'),
      findsOneWidget,
    );
    final opacity = tester.widget<Opacity>(
      find.ancestor(of: ongoing, matching: find.byType(Opacity)).first,
    );
    expect(opacity.opacity, 0.4);
    expect(tester.getSize(ongoing).height, greaterThanOrEqualTo(48));
    expect(
      tester.getSemantics(ongoing),
      isSemantics(hasEnabledState: true, isEnabled: false),
    );
    handle.dispose();
  });
}

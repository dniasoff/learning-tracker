// Mirror test for `lib/features/sub_tracks/presentation/widgets/
// add_next_year_action.dart` (Story 2.8 / DNI-499, AC-1, AC-2; UX-DR-28,
// UX-DR-36, UX-DR-158): the outlined pill, and its disabled-but-visible
// state with the reason.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_lifecycle.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/add_next_year_action.dart';

import '../../../../helpers/pump_app.dart';

final _pill = find.byKey(const ValueKey('subTrackAddNextYear'));

Future<List<int>> _pump(
  WidgetTester tester,
  NextYearAvailability availability,
) async {
  final taps = <int>[];
  await tester.pumpWidget(
    pumpApp(
      child: Scaffold(
        body: AddNextYearAction(
          nextAcademicYear: 2027,
          availability: availability,
          onPressed: () => taps.add(1),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return taps;
}

void main() {
  testWidgets('available: "Add next year (2027–28)" opens the form', (
    tester,
  ) async {
    final taps = await _pump(tester, NextYearAvailability.available);
    expect(find.text('Add next year (2027–28)'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(_pill).onPressed, isNotNull);
    await tester.tap(_pill);
    expect(taps, [1]);
    expect(tester.getSize(_pill).height, greaterThanOrEqualTo(48));
  });

  for (final (availability, reason) in [
    (
      NextYearAvailability.yearUsed,
      '2027–28 already has a school-year sub-track',
    ),
    (
      NextYearAvailability.beyondPickerRange,
      '2027–28 is past the years you can plan',
    ),
  ]) {
    testWidgets('${availability.name}: visible, full size, announced '
        'disabled with the reason, inert', (tester) async {
      final taps = await _pump(tester, availability);
      expect(_pill, findsOneWidget);
      expect(tester.widget<OutlinedButton>(_pill).onPressed, isNull);
      expect(
        tester.getSemantics(_pill),
        isSemantics(isButton: true, hasEnabledState: true, isEnabled: false),
      );
      expect(find.text(reason), findsOneWidget);
      expect(tester.getSize(_pill).height, greaterThanOrEqualTo(48));
      await tester.tap(_pill, warnIfMissed: false);
      expect(taps, isEmpty);
    });
  }
}

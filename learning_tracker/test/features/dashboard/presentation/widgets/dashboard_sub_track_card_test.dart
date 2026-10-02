// Story 2.9 (DNI-500) — the Dashboard summary card in isolation.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/widgets/animated_progress_bar.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/dashboard_sub_track_card.dart';
import 'package:learning_tracker/features/sub_tracks/sub_tracks.dart';

import '../../../../helpers/pump_app.dart';
import '../../../../helpers/sub_tracks/sub_track_home_fixtures.dart';

Future<int> _pump(WidgetTester tester, SubTrackHomeItem item) async {
  var opened = 0;
  await tester.pumpWidget(
    pumpApp(
      overrides: positionLabelOverrides(),
      child: Scaffold(
        body: DashboardSubTrackCard(item: item, onOpen: () => opened++),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(item.name));
  return opened;
}

double _value(WidgetTester tester) =>
    tester.widget<AnimatedProgressBar>(find.byType(AnimatedProgressBar)).value;

void main() {
  testWidgets('active: Next, ticked and the projected fill; tap opens', (
    tester,
  ) async {
    final opened = await _pump(
      tester,
      const SubTrackHomeItem(
        subTrackId: schoolId,
        curriculumId: mishnayos,
        name: 'School',
        kind: SubTrackRowKind.active,
        position: berachos14,
        ticked: 1,
        remaining: 3,
      ),
    );
    expect(find.text('Next: Berachos 1:4'), findsOneWidget);
    expect(find.text('1 ticked'), findsOneWidget);
    expect(_value(tester), 0.25);
    expect(opened, 1);
  });

  testWidgets('groundless: zero ticked and zero remaining is an empty bar', (
    tester,
  ) async {
    await _pump(
      tester,
      const SubTrackHomeItem(
        subTrackId: schoolId,
        curriculumId: mishnayos,
        name: 'School',
        kind: SubTrackRowKind.groundless,
      ),
    );
    expect(find.text('No ground yet'), findsOneWidget);
    expect(find.text('0 ticked'), findsOneWidget);
    expect(_value(tester), 0);
  });

  testWidgets('all recorded: full bar', (tester) async {
    await _pump(
      tester,
      const SubTrackHomeItem(
        subTrackId: schoolId,
        curriculumId: mishnayos,
        name: 'School',
        kind: SubTrackRowKind.allRecorded,
        ticked: 12,
      ),
    );
    expect(find.text('All ground recorded'), findsOneWidget);
    expect(_value(tester), 1);
  });
}

// Story 2.10 (DNI-501) T2: the Learn-tab sub-track row (DNI-500 seam).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sub_tracks/domain/services/on_home_sub_tracks.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_row.dart';

import '../../../../helpers/pump_app.dart';
import '../../helpers/up_to_fixtures.dart';

Future<void> _pump(
  WidgetTester tester, {
  required List<String> path,
  String? position,
  bool exhausted = false,
  VoidCallback? onPlusOne,
  Future<void> Function()? onUpTo,
}) async {
  await tester.pumpWidget(
    pumpApp(
      overrides: upToLabelOverrides(),
      child: Scaffold(
        body: SubTrackRow(
          item: OnHomeSubTrack(
            track: fixtureSubTrack(schoolId, 'School'),
            state: fixtureSubTrackState(
              schoolId,
              path: path,
              exhausted: exhausted,
            ),
          ),
          position: position,
          onUpTo: onUpTo,
          onPlusOne: onPlusOne,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('name, Next: position, exactly Up to… and +1 at 48dp', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var plus = 0;
    await _pump(
      tester,
      path: const ['Mishnah Berakhot 1:4'],
      position: 'Mishnah Berakhot 1:4',
      onPlusOne: () => plus++,
      onUpTo: () async {},
    );
    expect(find.text('School'), findsOneWidget);
    expect(find.text('Next: Berakhot 1:4'), findsOneWidget);
    expect(find.text('Up to…'), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
    expect(find.bySemanticsLabel('School, next Berakhot 1:4'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Record one mishna for School'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Record up to, School'), findsOneWidget);
    for (final key in [
      Key('subTrackUpTo-$schoolId'),
      Key('subTrackPlusOne-$schoolId'),
    ]) {
      expect(tester.getSize(find.byKey(key)).height, greaterThanOrEqualTo(48));
    }
    await tester.tap(find.text('+1'));
    expect(plus, 1);
    handle.dispose();
  });

  testWidgets('all ground recorded: +1 disabled, Up to… still opens the '
      'exhaustion message', (tester) async {
    var opened = false;
    await _pump(
      tester,
      path: const [],
      exhausted: true,
      onPlusOne: () {},
      onUpTo: () async => opened = true,
    );
    expect(find.text('All ground recorded'), findsOneWidget);
    final plus = tester.widget<FilledButton>(
      find.byKey(Key('subTrackPlusOne-$schoolId')),
    );
    expect(plus.onPressed, isNull);
    await tester.tap(find.byKey(Key('subTrackUpTo-$schoolId')));
    expect(opened, isTrue);
  });

  testWidgets('no ground: both actions disabled at 40%', (tester) async {
    await _pump(tester, path: const [], onPlusOne: () {}, onUpTo: () async {});
    expect(find.text('No ground yet'), findsOneWidget);
    final opacities = tester
        .widgetList<Opacity>(find.byType(Opacity))
        .map((o) => o.opacity);
    expect(opacities, everyElement(0.4));
  });
}

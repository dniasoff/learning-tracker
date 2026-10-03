// Story 2.7 (DNI-498) AC-7: on a calendar-program curriculum the picker is
// unavailable from every entry point, a direct route / deep link included.
// A real AppRouter, its other guards letting everything through.
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../../helpers/pump_app.dart';
import '../../../../helpers/sub_tracks/ground_picker_harness.dart';

Future<GroundPickerWorld> _deepLink(
  WidgetTester tester, {
  required bool calendar,
}) async {
  final world = GroundPickerWorld(
    corpus: mishnayosCorpus(),
    calendarProgram: calendar,
    commands: FakeLearningCommands(),
    tracks: [fixtureTrack(schoolId, 'School', curriculumId: engineCurriculum)],
  );
  addTearDown(world.dispose);
  tester.view.physicalSize = phoneSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = groundPickerTestRouter(isParent: () => world.parent);
  await tester.pumpWidget(
    pumpApp(
      overrides: world.overrides,
      routerConfig: router.config(
        deepLinkBuilder: (_) => const DeepLink.path(
          '/sub-tracks/$schoolId/ground',
          // Only the picker: the shell under it is not what is tested.
          includePrefixMatches: false,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return world;
}

void main() {
  testWidgets('a deep link on a calendar-program curriculum shows no '
      'editable picker', (tester) async {
    final world = await _deepLink(tester, calendar: true);
    expect(find.text("Ground can't be added here."), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(world.subTracks.calls, isEmpty);
  });

  testWidgets('the same deep link on a non-calendar curriculum opens the '
      'picker', (tester) async {
    await _deepLink(tester, calendar: false);
    expect(find.text('Add ground to School'), findsOneWidget);
    expect(find.byType(Checkbox), findsWidgets);
  });
}

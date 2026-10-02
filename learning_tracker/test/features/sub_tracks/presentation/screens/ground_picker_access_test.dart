// Story 2.7 (DNI-498) AC-8: a child session (no parent PIN) cannot reach
// the picker: the route's parent-session guard refuses a direct route or
// deep link before anything loads, and even a picker built anyway shows no
// editable ground control (hidden controls are not the authorization;
// `editSubTrack` also refuses a child actor, see
// edit_sub_track_ground_test.dart). The entry points' absence for a child
// is in add_ground_entry_test.dart.
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/ground_picker_pane.dart';

import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../../helpers/pump_app.dart';
import '../../../../helpers/sub_tracks/ground_picker_harness.dart';

GroundPickerWorld _world({required bool parent}) => GroundPickerWorld(
  corpus: mishnayosCorpus(),
  parent: parent,
  commands: FakeLearningCommands(),
  tracks: [fixtureTrack(schoolId, 'School', curriculumId: engineCurriculum)],
);

Future<void> _deepLink(WidgetTester tester, GroundPickerWorld world) async {
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
}

void main() {
  testWidgets('a child deep link is refused by the route guard', (
    tester,
  ) async {
    final world = _world(parent: false);
    await _deepLink(tester, world);
    expect(find.byType(GroundPickerPane), findsNothing);
    expect(find.text('Add ground to School'), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(world.corpusReads, 0);
  });

  testWidgets('a parent deep link reaches the picker', (tester) async {
    await _deepLink(tester, _world(parent: true));
    expect(find.text('Add ground to School'), findsOneWidget);
  });

  testWidgets('a picker built for a child anyway has no editable control', (
    tester,
  ) async {
    final world = _world(parent: false);
    addTearDown(world.dispose);
    await tester.pumpWidget(
      pumpApp(
        overrides: world.overrides,
        child: Scaffold(
          body: GroundPickerPane(subTrackId: schoolId, onClose: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("Ground can't be added here."), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
  });
}

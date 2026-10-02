// Mirror test for
// `lib/features/sub_tracks/presentation/screens/ground_picker_screen.dart`
// (Story 2.7 / DNI-498 AC-2): the phone route shows the full picker for its
// sub-track and closing it pops the route. The picker body's composition,
// generic levels and retry are in widgets/ground_picker_pane_test.dart.
import 'package:auto_route/auto_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/screens/ground_picker_screen.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../../helpers/pump_app.dart';
import '../../../../helpers/sub_tracks/ground_picker_harness.dart';

class _MockStackRouter extends Mock implements StackRouter {}

void main() {
  testWidgets('the route shows the picker; Close pops it', (tester) async {
    final world = GroundPickerWorld(
      corpus: mishnayosCorpus(),
      commands: FakeLearningCommands(),
      tracks: [
        fixtureTrack(schoolId, 'School', curriculumId: engineCurriculum),
      ],
    );
    addTearDown(world.dispose);
    tester.view.physicalSize = phoneSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = _MockStackRouter();
    when(() => router.maybePop<Object?>()).thenAnswer((_) async => true);
    await tester.pumpWidget(
      pumpApp(
        overrides: world.overrides,
        child: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: const GroundPickerScreen(subTrackId: schoolId),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Add ground to School'), findsOneWidget);
    expect(find.text('Add to School'), findsOneWidget);
    expect(
      find.text("They'll leave the home schedule while School holds them."),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    verify(() => router.maybePop<Object?>()).called(1);
  });
}

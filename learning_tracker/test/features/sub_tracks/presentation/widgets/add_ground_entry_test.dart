// Mirror test for
// `lib/features/sub_tracks/presentation/widgets/add_ground_entry.dart`
// (Story 2.7 / DNI-498 AC-1, AC-7, AC-8, AC-9): *+ Add ground* on a
// sub-track detail — groundless and populated — opens the picker (a pushed
// route on a phone, a right pane on a tablet), is absent for a child and on
// a calendar-program curriculum, and focus returns to it on close.
//
// Story 2.6's detail screen (DNI-497) is not on the integration branch
// yet, so a minimal detail stands in for it here: the entry point under
// test is the widget that screen hosts.
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/ground_assignment_rollbacks_provider.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/add_ground_entry.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../../helpers/pump_app.dart';
import '../../../../helpers/sub_tracks/ground_picker_harness.dart';

class _MockStackRouter extends Mock implements StackRouter {}

/// A stand-in sub-track detail (DNI-497 owns the real one).
class _Detail extends StatelessWidget {
  const _Detail({required this.ground});

  final List<NodeEntry> ground;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Text('School detail'),
      if (ground.isEmpty) const Text('No ground yet'),
      for (final node in ground) Text(node.ref),
      const AddGroundButton(
        subTrackId: schoolId,
        curriculumId: engineCurriculum,
      ),
    ],
  );
}

GroundPickerWorld _world({
  bool parent = true,
  bool calendar = false,
  List<NodeEntry> ground = const [],
  FakeLearningCommands? commands,
}) => GroundPickerWorld(
  corpus: mishnayosCorpus(),
  parent: parent,
  calendarProgram: calendar,
  commands: commands ?? FakeLearningCommands(),
  tracks: [
    fixtureTrack(
      schoolId,
      'School',
      curriculumId: engineCurriculum,
      ground: ground,
    ),
  ],
);

Future<_MockStackRouter> _pump(
  WidgetTester tester,
  GroundPickerWorld world, {
  Size size = phoneSize,
  bool split = false,
  List<NodeEntry> ground = const [],
}) async {
  addTearDown(world.dispose);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = _MockStackRouter();
  when(() => router.push<Object?>(any())).thenAnswer((_) async => null);
  final detail = _Detail(ground: ground);
  await tester.pumpWidget(
    pumpApp(
      overrides: world.overrides,
      child: StackRouterScope(
        controller: router,
        stateHash: 0,
        child: Scaffold(
          body: split ? GroundPickerSplitView(detail: detail) : detail,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

String? _focused() => FocusManager.instance.primaryFocus?.debugLabel;

void main() {
  setUpAll(() => registerFallbackValue(GroundPickerRoute(subTrackId: '')));

  group('AC-1 Add ground on the detail', () {
    for (final (label, ground) in [
      ('groundless', const <NodeEntry>[]),
      ('populated', const [berakhot1]),
    ]) {
      testWidgets('$label: shown, and it opens the picker for that '
          'sub-track; focus returns on close', (tester) async {
        final router = await _pump(
          tester,
          _world(ground: ground),
          ground: ground,
        );
        expect(find.text('Add ground'), findsOneWidget);
        await tester.tap(find.text('Add ground'));
        await tester.pumpAndSettle();
        final pushed =
            verify(() => router.push<Object?>(captureAny())).captured.single
                as GroundPickerRoute;
        expect(pushed.args!.subTrackId, schoolId);
        expect(_focused(), 'addGround');
      });
    }
  });

  group('AC-7 / AC-8 fail closed', () {
    testWidgets('a child session sees no Add ground', (tester) async {
      await _pump(tester, _world(parent: false));
      expect(find.text('School detail'), findsOneWidget);
      expect(find.text('Add ground'), findsNothing);
    });

    testWidgets('a calendar-program curriculum has no Add ground', (
      tester,
    ) async {
      await _pump(tester, _world(calendar: true));
      expect(find.text('Add ground'), findsNothing);
    });
  });

  group('AC-9 tablet split', () {
    testWidgets('at ≥ 840dp the picker opens as a right pane beside the '
        'detail; focus goes to its title and back on close', (tester) async {
      final router = await _pump(
        tester,
        _world(),
        size: tabletSize,
        split: true,
      );
      await tester.tap(find.text('Add ground'));
      await tester.pumpAndSettle();
      verifyNever(() => router.push<Object?>(any()));
      final title = find.text('Add ground to School');
      expect(title, findsOneWidget);
      expect(find.text('School detail'), findsOneWidget);
      expect(
        tester.getTopLeft(title).dx,
        greaterThan(tester.getTopRight(find.text('School detail')).dx),
      );
      expect(_focused(), 'groundPickerTitle');
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(title, findsNothing);
      expect(_focused(), 'addGround');
    });

    testWidgets('Escape closes the pane and returns focus', (tester) async {
      await _pump(tester, _world(), size: tabletSize, split: true);
      await tester.tap(find.text('Add ground'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Add ground to School'), findsNothing);
      expect(_focused(), 'addGround');
    });

    testWidgets('below 840dp the split host still pushes the phone route', (
      tester,
    ) async {
      final router = await _pump(tester, _world(), split: true);
      await tester.tap(find.text('Add ground'));
      await tester.pumpAndSettle();
      verify(() => router.push<Object?>(any())).called(1);
      expect(find.text('Add ground to School'), findsNothing);
    });
  });

  group('AC-4 late rollback (UX-DR-127)', () {
    testWidgets('after the picker closed on a queued assignment, a server '
        'refusal is announced once by Add ground', (tester) async {
      final commands = FakeLearningCommands();
      addTearDown(commands.dispose);
      await _pump(tester, _world(commands: commands));
      final container = ProviderScope.containerOf(
        tester.element(find.text('Add ground')),
      );
      container
          .read(groundAssignmentRollbacksProvider.notifier)
          .trackQueued(
            commands,
            schoolId,
            const CaptureSuccess(
              changeIds: ['change-1'],
              actionId: 'change-1',
              queued: true,
            ),
          );
      commands.pendingFailures.add([
        const PendingFailure(
          id: 'change-1',
          eventIds: [],
          changeIds: ['change-1'],
          reason: PendingFailureReason.permissionDenied,
        ),
      ]);
      await tester.pumpAndSettle();
      expect(
        find.text("Couldn't add the ground. Nothing was changed."),
        findsOneWidget,
      );
      expect(container.read(groundAssignmentRollbacksProvider), isEmpty);
    });
  });
}

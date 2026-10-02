// Story 2.10 (DNI-501) AC-10 / AC-11 integration: Mishna history's Change
// source offers the Browse list (Home, each onHome sub-track by name,
// Before tracking), and the replacement follows the Story 1.7 `replace`
// rules.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/labels/curriculum_label_providers.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/presentation/screens/mishna_history_screen.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_windows_provider.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_capture_providers.dart';

import '../../helpers/learner_state/engine_fixtures.dart';
import '../../helpers/learner_state/fake_learner_state.dart';
import '../../helpers/learner_state/fake_learning_commands.dart';
import '../../helpers/learner_state/mishna_history_fixtures.dart';
import '../../helpers/pump_app.dart';
import 'helpers/capture_harness.dart';
import 'helpers/up_to_fixtures.dart';

const _screen = MishnaHistoryScreen(
  curriculumId: historyCurriculum,
  leafRef: historyLeaf,
);

/// A live School sub-track of the history curriculum.
final SubTrack _school = fixtureSubTrack(schoolId, 'School');

Finder _row(int n) => find.byKey(ValueKey('mishnaHistoryRow-${eid(n)}'));

Finder _action(String name) => find.byKey(Key('mishnaHistoryAction-$name'));

Future<void> _pump(
  WidgetTester tester,
  HistoryPorts ports,
  FakeLearningCommands commands, {
  bool tutorSession = false,
}) async {
  ports.events.seed(ports.scope, [
    historyLearn(1, day: 3),
    historyLearn(2, day: 4, dateState: DateState.beforeTracking),
  ]);
  ports.tracks.seed(ports.scope, [_school]);
  final state = fakeLearnerState(
    curricula: {
      historyCurriculum: FakeCurriculumState(
        curriculumId: historyCurriculum,
        learntLeaves: const {historyLeaf},
        subTracks: {
          schoolId: fixtureSubTrackState(schoolId, path: const [historyLeaf]),
        },
      ),
    },
    countedEventIds: {eid(1), eid(2)},
  );
  await tester.pumpWidget(
    pumpApp(
      theme: AppTheme.themeFor(brightness: Brightness.light),
      overrides: <Override>[
        currentSacredWindowProvider.overrideWithValue(null),
        renderedDisplayForRefProvider.overrideWith((ref, _) async => 'B'),
        ...historyOverrides(ports, state: state, commands: commands),
        if (tutorSession)
          subTrackWritesAllowedProvider.overrideWithValue(false),
      ],
      child: _screen,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openSource(WidgetTester tester, int n) async {
  await tester.tap(_row(n));
  await tester.pumpAndSettle();
  await tester.tap(_action('changeSource'));
  await tester.pumpAndSettle();
}

void main() {
  late HistoryPorts ports;
  setUp(() => ports = HistoryPorts());
  tearDown(() => ports.dispose());

  testWidgets('Change source lists Home, School and Before tracking, in that '
      'order, with the current source selected', (tester) async {
    await _pump(tester, ports, FakeLearningCommands());
    await _openSource(tester, 1);
    final home = find.byKey(const Key('mishnaHistorySource-home'));
    final school = find.byKey(Key('mishnaHistorySource-$schoolId'));
    final before = find.byKey(const Key('mishnaHistorySource-before'));
    expect(school, findsOneWidget);
    expect(tester.getTopLeft(home).dy, lessThan(tester.getTopLeft(school).dy));
    expect(
      tester.getTopLeft(school).dy,
      lessThan(tester.getTopLeft(before).dy),
    );
    expect(
      find.descendant(
        of: home,
        matching: find.byIcon(Icons.radio_button_checked),
      ),
      findsOneWidget,
    );
  });

  testWidgets('moving a Home event to School replaces it with the sub-track '
      'source', (tester) async {
    final commands = FakeLearningCommands();
    await _pump(tester, ports, commands);
    await _openSource(tester, 1);
    await tester.tap(find.byKey(Key('mishnaHistorySource-$schoolId')));
    await tester.pumpAndSettle();
    expect(commands.calls, [
      LearningCommandCall('replace', {
        'targetId': eid(1),
        'replacement': EventReplacement(source: schoolId),
      }),
    ]);
  });

  testWidgets('moving a Before-tracking event to School asks the day and '
      'dates it', (tester) async {
    final commands = FakeLearningCommands();
    await _pump(tester, ports, commands);
    await _openSource(tester, 2);
    await tester.tap(find.byKey(Key('mishnaHistorySource-$schoolId')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    final call = commands.calls.single;
    final replacement = call.args['replacement']! as EventReplacement;
    expect(replacement.source, schoolId);
    expect(replacement.dateState, DateState.dated);
    expect(replacement.learnedOn, isNotNull);
  });

  testWidgets('AC-11: a tutored session offers no sub-track source', (
    tester,
  ) async {
    await _pump(tester, ports, FakeLearningCommands(), tutorSession: true);
    await _openSource(tester, 1);
    expect(find.byKey(Key('mishnaHistorySource-$schoolId')), findsNothing);
    expect(find.byKey(const Key('mishnaHistorySource-home')), findsOneWidget);
    expect(find.byKey(const Key('mishnaHistorySource-before')), findsOneWidget);
  });

  test('the Story 1.7 replace: the original is voided and linked; the '
      'sub-track replacement keeps its instant, drops the stage and earns '
      'no pts_ entry', () async {
    final original = engineLearn(
      1,
      'Mishnah Berakhot 1:1',
      stage: 1,
      minutes: 600,
    );
    final rig = CaptureRig(
      now: engineAt(1200),
      subTracks: [_school],
      seed: [original],
    );
    addTearDown(rig.dispose);
    await rig.commands.replace(original.id, EventReplacement(source: schoolId));
    final voids = rig.written.where((e) => e.isVoid).toList();
    final learns = rig.written.where((e) => e.isLearn).toList();
    expect(voids.single.targetId, original.id);
    final next = learns.single;
    expect(next.source, schoolId);
    expect(next.stage, isNull);
    expect(next.ref, original.ref);
    expect(next.dateState, DateState.dated);
    expect(next.learnedOn, original.learnedOn);
    expect(effectiveAt(next), effectiveAt(original), reason: 'same instant');
    expect(rig.awards, isEmpty);
    // School's position moves; the leaf stays learnt.
    final state = rig.state.curricula[engineCurriculum]!;
    expect(state.subTracks[schoolId]!.position, 'Mishnah Berakhot 1:2');
    expect(state.learntLeaves, contains('Mishnah Berakhot 1:1'));
  });
}

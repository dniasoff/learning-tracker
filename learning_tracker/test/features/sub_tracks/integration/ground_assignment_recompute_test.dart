// Story 2.7 (DNI-498) AC-4 / AC-5 integration: the picker writes through
// the production LearningCommands facade and the real governed
// SubTrackCommands into the sub-track store; the learner state — the real
// LearnerStateEngine over that store and the bundled Mishnayos
// ContentIndex — recomputes on the same screen. The FR-19 fixture: School
// (school-year, 10/wk, groundless, all Berachos unlearnt) with a deadline;
// adding Berachos perakim 1–3 takes 19 leaves off the main track and leaves
// the daily target unchanged. A refused write rolls back with a snackbar;
// offline the append is refused as online-required, never queued.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/domain/commands/sub_track_commands.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/ground_picker_pane.dart';

import '../../../helpers/learner_state/bundled_corpus.dart';
import '../../../helpers/learner_state/c0_fixtures.dart';
import '../../../helpers/learner_state/engine_fixtures.dart';
import '../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../helpers/learner_state/in_memory_ports.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/sub_tracks/ground_picker_harness.dart';
import '../../../helpers/sub_tracks/latest_write_sub_track_repository.dart';

const _today = '2026-10-01';
final _now = DateTime.parse('${_today}T12:00:00Z');

SubTrack _school() => SubTrack(
  id: schoolId,
  curriculumId: engineCurriculum,
  name: 'School',
  type: SubTrackType.schoolYear,
  academicYear: 2026,
  windowStart: '2026-09-01',
  windowEnd: '2027-07-31',
  ratePerWeek: 10,
  weeksPerYear: 39,
  learnsOnShabbos: false,
  ground: const [],
  lastChangeId: engineUlid(700),
);

/// The engine over the live sub-track store: every store change yields a
/// recomputed state (the AD-35 reactive read, without a special case).
Stream<LearnerState> _engineOver(InMemorySubTrackRepository repo) => repo
    .watchAll(c0Scope())
    .where((r) => r is CompleteReadReady<SubTrack>)
    .map(
      (r) => const LearnerStateEngine().run(
        engineInputs(
          nowUtc: _now,
          subTracks: (r as CompleteReadReady<SubTrack>).items,
          corpora: {engineCurriculum: bundledCorpus(engineCurriculum)},
          intents: {
            engineCurriculum: MainTrackIntent(
              curriculumId: engineCurriculum,
              track: MainTrack(
                curriculumId: engineCurriculum,
                state: MainTrackState.active,
              ),
            ),
          },
          goals: const {
            engineCurriculum: CurriculumGoals(
              deadline: DeadlineGoal(
                curriculumId: engineCurriculum,
                targetDate: '2029-03-14',
              ),
            ),
          },
        ),
      ),
    );

/// The screen's main-track numbers, read from the same learner state.
class _MainTrackStatus extends ConsumerWidget {
  const _MainTrackStatus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activeLearnerStateProvider).value;
    final c = state?[engineCurriculum];
    return Text(
      'target ${c?.dailyTarget} · remaining ${c?.mainTrackRemaining}',
    );
  }
}

final class _Rig {
  _Rig() {
    var n = 0;
    String id() => engineUlid(80000 + n++);
    subTrackCommands = SubTrackCommands(
      scope: world.scope,
      actor: const Actor(
        uid: 'owner-uid',
        role: ActorRole.parent,
        displayName: '',
      ),
      // Like FirestoreSubTrackRepository: the append commits as a
      // latest-row (server) write.
      subTracks: LatestWriteSubTrackRepository(world.subTracks),
      intent: world.intent,
      today: () => _today,
      nowUtc: () => _now,
      newId: id,
      corpusOf: (c) async =>
          c == engineCurriculum ? bundledCorpus(engineCurriculum) : null,
      ackTimeout: const Duration(milliseconds: 40),
    );
    commands = DefaultLearningCommands(
      scope: world.scope,
      actor: subTrackCommands.actor,
      reads: FakeLearningCommandReads(history: c0SettingsHistory()),
      writePort: InMemoryLearningWritePort(),
      gate: FakeCaptureGate.open(),
      analytics: RecordingLearningAnalytics(),
      failureReporter: RecordingLearningFailureReporter(),
      clock: () => _now,
      newUlid: (_) => id(),
      subTrackCommands: subTrackCommands,
    );
  }

  late final GroundPickerWorld world = GroundPickerWorld(
    corpus: bundledCorpus(engineCurriculum),
    tracks: [_school()],
    commandsOverride: () => commands,
    stateStream: (w) => _engineOver(w.subTracks),
  );
  late final SubTrackCommands subTrackCommands;
  late final DefaultLearningCommands commands;
  var closed = 0;

  Future<void> pump(WidgetTester tester) async {
    addTearDown(() async {
      await commands.dispose();
      await subTrackCommands.dispose();
      await world.dispose();
    });
    tester.view.physicalSize = const Size(600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      pumpApp(
        overrides: world.overrides,
        child: Scaffold(
          body: Column(
            children: [
              const _MainTrackStatus(),
              Expanded(
                child: GroundPickerPane(
                  subTrackId: schoolId,
                  onClose: () => closed++,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

Future<void> _pickBerakhot1to3(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Expand Seder Zeraim'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Expand Mishnah Berakhot'));
  await tester.pumpAndSettle();
  for (final n in [1, 2, 3]) {
    await tester.tap(
      find.descendant(
        of: find
            .ancestor(
              of: find.text('Mishnah Berakhot $n'),
              matching: find.byType(InkWell),
            )
            .first,
        matching: find.byType(Checkbox),
      ),
    );
    await tester.pumpAndSettle();
  }
  // Mishnayos "Chapter" is the curriculum's depth-3 level: Perek.
  expect(find.text('Add 3 Perakim to School'), findsOneWidget);
}

/// Confirms the pick. The governed command's reads complete on real
/// async only (its in-memory ports' stream cancellation never settles
/// under the widget tester's fake clock), so the tap runs in runAsync.
Future<void> _confirm(WidgetTester tester) async {
  await tester.runAsync(() async {
    await tester.tap(find.text('Add 3 Perakim to School'));
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('AC-4 / AC-5: one write, one change-log entry, and the main '
      'track recomputes on the same screen with the target unchanged', (
    tester,
  ) async {
    final rig = _Rig();
    await rig.pump(tester);
    expect(find.text('target 5 · remaining 4192'), findsOneWidget);
    await _pickBerakhot1to3(tester);
    await _confirm(tester);
    final repo = rig.world.subTracks;
    expect(repo.entries, hasLength(1));
    expect(repo.tracksOf(rig.world.scope).single.ground, [
      for (final n in [1, 2, 3])
        NodeEntry(level: 'chapter', ref: 'Mishnah Berakhot $n'),
    ]);
    expect(rig.closed, 1);
    // Same screen: 19 leaves left the main track; the target held.
    expect(find.text('target 5 · remaining 4173'), findsOneWidget);
  });

  testWidgets('a refused assignment rolls back with a snackbar; nothing '
      'recomputes', (tester) async {
    final rig = _Rig();
    rig.world.subTracks.failNextWith(
      const PermanentWriteRejection('permission-denied'),
    );
    await rig.pump(tester);
    await _pickBerakhot1to3(tester);
    await _confirm(tester);
    expect(
      find.text("Couldn't add the ground. Nothing was changed."),
      findsOneWidget,
    );
    expect(rig.closed, 0);
    expect(rig.world.subTracks.entries, isEmpty);
    expect(
      rig.world.subTracks.tracksOf(rig.world.scope).single.ground,
      isEmpty,
    );
    expect(find.text('target 5 · remaining 4192'), findsOneWidget);
    // The picks are kept for another try; the stored ground is not shown
    // as assigned.
    expect(find.text('Add 3 Perakim to School'), findsOneWidget);
    expect(find.text('Already in School'), findsNothing);
  });

  testWidgets('offline the assignment is refused as online-required: '
      'nothing is written or queued, the picks are kept and the target '
      'is unchanged', (tester) async {
    final rig = _Rig();
    final repo = rig.world.subTracks..offline = true;
    await rig.pump(tester);
    await _pickBerakhot1to3(tester);
    await _confirm(tester);
    expect(repo.heldCount, 0);
    expect(repo.calls, isEmpty);
    expect(repo.entries, isEmpty);
    expect(repo.tracksOf(rig.world.scope).single.ground, isEmpty);
    expect(rig.closed, 0);
    expect(
      find.text(
        "You're offline. Ground can be added once you're back online. "
        'Nothing was changed.',
      ),
      findsOneWidget,
    );
    expect(find.text('target 5 · remaining 4192'), findsOneWidget);
    expect(find.text('Add 3 Perakim to School'), findsOneWidget);
  });
}

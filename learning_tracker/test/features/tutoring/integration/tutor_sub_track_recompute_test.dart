// Story 4.2 (DNI-510) AC-3 — a tutor saves a new ongoing "Rebbe" sub-track
// (5 a week) with no ground: once the callable succeeds, the talmid's hub
// and Learn tab show the groundless Rebbe row with *Add ground* for the
// tutor (UX-DR-88). After he adds ground through the picker's append, the
// main track's schedulable refs and daily target recompute from the
// talmid's mirror within one second (NFR-5).
//
// The ground stands in for Beitzah with Peah, the fixture corpus's masechta.

@Tags(['tutor_mode'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/sub_tracks/sub_tracks.dart';

import '../../../helpers/learner_state/engine_fixtures.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/sub_tracks/sub_track_harness.dart';
import '../../../helpers/tutoring/tutor_learning_harness.dart';
import '../../../helpers/tutoring/tutor_sub_track_rig.dart';

const _rebbe = SubTrackDraft(
  curriculumId: subTrackTestCurriculum,
  name: 'Rebbe',
  type: SubTrackType.ongoing,
  windowStart: '2026-09-01',
  ratePerWeek: 5,
  weeksPerYear: 52,
  learnsOnShabbos: false,
  ground: [],
);

/// The engine over the talmid's mirror, as `learnerStateProvider` runs it
/// on every cache change.
LearnerState _engine(List<SubTrack> subTracks) =>
    const LearnerStateEngine().run(
      engineInputs(
        nowUtc: tutorFixtureNow,
        subTracks: subTracks,
        goals: {
          engineCurriculum: const CurriculumGoals(
            deadline: DeadlineGoal(
              curriculumId: engineCurriculum,
              targetDate: '2026-10-31',
            ),
          ),
        },
      ),
    );

const _peahLeaves = ['Mishnah Peah 1:1', 'Mishnah Peah 1:2'];

void main() {
  testWidgets('a groundless Rebbe track, then its ground, recompute the main '
      'track within one second', (tester) async {
    final rig = TutorSubTrackRig();
    addTearDown(rig.dispose);

    // The tutor saves the groundless Rebbe track: one callable.
    final created = (await tester.runAsync(
      () => rig.commands.createSubTrack(_rebbe),
    ))!;
    expect(created, isA<CaptureSuccess>());
    final rebbe = rig.hub.repo.tracksOf(rig.hub.scope).single;
    expect(rebbe.ground, isEmpty);

    final before = _engine(rig.hub.repo.tracksOf(rig.hub.scope));
    final item = projectHomeSubTracks(
      subTracks: rig.hub.repo.tracksOf(rig.hub.scope),
      learnerState: before,
    ).single;
    expect(item.kind, SubTrackRowKind.groundless);

    // The Learn row offers the tutor an enabled *Add ground* (UX-DR-88).
    var opened = 0;
    await tester.pumpWidget(
      pumpApp(
        child: Scaffold(
          body: SubTrackHomeRow(
            item: item,
            role: SubTrackViewerRole.tutor,
            onOpen: () {},
            onAddGround: () => opened++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('subTrackHomeAddGround-${rebbe.id}')));
    expect(opened, 1);
    expect(before[engineCurriculum]!.schedulableRefs, containsAll(_peahLeaves));

    // He adds the masechta through the picker's append: one callable; the
    // mirror changes only after it answered, and the engine recomputes.
    final added = (await tester.runAsync(
      () => rig.commands.editSubTrack(
        rebbe.id,
        const SubTrackEdit(appendGround: [peah]),
      ),
    ))!;
    expect(added, isA<CaptureSuccess>());
    final clock = Stopwatch()..start();
    final after = _engine(rig.hub.repo.tracksOf(rig.hub.scope));
    clock.stop();

    expect(clock.elapsed, lessThan(const Duration(seconds: 1)));
    final main = after[engineCurriculum]!;
    expect(main.subTracks[rebbe.id]!.holdsGround, isTrue);
    for (final leaf in _peahLeaves) {
      expect(main.schedulableRefs, isNot(contains(leaf)), reason: leaf);
    }
    // The daily target is re-derived from the smaller main-track remainder.
    expect(
      main.mainTrackRemaining,
      lessThan(before[engineCurriculum]!.mainTrackRemaining),
    );
    expect(main.dailyTarget, isNotNull);
    expect(
      [for (final c in rig.subTrackCalls) c.args['op']],
      ['create', 'edit'],
    );
  });
}

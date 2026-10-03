/// Shared fixtures of the Story 2.10 (DNI-501) Up to… tests.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/up_to_picker.dart';

import '../../../helpers/learner_state/c0_fixtures.dart';
import '../../../helpers/learner_state/engine_fixtures.dart';
import '../../../helpers/learner_state/fake_learner_state.dart';
import '../../../helpers/learner_state/learner_state_overrides.dart';

/// School's ULID.
final schoolId = engineUlid(10);

/// Rebbe's ULID.
final rebbeId = engineUlid(20);

/// A live sub-track of the fixture curriculum.
SubTrack fixtureSubTrack(
  String id,
  String name, {
  List<NodeEntry> ground = const [berakhot],
}) => SubTrack(
  id: id,
  curriculumId: engineCurriculum,
  name: name,
  type: SubTrackType.ongoing,
  windowStart: '2026-09-01',
  ratePerWeek: 5,
  weeksPerYear: 40,
  learnsOnShabbos: false,
  ground: ground,
  lastChangeId: engineUlid(90),
);

/// An `onHome` sub-track state over [path] from its first leaf.
SubTrackState fixtureSubTrackState(
  String id, {
  List<String> path = const [],
  Set<String> recordedAhead = const {},
  bool exhausted = false,
  bool onHome = true,
}) => SubTrackState(
  subTrackId: id,
  holdsGround: true,
  inForecast: true,
  onHome: onHome,
  position: path.isEmpty ? null : path.first,
  groundExhausted: exhausted,
  remainingPath: path,
  recordedAhead: recordedAhead,
);

/// A learner state of the fixture curriculum holding [subTracks].
LearnerState fixtureLearnerState({
  Map<String, SubTrackState> subTracks = const {},
  List<String> schedulable = const [],
}) => fakeLearnerState(
  curricula: {
    engineCurriculum: FakeCurriculumState(
      curriculumId: engineCurriculum,
      subTracks: subTracks,
      schedulableRefs: schedulable,
      mainTrackPosition: schedulable.isEmpty ? null : schedulable.first,
    ),
  },
);

/// Leaf labels without the "Mishnah " prefix, and the Mishnayos unit, so
/// widget tests never reach the content database.
List<Override> upToLabelOverrides() => [
  upToLeafLabelProvider.overrideWith(
    (ref, leaf) => leaf.replaceFirst('Mishnah ', ''),
  ),
  upToUnitLabelsProvider.overrideWith(
    (ref, _) => (one: 'mishna', many: 'mishnayos'),
  ),
];

/// The owner overrides of a picker or row test over [state].
List<Override> upToOverrides({LearnerState? state}) => [
  ...learnerStateOverrides(scope: c0Scope(), state: state),
  ...upToLabelOverrides(),
];

/// A phone-sized test surface.
const phoneSize = Size(400, 800);

/// A tablet-sized test surface.
const tabletSize = Size(1024, 1366);

/// Sets the test view to [size] logical pixels (device pixel ratio 1),
/// reset at teardown.
void useSurface(WidgetTester tester, Size size) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// A one-masechta corpus ("Mishnah Long") of [leaves], in order.
InMemoryCorpus longCorpus(List<String> leaves) =>
    InMemoryCorpus(engineCurriculum, [
      CorpusNode(const NodeEntry(level: 'masechta', ref: 'Mishnah Long'), [
        for (final l in leaves) CorpusNode(NodeEntry(level: 'mishnah', ref: l)),
      ]),
    ]);

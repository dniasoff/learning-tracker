/// Hermetic fixtures for the Learn-tab / Dashboard sub-track tests
/// (Story 2.9, DNI-500).
library;

import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

import '../learner_state/fake_learner_state.dart';
import '../learner_state_fixtures.dart';

/// School: the first track in hub order (lowest ULID).
const schoolId = ulidA;

/// Rebbe: the second track in hub order.
const rebbeId = ulidB;

/// A third, never-on-home track.
const futureId = ulidD;

/// The Mishnayos curriculum storage key.
const mishnayos = 'mishnayos';

/// A live school-year sub-track named [name] over [ground].
SubTrack homeSubTrack({
  required String id,
  String name = 'School',
  List<NodeEntry> ground = const [
    NodeEntry(level: 'masechet', ref: 'Mishnah_Berakhot'),
    NodeEntry(level: 'masechet', ref: 'Mishnah_Peah'),
  ],
  String curriculumId = mishnayos,
  DateTime? endedAt,
}) => SubTrack(
  id: id,
  curriculumId: curriculumId,
  name: name,
  type: SubTrackType.schoolYear,
  academicYear: 2026,
  windowStart: '2026-09-01',
  windowEnd: '2027-08-31',
  ratePerWeek: 7,
  weeksPerYear: 40,
  learnsOnShabbos: false,
  ground: ground,
  lastChangeId: ulidC,
  endedAt: endedAt,
  endReason: endedAt == null ? null : SubTrackEndReason.ended,
);

/// The engine's view of a sub-track (the fields the rows read).
SubTrackState homeState(
  String id, {
  bool onHome = true,
  String? position,
  bool groundExhausted = false,
  int ticked = 0,
  List<String> remainingPath = const [],
}) => SubTrackState(
  subTrackId: id,
  holdsGround: onHome,
  inForecast: onHome,
  onHome: onHome,
  position: position,
  groundExhausted: groundExhausted,
  ticked: ticked,
  remainingPath: remainingPath,
);

/// A [LearnerState] whose Mishnayos curriculum holds [states].
LearnerState homeLearnerState(
  List<SubTrackState> states, {
  Set<String> countedEventIds = const {},
  Set<String> lockIgnoredEventIds = const {},
}) => fakeLearnerState(
  curricula: {
    mishnayos: FakeCurriculumState(
      curriculumId: mishnayos,
      subTracks: {for (final s in states) s.subTrackId: s},
    ),
  },
  countedEventIds: countedEventIds,
  lockIgnoredEventIds: lockIgnoredEventIds,
);

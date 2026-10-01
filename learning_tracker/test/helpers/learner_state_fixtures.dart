/// Shared, hermetic fixtures for the Story 1.2 (DNI-464) learner-state
/// tests: fixed ULIDs, fixed UTC instants (TQ-6: no wall clock), and
/// canonical AD-52 golden storage maps.
library;

import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';

/// Valid Crockford ULIDs.
const ulidA = '01ARZ3NDEKTSV4RRFFQ69G5FAA';
const ulidB = '01ARZ3NDEKTSV4RRFFQ69G5FAB';
const ulidC = '01ARZ3NDEKTSV4RRFFQ69G5FAC';
const ulidD = '01ARZ3NDEKTSV4RRFFQ69G5FAD';
const ulidE = '01ARZ3NDEKTSV4RRFFQ69G5FAE';

/// A profile ULID.
const profileUlid = '01ARZ3NDEKTSV4RRFFQ69G5FB1';

/// Fixed instants.
final t0 = DateTime.utc(2026, 9, 1, 8, 30, 15, 123, 456);
final t1 = DateTime.utc(2026, 9, 2, 9);
final t2 = DateTime.utc(2025, 1, 1, 12);

/// A parent actor.
const parentActor = Actor(
  uid: 'owner-uid',
  role: ActorRole.parent,
  displayName: 'Abba',
);

/// Golden storage map of [parentActor].
const parentActorMap = <String, Object?>{
  'uid': 'owner-uid',
  'role': 'parent',
  'display_name': 'Abba',
};

/// A dated, main-track leaf `learn` event with a stage.
LearningEvent datedLearn({
  String id = ulidA,
  String source = LearningEvent.sourceMain,
  int? stage = 2,
  DateTime? recordedAt,
  DateTime? originalRecordedAt,
}) => LearningEvent.learn(
  id: id,
  curriculumId: 'mishnayos',
  ref: 'Mishnah Berakhot 1:1',
  source: source,
  dateState: DateState.dated,
  learnedOn: '2026-09-01',
  stage: stage,
  recordedAt: recordedAt ?? t0,
  originalRecordedAt: originalRecordedAt,
  actor: parentActor,
);

/// Golden storage map of [datedLearn] with defaults.
Map<String, Object?> datedLearnMap() => {
  'kind': 'learn',
  'curriculum_id': 'mishnayos',
  'ref': 'Mishnah Berakhot 1:1',
  'source': 'main',
  'date_state': 'dated',
  'learned_on': '2026-09-01',
  'stage': 2,
  'recorded_at': t0,
  'actor': Map<String, Object?>.of(parentActorMap),
};

/// Fixtures for the parent Change history tests (Story 4.5 / DNI-513):
/// actors of each role, governed entries and learning events numbered so
/// their ids sort with their number, at caller-chosen instants.
library;

import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';

import 'learner_state/engine_fixtures.dart';

/// A parent actor.
const historyParent = Actor(
  uid: 'parent-uid',
  role: ActorRole.parent,
  displayName: 'Abba',
);

/// A tutor actor.
const historyTutor = Actor(
  uid: 'tutor-uid',
  role: ActorRole.tutor,
  displayName: 'Rav Cohen',
);

/// A child actor.
const historyChild = Actor(
  uid: 'child-uid',
  role: ActorRole.child,
  displayName: 'Yehuda',
);

/// Instant [minutes] after 2026-09-01T00:00Z.
DateTime historyAt(int minutes) => engineAt(minutes);

/// The ULID numbered [n] (ids sort by [n]).
String historyId(int n) => engineUlid(n);

/// The `{collection}/{docId}.{field}` key an entry of [entity] changes by
/// default.
String defaultHistoryKey(GovernedEntity entity, String entityId) =>
    switch (entity) {
      GovernedEntity.goal => 'goals/$entityId.target_date',
      GovernedEntity.subTrack => 'sub_tracks/$entityId.name',
      GovernedEntity.learnerSettings => 'learner_profiles/$entityId.time_zone',
      _ => '${entity.collection}/$entityId.curriculum_id',
    };

/// A governed entry numbered [n] at [minutes]; imported from
/// [originalMinutes] when given (`original_at`).
ChangeLogEntry historyEntry(
  int n, {
  required int minutes,
  GovernedEntity entity = GovernedEntity.goal,
  Actor actor = historyParent,
  String? entityId,
  int? actionOf,
  int? reverts,
  Map<String, Object?>? before,
  Map<String, Object?>? after,
  int? originalMinutes,
}) {
  final id =
      entityId ??
      switch (entity) {
        GovernedEntity.subTrack => historyId(9000 + n),
        GovernedEntity.learnerSettings => historyId(9999),
        GovernedEntity.goal => 'goal_$n',
        _ => 'mishnayos',
      };
  final key = defaultHistoryKey(entity, id);
  return ChangeLogEntry(
    id: historyId(n),
    entity: entity,
    entityId: id,
    actionId: historyId(actionOf ?? n),
    revertsActionId: reverts == null ? null : historyId(reverts),
    before: before ?? {key: 'old$n'},
    after: after ?? {key: 'new$n'},
    at: historyAt(minutes),
    actor: actor,
    originalAt: originalMinutes == null ? null : historyAt(originalMinutes),
  );
}

/// A main-track `learn` event numbered [n] recorded at [minutes].
LearningEvent historyLearn(
  int n, {
  required int minutes,
  String ref = 'Mishnah Berakhot 1:1',
  Actor actor = historyParent,
  String source = LearningEvent.sourceMain,
  DateState dateState = DateState.dated,
  String learnedOn = '2026-09-01',
  int? originalMinutes,
}) => LearningEvent.learn(
  id: historyId(n),
  curriculumId: engineCurriculum,
  ref: ref,
  source: source,
  dateState: dateState,
  learnedOn: dateState == DateState.beforeTracking ? null : learnedOn,
  recordedAt: historyAt(minutes),
  originalRecordedAt: originalMinutes == null
      ? null
      : historyAt(originalMinutes),
  actor: actor,
);

/// A `void` numbered [n] of the event numbered [target].
LearningEvent historyVoid(
  int n, {
  required int target,
  required int minutes,
  Actor actor = historyParent,
}) => LearningEvent.voidOf(
  id: historyId(n),
  targetId: historyId(target),
  recordedAt: historyAt(minutes),
  actor: actor,
);

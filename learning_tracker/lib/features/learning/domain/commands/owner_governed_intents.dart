/// The owner governed intents of Story 1.14 (DNI-476): the AD-38 entity
/// changes the owner repositories hand to
/// `LearningCommands.applyGovernedChange` for goals, the main track and its
/// order, program, study days, stages and scope, plus the AD-38 track
/// lifecycle (remove / re-add).
///
/// Pure builders: no clock, no I/O. Every patch is in storage form
/// (`storage_codec.dart`), holds only the fields the caller changes, and
/// never sets `last_change_id` (the commands stamp it from the entry id).
///
/// * A `goal` is one of the two AD-43 fixed docs `goals/{c}_deadline` and
///   `goals/{c}_pace`, so a second create is structurally an update of the
///   same doc (logged, LWW per field, AD-38).
/// * A `mainTrack*` doc always carries its immutable `curriculum_id`
///   (AD-38): the commands drop it as unchanged on an existing doc and
///   write it on a new one, which the rules require.
/// * Removal is never a delete: it is an `ended_at` tombstone.
///
/// Imports only `lib/domain/learner_state/**` and `dart:`.
library;

import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/governed_change.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

/// The two AD-43 goal kinds of a curriculum.
enum GoalKind {
  /// `goals/{curriculumId}_deadline` (`target_date`).
  deadline('deadline'),

  /// `goals/{curriculumId}_pace` (`pace_value`, `pace_unit`,
  /// `pace_granularity`).
  pace('pace');

  const GoalKind(this.storage);

  /// The `goal_type` storage string and doc-id suffix.
  final String storage;

  /// Storage string → value.
  static final Map<String, GoalKind> byStorage = {
    for (final k in values) k.storage: k,
  };
}

/// Storage key `goal_type`.
const kGoalType = 'goal_type';

/// The AD-43 doc id of [curriculumId]'s goal of [kind].
String goalDocId(String curriculumId, GoalKind kind) =>
    '${curriculumId}_${kind.storage}';

/// The `(curriculumId, kind)` an AD-43 goal doc id names, or null when
/// [docId] is not `{curriculumId}_deadline` / `{curriculumId}_pace`.
({String curriculumId, GoalKind kind})? parseGoalDocId(String docId) {
  for (final kind in GoalKind.values) {
    final suffix = '_${kind.storage}';
    if (docId.length > suffix.length && docId.endsWith(suffix)) {
      return (
        curriculumId: docId.substring(0, docId.length - suffix.length),
        kind: kind,
      );
    }
  }
  return null;
}

/// The `mainTrack*` entities: their `entity_id` is the curriculum id and
/// every doc carries it as `curriculum_id`.
const Set<GovernedEntity> mainTrackEntities = {
  GovernedEntity.mainTrack,
  GovernedEntity.mainTrackOrder,
  GovernedEntity.mainTrackProgram,
  GovernedEntity.mainTrackStudyDays,
  GovernedEntity.mainTrackStages,
  GovernedEntity.mainTrackScope,
};

/// Builders for the owner governed entity changes (AD-38, AD-43).
abstract final class OwnerGovernedIntents {
  /// Upserts [curriculumId]'s AD-43 goal of [kind] with [fields] (storage
  /// form, changed fields only). `goal_type`, `curriculum_id` and a cleared
  /// `ended_at` are always stamped: re-creating an ended goal revives the
  /// same doc, never a second one.
  ///
  /// Throws [ArgumentError] when [fields] names a governance key or a
  /// different `goal_type` / `curriculum_id`.
  static GovernedEntityChange setGoal({
    required String curriculumId,
    required GoalKind kind,
    required Map<String, Object?> fields,
  }) {
    _requireCurriculum(curriculumId);
    if (fields.containsKey(GovernedKeys.lastChangeId) ||
        fields.containsKey(GovernedKeys.endedAt)) {
      throw ArgumentError.value(fields, 'fields', 'sets a governance key');
    }
    final type = fields[kGoalType];
    if (type != null && type != kind.storage) {
      throw ArgumentError.value(type, 'goal_type', 'must be ${kind.storage}');
    }
    final cid = fields[GovernedKeys.curriculumId];
    if (cid != null && cid != curriculumId) {
      throw ArgumentError.value(cid, 'curriculum_id', 'must be $curriculumId');
    }
    final docId = goalDocId(curriculumId, kind);
    return GovernedEntityChange(
      entity: GovernedEntity.goal,
      entityId: docId,
      docs: [
        GovernedDocPatch(
          collection: GovernedEntity.goal.collection,
          docId: docId,
          fields: {
            ...fields,
            kGoalType: kind.storage,
            GovernedKeys.curriculumId: curriculumId,
            GovernedKeys.endedAt: null,
          },
        ),
      ],
    );
  }

  /// Ends [curriculumId]'s goal of [kind]: an `ended_at` tombstone, never a
  /// delete (AD-38).
  static GovernedEntityChange endGoal({
    required String curriculumId,
    required GoalKind kind,
    required DateTime at,
  }) {
    _requireCurriculum(curriculumId);
    final docId = goalDocId(curriculumId, kind);
    return GovernedEntityChange(
      entity: GovernedEntity.goal,
      entityId: docId,
      docs: [
        GovernedDocPatch(
          collection: GovernedEntity.goal.collection,
          docId: docId,
          fields: {GovernedKeys.endedAt: at.toUtc()},
          mode: DocMode.update,
        ),
      ],
    );
  }

  /// One `mainTrack*` [entity] change of [curriculumId] patching [docs]
  /// (doc id → changed fields, storage form), in iteration order. Each
  /// patch carries `curriculum_id`.
  ///
  /// Throws [ArgumentError] for a non-`mainTrack*` entity, an empty [docs]
  /// map, a governance key other than `ended_at`, or a mismatched
  /// `curriculum_id`.
  static GovernedEntityChange mainTrackDocs({
    required GovernedEntity entity,
    required String curriculumId,
    required Map<String, Map<String, Object?>> docs,
  }) {
    _requireMainTrack(entity);
    _requireCurriculum(curriculumId);
    if (docs.isEmpty) {
      throw ArgumentError.value(docs, 'docs', 'must not be empty');
    }
    return GovernedEntityChange(
      entity: entity,
      entityId: curriculumId,
      docs: [
        for (final MapEntry(key: docId, value: fields) in docs.entries)
          GovernedDocPatch(
            collection: entity.collection,
            docId: docId,
            fields: _withCurriculum(fields, curriculumId),
          ),
      ],
    );
  }

  /// Tombstones [docIds] of the `mainTrack*` [entity] of [curriculumId]:
  /// `ended_at` = [at] on each (AD-38: removal is a tombstone).
  static GovernedEntityChange endMainTrackDocs({
    required GovernedEntity entity,
    required String curriculumId,
    required Iterable<String> docIds,
    required DateTime at,
  }) => mainTrackDocs(
    entity: entity,
    curriculumId: curriculumId,
    docs: {
      for (final id in docIds) id: {GovernedKeys.endedAt: at.toUtc()},
    },
  );

  /// AD-38 "Remove track": ONE action of a `mainTrack` entry setting
  /// `ended_at` on `curriculum_tracks/{curriculumId}` only, then one
  /// `subTrack` tombstone entry (`ended_at`, `end_reason: track_deleted`)
  /// per non-ended sub-track of that curriculum in [subTracks], in id
  /// order. Already-ended sub-tracks are not tombstoned again. Learning
  /// events and the points ledger are not governed and never touched.
  static GovernedAction removeTrack({
    required String curriculumId,
    required Iterable<SubTrack> subTracks,
    required DateTime at,
  }) {
    final when = at.toUtc();
    final live =
        subTracks
            .where((t) => t.curriculumId == curriculumId && t.endedAt == null)
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    return GovernedAction([
      mainTrackDocs(
        entity: GovernedEntity.mainTrack,
        curriculumId: curriculumId,
        docs: {
          curriculumId: {GovernedKeys.endedAt: when},
        },
      ),
      for (final t in live)
        GovernedEntityChange(
          entity: GovernedEntity.subTrack,
          entityId: t.id,
          docs: [
            GovernedDocPatch(
              collection: GovernedEntity.subTrack.collection,
              docId: t.id,
              fields: {
                SubTrack.kEndedAt: when,
                SubTrack.kEndReason: SubTrackEndReason.trackDeleted.storage,
              },
              mode: DocMode.update,
            ),
          ],
        ),
    ]);
  }

  /// AD-38 "Re-add": clears `ended_at` on `curriculum_tracks/{curriculumId}`
  /// through a logged change; every other field (the prior config) is kept.
  /// Sub-tracks ended by the removal stay ended (ruling B13).
  static GovernedEntityChange reAddTrack(String curriculumId) => mainTrackDocs(
    entity: GovernedEntity.mainTrack,
    curriculumId: curriculumId,
    docs: {
      curriculumId: {GovernedKeys.endedAt: null},
    },
  );

  static Map<String, Object?> _withCurriculum(
    Map<String, Object?> fields,
    String curriculumId,
  ) {
    if (fields.containsKey(GovernedKeys.lastChangeId)) {
      throw ArgumentError.value(fields, 'fields', 'sets last_change_id');
    }
    final cid = fields[GovernedKeys.curriculumId];
    if (cid != null && cid != curriculumId) {
      throw ArgumentError.value(cid, 'curriculum_id', 'must be $curriculumId');
    }
    return {...fields, GovernedKeys.curriculumId: curriculumId};
  }

  static void _requireMainTrack(GovernedEntity entity) {
    if (!mainTrackEntities.contains(entity)) {
      throw ArgumentError.value(entity, 'entity', 'not a mainTrack* entity');
    }
  }

  static void _requireCurriculum(String curriculumId) {
    if (curriculumId.isEmpty || curriculumId.contains('/')) {
      throw ArgumentError.value(curriculumId, 'curriculumId', 'invalid');
    }
  }
}

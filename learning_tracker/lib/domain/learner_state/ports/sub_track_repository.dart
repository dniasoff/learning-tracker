/// Port for `sub_tracks` — the complete read the engine consumes and the
/// governed write port `LearningCommands.applyGovernedChange` uses with
/// `entity = subTrack` (AD-38). Implemented in
/// `lib/data/repositories/firestore_sub_track_repository.dart`.
///
/// There is no create/edit command and no delete here: Story 1.2 ships the
/// substrate only. Removal is a tombstone (`ended_at` + `end_reason`);
/// client `delete` is denied by rules and never issued.
library;

import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

/// Reads a learner's sub-tracks and applies governed changes to them.
abstract interface class SubTrackRepository {
  /// Every sub-track of [scope] — live AND tombstoned — as a complete
  /// paged read (≤ 500 per query; loading until complete; never partial).
  Stream<CompleteRead<SubTrack>> watchAll(LearnerScope scope);

  /// Applies [change] as one atomic batch: a field-level
  /// `set(merge: true)` of the changed fields plus `last_change_id` on
  /// `sub_tracks/{id}`, and the create of `change_log/{entry.id}`
  /// (AD-38 "an entity's docs and its entry are always in one batch").
  /// Never deletes.
  Future<void> applyGovernedChange(LearnerScope scope, SubTrackChange change);
}

/// One governed change to one sub-track, paired with its change-log entry.
final class SubTrackChange {
  /// A field-level change: [changedFields] are storage-form values keyed by
  /// storage field name (e.g. `{'rate_per_week': 7}`), and [entry]'s
  /// `after` must hold exactly those fields as
  /// `sub_tracks/{subTrackId}.{field}`.
  SubTrackChange.fields({
    required this.subTrackId,
    required Map<String, Object?> changedFields,
    required this.entry,
  }) : changedFields = Map.unmodifiable(changedFields) {
    _validate();
  }

  /// A tombstone: sets `ended_at` and `end_reason` together (AD-38).
  SubTrackChange.tombstone({
    required String subTrackId,
    required DateTime endedAt,
    required SubTrackEndReason reason,
    required ChangeLogEntry entry,
  }) : this.fields(
         subTrackId: subTrackId,
         changedFields: {
           SubTrack.kEndedAt: endedAt.toUtc(),
           SubTrack.kEndReason: reason.storage,
         },
         entry: entry,
       );

  static const _type = 'SubTrackChange';

  /// The sub-track ULID (document id and `entry.entity_id`).
  final String subTrackId;

  /// Changed fields, storage form, excluding `last_change_id`.
  final Map<String, Object?> changedFields;

  /// The co-written change-log entry; its id becomes `last_change_id`.
  final ChangeLogEntry entry;

  /// The merge payload for `sub_tracks/{subTrackId}`: [changedFields] plus
  /// `last_change_id = entry.id`.
  Map<String, Object?> toMergePatch() => {
    ...changedFields,
    SubTrack.kLastChangeId: entry.id,
  };

  Never _fail(String field, String reason) =>
      throw StorageFormatException(_type, field, reason);

  void _validate() {
    if (!isUlid(subTrackId)) _fail('<id>', 'sub-track id is not a ULID');
    if (changedFields.isEmpty) _fail('<fields>', 'no changed fields');
    changedFields.forEach(SubTrack.validateGovernedField);

    final hasEndedAt = changedFields.containsKey(SubTrack.kEndedAt);
    final hasEndReason = changedFields.containsKey(SubTrack.kEndReason);
    if (hasEndedAt != hasEndReason ||
        (changedFields[SubTrack.kEndedAt] == null) !=
            (changedFields[SubTrack.kEndReason] == null)) {
      _fail(
        SubTrack.kEndReason,
        'ended_at and end_reason must change together and be consistent',
      );
    }

    if (entry.entity != GovernedEntity.subTrack) {
      _fail(ChangeLogEntry.kEntity, 'entry is not a subTrack entry');
    }
    if (entry.entityId != subTrackId) {
      _fail(ChangeLogEntry.kEntityId, 'entry covers another sub-track');
    }
    final expected = {
      for (final field in changedFields.keys)
        ChangedFieldKey('sub_tracks', subTrackId, field).key,
    };
    if (entry.after.length != expected.length ||
        !expected.every(entry.after.containsKey)) {
      _fail(ChangeLogEntry.kAfter, 'entry fields do not match the change');
    }
    for (final field in changedFields.keys) {
      final key = ChangedFieldKey('sub_tracks', subTrackId, field).key;
      if (!storageValueEquals(entry.after[key], changedFields[field])) {
        _fail(ChangeLogEntry.kAfter, 'entry value differs for $field');
      }
    }
  }
}

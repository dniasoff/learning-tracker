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
  ///
  /// The target must exist: an unknown [SubTrackChange.subTrackId] throws
  /// [SubTrackNotFoundException], and a change whose MERGED row is not a
  /// valid [SubTrack] (cross-field invariants included) throws
  /// [StorageFormatException]. Neither writes anything.
  ///
  /// The entry's `before` must be the truthful baseline (AD-38: the
  /// writer's cached value per field, `null` when absent): any field whose
  /// `before` differs from the stored row throws
  /// [ChangeBaselineMismatchException] and nothing is written.
  ///
  /// The change log is append-only (AD-6, AD-38, AD-46): an identical
  /// replay of an entry that already exists is a no-op (the sub-track is
  /// not re-patched), and a NON-identical entry at an existing id throws
  /// [ChangeLogConflictException] without writing either document.
  Future<void> applyGovernedChange(LearnerScope scope, SubTrackChange change);
}

/// A governed change whose `change_log/{entryId}` already holds a DIFFERENT
/// entry — a retry whose entry was rebuilt instead of reused, or an id
/// collision. Neither the audit row nor the sub-track is written (AD-38
/// append-only, AD-46 create-only plus identical replay).
final class ChangeLogConflictException implements Exception {
  /// Creates the exception for [entryId].
  const ChangeLogConflictException(this.entryId);

  /// The contested `change_log/{ulid}` id.
  final String entryId;

  @override
  String toString() =>
      'ChangeLogConflictException: change_log/$entryId already holds a '
      'different entry';
}

/// A governed change whose target `sub_tracks/{id}` row the client cannot
/// find (not in the local cache and not on the server, or offline with no
/// cached row). Nothing is written: a merge would mint a partial row.
final class SubTrackNotFoundException implements Exception {
  /// Creates the exception for [subTrackId].
  const SubTrackNotFoundException(this.subTrackId);

  /// The missing `sub_tracks/{ulid}` id.
  final String subTrackId;

  @override
  String toString() =>
      'SubTrackNotFoundException: sub_tracks/$subTrackId does not exist';
}

/// A governed change whose `entry.before` does not match the stored
/// `sub_tracks/{id}` row for [field] (absent counts as `null`). Writing it
/// would record a false audit baseline that a later undo would "restore"
/// (AD-38). Nothing is written; the caller rebuilds the change from the
/// current row.
final class ChangeBaselineMismatchException implements Exception {
  /// Creates the exception for [subTrackId] and [field].
  const ChangeBaselineMismatchException(this.subTrackId, this.field);

  /// The target `sub_tracks/{ulid}` id.
  final String subTrackId;

  /// The storage field whose `before` value is not the stored one.
  final String field;

  @override
  String toString() =>
      'ChangeBaselineMismatchException: change_log before.$field does not '
      'match sub_tracks/$subTrackId';
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
  }) : changedFields = freezeStorageMap(changedFields) {
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

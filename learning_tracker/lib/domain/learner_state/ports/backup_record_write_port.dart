/// Port for the AD-49 backup replay's last step (DNI-482): the non-event
/// `points_ledger` entries (spends, parent adjustments) and the
/// `reward_redemptions` records, written as NEW documents.
///
/// Event-linked `points_ledger/pts_{eventId}` entries never go through this
/// port: they are re-derived and co-written with their learning event
/// (AD-50) through `LearningWritePort`.
library;

import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';

/// The profile-scoped collections this port writes.
enum BackupRecordCollection {
  /// `points_ledger` (non-event entries only).
  pointsLedger('points_ledger'),

  /// `reward_redemptions`.
  rewardRedemptions('reward_redemptions');

  const BackupRecordCollection(this.name);

  /// The collection name under the learner profile.
  final String name;
}

/// One new record: `{collection}/{docId}` with storage-form [fields]
/// (instants as UTC `DateTime`s).
final class BackupRecordWrite {
  /// Creates the write.
  ///
  /// Throws [ArgumentError] for a `points_ledger` entry that is
  /// event-linked (`pts_` id or an `event_id` field): those are re-derived,
  /// never imported (AD-50).
  BackupRecordWrite({
    required this.collection,
    required this.docId,
    required Map<String, Object?> fields,
  }) : fields = freezeStorageMap(fields) {
    if (docId.isEmpty || docId.contains('/')) {
      throw ArgumentError.value(docId, 'docId', 'not a document id');
    }
    if (collection == BackupRecordCollection.pointsLedger &&
        isEventPointsEntry(docId, fields)) {
      throw ArgumentError.value(docId, 'docId', 'event points entry');
    }
  }

  /// The collection.
  final BackupRecordCollection collection;

  /// The new document id.
  final String docId;

  /// The document fields, storage form; deeply unmodifiable.
  final Map<String, Object?> fields;

  @override
  String toString() => 'BackupRecordWrite(${collection.name}/$docId)';
}

/// Whether the `points_ledger` row [docId] with [fields] is an AD-50
/// event entry (`pts_{eventId}`, or any row carrying `event_id`).
bool isEventPointsEntry(String docId, Map<String, Object?> fields) =>
    docId.startsWith('pts_') || fields.containsKey('event_id');

/// Commits backup records.
abstract interface class BackupRecordWritePort {
  /// The most writes one [commit] may carry (AD-54).
  static const maxWrites = 450;

  /// Commits [writes] (at most [maxWrites]) for [scope] as one batch of
  /// creates. A server refusal that a retry cannot fix throws
  /// `PermanentWriteRejection`.
  Future<void> commit(LearnerScope scope, List<BackupRecordWrite> writes);
}

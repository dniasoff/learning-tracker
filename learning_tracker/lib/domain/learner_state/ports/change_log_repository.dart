/// Port for `change_log` — the AD-37 intent history the engine and
/// `LearnerSettingsHistory.reconstruct` read, the undo lookups, and the
/// AD-38 governed batch write for every non-sub-track entity.
///
/// Filled by DNI-470 (1.8) in `lib/data/repositories/`. Sub-track changes
/// go through `SubTrackRepository.applyGovernedChange` instead.
library;

import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/sub_track_repository.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';

/// The entities whose change-log entries form the AD-37 intent history.
const Set<GovernedEntity> intentHistoryEntities = {
  GovernedEntity.learnerSettings,
  GovernedEntity.mainTrackOrder,
  GovernedEntity.mainTrackProgram,
  GovernedEntity.mainTrackStages,
  GovernedEntity.mainTrackStudyDays,
};

/// The field-level merge of one governed doc in a [GovernedBatch].
final class GovernedDocMerge {
  /// Creates a merge; [fields] are storage form, excluding
  /// `last_change_id`.
  ///
  /// [fields] is deep-copied into an unmodifiable snapshot, so mutating the
  /// caller's map (or a nested list or map in it) after construction cannot
  /// make a validated [GovernedBatch] write something other than its
  /// `entry.after`.
  GovernedDocMerge({
    required this.collection,
    required this.docId,
    required Map<String, Object?> fields,
  }) : fields = freezeStorageMap(fields);

  /// The profile-scoped collection.
  final String collection;

  /// The document id.
  final String docId;

  /// Changed fields, storage form (null clears a field); deeply
  /// unmodifiable.
  final Map<String, Object?> fields;

  /// The `set(merge: true)` payload: [fields] plus
  /// `last_change_id = entryId`.
  Map<String, Object?> toMergePatch(String entryId) => {
    ...fields,
    GovernedKeys.lastChangeId: entryId,
  };

  @override
  bool operator ==(Object other) =>
      other is GovernedDocMerge &&
      other.collection == collection &&
      other.docId == docId &&
      storageValueEquals(other.fields, fields);

  @override
  int get hashCode => Object.hash(collection, docId, storageValueHash(fields));

  @override
  String toString() => 'GovernedDocMerge($collection/$docId)';
}

/// One AD-38 atomic batch: a change-log [entry] and the doc [merges] it
/// describes.
final class GovernedBatch {
  /// Creates a batch.
  ///
  /// Throws [ArgumentError] when the entry is a `subTrack` entry, when
  /// there are more than [maxDocs] docs (AD-54) or a doc repeats, when a
  /// merge sets `last_change_id` itself, or when `entry.after` does not
  /// hold exactly the merge fields keyed `{collection}/{docId}.{field}`
  /// with the same values.
  GovernedBatch({required this.entry, required List<GovernedDocMerge> merges})
    : merges = List.unmodifiable(merges) {
    _validate();
  }

  /// The AD-54 cap on docs per governed batch.
  static const maxDocs = 10;

  /// The co-written change-log entry; its id becomes each doc's
  /// `last_change_id`.
  final ChangeLogEntry entry;

  /// The doc merges.
  final List<GovernedDocMerge> merges;

  Never _fail(String reason) =>
      throw ArgumentError.value(entry.id, 'GovernedBatch', reason);

  void _validate() {
    if (entry.entity == GovernedEntity.subTrack) {
      _fail('subTrack changes go through SubTrackRepository');
    }
    if (merges.length > maxDocs) _fail('more than $maxDocs docs');
    final docs = <String>{};
    final expected = <String, Object?>{};
    for (final merge in merges) {
      if (!docs.add('${merge.collection}/${merge.docId}')) {
        _fail('doc ${merge.collection}/${merge.docId} appears twice');
      }
      if (merge.fields.containsKey(GovernedKeys.lastChangeId)) {
        _fail('last_change_id is set from the entry id');
      }
      merge.fields.forEach((field, value) {
        expected[ChangedFieldKey(merge.collection, merge.docId, field).key] =
            value;
      });
    }
    if (expected.length != entry.after.length ||
        !expected.keys.every(entry.after.containsKey)) {
      _fail('entry.after keys do not match the merge fields');
    }
    for (final MapEntry(:key, :value) in expected.entries) {
      if (!storageValueEquals(entry.after[key], value)) {
        _fail('entry.after differs from the merge for $key');
      }
    }
  }

  @override
  bool operator ==(Object other) {
    if (other is! GovernedBatch ||
        other.entry != entry ||
        other.merges.length != merges.length) {
      return false;
    }
    for (var i = 0; i < merges.length; i++) {
      if (other.merges[i] != merges[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(entry, Object.hashAll(merges));

  @override
  String toString() => 'GovernedBatch(${entry.id}, ${merges.length} docs)';
}

/// Reads the change log and commits governed batches.
abstract interface class ChangeLogRepository {
  /// The complete [intentHistoryEntities] history of [scope], live, in
  /// document-id order (loading until complete; never partial).
  Stream<CompleteRead<ChangeLogEntry>> watchIntentHistory(LearnerScope scope);

  /// Every entry of the action [actionId], in document-id order.
  Future<List<ChangeLogEntry>> entriesOfAction(
    LearnerScope scope,
    String actionId,
  );

  /// Whether any entry reverts [actionId] (`reverts_action_id`), live.
  Stream<bool> watchIsReverted(LearnerScope scope, String actionId);

  /// Commits [batch] atomically: each merge as `set(merge: true)` with
  /// `last_change_id`, and the create of `change_log/{entry.id}`.
  ///
  /// An identical replay is a no-op; a different entry at an existing id
  /// throws [ChangeLogConflictException] and writes nothing.
  Future<void> commitGoverned(LearnerScope scope, GovernedBatch batch);
}

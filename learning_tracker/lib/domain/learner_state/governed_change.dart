/// The AD-38 owner governed-change intent: one user action over one or
/// more governed entities.
///
/// Mirrors `GovernedEntryIntent` in `functions/src/write_with_change_log.ts`.
/// `LearningCommands.applyGovernedChange` (DNI-470) turns a
/// [GovernedAction] into change-log entries and their doc writes.
library;

import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';

/// How a governed doc is written.
enum DocMode {
  /// The doc must not exist yet.
  create,

  /// Create or merge.
  upsert,

  /// The doc must exist.
  update,
}

/// The changed fields of one governed doc.
final class GovernedDocPatch {
  /// Creates a patch.
  ///
  /// [fields] holds changed fields only, in storage form. A null value
  /// clears the field; a tombstone is `ended_at: <UTC DateTime>`.
  const GovernedDocPatch({
    required this.collection,
    required this.docId,
    required this.fields,
    this.mode = DocMode.upsert,
  });

  /// The profile-scoped collection.
  final String collection;

  /// The document id.
  final String docId;

  /// Changed fields, storage form.
  final Map<String, Object?> fields;

  /// The write mode.
  final DocMode mode;

  @override
  bool operator ==(Object other) =>
      other is GovernedDocPatch &&
      other.collection == collection &&
      other.docId == docId &&
      other.mode == mode &&
      storageValueEquals(other.fields, fields);

  @override
  int get hashCode =>
      Object.hash(collection, docId, mode, storageValueHash(fields));

  @override
  String toString() => 'GovernedDocPatch($collection/$docId, ${mode.name})';
}

/// The doc patches of one governed entity in one action.
final class GovernedEntityChange {
  /// Creates an entity change.
  const GovernedEntityChange({
    required this.entity,
    required this.entityId,
    required this.docs,
  });

  /// The governed entity.
  final GovernedEntity entity;

  /// Its id per AD-38 (doc id, curriculumId or profileId).
  final String entityId;

  /// The doc patches.
  final List<GovernedDocPatch> docs;

  @override
  bool operator ==(Object other) {
    if (other is! GovernedEntityChange ||
        other.entity != entity ||
        other.entityId != entityId ||
        other.docs.length != docs.length) {
      return false;
    }
    for (var i = 0; i < docs.length; i++) {
      if (other.docs[i] != docs[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(entity, entityId, Object.hashAll(docs));

  @override
  String toString() => 'GovernedEntityChange(${entity.storage}/$entityId)';
}

/// One owner action: its entity changes, in action order.
final class GovernedAction {
  /// Creates an action; throws [ArgumentError] when [changes] is empty.
  GovernedAction(List<GovernedEntityChange> changes)
    : changes = List.unmodifiable(changes) {
    if (changes.isEmpty) {
      throw ArgumentError.value(changes, 'changes', 'must not be empty');
    }
  }

  /// The entity changes, in action order.
  final List<GovernedEntityChange> changes;

  @override
  bool operator ==(Object other) {
    if (other is! GovernedAction || other.changes.length != changes.length) {
      return false;
    }
    for (var i = 0; i < changes.length; i++) {
      if (other.changes[i] != changes[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(changes);

  @override
  String toString() => 'GovernedAction(${changes.length} changes)';
}

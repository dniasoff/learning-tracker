/// AD-38 / AD-52 governed change-log entry — `change_log/{ulid}`.
///
/// Story 1.2 owns the model and codec only. The `change_log` repository and
/// the generalised governed-write command are Story 1.8; the sub-track write
/// port co-writes an entry with its doc in one batch (AD-38 "an entity's
/// docs and its entry are always in one batch").
library;

import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';

/// `entity` storage enum, each value mapped to the collection it governs.
enum GovernedEntity {
  /// `sub_tracks` (entity_id = sub-track ULID).
  subTrack('subTrack', 'sub_tracks'),

  /// `goals` (entity_id = doc id).
  goal('goal', 'goals'),

  /// `curriculum_tracks` (entity_id = curriculumId).
  mainTrack('mainTrack', 'curriculum_tracks'),

  /// `track_learning_order` (entity_id = curriculumId).
  mainTrackOrder('mainTrackOrder', 'track_learning_order'),

  /// `profile_programs` (entity_id = curriculumId).
  mainTrackProgram('mainTrackProgram', 'profile_programs'),

  /// `study_day_configs` (entity_id = curriculumId).
  mainTrackStudyDays('mainTrackStudyDays', 'study_day_configs'),

  /// `stage_definitions` (entity_id = curriculumId).
  mainTrackStages('mainTrackStages', 'stage_definitions'),

  /// `curriculum_scopes` (entity_id = curriculumId).
  mainTrackScope('mainTrackScope', 'curriculum_scopes'),

  /// `learner_profiles` (AD-37 fields; entity_id = profileId).
  learnerSettings('learnerSettings', 'learner_profiles');

  const GovernedEntity(this.storage, this.collection);

  /// Whether every changed doc of this entity IS the entity, i.e. its doc
  /// id equals `entity_id` (AD-38 owner rule: the doc id for `subTrack` and
  /// `goal`, the profileId for `learnerSettings`, whose doc is
  /// `learner_profiles/{profileId}`). False for the `mainTrack*` entities,
  /// whose `entity_id` is the curriculumId while one entry may cover
  /// several docs with other ids (e.g. per-node `track_learning_order`
  /// docs); their link is each doc's immutable `curriculum_id` field, which
  /// the AD-38 rules and `writeWithChangeLog` check against the stored doc.
  bool get docIdIsEntityId => switch (this) {
    subTrack || goal || learnerSettings => true,
    mainTrack ||
    mainTrackOrder ||
    mainTrackProgram ||
    mainTrackStudyDays ||
    mainTrackStages ||
    mainTrackScope => false,
  };

  /// The exact storage string.
  final String storage;

  /// The profile-scoped collection this entity's docs live in.
  final String collection;

  /// Storage string → value.
  static final Map<String, GovernedEntity> byStorage = {
    for (final e in values) e.storage: e,
  };
}

/// A `{collection}/{docId}.{field}` key of `before` / `after`.
final class ChangedFieldKey {
  /// Creates a key.
  const ChangedFieldKey(this.collection, this.docId, this.field);

  /// Parses `{collection}/{docId}.{field}`; null when malformed. The field
  /// is the text after the LAST `.` (storage field names never contain a
  /// dot), the collection the text before the FIRST `/`.
  static ChangedFieldKey? tryParse(String key) {
    final slash = key.indexOf('/');
    final dot = key.lastIndexOf('.');
    if (slash <= 0 || dot <= slash + 1 || dot == key.length - 1) return null;
    return ChangedFieldKey(
      key.substring(0, slash),
      key.substring(slash + 1, dot),
      key.substring(dot + 1),
    );
  }

  /// Collection name.
  final String collection;

  /// Document id inside [collection].
  final String docId;

  /// Storage field name.
  final String field;

  /// The storage form.
  String get key => '$collection/$docId.$field';

  @override
  bool operator ==(Object other) =>
      other is ChangedFieldKey &&
      other.collection == collection &&
      other.docId == docId &&
      other.field == field;

  @override
  int get hashCode => Object.hash(collection, docId, field);

  @override
  String toString() => key;
}

/// One `change_log/{ulid}` document.
final class ChangeLogEntry {
  /// Creates an entry.
  ChangeLogEntry({
    required this.id,
    required this.entity,
    required this.entityId,
    required this.actionId,
    required Map<String, Object?> before,
    required Map<String, Object?> after,
    required DateTime at,
    required this.actor,
    this.revertsActionId,
    DateTime? originalAt,
  }) : before = Map.unmodifiable(before),
       after = Map.unmodifiable(after),
       at = at.toUtc(),
       originalAt = originalAt?.toUtc();

  /// Strict decode of document [id] with storage [map].
  factory ChangeLogEntry.fromStorage(String id, Map<String, Object?> map) {
    final r = StorageReader(_type, map)..requireOnly(storageKeys);
    final entry = ChangeLogEntry(
      id: id,
      entity: r.requiredEnum(kEntity, GovernedEntity.byStorage),
      entityId: r.requiredString(kEntityId),
      actionId: r.requiredUlid(kActionId),
      revertsActionId: r.optionalUlid(kRevertsActionId),
      before: r.requiredMap(kBefore),
      after: r.requiredMap(kAfter),
      at: r.requiredInstant(kAt),
      actor: Actor.fromStorage(asStorageMap(_type, kActor, map[kActor])),
      originalAt: r.optionalInstant(kOriginalAt),
    );
    return entry.._validate();
  }

  static const _type = 'ChangeLogEntry';

  /// Storage key `entity`.
  static const kEntity = 'entity';

  /// Storage key `entity_id`.
  static const kEntityId = 'entity_id';

  /// Storage key `action_id`.
  static const kActionId = 'action_id';

  /// Storage key `reverts_action_id`.
  static const kRevertsActionId = 'reverts_action_id';

  /// Storage key `before`.
  static const kBefore = 'before';

  /// Storage key `after`.
  static const kAfter = 'after';

  /// Storage key `at`.
  static const kAt = 'at';

  /// Storage key `actor`.
  static const kActor = 'actor';

  /// Storage key `original_at`.
  static const kOriginalAt = 'original_at';

  /// The AD-52 `change_log` key set (the rules' `hasOnly`).
  static const Set<String> storageKeys = {
    kEntity,
    kEntityId,
    kActionId,
    kRevertsActionId,
    kBefore,
    kAfter,
    kAt,
    kActor,
    kOriginalAt,
  };

  /// The entry ULID (document id; every changed doc's `last_change_id`).
  final String id;

  /// The governed entity this entry covers (exactly one, AD-38).
  final GovernedEntity entity;

  /// Doc id / profileId / curriculumId per AD-38.
  final String entityId;

  /// ULID of the first entry of the user action.
  final String actionId;

  /// ULID of the action an undo reverts.
  final String? revertsActionId;

  /// Changed fields before the change (`null` per field = absent).
  final Map<String, Object?> before;

  /// Changed fields after the change (`null` per field = absent).
  final Map<String, Object?> after;

  /// Client instant of the change (UTC).
  final DateTime at;

  /// Who changed it.
  final Actor actor;

  /// Original instant, import only (UTC).
  final DateTime? originalAt;

  /// Parsed [after] keys.
  Iterable<ChangedFieldKey> get changedKeys =>
      after.keys.map((k) => ChangedFieldKey.tryParse(k)!);

  /// Encodes this entry; optional keys are omitted while null.
  Map<String, Object?> toStorage() {
    _validate();
    return {
      kEntity: entity.storage,
      kEntityId: entityId,
      kActionId: actionId,
      if (revertsActionId != null) kRevertsActionId: revertsActionId,
      kBefore: Map<String, Object?>.of(before),
      kAfter: Map<String, Object?>.of(after),
      kAt: at,
      kActor: actor.toStorage(),
      if (originalAt != null) kOriginalAt: originalAt,
    };
  }

  Never _fail(String field, String reason) =>
      throw StorageFormatException(_type, field, reason);

  void _validate() {
    if (!isUlid(id)) _fail('<id>', 'document id is not a ULID');
    if (entityId.isEmpty) _fail(kEntityId, 'empty');
    if (!isUlid(actionId)) _fail(kActionId, 'not a ULID');
    final reverts = revertsActionId;
    if (reverts != null && !isUlid(reverts)) {
      _fail(kRevertsActionId, 'not a ULID');
    }
    if (after.isEmpty) _fail(kAfter, 'no changed fields');
    if (before.length != after.length ||
        !before.keys.every(after.containsKey)) {
      _fail(kBefore, 'before and after must cover the same keys');
    }
    for (final key in after.keys) {
      final parsed = ChangedFieldKey.tryParse(key);
      if (parsed == null) _fail(kAfter, 'malformed changed-field key');
      if (parsed.collection != entity.collection) {
        _fail(kAfter, 'changed field outside the entity collection');
      }
      // AD-38 entity ↔ doc mapping: an entry may not claim entity A while
      // its changed fields address document B (audit and undo would then
      // describe, and revert, the wrong doc).
      if (entity.docIdIsEntityId && parsed.docId != entityId) {
        _fail(kAfter, 'changed field on a document other than entity_id');
      }
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ChangeLogEntry &&
      other.id == id &&
      other.entity == entity &&
      other.entityId == entityId &&
      other.actionId == actionId &&
      other.revertsActionId == revertsActionId &&
      storageValueEquals(other.before, before) &&
      storageValueEquals(other.after, after) &&
      other.at == at &&
      other.actor == actor &&
      other.originalAt == originalAt;

  @override
  int get hashCode => Object.hash(
    id,
    entity,
    entityId,
    actionId,
    revertsActionId,
    storageValueHash(before),
    storageValueHash(after),
    at,
    actor,
    originalAt,
  );

  @override
  String toString() => 'ChangeLogEntry($id, ${entity.storage}/$entityId)';
}

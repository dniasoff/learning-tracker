/// AD-31 / AD-52 learning event — `learning_events/{ulid}`, the only record
/// of learning.
///
/// Time access is deliberately narrow (AD-31 "Effective instant"): the raw
/// `recorded_at` / `original_recorded_at` instants are private to this
/// library. Rule code reads an event's time only through [effectiveAt]; the
/// AD-54 clock-skew rule alone uses [rawRecordedAtForSkewRule]. Both live in
/// `learning_event_time.dart` (a part of this library).
library;

import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';

part 'learning_event_time.dart';

/// `kind` storage enum.
enum LearningEventKind {
  /// Something was learnt.
  learn('learn'),

  /// Cancels the `learn` event named by `target_id`.
  void_('void');

  const LearningEventKind(this.storage);

  /// The exact storage string.
  final String storage;

  /// Storage string → value.
  static final Map<String, LearningEventKind> byStorage = {
    for (final k in values) k.storage: k,
  };
}

/// `date_state` storage enum.
enum DateState {
  /// Learnt on `learned_on`, recorded the same day.
  dated('dated'),

  /// Learnt on a locked day, recorded in the catch-up window (AD-40).
  catchUp('catch_up'),

  /// Learnt before tracking began; `learned_on` may be null and `ref` may
  /// be a node carrying `level`.
  beforeTracking('before_tracking');

  const DateState(this.storage);

  /// The exact storage string.
  final String storage;

  /// Storage string → value.
  static final Map<String, DateState> byStorage = {
    for (final s in values) s.storage: s,
  };
}

/// One `learning_events/{ulid}` document.
///
/// Construct with [LearningEvent.learn] or [LearningEvent.voidOf]. The
/// constructors do not validate; [toStorage] and [LearningEvent.fromStorage]
/// both run the full AD-52 / AD-31 field-combination check and throw
/// [StorageFormatException] on any violation, so an invalid event can be
/// neither written nor read.
final class LearningEvent {
  /// A `learn` event.
  LearningEvent.learn({
    required this.id,
    required String this.curriculumId,
    required String this.ref,
    required String this.source,
    required DateState this.dateState,
    required this.learnedOn,
    required DateTime recordedAt,
    required this.actor,
    this.level,
    this.stage,
    DateTime? originalRecordedAt,
    this.targetId,
    this.revertsActionId,
  }) : kind = LearningEventKind.learn,
       _recordedAt = recordedAt.toUtc(),
       _originalRecordedAt = originalRecordedAt?.toUtc();

  /// A `void` event cancelling [targetId].
  LearningEvent.voidOf({
    required this.id,
    required String this.targetId,
    required DateTime recordedAt,
    required this.actor,
    this.revertsActionId,
    DateTime? originalRecordedAt,
    this.curriculumId,
    this.ref,
    this.source,
    this.dateState,
    this.learnedOn,
    this.level,
    this.stage,
  }) : kind = LearningEventKind.void_,
       _recordedAt = recordedAt.toUtc(),
       _originalRecordedAt = originalRecordedAt?.toUtc();

  LearningEvent._decoded({
    required this.id,
    required this.kind,
    required this.curriculumId,
    required this.ref,
    required this.level,
    required this.source,
    required this.dateState,
    required this.learnedOn,
    required this.stage,
    required this.targetId,
    required this.revertsActionId,
    required DateTime? originalRecordedAt,
    required DateTime recordedAt,
    required this.actor,
  }) : _recordedAt = recordedAt,
       _originalRecordedAt = originalRecordedAt;

  /// Strict decode of the document [id] with storage [map].
  ///
  /// Rejects unknown keys, invalid enum values, a missing required key, a
  /// non-ULID id and every invalid field combination [toStorage] rejects.
  factory LearningEvent.fromStorage(String id, Map<String, Object?> map) {
    final r = StorageReader(_type, map)..requireOnly(storageKeys);
    final kind = r.requiredEnum(kKind, LearningEventKind.byStorage);
    final isLearn = kind == LearningEventKind.learn;
    final event = LearningEvent._decoded(
      id: id,
      kind: kind,
      curriculumId: isLearn
          ? r.requiredString(kCurriculumId)
          : r.optional<String>(kCurriculumId),
      ref: isLearn ? r.requiredString(kRef) : r.optional<String>(kRef),
      level: r.optional<String>(kLevel),
      source: isLearn ? r.requiredString(kSource) : r.optional<String>(kSource),
      dateState: isLearn
          ? r.requiredEnum(kDateState, DateState.byStorage)
          : r.optionalEnum(kDateState, DateState.byStorage),
      learnedOn: isLearn
          ? r.requiredNullable<String>(kLearnedOn)
          : r.optional<String>(kLearnedOn),
      stage: r.optional<int>(kStage),
      targetId: r.optional<String>(kTargetId),
      revertsActionId: r.optional<String>(kRevertsActionId),
      originalRecordedAt: r.optionalInstant(kOriginalRecordedAt),
      recordedAt: r.requiredInstant(kRecordedAt),
      actor: Actor.fromStorage(asStorageMap(_type, kActor, map[kActor])),
    );
    if (!isLearn) {
      // A void carries no learn-only key at all — not even an explicit
      // null — so a decoded void can never be re-emitted differently.
      for (final key in learnOnlyKeys) {
        if (map.containsKey(key)) {
          throw StorageFormatException(_type, key, 'learn-only');
        }
      }
    }
    return event.._validate();
  }

  static const _type = 'LearningEvent';

  /// Storage key `kind`.
  static const kKind = 'kind';

  /// Storage key `curriculum_id`.
  static const kCurriculumId = 'curriculum_id';

  /// Storage key `ref`.
  static const kRef = 'ref';

  /// Storage key `level`.
  static const kLevel = 'level';

  /// Storage key `source`.
  static const kSource = 'source';

  /// Storage key `date_state`.
  static const kDateState = 'date_state';

  /// Storage key `learned_on`.
  static const kLearnedOn = 'learned_on';

  /// Storage key `stage`.
  static const kStage = 'stage';

  /// Storage key `target_id`.
  static const kTargetId = 'target_id';

  /// Storage key `reverts_action_id`.
  static const kRevertsActionId = 'reverts_action_id';

  /// Storage key `original_recorded_at`.
  static const kOriginalRecordedAt = 'original_recorded_at';

  /// Storage key `recorded_at`.
  static const kRecordedAt = 'recorded_at';

  /// Storage key `actor`.
  static const kActor = 'actor';

  /// `source` value for the main track (otherwise a sub-track ULID).
  static const sourceMain = 'main';

  /// The full AD-52 `learning_events` key set (the rules' `hasOnly`).
  static const Set<String> storageKeys = {
    kKind,
    kCurriculumId,
    kRef,
    kLevel,
    kSource,
    kDateState,
    kLearnedOn,
    kStage,
    kTargetId,
    kRevertsActionId,
    kOriginalRecordedAt,
    kRecordedAt,
    kActor,
  };

  /// Keys only a `learn` event may carry.
  static const Set<String> learnOnlyKeys = {
    kCurriculumId,
    kRef,
    kLevel,
    kSource,
    kDateState,
    kLearnedOn,
    kStage,
  };

  /// The client ULID, also the document id (AD-31, parent AD-5).
  final String id;

  /// `learn` or `void`.
  final LearningEventKind kind;

  /// CurriculumId storage key (learn only).
  final String? curriculumId;

  /// sefariaRef — a leaf, or a node for `before_tracking` (learn only).
  final String? ref;

  /// ContentIndex level, only on a `before_tracking` node ref.
  final String? level;

  /// `main` or a sub-track ULID (learn only).
  final String? source;

  /// How [learnedOn] relates to the recording time (learn only).
  final DateState? dateState;

  /// `YYYY-MM-DD` civil date; null only for `before_tracking` (learn only).
  final String? learnedOn;

  /// Stage order, `source == main` only.
  final int? stage;

  /// ULID of the learn event a void cancels (void only).
  final String? targetId;

  /// Id of the undone capture, only on voids written by an undo.
  final String? revertsActionId;

  final DateTime _recordedAt;
  final DateTime? _originalRecordedAt;

  /// The event's author.
  final Actor actor;

  /// Whether this is a `learn` event.
  bool get isLearn => kind == LearningEventKind.learn;

  /// Whether this is a `void` event.
  bool get isVoid => kind == LearningEventKind.void_;

  /// Encodes this event to its AD-52 storage map.
  ///
  /// Emits only [storageKeys]; optional keys are omitted when null, except
  /// `learned_on`, which a learn event always carries (null only for
  /// `before_tracking`). Throws [StorageFormatException] on any invalid
  /// field combination (AC-3). Timestamps are UTC [DateTime]s — the
  /// repository converts them; no server timestamp is ever emitted (AD-46).
  Map<String, Object?> toStorage() {
    _validate();
    return {
      kKind: kind.storage,
      if (isLearn) ...{
        kCurriculumId: curriculumId,
        kRef: ref,
        if (level != null) kLevel: level,
        kSource: source,
        kDateState: dateState!.storage,
        kLearnedOn: learnedOn,
        if (stage != null) kStage: stage,
      },
      if (targetId != null) kTargetId: targetId,
      if (revertsActionId != null) kRevertsActionId: revertsActionId,
      if (_originalRecordedAt != null) kOriginalRecordedAt: _originalRecordedAt,
      kRecordedAt: _recordedAt,
      kActor: actor.toStorage(),
    };
  }

  Never _fail(String field, String reason) =>
      throw StorageFormatException(_type, field, reason);

  void _validate() {
    if (!isUlid(id)) _fail('<id>', 'document id is not a ULID');
    if (isVoid) {
      final target = targetId;
      if (target == null) _fail(kTargetId, 'void requires target_id');
      if (!isUlid(target)) _fail(kTargetId, 'not a ULID');
      if (curriculumId != null) _fail(kCurriculumId, 'learn-only');
      if (ref != null) _fail(kRef, 'learn-only');
      if (level != null) _fail(kLevel, 'learn-only');
      if (source != null) _fail(kSource, 'learn-only');
      if (dateState != null) _fail(kDateState, 'learn-only');
      if (learnedOn != null) _fail(kLearnedOn, 'learn-only');
      if (stage != null) _fail(kStage, 'learn-only');
      final reverts = revertsActionId;
      if (reverts != null && !isUlid(reverts)) {
        _fail(kRevertsActionId, 'not a ULID');
      }
    } else {
      if (targetId != null) _fail(kTargetId, 'learn must not carry target_id');
      if (revertsActionId != null) {
        _fail(kRevertsActionId, 'only on voids written by an undo');
      }
      if (curriculumId == null || curriculumId!.isEmpty) {
        _fail(kCurriculumId, 'required for learn');
      }
      if (ref == null || ref!.isEmpty) _fail(kRef, 'required for learn');
      final src = source;
      if (src == null) _fail(kSource, 'required for learn');
      if (src != sourceMain && !isUlid(src)) {
        _fail(kSource, 'must be main or a sub-track ULID');
      }
      final state = dateState;
      if (state == null) _fail(kDateState, 'required for learn');
      if (level != null) {
        if (state != DateState.beforeTracking) {
          _fail(kLevel, 'only on a before_tracking event');
        }
        if (level!.isEmpty) _fail(kLevel, 'empty');
      }
      if (stage != null) {
        if (src != sourceMain) _fail(kStage, 'only when source == main');
        if (stage! < 0) _fail(kStage, 'negative stage order');
      }
      final date = learnedOn;
      if (date == null) {
        if (state != DateState.beforeTracking) {
          _fail(kLearnedOn, 'null only for before_tracking');
        }
      } else if (!isCivilDate(date)) {
        _fail(kLearnedOn, 'not a valid YYYY-MM-DD date');
      }
    }
  }

  @override
  bool operator ==(Object other) =>
      other is LearningEvent &&
      other.id == id &&
      other.kind == kind &&
      other.curriculumId == curriculumId &&
      other.ref == ref &&
      other.level == level &&
      other.source == source &&
      other.dateState == dateState &&
      other.learnedOn == learnedOn &&
      other.stage == stage &&
      other.targetId == targetId &&
      other.revertsActionId == revertsActionId &&
      other._originalRecordedAt == _originalRecordedAt &&
      other._recordedAt == _recordedAt &&
      other.actor == actor;

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    curriculumId,
    ref,
    level,
    source,
    dateState,
    learnedOn,
    stage,
    targetId,
    revertsActionId,
    _originalRecordedAt,
    _recordedAt,
    actor,
  );

  @override
  String toString() => 'LearningEvent($id, ${kind.storage})';
}

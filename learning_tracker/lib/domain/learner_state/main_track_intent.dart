/// AD-35 `mainTrackIntent` — the governed main-track configuration of ONE
/// curriculum, as the engine consumes it: track, order, program, study
/// days, stages and scope.
///
/// **Not a stored document.** There is no `main_track_intent` collection
/// and this type introduces no storage key. It is assembled from the
/// AD-38 governed docs it names, and its codec is the set of those docs,
/// keyed `{collection}/{docId}` exactly like `change_log.before/after`
/// prefixes ([MainTrackIntent.toStorageDocs] /
/// [MainTrackIntent.fromStorageDocs]).
///
/// These collections pre-date the sub-tracks epic and their docs still
/// carry retired or unrelated fields (e.g. `curriculum_tracks.purged`,
/// `updated_at`). Decoding is therefore a **projection**: the AD-52 keys
/// are read and validated strictly, every other key is dropped and never
/// re-emitted. Only `curriculum_tracks`, `profile_programs` and
/// `track_learning_order` have typed AD-52 rows; `study_day_configs`,
/// `stage_definitions` and `curriculum_scopes` are carried as
/// [MainTrackConfigDoc]s (governance keys typed, payload opaque) until the
/// engine-planning story types them.
library;

import 'package:learning_tracker/domain/learner_state/storage_codec.dart';

/// `curriculum_tracks.state` storage enum.
enum MainTrackState {
  /// Evaluated for plan and streak (when not ended).
  active('active'),

  /// Retired by the learner.
  retired('retired'),

  /// Archived.
  archived('archived');

  const MainTrackState(this.storage);

  /// The exact storage string.
  final String storage;

  /// Storage string → value.
  static final Map<String, MainTrackState> byStorage = {
    for (final s in values) s.storage: s,
  };
}

/// Shared governance keys every AD-38 governed doc carries.
abstract final class GovernedKeys {
  /// Storage key `curriculum_id` (required, immutable).
  static const curriculumId = 'curriculum_id';

  /// Storage key `last_change_id`.
  static const lastChangeId = 'last_change_id';

  /// Storage key `ended_at`.
  static const endedAt = 'ended_at';

  /// All three.
  static const Set<String> all = {curriculumId, lastChangeId, endedAt};

  /// Retired from governed docs (AD-38); dropped by every projection.
  static const Set<String> retired = {'updated_at', 'synced_at'};
}

/// `curriculum_tracks/{curriculumId}` — the `mainTrack` entity.
final class MainTrack {
  /// Creates a main-track doc value.
  MainTrack({
    required this.curriculumId,
    required this.state,
    this.lastChangeId,
    DateTime? endedAt,
  }) : endedAt = endedAt?.toUtc();

  /// Projects the AD-52 keys out of a `curriculum_tracks` doc.
  factory MainTrack.fromStorage(String docId, Map<String, Object?> map) {
    final r = StorageReader(_type, map);
    final track = MainTrack(
      curriculumId: r.requiredString(GovernedKeys.curriculumId),
      state: r.requiredEnum(kState, MainTrackState.byStorage),
      lastChangeId: r.optionalUlid(GovernedKeys.lastChangeId),
      endedAt: r.optionalInstant(GovernedKeys.endedAt),
    );
    if (docId != track.curriculumId) {
      throw const StorageFormatException(_type, '<id>', 'doc id != curriculum');
    }
    return track;
  }

  static const _type = 'MainTrack';

  /// Collection name.
  static const collection = 'curriculum_tracks';

  /// Storage key `state`.
  static const kState = 'state';

  /// The AD-52 key set.
  static const Set<String> storageKeys = {kState, ...GovernedKeys.all};

  /// CurriculumId storage key (also the doc id).
  final String curriculumId;

  /// Lifecycle state.
  final MainTrackState state;

  /// Last governed change.
  final String? lastChangeId;

  /// Removal tombstone (UTC).
  final DateTime? endedAt;

  /// Encodes the AD-52 keys only.
  Map<String, Object?> toStorage() => {
    kState: state.storage,
    GovernedKeys.curriculumId: curriculumId,
    if (lastChangeId != null) GovernedKeys.lastChangeId: lastChangeId,
    if (endedAt != null) GovernedKeys.endedAt: endedAt,
  };

  @override
  bool operator ==(Object other) =>
      other is MainTrack &&
      other.curriculumId == curriculumId &&
      other.state == state &&
      other.lastChangeId == lastChangeId &&
      other.endedAt == endedAt;

  @override
  int get hashCode => Object.hash(curriculumId, state, lastChangeId, endedAt);
}

/// `profile_programs/{curriculumId}` — the `mainTrackProgram` entity.
final class MainTrackProgram {
  /// Creates a program doc value.
  MainTrackProgram({
    required this.curriculumId,
    this.programId,
    this.trackingStartDate,
    this.trackingStartRef,
    this.lastChangeId,
    DateTime? endedAt,
  }) : endedAt = endedAt?.toUtc();

  /// Projects the AD-52 keys out of a `profile_programs` doc.
  factory MainTrackProgram.fromStorage(String docId, Map<String, Object?> map) {
    final r = StorageReader(_type, map);
    final program = MainTrackProgram(
      curriculumId: r.requiredString(GovernedKeys.curriculumId),
      programId: r.optional<String>(kProgramId),
      trackingStartDate: r.optional<String>(kTrackingStartDate),
      trackingStartRef: r.optional<String>(kTrackingStartRef),
      lastChangeId: r.optionalUlid(GovernedKeys.lastChangeId),
      endedAt: r.optionalInstant(GovernedKeys.endedAt),
    );
    if (docId != program.curriculumId) {
      throw const StorageFormatException(_type, '<id>', 'doc id != curriculum');
    }
    return program.._validate();
  }

  static const _type = 'MainTrackProgram';

  /// Collection name.
  static const collection = 'profile_programs';

  /// Storage key `program_id`.
  static const kProgramId = 'program_id';

  /// Storage key `tracking_start_date`.
  static const kTrackingStartDate = 'tracking_start_date';

  /// Storage key `tracking_start_ref`.
  static const kTrackingStartRef = 'tracking_start_ref';

  /// The AD-52 key set.
  static const Set<String> storageKeys = {
    kProgramId,
    kTrackingStartDate,
    kTrackingStartRef,
    ...GovernedKeys.all,
  };

  /// CurriculumId storage key (also the doc id).
  final String curriculumId;

  /// Calendar program id, or null for a self-paced track.
  final String? programId;

  /// `YYYY-MM-DD`; required when [programId] is set.
  final String? trackingStartDate;

  /// sefariaRef the learner started tracking from.
  final String? trackingStartRef;

  /// Last governed change.
  final String? lastChangeId;

  /// Tombstone (UTC).
  final DateTime? endedAt;

  void _validate() {
    final date = trackingStartDate;
    if (programId != null && date == null) {
      throw const StorageFormatException(
        _type,
        kTrackingStartDate,
        'required when program_id is set',
      );
    }
    if (date != null && !isCivilDate(date)) {
      throw const StorageFormatException(
        _type,
        kTrackingStartDate,
        'not a civil date',
      );
    }
  }

  /// Encodes the AD-52 keys only; optional keys omitted while null.
  Map<String, Object?> toStorage() {
    _validate();
    return {
      if (programId != null) kProgramId: programId,
      if (trackingStartDate != null) kTrackingStartDate: trackingStartDate,
      if (trackingStartRef != null) kTrackingStartRef: trackingStartRef,
      GovernedKeys.curriculumId: curriculumId,
      if (lastChangeId != null) GovernedKeys.lastChangeId: lastChangeId,
      if (endedAt != null) GovernedKeys.endedAt: endedAt,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is MainTrackProgram &&
      other.curriculumId == curriculumId &&
      other.programId == programId &&
      other.trackingStartDate == trackingStartDate &&
      other.trackingStartRef == trackingStartRef &&
      other.lastChangeId == lastChangeId &&
      other.endedAt == endedAt;

  @override
  int get hashCode => Object.hash(
    curriculumId,
    programId,
    trackingStartDate,
    trackingStartRef,
    lastChangeId,
    endedAt,
  );
}

/// `track_learning_order/{c}_{level}_{ref}` — one `mainTrackOrder` doc.
final class MainTrackOrderEntry {
  /// Creates an order entry.
  MainTrackOrderEntry({
    required this.docId,
    required this.curriculumId,
    required this.level,
    required this.ref,
    required this.userSortOrder,
    required this.lastChangeId,
    DateTime? endedAt,
  }) : endedAt = endedAt?.toUtc();

  /// Projects the AD-52 keys out of a `track_learning_order` doc.
  factory MainTrackOrderEntry.fromStorage(
    String docId,
    Map<String, Object?> map,
  ) {
    final r = StorageReader(_type, map);
    return MainTrackOrderEntry(
      docId: docId,
      curriculumId: r.requiredString(GovernedKeys.curriculumId),
      level: r.requiredString(kLevel),
      ref: r.requiredString(kRef),
      userSortOrder: r.required<int>(kUserSortOrder),
      lastChangeId: r.requiredUlid(GovernedKeys.lastChangeId),
      endedAt: r.optionalInstant(GovernedKeys.endedAt),
    );
  }

  static const _type = 'MainTrackOrderEntry';

  /// Collection name.
  static const collection = 'track_learning_order';

  /// Storage key `level`.
  static const kLevel = 'level';

  /// Storage key `ref`.
  static const kRef = 'ref';

  /// Storage key `user_sort_order`.
  static const kUserSortOrder = 'user_sort_order';

  /// The AD-52 key set.
  static const Set<String> storageKeys = {
    kLevel,
    kRef,
    kUserSortOrder,
    ...GovernedKeys.all,
  };

  /// Document id.
  final String docId;

  /// CurriculumId storage key.
  final String curriculumId;

  /// ContentIndex level of [ref].
  final String level;

  /// sefariaRef of the ordered node.
  final String ref;

  /// Learner sort position.
  final int userSortOrder;

  /// Last governed change.
  final String lastChangeId;

  /// Tombstone (UTC).
  final DateTime? endedAt;

  /// Encodes the AD-52 keys only.
  Map<String, Object?> toStorage() => {
    kLevel: level,
    kRef: ref,
    kUserSortOrder: userSortOrder,
    GovernedKeys.curriculumId: curriculumId,
    GovernedKeys.lastChangeId: lastChangeId,
    if (endedAt != null) GovernedKeys.endedAt: endedAt,
  };

  @override
  bool operator ==(Object other) =>
      other is MainTrackOrderEntry &&
      other.docId == docId &&
      other.curriculumId == curriculumId &&
      other.level == level &&
      other.ref == ref &&
      other.userSortOrder == userSortOrder &&
      other.lastChangeId == lastChangeId &&
      other.endedAt == endedAt;

  @override
  int get hashCode => Object.hash(
    docId,
    curriculumId,
    level,
    ref,
    userSortOrder,
    lastChangeId,
    endedAt,
  );
}

/// A `study_day_configs` / `stage_definitions` / `curriculum_scopes` doc:
/// AD-38 governance keys typed, the entity's own fields carried opaquely in
/// [fields] (retired `updated_at` / `synced_at` dropped).
final class MainTrackConfigDoc {
  /// Creates a config doc value.
  MainTrackConfigDoc({
    required this.collection,
    required this.docId,
    required this.curriculumId,
    required Map<String, Object?> fields,
    this.lastChangeId,
    DateTime? endedAt,
  }) : fields = Map.unmodifiable(fields),
       endedAt = endedAt?.toUtc();

  /// Projects a config doc of [collection].
  factory MainTrackConfigDoc.fromStorage(
    String collection,
    String docId,
    Map<String, Object?> map,
  ) {
    if (!collections.contains(collection)) {
      throw StorageFormatException(_type, '<collection>', collection);
    }
    final r = StorageReader(_type, map);
    return MainTrackConfigDoc(
      collection: collection,
      docId: docId,
      curriculumId: r.requiredString(GovernedKeys.curriculumId),
      lastChangeId: r.optionalUlid(GovernedKeys.lastChangeId),
      endedAt: r.optionalInstant(GovernedKeys.endedAt),
      fields: {
        for (final entry in map.entries)
          if (!GovernedKeys.all.contains(entry.key) &&
              !GovernedKeys.retired.contains(entry.key))
            entry.key: entry.value,
      },
    );
  }

  static const _type = 'MainTrackConfigDoc';

  /// `study_day_configs` (`mainTrackStudyDays`).
  static const studyDays = 'study_day_configs';

  /// `stage_definitions` (`mainTrackStages`).
  static const stages = 'stage_definitions';

  /// `curriculum_scopes` (`mainTrackScope`).
  static const scope = 'curriculum_scopes';

  /// The three config collections.
  static const Set<String> collections = {studyDays, stages, scope};

  /// Owning collection.
  final String collection;

  /// Document id.
  final String docId;

  /// CurriculumId storage key.
  final String curriculumId;

  /// The entity's own (not yet typed) fields.
  final Map<String, Object?> fields;

  /// Last governed change.
  final String? lastChangeId;

  /// Tombstone (UTC).
  final DateTime? endedAt;

  /// Encodes [fields] plus the governance keys.
  Map<String, Object?> toStorage() => {
    ...fields,
    GovernedKeys.curriculumId: curriculumId,
    if (lastChangeId != null) GovernedKeys.lastChangeId: lastChangeId,
    if (endedAt != null) GovernedKeys.endedAt: endedAt,
  };

  @override
  bool operator ==(Object other) =>
      other is MainTrackConfigDoc &&
      other.collection == collection &&
      other.docId == docId &&
      other.curriculumId == curriculumId &&
      storageValueEquals(other.fields, fields) &&
      other.lastChangeId == lastChangeId &&
      other.endedAt == endedAt;

  @override
  int get hashCode => Object.hash(
    collection,
    docId,
    curriculumId,
    storageValueHash(fields),
    lastChangeId,
    endedAt,
  );
}

/// The governed main-track intent of one curriculum (AD-35 input).
final class MainTrackIntent {
  /// Creates an intent value.
  MainTrackIntent({
    required this.curriculumId,
    required this.track,
    this.program,
    List<MainTrackOrderEntry> order = const [],
    List<MainTrackConfigDoc> studyDays = const [],
    List<MainTrackConfigDoc> stages = const [],
    this.scope,
  }) : order = List.unmodifiable(order),
       studyDays = List.unmodifiable(studyDays),
       stages = List.unmodifiable(stages) {
    _validate();
  }

  /// Assembles an intent from its governed docs, keyed
  /// `{collection}/{docId}`. Exactly one `curriculum_tracks` doc is
  /// required; at most one `profile_programs` and one `curriculum_scopes`
  /// doc; any other collection is rejected.
  factory MainTrackIntent.fromStorageDocs(
    String curriculumId,
    Map<String, Map<String, Object?>> docs,
  ) {
    MainTrack? track;
    MainTrackProgram? program;
    MainTrackConfigDoc? scope;
    final order = <MainTrackOrderEntry>[];
    final studyDays = <MainTrackConfigDoc>[];
    final stages = <MainTrackConfigDoc>[];
    for (final entry in docs.entries) {
      final slash = entry.key.indexOf('/');
      if (slash <= 0 || slash == entry.key.length - 1) {
        throw StorageFormatException(_type, entry.key, 'malformed doc key');
      }
      final collection = entry.key.substring(0, slash);
      final docId = entry.key.substring(slash + 1);
      switch (collection) {
        case MainTrack.collection:
          if (track != null) _duplicate(collection);
          track = MainTrack.fromStorage(docId, entry.value);
        case MainTrackProgram.collection:
          if (program != null) _duplicate(collection);
          program = MainTrackProgram.fromStorage(docId, entry.value);
        case MainTrackOrderEntry.collection:
          order.add(MainTrackOrderEntry.fromStorage(docId, entry.value));
        case MainTrackConfigDoc.studyDays:
          studyDays.add(
            MainTrackConfigDoc.fromStorage(collection, docId, entry.value),
          );
        case MainTrackConfigDoc.stages:
          stages.add(
            MainTrackConfigDoc.fromStorage(collection, docId, entry.value),
          );
        case MainTrackConfigDoc.scope:
          if (scope != null) _duplicate(collection);
          scope = MainTrackConfigDoc.fromStorage(
            collection,
            docId,
            entry.value,
          );
        default:
          throw StorageFormatException(_type, collection, 'not main-track');
      }
    }
    final resolvedTrack = track;
    if (resolvedTrack == null) {
      throw const StorageFormatException(
        _type,
        MainTrack.collection,
        'missing curriculum_tracks doc',
      );
    }
    return MainTrackIntent(
      curriculumId: curriculumId,
      track: resolvedTrack,
      program: program,
      order: order,
      studyDays: studyDays,
      stages: stages,
      scope: scope,
    );
  }

  static const _type = 'MainTrackIntent';

  static Never _duplicate(String collection) =>
      throw StorageFormatException(_type, collection, 'duplicate doc');

  /// CurriculumId storage key every member doc carries.
  final String curriculumId;

  /// `curriculum_tracks/{curriculumId}`.
  final MainTrack track;

  /// `profile_programs/{curriculumId}`, if any.
  final MainTrackProgram? program;

  /// `track_learning_order` docs.
  final List<MainTrackOrderEntry> order;

  /// `study_day_configs` docs.
  final List<MainTrackConfigDoc> studyDays;

  /// `stage_definitions` docs.
  final List<MainTrackConfigDoc> stages;

  /// `curriculum_scopes` doc, if any.
  final MainTrackConfigDoc? scope;

  /// AD-35: evaluated for plan and streak only while active and not ended.
  /// While the track has `ended_at`, readers treat its other governed docs
  /// as ended too (AD-38 track lifecycle).
  bool get isEvaluated =>
      track.state == MainTrackState.active && track.endedAt == null;

  /// The member docs keyed `{collection}/{docId}`, each holding only its
  /// AD-52 keys (config docs: their payload plus governance keys).
  Map<String, Map<String, Object?>> toStorageDocs() => {
    '${MainTrack.collection}/$curriculumId': track.toStorage(),
    if (program != null)
      '${MainTrackProgram.collection}/$curriculumId': program!.toStorage(),
    for (final e in order)
      '${MainTrackOrderEntry.collection}/${e.docId}': e.toStorage(),
    for (final d in studyDays) '${d.collection}/${d.docId}': d.toStorage(),
    for (final d in stages) '${d.collection}/${d.docId}': d.toStorage(),
    if (scope != null)
      '${scope!.collection}/${scope!.docId}': scope!.toStorage(),
  };

  void _validate() {
    void check(String member, String docCurriculum) {
      if (docCurriculum != curriculumId) {
        throw StorageFormatException(_type, member, 'curriculum_id mismatch');
      }
    }

    check(MainTrack.collection, track.curriculumId);
    if (program != null) {
      check(MainTrackProgram.collection, program!.curriculumId);
    }
    for (final e in order) {
      check(MainTrackOrderEntry.collection, e.curriculumId);
    }
    for (final d in [...studyDays, ...stages, ?scope]) {
      check(d.collection, d.curriculumId);
    }
    for (final d in studyDays) {
      if (d.collection != MainTrackConfigDoc.studyDays) {
        throw StorageFormatException(_type, d.collection, 'not study days');
      }
    }
    for (final d in stages) {
      if (d.collection != MainTrackConfigDoc.stages) {
        throw StorageFormatException(_type, d.collection, 'not stages');
      }
    }
    final s = scope;
    if (s != null && s.collection != MainTrackConfigDoc.scope) {
      throw StorageFormatException(_type, s.collection, 'not scope');
    }
  }
}

/// AD-52 sub-track — `sub_tracks/{ulid}`, a governed entity (AD-38
/// `subTrack`).
library;

import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';

/// `type` storage enum.
enum SubTrackType {
  /// Bound to an academic year (`academic_year` required).
  schoolYear('school_year'),

  /// Open-ended (`academic_year` forbidden).
  ongoing('ongoing');

  const SubTrackType(this.storage);

  /// The exact storage string.
  final String storage;

  /// Storage string → value.
  static final Map<String, SubTrackType> byStorage = {
    for (final t in values) t.storage: t,
  };
}

/// `end_reason` storage enum — why a sub-track was tombstoned.
enum SubTrackEndReason {
  /// The learner ended it.
  ended('ended'),

  /// The learner deleted it (still a tombstone; client delete is denied).
  deleted('deleted'),

  /// An undo of its creation.
  undo('undo'),

  /// Its curriculum's main track was removed (AD-38 track lifecycle).
  trackDeleted('track_deleted');

  const SubTrackEndReason(this.storage);

  /// The exact storage string.
  final String storage;

  /// Storage string → value.
  static final Map<String, SubTrackEndReason> byStorage = {
    for (final r in values) r.storage: r,
  };
}

/// One `sub_tracks/{ulid}` document.
///
/// [toStorage] and [SubTrack.fromStorage] validate the full AD-52 contract
/// and throw [StorageFormatException] on any violation.
final class SubTrack {
  /// Creates a sub-track value.
  SubTrack({
    required this.id,
    required this.curriculumId,
    required this.name,
    required this.type,
    required this.windowStart,
    required this.ratePerWeek,
    required this.weeksPerYear,
    required this.learnsOnShabbos,
    required List<NodeEntry> ground,
    required this.lastChangeId,
    this.academicYear,
    this.windowEnd,
    DateTime? endedAt,
    this.endReason,
  }) : ground = List.unmodifiable(ground),
       endedAt = endedAt?.toUtc();

  /// Strict decode of document [id] with storage [map].
  factory SubTrack.fromStorage(String id, Map<String, Object?> map) {
    final r = StorageReader(_type, map)..requireOnly(storageKeys);
    final rawGround = r.requiredList(kGround);
    final track = SubTrack(
      id: id,
      curriculumId: r.requiredString(kCurriculumId),
      name: r.required<String>(kName),
      type: r.requiredEnum(kType, SubTrackType.byStorage),
      academicYear: r.optional<int>(kAcademicYear),
      windowStart: r.requiredString(kWindowStart),
      windowEnd: r.optional<String>(kWindowEnd),
      ratePerWeek: r.requiredNumber(kRatePerWeek),
      weeksPerYear: r.requiredNumber(kWeeksPerYear),
      learnsOnShabbos: r.required<bool>(kLearnsOnShabbos),
      ground: [
        for (final entry in rawGround)
          NodeEntry.fromStorage(asStorageMap(_type, kGround, entry)),
      ],
      endedAt: r.optionalInstant(kEndedAt),
      endReason: r.optionalEnum(kEndReason, SubTrackEndReason.byStorage),
      lastChangeId: r.requiredUlid(kLastChangeId),
    );
    return track.._validate();
  }

  static const _type = 'SubTrack';

  /// Storage key `curriculum_id`.
  static const kCurriculumId = 'curriculum_id';

  /// Storage key `name`.
  static const kName = 'name';

  /// Storage key `type`.
  static const kType = 'type';

  /// Storage key `academic_year`.
  static const kAcademicYear = 'academic_year';

  /// Storage key `window_start`.
  static const kWindowStart = 'window_start';

  /// Storage key `window_end`.
  static const kWindowEnd = 'window_end';

  /// Storage key `rate_per_week`.
  static const kRatePerWeek = 'rate_per_week';

  /// Storage key `weeks_per_year`.
  static const kWeeksPerYear = 'weeks_per_year';

  /// Storage key `learns_on_shabbos`.
  static const kLearnsOnShabbos = 'learns_on_shabbos';

  /// Storage key `ground`.
  static const kGround = 'ground';

  /// Storage key `ended_at`.
  static const kEndedAt = 'ended_at';

  /// Storage key `end_reason`.
  static const kEndReason = 'end_reason';

  /// Storage key `last_change_id`.
  static const kLastChangeId = 'last_change_id';

  /// The AD-52 `sub_tracks` key set (the rules' `hasOnly`).
  static const Set<String> storageKeys = {
    kCurriculumId,
    kName,
    kType,
    kAcademicYear,
    kWindowStart,
    kWindowEnd,
    kRatePerWeek,
    kWeeksPerYear,
    kLearnsOnShabbos,
    kGround,
    kEndedAt,
    kEndReason,
    kLastChangeId,
  };

  /// Fields a governed change may set. `last_change_id` is excluded: the
  /// write port stamps it from the change-log entry id (AD-38).
  static const Set<String> governedFieldKeys = {
    kCurriculumId,
    kName,
    kType,
    kAcademicYear,
    kWindowStart,
    kWindowEnd,
    kRatePerWeek,
    kWeeksPerYear,
    kLearnsOnShabbos,
    kGround,
    kEndedAt,
    kEndReason,
  };

  /// The sub-track ULID (document id; `change_log.entity_id`).
  final String id;

  /// CurriculumId storage key.
  final String curriculumId;

  /// Learner-facing name.
  final String name;

  /// `school_year` or `ongoing`.
  final SubTrackType type;

  /// Civil year the academic year starts; `school_year` only.
  final int? academicYear;

  /// `YYYY-MM-DD` inclusive window start.
  final String windowStart;

  /// `YYYY-MM-DD` inclusive window end; null = open.
  final String? windowEnd;

  /// Leaf units per week.
  final double ratePerWeek;

  /// Study weeks per year.
  final double weeksPerYear;

  /// Whether the learner studies this sub-track on shabbos.
  final bool learnsOnShabbos;

  /// The sub-track's ground, in list order (AD-34).
  final List<NodeEntry> ground;

  /// Tombstone instant (UTC), or null while live.
  final DateTime? endedAt;

  /// Tombstone reason, set iff [endedAt] is set.
  final SubTrackEndReason? endReason;

  /// The id of the `change_log` entry that last wrote this doc.
  final String lastChangeId;

  /// Whether this sub-track is tombstoned.
  bool get isEnded => endedAt != null;

  /// Validates one storage-form field [value] for a governed field-level
  /// write (AD-38). Only [governedFieldKeys] are accepted; `academic_year`,
  /// `window_end`, `ended_at` and `end_reason` may be `null` (= absent /
  /// open / live), every other field must be present and well-typed.
  /// Cross-field rules that need the stored doc (e.g. `academic_year` vs
  /// `type`) are the command layer's job.
  static void validateGovernedField(String key, Object? value) {
    Never fail(String reason) =>
        throw StorageFormatException(_type, key, reason);
    if (!governedFieldKeys.contains(key)) fail('not a governed field');
    switch (key) {
      case kCurriculumId:
      case kName:
        if (value is! String || (key == kCurriculumId && value.isEmpty)) {
          fail('expected non-empty string');
        }
      case kType:
        if (value is! String || !SubTrackType.byStorage.containsKey(value)) {
          fail('invalid enum value');
        }
      case kAcademicYear:
        if (value != null && value is! int) fail('expected int');
      case kWindowStart:
        if (value is! String || !isCivilDate(value)) fail('not a civil date');
      case kWindowEnd:
        if (value != null && (value is! String || !isCivilDate(value))) {
          fail('not a civil date');
        }
      case kRatePerWeek:
      case kWeeksPerYear:
        if (value is! num || !value.isFinite || value < 0) {
          fail('not a non-negative number');
        }
      case kLearnsOnShabbos:
        if (value is! bool) fail('expected bool');
      case kGround:
        if (value is! List<Object?>) fail('expected list');
        for (final entry in value) {
          NodeEntry.fromStorage(asStorageMap(_type, kGround, entry));
        }
      case kEndedAt:
        if (value != null && value is! DateTime) fail('expected timestamp');
      case kEndReason:
        if (value != null &&
            (value is! String ||
                !SubTrackEndReason.byStorage.containsKey(value))) {
          fail('invalid enum value');
        }
    }
  }

  /// Encodes this sub-track to its AD-52 storage map.
  ///
  /// `window_end` is always emitted (null = open); `academic_year`,
  /// `ended_at` and `end_reason` are omitted while null.
  Map<String, Object?> toStorage() {
    _validate();
    return {
      kCurriculumId: curriculumId,
      kName: name,
      kType: type.storage,
      if (academicYear != null) kAcademicYear: academicYear,
      kWindowStart: windowStart,
      kWindowEnd: windowEnd,
      kRatePerWeek: ratePerWeek,
      kWeeksPerYear: weeksPerYear,
      kLearnsOnShabbos: learnsOnShabbos,
      kGround: [for (final entry in ground) entry.toStorage()],
      if (endedAt != null) kEndedAt: endedAt,
      if (endReason != null) kEndReason: endReason!.storage,
      kLastChangeId: lastChangeId,
    };
  }

  Never _fail(String field, String reason) =>
      throw StorageFormatException(_type, field, reason);

  void _validate() {
    if (!isUlid(id)) _fail('<id>', 'document id is not a ULID');
    if (curriculumId.isEmpty) _fail(kCurriculumId, 'empty');
    if (type == SubTrackType.schoolYear && academicYear == null) {
      _fail(kAcademicYear, 'required for school_year');
    }
    if (type == SubTrackType.ongoing && academicYear != null) {
      _fail(kAcademicYear, 'school_year only');
    }
    if (!isCivilDate(windowStart)) _fail(kWindowStart, 'not a civil date');
    final end = windowEnd;
    if (end != null) {
      if (!isCivilDate(end)) _fail(kWindowEnd, 'not a civil date');
      if (end.compareTo(windowStart) < 0) {
        _fail(kWindowEnd, 'before window_start');
      }
    }
    if (!ratePerWeek.isFinite || ratePerWeek < 0) {
      _fail(kRatePerWeek, 'not a non-negative number');
    }
    if (!weeksPerYear.isFinite || weeksPerYear < 0) {
      _fail(kWeeksPerYear, 'not a non-negative number');
    }
    if ((endedAt == null) != (endReason == null)) {
      _fail(kEndReason, 'ended_at and end_reason must be set together');
    }
    if (!isUlid(lastChangeId)) _fail(kLastChangeId, 'not a ULID');
    for (final entry in ground) {
      entry.toStorage();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is SubTrack &&
      other.id == id &&
      other.curriculumId == curriculumId &&
      other.name == name &&
      other.type == type &&
      other.academicYear == academicYear &&
      other.windowStart == windowStart &&
      other.windowEnd == windowEnd &&
      other.ratePerWeek == ratePerWeek &&
      other.weeksPerYear == weeksPerYear &&
      other.learnsOnShabbos == learnsOnShabbos &&
      _listEquals(other.ground, ground) &&
      other.endedAt == endedAt &&
      other.endReason == endReason &&
      other.lastChangeId == lastChangeId;

  @override
  int get hashCode => Object.hash(
    id,
    curriculumId,
    name,
    type,
    academicYear,
    windowStart,
    windowEnd,
    ratePerWeek,
    weeksPerYear,
    learnsOnShabbos,
    Object.hashAll(ground),
    endedAt,
    endReason,
    lastChangeId,
  );

  @override
  String toString() => 'SubTrack($id, ${type.storage})';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

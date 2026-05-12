import 'package:drift/drift.dart';

/// Curriculum tracks table — stores track activation state per curriculum.
///
/// V1 uses a single track per curriculum (`personal`). The [trackType]
/// column is retained for historical rows and future use but should always
/// be `'personal'` for new writes.
class CurriculumTracks extends Table {
  /// Auto-increment primary key for FK references from other tables.
  IntColumn get id => integer().autoIncrement()();

  IntColumn get profileId => integer().withDefault(const Constant(0))();

  /// curriculum_id from CurriculumId enum storageKey
  TextColumn get curriculumId => text()();

  /// track_type from TrackType enum storageKey
  TextColumn get trackType => text()();

  /// Whether this track is currently active for this curriculum
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// When this track was activated (or reactivated) for this curriculum
  DateTimeColumn get activatedAt => dateTime()();

  /// When this track was last deactivated (null if currently active)
  DateTimeColumn get deactivatedAt => dateTime().nullable()();

  /// Date when pace was last reset (for Reset Pace recovery action).
  /// Null if pace has never been reset.
  DateTimeColumn get paceResetDate => dateTime().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {profileId, curriculumId, trackType},
  ];
}

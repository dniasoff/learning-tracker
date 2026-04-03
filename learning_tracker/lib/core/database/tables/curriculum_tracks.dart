import 'package:drift/drift.dart';

/// Curriculum tracks table — stores track activation state per curriculum.
///
/// Each curriculum starts with personal track only. School and tutor tracks
/// can be activated/deactivated per curriculum. Deactivating a track hides
/// it but preserves completion data.
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

  /// When this track was archived (null if not archived).
  /// Archived tracks are hidden from dashboard/scheduler but data is preserved.
  DateTimeColumn get archivedAt => dateTime().nullable()();

  /// Date when pace was last reset (for Reset Pace recovery action).
  /// Null if pace has never been reset.
  DateTimeColumn get paceResetDate => dateTime().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {profileId, curriculumId, trackType},
  ];
}

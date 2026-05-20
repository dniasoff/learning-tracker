import 'package:drift/drift.dart';

/// Curriculum tracks table — stores track activation state per curriculum.
///
/// V1 uses a single track per curriculum (`personal`). The `trackType`
/// column has been removed in W3.22 — all tracks are `personal` and the
/// UNIQUE constraint is now (profileId, curriculumId).
///
/// W3.28/W3.29: replaced ad-hoc `isActive`/`deletedAt`/`deactivatedAt`
/// tombstone columns with a single unified `state` enum column
/// (active | retired | archived | deleted) and a `stateChangedAt` timestamp.
class CurriculumTracks extends Table {
  /// Auto-increment primary key for FK references from other tables.
  IntColumn get id => integer().autoIncrement()();

  IntColumn get profileId => integer()();

  /// curriculum_id from CurriculumId enum storageKey
  TextColumn get curriculumId => text()();

  /// Unified lifecycle state. One of: 'active', 'retired', 'archived', 'deleted'.
  ///
  /// active  — track is in use; displayed in the UI.
  /// retired — track was deactivated by the user; hidden but not purged.
  /// archived — track reached a natural completion milestone.
  /// deleted — track was soft-deleted (deleteTrackAndData); awaits purge.
  TextColumn get state => text().withDefault(const Constant('active'))();

  /// When [state] was last changed (UTC). Acts as the LWW timestamp for sync.
  DateTimeColumn get stateChangedAt => dateTime()();

  /// When this track was activated (or reactivated) for this curriculum.
  DateTimeColumn get activatedAt => dateTime()();

  /// Date when pace was last reset (for Reset Pace recovery action).
  /// Null if pace has never been reset.
  DateTimeColumn get paceResetDate => dateTime().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {profileId, curriculumId},
  ];
}

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
  /// archived — user chose "Archive (keep history)" over deleting the track
  ///   (TrackDao.archiveTrack); config data (goals/stages/point config/etc.)
  ///   is preserved for possible reactivation, unlike 'deleted'.
  /// deleted — track was soft-deleted (deleteTrackAndData); config data was
  ///   hard-deleted and the row awaits purge.
  TextColumn get state => text().withDefault(const Constant('active'))();

  /// When [state] was last changed (UTC). Acts as the LWW timestamp for sync.
  DateTimeColumn get stateChangedAt => dateTime()();

  /// When this track was activated (or reactivated) for this curriculum.
  DateTimeColumn get activatedAt => dateTime()();

  /// Date when pace was last reset (for Reset Pace recovery action).
  /// Null if pace has never been reset.
  DateTimeColumn get paceResetDate => dateTime().nullable()();

  /// UTC timestamp of the most recent content-order change for this track.
  ///
  /// Set to [activatedAt] on track creation so the initial (default) order is
  /// treated as "just reordered" and no prior tasks are amnestied on first
  /// activation. Updated every time the user reorders sedarim, masechtos, or
  /// whole-curriculum items for this track.
  ///
  /// The projection filter uses this to filter out overdue items whose
  /// [scheduledDate] is strictly before this timestamp — i.e. items that were
  /// scheduled before the last reorder are amnestied (cleared) and will
  /// re-project from today's date forward.
  ///
  /// Null rows (from rows created before this column existed) are treated as
  /// [DateTime.fromMillisecondsSinceEpoch(0)] — "never amnestied" — so all
  /// historic overdue tasks remain visible.
  DateTimeColumn get lastReorderAt => dateTime().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {profileId, curriculumId},
  ];
}

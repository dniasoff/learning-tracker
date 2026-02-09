import 'package:drift/drift.dart';

/// Curriculum tracks table — stores track activation state per curriculum.
///
/// Each curriculum starts with personal track only. School and tutor tracks
/// can be activated/deactivated per curriculum. Deactivating a track hides
/// it but preserves completion data.
class CurriculumTracks extends Table {
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

  @override
  Set<Column> get primaryKey => {curriculumId, trackType};
}

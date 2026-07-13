import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/learner_profiles.dart';

/// Per-track custom learning order (sedarim/masechtos reordering).
///
/// AUD-t-cross-06 (schema v36): this table holds a specific profile's
/// personal reordering preference within their own track — it is NOT
/// shared/global content — so, like every other user-data leaf table
/// (Bookmarks, Goals, StreakEvents, ...), it must carry `profileId` as
/// part of its keying surface. Before this, isolation depended entirely
/// on `trackId` never being confused across profiles: a caching or
/// profile-switch bug that reused a stale `trackId` could silently
/// read/write another profile's custom ordering with no schema-level
/// guard to catch it, and rows were never purged on profile delete
/// (no FK at all — see `ProfileDao._wipeNonCascadingMirrorRows`).
class TrackLearningOrder extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// AUD-t-cross-06: FK → learner_profiles(id) CASCADE DELETE.
  IntColumn get profileId =>
      integer().references(LearnerProfiles, #id, onDelete: KeyAction.cascade)();
  IntColumn get trackId => integer()();
  TextColumn get sefariaRef => text()();
  IntColumn get sortOrder => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {profileId, trackId, sefariaRef},
  ];
}

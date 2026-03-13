import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/database/tables/curriculum_tracks.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';

part 'track_dao.g.dart';

@DriftAccessor(tables: [CurriculumTracks])
class TrackDao extends DatabaseAccessor<AppDatabase> with _$TrackDaoMixin {
  TrackDao(super.db);

  /// Get all active tracks for a curriculum.
  ///
  /// Returns only tracks where isActive = true.
  Future<List<CurriculumTrack>> getActiveTracks(CurriculumId curriculumId) =>
      (select(curriculumTracks)..where(
            (t) =>
                t.curriculumId.equals(curriculumId.storageKey) &
                t.isActive.equals(true),
          ))
          .get();

  /// Get all tracks (active and inactive) for a curriculum.
  Future<List<CurriculumTrack>> getAllTracks(CurriculumId curriculumId) =>
      (select(
        curriculumTracks,
      )..where((t) => t.curriculumId.equals(curriculumId.storageKey))).get();

  /// Check if a specific track is active for a curriculum.
  Future<bool> isTrackActive(
    CurriculumId curriculumId,
    TrackType trackType,
  ) async {
    final track =
        await (select(curriculumTracks)..where(
              (t) =>
                  t.curriculumId.equals(curriculumId.storageKey) &
                  t.trackType.equals(trackType.storageKey),
            ))
            .getSingleOrNull();

    return track?.isActive ?? false;
  }

  /// Activate a track for a curriculum.
  ///
  /// If the track doesn't exist, creates it. If it exists and is inactive,
  /// reactivates it with a new activatedAt timestamp.
  Future<void> activateTrack(
    CurriculumId curriculumId,
    TrackType trackType,
  ) async {
    final existing =
        await (select(curriculumTracks)..where(
              (t) =>
                  t.curriculumId.equals(curriculumId.storageKey) &
                  t.trackType.equals(trackType.storageKey),
            ))
            .getSingleOrNull();

    if (existing == null) {
      // Create new active track
      await into(curriculumTracks).insert(
        CurriculumTracksCompanion.insert(
          curriculumId: curriculumId.storageKey,
          trackType: trackType.storageKey,
          isActive: const Value(true),
          activatedAt: DateTimeFactory.nowUtc(),
        ),
      );
    } else if (!existing.isActive) {
      // Reactivate existing track
      await (update(curriculumTracks)..where(
            (t) =>
                t.curriculumId.equals(curriculumId.storageKey) &
                t.trackType.equals(trackType.storageKey),
          ))
          .write(
            CurriculumTracksCompanion(
              isActive: const Value(true),
              activatedAt: Value(DateTimeFactory.nowUtc()),
              deactivatedAt: const Value(null),
            ),
          );
    }
    // If already active, do nothing
  }

  /// Deactivate a track for a curriculum.
  ///
  /// Cannot deactivate the personal track. Preserves the track record
  /// (doesn't delete) to maintain history.
  Future<void> deactivateTrack(
    CurriculumId curriculumId,
    TrackType trackType,
  ) async {
    if (trackType == TrackType.personal) {
      throw const InvalidOperationException(
        'Cannot deactivate personal track - it is always active',
      );
    }

    final existing =
        await (select(curriculumTracks)..where(
              (t) =>
                  t.curriculumId.equals(curriculumId.storageKey) &
                  t.trackType.equals(trackType.storageKey),
            ))
            .getSingleOrNull();

    if (existing != null && existing.isActive) {
      await (update(curriculumTracks)..where(
            (t) =>
                t.curriculumId.equals(curriculumId.storageKey) &
                t.trackType.equals(trackType.storageKey),
          ))
          .write(
            CurriculumTracksCompanion(
              isActive: const Value(false),
              deactivatedAt: Value(DateTimeFactory.nowUtc()),
            ),
          );
    }
  }

  /// Initialize default tracks for a curriculum.
  ///
  /// Creates only the personal track (active by default).
  /// Should be called when a curriculum is first activated.
  Future<void> initializeDefaultTracks(CurriculumId curriculumId) async {
    final existing = await (select(
      curriculumTracks,
    )..where((t) => t.curriculumId.equals(curriculumId.storageKey))).get();

    if (existing.isEmpty) {
      await into(curriculumTracks).insert(
        CurriculumTracksCompanion.insert(
          curriculumId: curriculumId.storageKey,
          trackType: TrackType.personal.storageKey,
          isActive: const Value(true),
          activatedAt: DateTimeFactory.nowUtc(),
        ),
      );
    }
  }
}

/// Exception thrown when attempting an invalid track operation.
class InvalidOperationException implements Exception {
  const InvalidOperationException(this.message);
  final String message;

  @override
  String toString() => 'InvalidOperationException: $message';
}

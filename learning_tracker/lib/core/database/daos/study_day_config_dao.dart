import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/daos/dao_invariant_error.dart';
import 'package:learning_tracker/core/database/tables/curriculum_tracks.dart';
import 'package:learning_tracker/core/database/tables/study_day_configs.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';

part 'study_day_config_dao.g.dart';

@DriftAccessor(tables: [StudyDayConfigs, CurriculumTracks])
class StudyDayConfigDao extends DatabaseAccessor<UserDatabase>
    with _$StudyDayConfigDaoMixin {
  StudyDayConfigDao(super.db);

  /// Get study day configs for a curriculum and profile.
  Future<List<StudyDayConfig>> getConfigsByCurriculumAndProfile(
    String curriculumId,
    int profileId,
  ) =>
      (select(studyDayConfigs)
            ..where(
              (t) =>
                  t.curriculumId.equals(curriculumId) &
                  t.profileId.equals(profileId),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.dayOfWeek)]))
          .get();

  /// Watch study day configs reactively.
  Stream<List<StudyDayConfig>> watchConfigsByCurriculumAndProfile(
    String curriculumId,
    int profileId,
  ) =>
      (select(studyDayConfigs)
            ..where(
              (t) =>
                  t.curriculumId.equals(curriculumId) &
                  t.profileId.equals(profileId),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.dayOfWeek)]))
          .watch();

  /// Upsert a single day config.
  Future<void> upsertDayConfig({
    required int profileId,
    required String curriculumId,
    required int trackId,
    required int dayOfWeek,
    required String dayType,
  }) async {
    await into(studyDayConfigs).insertOnConflictUpdate(
      StudyDayConfigsCompanion.insert(
        profileId: profileId,
        curriculumId: curriculumId,
        trackId: trackId,
        dayOfWeek: dayOfWeek,
        dayType: Value(dayType),
        updatedAt: DateTimeFactory.nowUtc(),
      ),
    );
  }

  /// Upsert a single day config carrying an explicit [updatedAt] — used by
  /// the sync merge path, where the LWW timestamp is the REMOTE row's
  /// `updated_at`, not "now" ([upsertDayConfig] above always stamps `now`,
  /// which is correct for local edits but wrong for applying a pulled
  /// remote value).
  ///
  /// AUD-core-sync-22 (DB-1): extracted from StudyDayConfigMerger, which
  /// previously wrote `_db.into(_db.studyDayConfigs)` directly.
  Future<void> upsertDayConfigFromSync({
    required int profileId,
    required String curriculumId,
    required int trackId,
    required int dayOfWeek,
    required String dayType,
    required DateTime updatedAt,
  }) async {
    await into(studyDayConfigs).insertOnConflictUpdate(
      StudyDayConfigsCompanion.insert(
        profileId: profileId,
        curriculumId: curriculumId,
        trackId: trackId,
        dayOfWeek: dayOfWeek,
        dayType: Value(dayType),
        updatedAt: updatedAt,
      ),
    );
  }

  /// Seed default configs (all 7 days as 'study') for a curriculum/profile.
  Future<void> seedDefaults({
    required int profileId,
    required String curriculumId,
    required int trackId,
  }) async {
    final now = DateTimeFactory.nowUtc();
    for (var day = 1; day <= 7; day++) {
      await into(studyDayConfigs).insertOnConflictUpdate(
        StudyDayConfigsCompanion.insert(
          profileId: profileId,
          curriculumId: curriculumId,
          trackId: trackId,
          dayOfWeek: day,
          dayType: const Value('study'),
          updatedAt: now,
        ),
      );
    }
  }

  /// Replace all study-day configs for [trackId]: delete existing rows for
  /// (curriculumId, profileId), then batch-insert the new set in a single
  /// round trip.
  ///
  /// AUD-tracks-19 (Fowler duplication + DB-3): TrackCreationService and
  /// TrackEditService previously each carried a byte-for-byte-identical
  /// private "delete then loop-await-upsert" method; this is now the one
  /// shared implementation both call, and the per-row awaited loop is
  /// replaced by a single `batch()`. Callers already run this inside their
  /// own `transaction()`, so `batch()` reuses it rather than opening a new
  /// one (DB-2).
  Future<void> replaceAllForTrack({
    required int profileId,
    required String curriculumId,
    required int trackId,
    required Map<int, String> studyDays,
  }) async {
    await deleteConfigsByCurriculumAndProfile(curriculumId, profileId);
    if (studyDays.isEmpty) return;
    final now = DateTimeFactory.nowUtc();
    await batch((b) {
      b.insertAll(studyDayConfigs, [
        for (final entry in studyDays.entries)
          StudyDayConfigsCompanion.insert(
            profileId: profileId,
            curriculumId: curriculumId,
            trackId: trackId,
            dayOfWeek: entry.key,
            dayType: Value(entry.value),
            updatedAt: now,
          ),
      ]);
    });
  }

  /// Delete all configs for a specific track (used when hard-deleting a track).
  Future<int> deleteConfigsForTrack(int trackId) =>
      (delete(studyDayConfigs)..where((t) => t.trackId.equals(trackId))).go();

  /// Delete all configs for a curriculum/profile.
  Future<int> deleteConfigsByCurriculumAndProfile(
    String curriculumId,
    int profileId,
  ) =>
      (delete(studyDayConfigs)..where(
            (t) =>
                t.curriculumId.equals(curriculumId) &
                t.profileId.equals(profileId),
          ))
          .go();

  /// Check if a specific day is a study day.
  Future<bool> isStudyDay({
    required int profileId,
    required String curriculumId,
    required int dayOfWeek,
  }) async {
    final config =
        await (select(studyDayConfigs)..where(
              (t) =>
                  t.profileId.equals(profileId) &
                  t.curriculumId.equals(curriculumId) &
                  t.dayOfWeek.equals(dayOfWeek),
            ))
            .getSingleOrNull();
    // Default to study if no config exists
    return config == null || config.dayType == 'study';
  }

  /// Get count of study days per week for a curriculum/profile.
  Future<int> getStudyDaysPerWeek({
    required int profileId,
    required String curriculumId,
  }) async {
    final configs = await getConfigsByCurriculumAndProfile(
      curriculumId,
      profileId,
    );
    if (configs.isEmpty) return 7; // default all days are study
    return configs.where((c) => c.dayType == 'study').length;
  }

  // ========== Track-Scoped Queries (Story 20.2) ==========

  /// Get study day configs for a specific track.
  Future<List<StudyDayConfig>> getConfigsByTrack(int trackId) =>
      (select(studyDayConfigs)
            ..where((t) => t.trackId.equals(trackId))
            ..orderBy([(t) => OrderingTerm.asc(t.dayOfWeek)]))
          .get();

  /// Watch study day configs for a specific track reactively.
  Stream<List<StudyDayConfig>> watchConfigsByTrack(int trackId) =>
      (select(studyDayConfigs)
            ..where((t) => t.trackId.equals(trackId))
            ..orderBy([(t) => OrderingTerm.asc(t.dayOfWeek)]))
          .watch();

  /// Check if a specific day is a study day for a track.
  Future<bool> isStudyDayForTrack({
    required int trackId,
    required int dayOfWeek,
  }) async {
    final config =
        await (select(studyDayConfigs)..where(
              (t) => t.trackId.equals(trackId) & t.dayOfWeek.equals(dayOfWeek),
            ))
            .getSingleOrNull();
    return config == null || config.dayType == 'study';
  }

  /// Get count of study days per week for a track.
  Future<int> getStudyDaysPerWeekForTrack({required int trackId}) async {
    final configs = await getConfigsByTrack(trackId);
    if (configs.isEmpty) return 7;
    return configs.where((c) => c.dayType == 'study').length;
  }

  /// Inclusive count of dates in [startInclusive, endInclusive] (calendar
  /// days, time ignored) whose [DateTime.weekday] is a study day for [trackId].
  ///
  /// Used to spread deadline goals across actual study days (not a 5/7
  /// approximation). Monday = 1 … Sunday = 7 (Dart [DateTime.weekday]).
  Future<int> countStudyDaysInInclusiveDateRangeForTrack({
    required int trackId,
    required DateTime startInclusive,
    required DateTime endInclusive,
  }) async {
    final configs = await getConfigsByTrack(trackId);
    final Set<int> studyWeekdays;
    if (configs.isEmpty) {
      studyWeekdays = {1, 2, 3, 4, 5, 6, 7};
    } else {
      studyWeekdays = {
        for (final c in configs)
          if (c.dayType == 'study') c.dayOfWeek,
      };
    }
    if (studyWeekdays.isEmpty) return 0;

    var d = DateTime(
      startInclusive.year,
      startInclusive.month,
      startInclusive.day,
    );
    final end = DateTime(
      endInclusive.year,
      endInclusive.month,
      endInclusive.day,
    );
    if (d.isAfter(end)) return 0;

    var n = 0;
    while (!d.isAfter(end)) {
      if (studyWeekdays.contains(d.weekday)) n++;
      d = d.add(const Duration(days: 1));
    }
    return n;
  }

  /// Seed default 7-day 'study' configs for a track.
  ///
  /// Per Epic 20 / DNI-212 — track-only API. Looks up the owning profile
  /// and curriculum from `curriculum_tracks` so callers don't need to
  /// pass them explicitly.
  Future<void> seedDefaultsForTrack({required int trackId}) async {
    final track = await (select(
      curriculumTracks,
    )..where((t) => t.id.equals(trackId))).getSingleOrNull();
    if (track == null) {
      // AUD-core-database-14 (EH-5): stable code, not a pre-formatted
      // English message. trackId carried as debugDetail for logs only.
      throw DaoInvariantError(DaoErrorCode.studyDayTrackNotFound, trackId);
    }
    await seedDefaults(
      profileId: track.profileId,
      curriculumId: track.curriculumId,
      trackId: trackId,
    );
  }

  /// Get the latest updatedAt timestamp across all day configs for a curriculum.
  Future<DateTime?> getLatestUpdatedAt({
    required int profileId,
    required String curriculumId,
  }) async {
    final configs = await getConfigsByCurriculumAndProfile(
      curriculumId,
      profileId,
    );
    if (configs.isEmpty) return null;
    return configs
        .map((c) => c.updatedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }
}

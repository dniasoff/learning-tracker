import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/database/tables/study_day_configs.dart';

part 'study_day_config_dao.g.dart';

@DriftAccessor(tables: [StudyDayConfigs])
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
        profileId: Value(profileId),
        curriculumId: curriculumId,
        trackId: trackId,
        dayOfWeek: dayOfWeek,
        dayType: Value(dayType),
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  /// Seed default configs (all 7 days as 'study') for a curriculum/profile.
  Future<void> seedDefaults({
    required int profileId,
    required String curriculumId,
    required int trackId,
  }) async {
    final now = DateTime.now().toUtc();
    for (var day = 1; day <= 7; day++) {
      await into(studyDayConfigs).insertOnConflictUpdate(
        StudyDayConfigsCompanion.insert(
          profileId: Value(profileId),
          curriculumId: curriculumId,
          trackId: trackId,
          dayOfWeek: day,
          dayType: const Value('study'),
          updatedAt: now,
        ),
      );
    }
  }

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
              (t) =>
                  t.trackId.equals(trackId) & t.dayOfWeek.equals(dayOfWeek),
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

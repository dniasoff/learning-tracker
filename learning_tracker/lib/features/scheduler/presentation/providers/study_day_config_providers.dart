import 'package:drift/drift.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';
import 'package:learning_tracker/features/scheduler/domain/models/study_day_config.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'study_day_config_providers.g.dart';

/// Watch study day configs for a curriculum reactively as domain models.
@riverpod
Stream<List<StudyDayConfigEntry>> studyDayConfigs(
  Ref ref,
  CurriculumId curriculumId,
) {
  final db = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  return db.studyDayConfigDao
      .watchConfigsByCurriculumAndProfile(curriculumId.storageKey, profileId)
      .map(
        (rows) => rows
            .map(
              (r) => StudyDayConfigEntry(
                dayOfWeek: r.dayOfWeek,
                dayType: DayType.fromStorageKey(r.dayType),
              ),
            )
            .toList(),
      );
}

/// Check if today is a study day for a curriculum.
@riverpod
Future<bool> isStudyDay(Ref ref, CurriculumId curriculumId) async {
  final db = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final today = ref.watch(clockProvider);
  return db.studyDayConfigDao.isStudyDay(
    profileId: profileId,
    curriculumId: curriculumId.storageKey,
    dayOfWeek: today.weekday,
  );
}

/// Get count of study days per week for a curriculum.
@riverpod
Future<int> studyDaysPerWeek(Ref ref, CurriculumId curriculumId) async {
  final db = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  return db.studyDayConfigDao.getStudyDaysPerWeek(
    profileId: profileId,
    curriculumId: curriculumId.storageKey,
  );
}

/// Toggle a day between study and review.
///
/// DEPRECATED / DEAD CODE — this provider has no call sites. The production
/// toggle path is `study_day_config_screen.dart:_toggleDay`, which correctly
/// pushes sync and invalidates the scheduler after the DB write completes.
/// This provider is kept only to avoid regenerating build_runner output;
/// it must not be used because:
///   1. It does not push sync (no syncFacade call).
///   2. ref.invalidate(allDailyTasksProvider) fires before the write completes
///      (STUDYDAY-TOGGLE-RACE-14 — fixed in the screen's _toggleDay).
@riverpod
Future<void> toggleStudyDay(
  Ref ref,
  CurriculumId curriculumId,
  int dayOfWeek,
  DayType newType,
) async {
  final db = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  // Look up trackId for this curriculum
  final track =
      await (db.select(db.curriculumTracks)
            ..where(
              (t) =>
                  t.profileId.equals(profileId) &
                  t.curriculumId.equals(curriculumId.storageKey),
            )
            ..limit(1))
          .getSingleOrNull();
  // STUDYDAY-COMPANION-10: skip the write if the track does not exist rather
  // than falling back to trackId=0, which violates the FK constraint on
  // study_day_configs.track_id → curriculum_tracks.id.
  final trackId = track?.id;
  if (trackId == null) return;
  await db.studyDayConfigDao.upsertDayConfig(
    profileId: profileId,
    curriculumId: curriculumId.storageKey,
    trackId: trackId,
    dayOfWeek: dayOfWeek,
    dayType: newType.storageKey,
  );
  // Invalidate scheduler so tasks regenerate.
  // BUG: this fires before the write completes (STUDYDAY-TOGGLE-RACE-14).
  // Do not use this provider — see study_day_config_screen._toggleDay instead.
  ref.invalidate(allDailyTasksProvider);
}

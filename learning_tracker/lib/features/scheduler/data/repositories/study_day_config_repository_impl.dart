import 'package:learning_tracker/core/database/daos/study_day_config_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart'
    as db
    show StudyDayConfig;
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';
import 'package:learning_tracker/features/scheduler/domain/models/study_day_config.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/study_day_config_repository.dart';

class StudyDayConfigRepositoryImpl implements StudyDayConfigRepository {
  StudyDayConfigRepositoryImpl({
    required StudyDayConfigDao dao,
    required int profileId,
  }) : _dao = dao,
       _profileId = profileId;

  final StudyDayConfigDao _dao;
  final int _profileId;

  List<StudyDayConfigEntry> _mapToEntries(List<db.StudyDayConfig> rows) {
    return rows
        .map(
          (row) => StudyDayConfigEntry(
            dayOfWeek: row.dayOfWeek,
            dayType: DayType.fromStorageKey(row.dayType),
          ),
        )
        .toList();
  }

  @override
  Future<List<StudyDayConfigEntry>> getConfig(CurriculumId curriculumId) async {
    final rows = await _dao.getConfigsByCurriculumAndProfile(
      curriculumId.storageKey,
      _profileId,
    );
    return _mapToEntries(rows);
  }

  @override
  Stream<List<StudyDayConfigEntry>> watchConfig(CurriculumId curriculumId) {
    return _dao
        .watchConfigsByCurriculumAndProfile(curriculumId.storageKey, _profileId)
        .map(_mapToEntries);
  }

  @override
  Future<void> updateDayType(
    CurriculumId curriculumId,
    int dayOfWeek,
    DayType dayType, {
    required int trackId,
  }) async {
    await _dao.upsertDayConfig(
      profileId: _profileId,
      curriculumId: curriculumId.storageKey,
      trackId: trackId,
      dayOfWeek: dayOfWeek,
      dayType: dayType.storageKey,
    );
  }

  @override
  Future<void> seedDefaults(
    CurriculumId curriculumId, {
    required int trackId,
  }) async {
    await _dao.seedDefaults(
      profileId: _profileId,
      curriculumId: curriculumId.storageKey,
      trackId: trackId,
    );
  }

  @override
  Future<bool> isStudyDay(CurriculumId curriculumId, int dayOfWeek) {
    return _dao.isStudyDay(
      profileId: _profileId,
      curriculumId: curriculumId.storageKey,
      dayOfWeek: dayOfWeek,
    );
  }

  @override
  Future<int> getStudyDaysPerWeek(CurriculumId curriculumId) {
    return _dao.getStudyDaysPerWeek(
      profileId: _profileId,
      curriculumId: curriculumId.storageKey,
    );
  }
}

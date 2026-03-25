import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';
import 'package:learning_tracker/features/scheduler/domain/models/study_day_config.dart';

abstract class StudyDayConfigRepository {
  Future<List<StudyDayConfigEntry>> getConfig(CurriculumId curriculumId);
  Stream<List<StudyDayConfigEntry>> watchConfig(CurriculumId curriculumId);
  Future<void> updateDayType(
    CurriculumId curriculumId,
    int dayOfWeek,
    DayType dayType,
  );
  Future<void> seedDefaults(CurriculumId curriculumId);
  Future<bool> isStudyDay(CurriculumId curriculumId, int dayOfWeek);
  Future<int> getStudyDaysPerWeek(CurriculumId curriculumId);
}

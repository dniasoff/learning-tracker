// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'study_day_config_dao.dart';

// ignore_for_file: type=lint
mixin _$StudyDayConfigDaoMixin on DatabaseAccessor<UserDatabase> {
  $CurriculumTracksTable get curriculumTracks =>
      attachedDatabase.curriculumTracks;
  $StudyDayConfigsTable get studyDayConfigs => attachedDatabase.studyDayConfigs;
  StudyDayConfigDaoManager get managers => StudyDayConfigDaoManager(this);
}

class StudyDayConfigDaoManager {
  final _$StudyDayConfigDaoMixin _db;
  StudyDayConfigDaoManager(this._db);
  $$CurriculumTracksTableTableManager get curriculumTracks =>
      $$CurriculumTracksTableTableManager(
        _db.attachedDatabase,
        _db.curriculumTracks,
      );
  $$StudyDayConfigsTableTableManager get studyDayConfigs =>
      $$StudyDayConfigsTableTableManager(
        _db.attachedDatabase,
        _db.studyDayConfigs,
      );
}

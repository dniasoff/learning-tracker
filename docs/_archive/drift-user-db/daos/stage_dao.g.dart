// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stage_dao.dart';

// ignore_for_file: type=lint
mixin _$StageDaoMixin on DatabaseAccessor<UserDatabase> {
  $AccountsTable get accounts => attachedDatabase.accounts;
  $LearnerProfilesTable get learnerProfiles => attachedDatabase.learnerProfiles;
  $CurriculumTracksTable get curriculumTracks =>
      attachedDatabase.curriculumTracks;
  $StageDefinitionsTable get stageDefinitions =>
      attachedDatabase.stageDefinitions;
  StageDaoManager get managers => StageDaoManager(this);
}

class StageDaoManager {
  final _$StageDaoMixin _db;
  StageDaoManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$LearnerProfilesTableTableManager get learnerProfiles =>
      $$LearnerProfilesTableTableManager(
        _db.attachedDatabase,
        _db.learnerProfiles,
      );
  $$CurriculumTracksTableTableManager get curriculumTracks =>
      $$CurriculumTracksTableTableManager(
        _db.attachedDatabase,
        _db.curriculumTracks,
      );
  $$StageDefinitionsTableTableManager get stageDefinitions =>
      $$StageDefinitionsTableTableManager(
        _db.attachedDatabase,
        _db.stageDefinitions,
      );
}

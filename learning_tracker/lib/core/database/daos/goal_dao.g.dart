// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'goal_dao.dart';

// ignore_for_file: type=lint
mixin _$GoalDaoMixin on DatabaseAccessor<UserDatabase> {
  $LearnerProfilesTable get learnerProfiles => attachedDatabase.learnerProfiles;
  $CurriculumTracksTable get curriculumTracks =>
      attachedDatabase.curriculumTracks;
  $GoalsTable get goals => attachedDatabase.goals;
  GoalDaoManager get managers => GoalDaoManager(this);
}

class GoalDaoManager {
  final _$GoalDaoMixin _db;
  GoalDaoManager(this._db);
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
  $$GoalsTableTableManager get goals =>
      $$GoalsTableTableManager(_db.attachedDatabase, _db.goals);
}

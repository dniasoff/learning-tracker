// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'completion_dao.dart';

// ignore_for_file: type=lint
mixin _$CompletionDaoMixin on DatabaseAccessor<UserDatabase> {
  $LearnerProfilesTable get learnerProfiles => attachedDatabase.learnerProfiles;
  $CurriculumTracksTable get curriculumTracks =>
      attachedDatabase.curriculumTracks;
  $CompletionsTable get completions => attachedDatabase.completions;
  CompletionDaoManager get managers => CompletionDaoManager(this);
}

class CompletionDaoManager {
  final _$CompletionDaoMixin _db;
  CompletionDaoManager(this._db);
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
  $$CompletionsTableTableManager get completions =>
      $$CompletionsTableTableManager(_db.attachedDatabase, _db.completions);
}

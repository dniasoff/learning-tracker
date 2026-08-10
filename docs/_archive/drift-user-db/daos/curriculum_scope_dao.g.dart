// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'curriculum_scope_dao.dart';

// ignore_for_file: type=lint
mixin _$CurriculumScopeDaoMixin on DatabaseAccessor<UserDatabase> {
  $AccountsTable get accounts => attachedDatabase.accounts;
  $LearnerProfilesTable get learnerProfiles => attachedDatabase.learnerProfiles;
  $CurriculumTracksTable get curriculumTracks =>
      attachedDatabase.curriculumTracks;
  $CurriculumScopesTable get curriculumScopes =>
      attachedDatabase.curriculumScopes;
  CurriculumScopeDaoManager get managers => CurriculumScopeDaoManager(this);
}

class CurriculumScopeDaoManager {
  final _$CurriculumScopeDaoMixin _db;
  CurriculumScopeDaoManager(this._db);
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
  $$CurriculumScopesTableTableManager get curriculumScopes =>
      $$CurriculumScopesTableTableManager(
        _db.attachedDatabase,
        _db.curriculumScopes,
      );
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'curriculum_scope_dao.dart';

// ignore_for_file: type=lint
mixin _$CurriculumScopeDaoMixin on DatabaseAccessor<UserDatabase> {
  $CurriculumTracksTable get curriculumTracks =>
      attachedDatabase.curriculumTracks;
  $CurriculumScopesTable get curriculumScopes =>
      attachedDatabase.curriculumScopes;
  CurriculumScopeDaoManager get managers => CurriculumScopeDaoManager(this);
}

class CurriculumScopeDaoManager {
  final _$CurriculumScopeDaoMixin _db;
  CurriculumScopeDaoManager(this._db);
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

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'active_curriculum_dao.dart';

// ignore_for_file: type=lint
mixin _$ActiveCurriculumDaoMixin on DatabaseAccessor<UserDatabase> {
  $CurriculumTracksTable get curriculumTracks =>
      attachedDatabase.curriculumTracks;
  ActiveCurriculumDaoManager get managers => ActiveCurriculumDaoManager(this);
}

class ActiveCurriculumDaoManager {
  final _$ActiveCurriculumDaoMixin _db;
  ActiveCurriculumDaoManager(this._db);
  $$CurriculumTracksTableTableManager get curriculumTracks =>
      $$CurriculumTracksTableTableManager(
        _db.attachedDatabase,
        _db.curriculumTracks,
      );
}

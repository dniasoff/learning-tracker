// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'active_curriculum_dao.dart';

// ignore_for_file: type=lint
mixin _$ActiveCurriculumDaoMixin on DatabaseAccessor<UserDatabase> {
  $ActiveCurriculaTable get activeCurricula => attachedDatabase.activeCurricula;
  ActiveCurriculumDaoManager get managers => ActiveCurriculumDaoManager(this);
}

class ActiveCurriculumDaoManager {
  final _$ActiveCurriculumDaoMixin _db;
  ActiveCurriculumDaoManager(this._db);
  $$ActiveCurriculaTableTableManager get activeCurricula =>
      $$ActiveCurriculaTableTableManager(
        _db.attachedDatabase,
        _db.activeCurricula,
      );
}

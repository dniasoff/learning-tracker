// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stage_dao.dart';

// ignore_for_file: type=lint
mixin _$StageDaoMixin on DatabaseAccessor<UserDatabase> {
  $StageDefinitionsTable get stageDefinitions =>
      attachedDatabase.stageDefinitions;
  StageDaoManager get managers => StageDaoManager(this);
}

class StageDaoManager {
  final _$StageDaoMixin _db;
  StageDaoManager(this._db);
  $$StageDefinitionsTableTableManager get stageDefinitions =>
      $$StageDefinitionsTableTableManager(
        _db.attachedDatabase,
        _db.stageDefinitions,
      );
}

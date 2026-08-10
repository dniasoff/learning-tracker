// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'point_config_dao.dart';

// ignore_for_file: type=lint
mixin _$PointConfigDaoMixin on DatabaseAccessor<UserDatabase> {
  $CurriculumTracksTable get curriculumTracks =>
      attachedDatabase.curriculumTracks;
  $PointConfigsTable get pointConfigs => attachedDatabase.pointConfigs;
  PointConfigDaoManager get managers => PointConfigDaoManager(this);
}

class PointConfigDaoManager {
  final _$PointConfigDaoMixin _db;
  PointConfigDaoManager(this._db);
  $$CurriculumTracksTableTableManager get curriculumTracks =>
      $$CurriculumTracksTableTableManager(
        _db.attachedDatabase,
        _db.curriculumTracks,
      );
  $$PointConfigsTableTableManager get pointConfigs =>
      $$PointConfigsTableTableManager(_db.attachedDatabase, _db.pointConfigs);
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'curriculum_hierarchy_config_dao.dart';

// ignore_for_file: type=lint
mixin _$CurriculumHierarchyConfigDaoMixin on DatabaseAccessor<AppDatabase> {
  $CurriculumHierarchyConfigTable get curriculumHierarchyConfig =>
      attachedDatabase.curriculumHierarchyConfig;
  CurriculumHierarchyConfigDaoManager get managers =>
      CurriculumHierarchyConfigDaoManager(this);
}

class CurriculumHierarchyConfigDaoManager {
  final _$CurriculumHierarchyConfigDaoMixin _db;
  CurriculumHierarchyConfigDaoManager(this._db);
  $$CurriculumHierarchyConfigTableTableManager get curriculumHierarchyConfig =>
      $$CurriculumHierarchyConfigTableTableManager(
        _db.attachedDatabase,
        _db.curriculumHierarchyConfig,
      );
}

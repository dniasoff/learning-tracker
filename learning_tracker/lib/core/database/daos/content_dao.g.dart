// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'content_dao.dart';

// ignore_for_file: type=lint
mixin _$ContentDaoMixin on DatabaseAccessor<AppDatabase> {
  $ContentItemsTable get contentItems => attachedDatabase.contentItems;
  ContentDaoManager get managers => ContentDaoManager(this);
}

class ContentDaoManager {
  final _$ContentDaoMixin _db;
  ContentDaoManager(this._db);
  $$ContentItemsTableTableManager get contentItems =>
      $$ContentItemsTableTableManager(_db.attachedDatabase, _db.contentItems);
}

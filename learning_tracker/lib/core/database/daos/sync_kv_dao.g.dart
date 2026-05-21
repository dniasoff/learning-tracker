// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_kv_dao.dart';

// ignore_for_file: type=lint
mixin _$SyncKvDaoMixin on DatabaseAccessor<UserDatabase> {
  $SyncKvTable get syncKv => attachedDatabase.syncKv;
  SyncKvDaoManager get managers => SyncKvDaoManager(this);
}

class SyncKvDaoManager {
  final _$SyncKvDaoMixin _db;
  SyncKvDaoManager(this._db);
  $$SyncKvTableTableManager get syncKv =>
      $$SyncKvTableTableManager(_db.attachedDatabase, _db.syncKv);
}

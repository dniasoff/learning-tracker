// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'text_cache_dao.dart';

// ignore_for_file: type=lint
mixin _$ContentTextCacheDaoMixin on DatabaseAccessor<ContentDatabase> {
  $TextCacheTable get textCache => attachedDatabase.textCache;
  ContentTextCacheDaoManager get managers => ContentTextCacheDaoManager(this);
}

class ContentTextCacheDaoManager {
  final _$ContentTextCacheDaoMixin _db;
  ContentTextCacheDaoManager(this._db);
  $$TextCacheTableTableManager get textCache =>
      $$TextCacheTableTableManager(_db.attachedDatabase, _db.textCache);
}

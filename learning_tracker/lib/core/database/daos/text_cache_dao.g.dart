// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'text_cache_dao.dart';

// ignore_for_file: type=lint
mixin _$TextCacheDaoMixin on DatabaseAccessor<AppDatabase> {
  $TextCacheTable get textCache => attachedDatabase.textCache;
  TextCacheDaoManager get managers => TextCacheDaoManager(this);
}

class TextCacheDaoManager {
  final _$TextCacheDaoMixin _db;
  TextCacheDaoManager(this._db);
  $$TextCacheTableTableManager get textCache =>
      $$TextCacheTableTableManager(_db.attachedDatabase, _db.textCache);
}

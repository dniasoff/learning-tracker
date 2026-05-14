// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_content_dao.dart';

// ignore_for_file: type=lint
mixin _$DailyContentDaoMixin on DatabaseAccessor<ContentDatabase> {
  $DailyContentTable get dailyContent => attachedDatabase.dailyContent;
  DailyContentDaoManager get managers => DailyContentDaoManager(this);
}

class DailyContentDaoManager {
  final _$DailyContentDaoMixin _db;
  DailyContentDaoManager(this._db);
  $$DailyContentTableTableManager get dailyContent =>
      $$DailyContentTableTableManager(_db.attachedDatabase, _db.dailyContent);
}

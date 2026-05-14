// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'streak_event_dao.dart';

// ignore_for_file: type=lint
mixin _$StreakEventDaoMixin on DatabaseAccessor<UserDatabase> {
  $StreakEventsTable get streakEvents => attachedDatabase.streakEvents;
  StreakEventDaoManager get managers => StreakEventDaoManager(this);
}

class StreakEventDaoManager {
  final _$StreakEventDaoMixin _db;
  StreakEventDaoManager(this._db);
  $$StreakEventsTableTableManager get streakEvents =>
      $$StreakEventsTableTableManager(_db.attachedDatabase, _db.streakEvents);
}

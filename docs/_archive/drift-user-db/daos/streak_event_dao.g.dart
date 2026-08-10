// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'streak_event_dao.dart';

// ignore_for_file: type=lint
mixin _$StreakEventDaoMixin on DatabaseAccessor<UserDatabase> {
  $AccountsTable get accounts => attachedDatabase.accounts;
  $LearnerProfilesTable get learnerProfiles => attachedDatabase.learnerProfiles;
  $StreakEventsTable get streakEvents => attachedDatabase.streakEvents;
  StreakEventDaoManager get managers => StreakEventDaoManager(this);
}

class StreakEventDaoManager {
  final _$StreakEventDaoMixin _db;
  StreakEventDaoManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$LearnerProfilesTableTableManager get learnerProfiles =>
      $$LearnerProfilesTableTableManager(
        _db.attachedDatabase,
        _db.learnerProfiles,
      );
  $$StreakEventsTableTableManager get streakEvents =>
      $$StreakEventsTableTableManager(_db.attachedDatabase, _db.streakEvents);
}

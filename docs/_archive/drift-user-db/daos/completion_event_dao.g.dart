// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'completion_event_dao.dart';

// ignore_for_file: type=lint
mixin _$CompletionEventDaoMixin on DatabaseAccessor<UserDatabase> {
  $AccountsTable get accounts => attachedDatabase.accounts;
  $LearnerProfilesTable get learnerProfiles => attachedDatabase.learnerProfiles;
  $CompletionEventsTable get completionEvents =>
      attachedDatabase.completionEvents;
  CompletionEventDaoManager get managers => CompletionEventDaoManager(this);
}

class CompletionEventDaoManager {
  final _$CompletionEventDaoMixin _db;
  CompletionEventDaoManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$LearnerProfilesTableTableManager get learnerProfiles =>
      $$LearnerProfilesTableTableManager(
        _db.attachedDatabase,
        _db.learnerProfiles,
      );
  $$CompletionEventsTableTableManager get completionEvents =>
      $$CompletionEventsTableTableManager(
        _db.attachedDatabase,
        _db.completionEvents,
      );
}

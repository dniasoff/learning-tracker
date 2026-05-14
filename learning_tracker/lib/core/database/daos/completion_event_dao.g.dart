// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'completion_event_dao.dart';

// ignore_for_file: type=lint
mixin _$CompletionEventDaoMixin on DatabaseAccessor<UserDatabase> {
  $CompletionEventsTable get completionEvents =>
      attachedDatabase.completionEvents;
  CompletionEventDaoManager get managers => CompletionEventDaoManager(this);
}

class CompletionEventDaoManager {
  final _$CompletionEventDaoMixin _db;
  CompletionEventDaoManager(this._db);
  $$CompletionEventsTableTableManager get completionEvents =>
      $$CompletionEventsTableTableManager(
        _db.attachedDatabase,
        _db.completionEvents,
      );
}

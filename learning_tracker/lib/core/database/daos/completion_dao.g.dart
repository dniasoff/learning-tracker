// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'completion_dao.dart';

// ignore_for_file: type=lint
mixin _$CompletionDaoMixin on DatabaseAccessor<UserDatabase> {
  $LearnerProfilesTable get learnerProfiles => attachedDatabase.learnerProfiles;
  $CompletionEventsTable get completionEvents =>
      attachedDatabase.completionEvents;
  $CompletionsViewView get completionsView => attachedDatabase.completionsView;
  CompletionDaoManager get managers => CompletionDaoManager(this);
}

class CompletionDaoManager {
  final _$CompletionDaoMixin _db;
  CompletionDaoManager(this._db);
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

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'track_learning_order_dao.dart';

// ignore_for_file: type=lint
mixin _$TrackLearningOrderDaoMixin on DatabaseAccessor<UserDatabase> {
  $AccountsTable get accounts => attachedDatabase.accounts;
  $LearnerProfilesTable get learnerProfiles => attachedDatabase.learnerProfiles;
  $TrackLearningOrderTable get trackLearningOrder =>
      attachedDatabase.trackLearningOrder;
  TrackLearningOrderDaoManager get managers =>
      TrackLearningOrderDaoManager(this);
}

class TrackLearningOrderDaoManager {
  final _$TrackLearningOrderDaoMixin _db;
  TrackLearningOrderDaoManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$LearnerProfilesTableTableManager get learnerProfiles =>
      $$LearnerProfilesTableTableManager(
        _db.attachedDatabase,
        _db.learnerProfiles,
      );
  $$TrackLearningOrderTableTableManager get trackLearningOrder =>
      $$TrackLearningOrderTableTableManager(
        _db.attachedDatabase,
        _db.trackLearningOrder,
      );
}

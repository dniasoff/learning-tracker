// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'learning_order_dao.dart';

// ignore_for_file: type=lint
mixin _$LearningOrderDaoMixin on DatabaseAccessor<UserDatabase> {
  $AccountsTable get accounts => attachedDatabase.accounts;
  $LearnerProfilesTable get learnerProfiles => attachedDatabase.learnerProfiles;
  $LearningOrderTable get learningOrder => attachedDatabase.learningOrder;
  LearningOrderDaoManager get managers => LearningOrderDaoManager(this);
}

class LearningOrderDaoManager {
  final _$LearningOrderDaoMixin _db;
  LearningOrderDaoManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$LearnerProfilesTableTableManager get learnerProfiles =>
      $$LearnerProfilesTableTableManager(
        _db.attachedDatabase,
        _db.learnerProfiles,
      );
  $$LearningOrderTableTableManager get learningOrder =>
      $$LearningOrderTableTableManager(_db.attachedDatabase, _db.learningOrder);
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'learning_order_dao.dart';

// ignore_for_file: type=lint
mixin _$LearningOrderDaoMixin on DatabaseAccessor<AppDatabase> {
  $LearningOrderTable get learningOrder => attachedDatabase.learningOrder;
  LearningOrderDaoManager get managers => LearningOrderDaoManager(this);
}

class LearningOrderDaoManager {
  final _$LearningOrderDaoMixin _db;
  LearningOrderDaoManager(this._db);
  $$LearningOrderTableTableManager get learningOrder =>
      $$LearningOrderTableTableManager(_db.attachedDatabase, _db.learningOrder);
}

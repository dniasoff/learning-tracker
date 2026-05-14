// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'outbox_dao.dart';

// ignore_for_file: type=lint
mixin _$OutboxDaoMixin on DatabaseAccessor<UserDatabase> {
  $OutboxTable get outbox => attachedDatabase.outbox;
  OutboxDaoManager get managers => OutboxDaoManager(this);
}

class OutboxDaoManager {
  final _$OutboxDaoMixin _db;
  OutboxDaoManager(this._db);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db.attachedDatabase, _db.outbox);
}

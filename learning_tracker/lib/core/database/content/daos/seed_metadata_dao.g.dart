// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'seed_metadata_dao.dart';

// ignore_for_file: type=lint
mixin _$SeedMetadataDaoMixin on DatabaseAccessor<ContentDatabase> {
  $SeedMetadataTable get seedMetadata => attachedDatabase.seedMetadata;
  SeedMetadataDaoManager get managers => SeedMetadataDaoManager(this);
}

class SeedMetadataDaoManager {
  final _$SeedMetadataDaoMixin _db;
  SeedMetadataDaoManager(this._db);
  $$SeedMetadataTableTableManager get seedMetadata =>
      $$SeedMetadataTableTableManager(_db.attachedDatabase, _db.seedMetadata);
}

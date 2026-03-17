// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'text_download_status_dao.dart';

// ignore_for_file: type=lint
mixin _$TextDownloadStatusDaoMixin on DatabaseAccessor<AppDatabase> {
  $TextDownloadStatusesTable get textDownloadStatuses =>
      attachedDatabase.textDownloadStatuses;
  TextDownloadStatusDaoManager get managers =>
      TextDownloadStatusDaoManager(this);
}

class TextDownloadStatusDaoManager {
  final _$TextDownloadStatusDaoMixin _db;
  TextDownloadStatusDaoManager(this._db);
  $$TextDownloadStatusesTableTableManager get textDownloadStatuses =>
      $$TextDownloadStatusesTableTableManager(
        _db.attachedDatabase,
        _db.textDownloadStatuses,
      );
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'track_dao.dart';

// ignore_for_file: type=lint
mixin _$TrackDaoMixin on DatabaseAccessor<AppDatabase> {
  $CurriculumTracksTable get curriculumTracks =>
      attachedDatabase.curriculumTracks;
  TrackDaoManager get managers => TrackDaoManager(this);
}

class TrackDaoManager {
  final _$TrackDaoMixin _db;
  TrackDaoManager(this._db);
  $$CurriculumTracksTableTableManager get curriculumTracks =>
      $$CurriculumTracksTableTableManager(
        _db.attachedDatabase,
        _db.curriculumTracks,
      );
}

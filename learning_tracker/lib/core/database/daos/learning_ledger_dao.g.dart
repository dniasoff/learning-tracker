// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'learning_ledger_dao.dart';

// ignore_for_file: type=lint
mixin _$LearningLedgerDaoMixin on DatabaseAccessor<UserDatabase> {
  $CurriculumTracksTable get curriculumTracks =>
      attachedDatabase.curriculumTracks;
  $LearningLedgerTable get learningLedger => attachedDatabase.learningLedger;
  LearningLedgerDaoManager get managers => LearningLedgerDaoManager(this);
}

class LearningLedgerDaoManager {
  final _$LearningLedgerDaoMixin _db;
  LearningLedgerDaoManager(this._db);
  $$CurriculumTracksTableTableManager get curriculumTracks =>
      $$CurriculumTracksTableTableManager(
        _db.attachedDatabase,
        _db.curriculumTracks,
      );
  $$LearningLedgerTableTableManager get learningLedger =>
      $$LearningLedgerTableTableManager(
        _db.attachedDatabase,
        _db.learningLedger,
      );
}

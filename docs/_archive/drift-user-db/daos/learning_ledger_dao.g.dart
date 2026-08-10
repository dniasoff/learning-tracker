// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'learning_ledger_dao.dart';

// ignore_for_file: type=lint
mixin _$LearningLedgerDaoMixin on DatabaseAccessor<UserDatabase> {
  $AccountsTable get accounts => attachedDatabase.accounts;
  $LearnerProfilesTable get learnerProfiles => attachedDatabase.learnerProfiles;
  $CurriculumTracksTable get curriculumTracks =>
      attachedDatabase.curriculumTracks;
  $LearningLedgerTable get learningLedger => attachedDatabase.learningLedger;
  LearningLedgerDaoManager get managers => LearningLedgerDaoManager(this);
}

class LearningLedgerDaoManager {
  final _$LearningLedgerDaoMixin _db;
  LearningLedgerDaoManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$LearnerProfilesTableTableManager get learnerProfiles =>
      $$LearnerProfilesTableTableManager(
        _db.attachedDatabase,
        _db.learnerProfiles,
      );
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

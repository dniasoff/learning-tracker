// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_program_dao.dart';

// ignore_for_file: type=lint
mixin _$ProfileProgramDaoMixin on DatabaseAccessor<UserDatabase> {
  $ProfileProgramsTable get profilePrograms => attachedDatabase.profilePrograms;
  ProfileProgramDaoManager get managers => ProfileProgramDaoManager(this);
}

class ProfileProgramDaoManager {
  final _$ProfileProgramDaoMixin _db;
  ProfileProgramDaoManager(this._db);
  $$ProfileProgramsTableTableManager get profilePrograms =>
      $$ProfileProgramsTableTableManager(
        _db.attachedDatabase,
        _db.profilePrograms,
      );
}

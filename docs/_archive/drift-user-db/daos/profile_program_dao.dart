import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/profile_programs.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

part 'profile_program_dao.g.dart';

@DriftAccessor(tables: [ProfilePrograms])
class ProfileProgramDao extends DatabaseAccessor<UserDatabase>
    with _$ProfileProgramDaoMixin {
  ProfileProgramDao(super.db);

  Future<List<ProfileProgram>> getProgramsForProfile(int profileId) => (select(
    profilePrograms,
  )..where((t) => t.profileId.equals(profileId))).get();

  Future<ProfileProgram?> getProgramForProfileAndCurriculum(
    int profileId,
    String curriculumType,
  ) =>
      (select(profilePrograms)..where(
            (t) =>
                t.profileId.equals(profileId) &
                t.curriculumType.equals(curriculumType),
          ))
          .getSingleOrNull();

  Future<int> insertProfileProgram(ProfileProgramsCompanion entry) =>
      into(profilePrograms).insert(entry);

  /// Upsert: set or replace the program for a profile+curriculum pair.
  Future<void> setProfileProgram({
    required int profileId,
    required String curriculumType,
    required int programId,
    DateTime? trackingStartDate,
    String? trackingStartRef,
  }) async {
    final existing = await getProgramForProfileAndCurriculum(
      profileId,
      curriculumType,
    );
    if (existing != null) {
      await (update(
        profilePrograms,
      )..where((t) => t.id.equals(existing.id))).write(
        ProfileProgramsCompanion(
          programId: Value(programId),
          trackingStartDate: Value(trackingStartDate),
          trackingStartRef: Value(trackingStartRef),
        ),
      );
    } else {
      await insertProfileProgram(
        ProfileProgramsCompanion.insert(
          profileId: profileId,
          curriculumType: curriculumType,
          programId: programId,
          trackingStartDate: Value(trackingStartDate),
          trackingStartRef: Value(trackingStartRef),
        ),
      );
    }
  }

  Future<int> deleteForProfile(int profileId) => (delete(
    profilePrograms,
  )..where((t) => t.profileId.equals(profileId))).go();

  /// Removes program enrollment for one curriculum (self-paced re-add or switch).
  Future<int> clearProgramForProfileAndCurriculum(
    int profileId,
    String curriculumType,
  ) =>
      (delete(profilePrograms)..where(
            (t) =>
                t.profileId.equals(profileId) &
                t.curriculumType.equals(curriculumType),
          ))
          .go();
}

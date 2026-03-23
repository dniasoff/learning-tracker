import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/database/tables/curriculum_scopes.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';

part 'curriculum_scope_dao.g.dart';

@DriftAccessor(tables: [CurriculumScopes])
class CurriculumScopeDao extends DatabaseAccessor<AppDatabase>
    with _$CurriculumScopeDaoMixin {
  CurriculumScopeDao(super.db);

  /// Get all scopes for a profile+curriculum.
  Future<List<CurriculumScope>> getScopes(
    int profileId,
    CurriculumId curriculum,
  ) async {
    return (select(curriculumScopes)..where(
          (t) =>
              t.profileId.equals(profileId) &
              t.curriculumId.equals(curriculum.storageKey),
        ))
        .get();
  }

  /// Watch scopes for a profile+curriculum.
  Stream<List<CurriculumScope>> watchScopes(
    int profileId,
    CurriculumId curriculum,
  ) {
    return (select(curriculumScopes)..where(
          (t) =>
              t.profileId.equals(profileId) &
              t.curriculumId.equals(curriculum.storageKey),
        ))
        .watch();
  }

  /// Set scopes for a profile+curriculum, replacing any existing ones.
  ///
  /// [scopeLevel] is the hierarchy level (1-4).
  /// [scopeValues] are the selected values at that level.
  /// Pass empty list to clear all scopes (= track entire curriculum).
  Future<void> setScopes(
    int profileId,
    CurriculumId curriculum,
    int scopeLevel,
    List<String> scopeValues,
  ) async {
    await transaction(() async {
      // Delete existing scopes for this profile+curriculum
      await (delete(curriculumScopes)..where(
            (t) =>
                t.profileId.equals(profileId) &
                t.curriculumId.equals(curriculum.storageKey),
          ))
          .go();

      // Insert new scopes
      final now = DateTimeFactory.nowUtc();
      for (final value in scopeValues) {
        await into(curriculumScopes).insert(
          CurriculumScopesCompanion.insert(
            profileId: Value(profileId),
            curriculumId: curriculum.storageKey,
            scopeLevel: scopeLevel,
            scopeValue: value,
            createdAt: now,
          ),
        );
      }
    });
  }

  /// Clear all scopes for a profile+curriculum (= track entire curriculum).
  Future<void> clearScopes(int profileId, CurriculumId curriculum) async {
    await (delete(curriculumScopes)..where(
          (t) =>
              t.profileId.equals(profileId) &
              t.curriculumId.equals(curriculum.storageKey),
        ))
        .go();
  }

  /// Check if a curriculum has any scopes set.
  Future<bool> hasScopes(int profileId, CurriculumId curriculum) async {
    final count =
        await (select(curriculumScopes)..where(
              (t) =>
                  t.profileId.equals(profileId) &
                  t.curriculumId.equals(curriculum.storageKey),
            ))
            .get();
    return count.isNotEmpty;
  }

  /// Get scope values as simple strings for a profile+curriculum.
  Future<List<String>> getScopeValues(
    int profileId,
    CurriculumId curriculum,
  ) async {
    final scopes = await getScopes(profileId, curriculum);
    return scopes.map((s) => s.scopeValue).toList();
  }

  /// Get the scope level for a profile+curriculum, or null if no scopes.
  Future<int?> getScopeLevel(int profileId, CurriculumId curriculum) async {
    final scopes = await getScopes(profileId, curriculum);
    if (scopes.isEmpty) return null;
    return scopes.first.scopeLevel;
  }
}

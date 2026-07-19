import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/curriculum_scopes.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';

part 'curriculum_scope_dao.g.dart';

@DriftAccessor(tables: [CurriculumScopes])
class CurriculumScopeDao extends DatabaseAccessor<UserDatabase>
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
    int trackId,
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

      // Insert new scopes.
      //
      // AUD-core-database-06 (DB-3): single batch() round trip instead of an
      // awaited per-row insert loop. Already inside the enclosing
      // transaction() above (DB-2), so batch() reuses it rather than opening
      // its own.
      final now = DateTimeFactory.nowUtc();
      if (scopeValues.isNotEmpty) {
        await batch((b) {
          b.insertAll(
            curriculumScopes,
            scopeValues.map(
              (value) => CurriculumScopesCompanion.insert(
                profileId: profileId,
                curriculumId: curriculum.storageKey,
                trackId: trackId,
                scopeLevel: scopeLevel,
                scopeValue: value,
                createdAt: now,
              ),
            ),
          );
        });
      }
    });
  }

  /// Batch-insert scope rows for [trackId] in a single round trip.
  ///
  /// AUD-tracks-19 (DB-3): replaces an awaited per-row `into().insert()`
  /// loop that TrackCreationService previously ran directly against the
  /// table (bypassing the DAO). This does NOT delete first — mixed-level
  /// breadcrumb selections (level 1 → 2 → 3 as a user drills into the
  /// hierarchy) mean a single uniform [scopeLevel]/[List<String>] pair (as
  /// [setScopes] assumes) does not fit; callers that need replace semantics
  /// clear first (e.g. [clearScopesForTrack]) then call this to insert.
  Future<void> insertScopesForTrack({
    required int profileId,
    required CurriculumId curriculum,
    required int trackId,
    required List<({int level, String value})> scopes,
  }) async {
    if (scopes.isEmpty) return;
    final now = DateTimeFactory.nowUtc();
    await batch((b) {
      b.insertAll(curriculumScopes, [
        for (final scope in scopes)
          CurriculumScopesCompanion.insert(
            profileId: profileId,
            curriculumId: curriculum.storageKey,
            trackId: trackId,
            scopeLevel: scope.level,
            scopeValue: scope.value,
            createdAt: now,
          ),
      ]);
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

  // ========== Track-Scoped Queries (Story 20.2) ==========

  /// Get all scopes for a specific track.
  Future<List<CurriculumScope>> getScopesByTrack(int trackId) =>
      (select(curriculumScopes)..where((t) => t.trackId.equals(trackId))).get();

  /// Watch scopes for a specific track.
  Stream<List<CurriculumScope>> watchScopesByTrack(int trackId) => (select(
    curriculumScopes,
  )..where((t) => t.trackId.equals(trackId))).watch();

  /// Clear all scopes for a specific track.
  Future<int> clearScopesForTrack(int trackId) =>
      (delete(curriculumScopes)..where((t) => t.trackId.equals(trackId))).go();

  /// Check if a track has any scopes set.
  Future<bool> hasScopesForTrack(int trackId) async {
    final result =
        await (select(curriculumScopes)
              ..where((t) => t.trackId.equals(trackId))
              ..limit(1))
            .get();
    return result.isNotEmpty;
  }

  /// Get scope values as simple strings for a track.
  Future<List<String>> getScopeValuesForTrack(int trackId) async {
    final scopes = await getScopesByTrack(trackId);
    return scopes.map((s) => s.scopeValue).toList();
  }

  /// Get the scope level for a track, or null if no scopes.
  Future<int?> getScopeLevelForTrack(int trackId) async {
    final scopes = await getScopesByTrack(trackId);
    if (scopes.isEmpty) return null;
    return scopes.first.scopeLevel;
  }
}

// Extra coverage for CurriculumScopeDao — tests the track-scoped methods
// not exercised by curriculum_scope_dao_test.dart:
//   - getScopesByTrack (line 119-120)
//   - watchScopesByTrack (lines 123-125)
//   - clearScopesForTrack (lines 128-129)
//   - hasScopesForTrack (lines 132-138)
//   - getScopeValuesForTrack (lines 142-144)
//   - getScopeLevelForTrack (lines 148-151)
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

import '../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;
  late int trackId;

  const profileId = 1;
  const curriculum = CurriculumId.mishnayos;

  setUp(() async {
    db = inMemoryDb();
    trackId = await db
        .into(db.curriculumTracks)
        .insert(
          CurriculumTracksCompanion.insert(
            profileId: profileId,
            curriculumId: curriculum.storageKey,
            trackType: 'personal',
            activatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> addScope(String value, {int level = 1}) async {
    await db.curriculumScopeDao.setScopes(
      profileId,
      curriculum,
      trackId,
      level,
      [value],
    );
  }

  // =========================================================================
  // getScopesByTrack
  // =========================================================================

  group('CurriculumScopeDao.getScopesByTrack', () {
    test('returns empty list when no scopes exist', () async {
      final scopes = await db.curriculumScopeDao.getScopesByTrack(trackId);
      expect(scopes, isEmpty);
    });

    test('returns scopes for the given track', () async {
      await addScope('Seder Zeraim');
      final scopes = await db.curriculumScopeDao.getScopesByTrack(trackId);
      expect(scopes, hasLength(1));
      expect(scopes.first.scopeValue, 'Seder Zeraim');
    });

    test('does not return scopes from another track', () async {
      final otherTrack = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              trackType: 'personal',
              activatedAt: DateTime.utc(2026, 1, 1),
            ),
          );
      await db.curriculumScopeDao.setScopes(
        profileId,
        CurriculumId.bavli,
        otherTrack,
        1,
        ['Moed'],
      );

      final scopes = await db.curriculumScopeDao.getScopesByTrack(trackId);
      expect(scopes, isEmpty);
    });
  });

  // =========================================================================
  // watchScopesByTrack
  // =========================================================================

  group('CurriculumScopeDao.watchScopesByTrack', () {
    test('emits empty list initially', () async {
      final first = await db.curriculumScopeDao
          .watchScopesByTrack(trackId)
          .first;
      expect(first, isEmpty);
    });

    test('emits updated scopes after insertion', () async {
      await addScope('Berakhot');
      final first = await db.curriculumScopeDao
          .watchScopesByTrack(trackId)
          .first;
      expect(first, hasLength(1));
      expect(first.first.scopeValue, 'Berakhot');
    });
  });

  // =========================================================================
  // clearScopesForTrack
  // =========================================================================

  group('CurriculumScopeDao.clearScopesForTrack', () {
    test('deletes all scopes for the track and returns count', () async {
      await addScope('Seder Zeraim');
      final deleted = await db.curriculumScopeDao.clearScopesForTrack(trackId);
      expect(deleted, 1);
      final remaining = await db.curriculumScopeDao.getScopesByTrack(trackId);
      expect(remaining, isEmpty);
    });

    test('returns 0 when no scopes exist', () async {
      final deleted = await db.curriculumScopeDao.clearScopesForTrack(999);
      expect(deleted, 0);
    });
  });

  // =========================================================================
  // hasScopesForTrack
  // =========================================================================

  group('CurriculumScopeDao.hasScopesForTrack', () {
    test('returns false when no scopes exist', () async {
      final has = await db.curriculumScopeDao.hasScopesForTrack(trackId);
      expect(has, isFalse);
    });

    test('returns true after scopes are added', () async {
      await addScope('Seder Zeraim');
      final has = await db.curriculumScopeDao.hasScopesForTrack(trackId);
      expect(has, isTrue);
    });
  });

  // =========================================================================
  // getScopeValuesForTrack
  // =========================================================================

  group('CurriculumScopeDao.getScopeValuesForTrack', () {
    test('returns empty list when no scopes set', () async {
      final values = await db.curriculumScopeDao.getScopeValuesForTrack(
        trackId,
      );
      expect(values, isEmpty);
    });

    test('returns scope values as strings', () async {
      await db.curriculumScopeDao.setScopes(profileId, curriculum, trackId, 1, [
        'Seder Zeraim',
        'Seder Moed',
      ]);

      final values = await db.curriculumScopeDao.getScopeValuesForTrack(
        trackId,
      );
      expect(values, containsAll(['Seder Zeraim', 'Seder Moed']));
    });
  });

  // =========================================================================
  // getScopeLevelForTrack
  // =========================================================================

  group('CurriculumScopeDao.getScopeLevelForTrack', () {
    test('returns null when no scopes exist', () async {
      final level = await db.curriculumScopeDao.getScopeLevelForTrack(trackId);
      expect(level, isNull);
    });

    test('returns the scope level when scopes exist', () async {
      await db.curriculumScopeDao.setScopes(profileId, curriculum, trackId, 2, [
        'Berakhot',
      ]);
      final level = await db.curriculumScopeDao.getScopeLevelForTrack(trackId);
      expect(level, 2);
    });
  });
}

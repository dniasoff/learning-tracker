import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

import '../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase database;
  late int trackId;

  setUp(() async {
    database = inMemoryDb();
    // Seed profiles: profileId=0 (used by most setScopes calls) and
    // profileId=1 (used by the scopes-isolated-by-profileId test).
    await seedProfileZero(database);
    await seedProfile(database);
    // Insert a track first to satisfy FK constraint on curriculum_scopes.trackId.
    // W3.22: UNIQUE constraint is (profileId, curriculumId); no trackType.
    trackId = await seedTrack(
      database,
      profileId: 1,
      curriculumId: 'mishnayos',
      activatedAt: DateTime.now(),
    );
  });

  tearDown(() async {
    await database.close();
  });

  group('CurriculumScopeDao', () {
    test('getScopes returns empty list initially', () async {
      final scopes = await database.curriculumScopeDao.getScopes(
        0,
        CurriculumId.mishnayos,
      );
      expect(scopes, isEmpty);
    });

    test('hasScopes returns false when no scopes set', () async {
      final has = await database.curriculumScopeDao.hasScopes(
        0,
        CurriculumId.mishnayos,
      );
      expect(has, isFalse);
    });

    test('setScopes adds scope entries', () async {
      await database.curriculumScopeDao.setScopes(
        0,
        CurriculumId.mishnayos,
        trackId,
        1,
        ['Seder Zeraim', 'Seder Moed'],
      );

      final scopes = await database.curriculumScopeDao.getScopes(
        0,
        CurriculumId.mishnayos,
      );
      expect(scopes, hasLength(2));
      expect(
        scopes.map((s) => s.scopeValue),
        containsAll(['Seder Zeraim', 'Seder Moed']),
      );
      expect(scopes.first.scopeLevel, equals(1));
    });

    test('hasScopes returns true after setting scopes', () async {
      await database.curriculumScopeDao.setScopes(
        0,
        CurriculumId.mishnayos,
        trackId,
        1,
        ['Seder Zeraim'],
      );

      final has = await database.curriculumScopeDao.hasScopes(
        0,
        CurriculumId.mishnayos,
      );
      expect(has, isTrue);
    });

    test('setScopes replaces existing scopes', () async {
      await database.curriculumScopeDao.setScopes(
        0,
        CurriculumId.mishnayos,
        trackId,
        1,
        ['Seder Zeraim'],
      );

      await database.curriculumScopeDao.setScopes(
        0,
        CurriculumId.mishnayos,
        trackId,
        2,
        ['Berachos', 'Shabbos'],
      );

      final scopes = await database.curriculumScopeDao.getScopes(
        0,
        CurriculumId.mishnayos,
      );
      expect(scopes, hasLength(2));
      expect(scopes.first.scopeLevel, equals(2));
      expect(
        scopes.map((s) => s.scopeValue),
        containsAll(['Berachos', 'Shabbos']),
      );
    });

    test('clearScopes removes all scopes', () async {
      await database.curriculumScopeDao.setScopes(
        0,
        CurriculumId.mishnayos,
        trackId,
        1,
        ['Seder Zeraim', 'Seder Moed'],
      );

      await database.curriculumScopeDao.clearScopes(0, CurriculumId.mishnayos);

      final scopes = await database.curriculumScopeDao.getScopes(
        0,
        CurriculumId.mishnayos,
      );
      expect(scopes, isEmpty);
    });

    test('getScopeValues returns just the value strings', () async {
      await database.curriculumScopeDao.setScopes(
        0,
        CurriculumId.mishnayos,
        trackId,
        1,
        ['Seder Zeraim', 'Seder Moed'],
      );

      final values = await database.curriculumScopeDao.getScopeValues(
        0,
        CurriculumId.mishnayos,
      );
      expect(values, containsAll(['Seder Zeraim', 'Seder Moed']));
    });

    test('getScopeLevel returns the scope level', () async {
      await database.curriculumScopeDao.setScopes(
        0,
        CurriculumId.mishnayos,
        trackId,
        2,
        ['Berachos'],
      );

      final level = await database.curriculumScopeDao.getScopeLevel(
        0,
        CurriculumId.mishnayos,
      );
      expect(level, equals(2));
    });

    test('getScopeLevel returns null when no scopes', () async {
      final level = await database.curriculumScopeDao.getScopeLevel(
        0,
        CurriculumId.mishnayos,
      );
      expect(level, isNull);
    });

    test('scopes are isolated by profileId', () async {
      await database.curriculumScopeDao.setScopes(
        0,
        CurriculumId.mishnayos,
        trackId,
        1,
        ['Seder Zeraim'],
      );

      await database.curriculumScopeDao.setScopes(
        1,
        CurriculumId.mishnayos,
        trackId,
        1,
        ['Seder Moed'],
      );

      final profile0 = await database.curriculumScopeDao.getScopeValues(
        0,
        CurriculumId.mishnayos,
      );
      final profile1 = await database.curriculumScopeDao.getScopeValues(
        1,
        CurriculumId.mishnayos,
      );

      expect(profile0, equals(['Seder Zeraim']));
      expect(profile1, equals(['Seder Moed']));
    });

    test('scopes are isolated by curriculumId', () async {
      // Need a track for bavli too
      final bavliTrackId = await seedTrack(
        database,
        profileId: 1,
        curriculumId: 'bavli',
        activatedAt: DateTime.now(),
      );

      await database.curriculumScopeDao.setScopes(
        0,
        CurriculumId.mishnayos,
        trackId,
        1,
        ['Seder Zeraim'],
      );

      await database.curriculumScopeDao.setScopes(
        0,
        CurriculumId.bavli,
        bavliTrackId,
        1,
        ['Berachos'],
      );

      final mishnayos = await database.curriculumScopeDao.getScopeValues(
        0,
        CurriculumId.mishnayos,
      );
      final bavli = await database.curriculumScopeDao.getScopeValues(
        0,
        CurriculumId.bavli,
      );

      expect(mishnayos, equals(['Seder Zeraim']));
      expect(bavli, equals(['Berachos']));
    });

    test('setScopes with empty list clears scopes', () async {
      await database.curriculumScopeDao.setScopes(
        0,
        CurriculumId.mishnayos,
        trackId,
        1,
        ['Seder Zeraim'],
      );

      await database.curriculumScopeDao.setScopes(
        0,
        CurriculumId.mishnayos,
        trackId,
        1,
        [],
      );

      final scopes = await database.curriculumScopeDao.getScopes(
        0,
        CurriculumId.mishnayos,
      );
      expect(scopes, isEmpty);
    });

    test('watchScopes emits updates', () async {
      final stream = database.curriculumScopeDao.watchScopes(
        0,
        CurriculumId.mishnayos,
      );

      // Collect first emission (empty)
      final first = await stream.first;
      expect(first, isEmpty);

      // Set scopes
      await database.curriculumScopeDao.setScopes(
        0,
        CurriculumId.mishnayos,
        trackId,
        1,
        ['Seder Zeraim'],
      );

      // Next emission should have the scope
      final second = await stream.first;
      expect(second, hasLength(1));
      expect(second.first.scopeValue, equals('Seder Zeraim'));
    });
  });
}

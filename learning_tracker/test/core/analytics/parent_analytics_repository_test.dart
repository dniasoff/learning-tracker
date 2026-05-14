/// Tests for [ParentAnalyticsRepository] and its default impl — DNI-338.
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:learning_tracker/core/analytics/parent_analytics_repository.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/cross_profile_scope.dart';
import 'package:test/test.dart';

CompletionsCompanion _completion({
  required int profileId,
  required String curriculumId,
  String ref = 'ref-1',
  int stageId = 1,
  String trackType = 'forwards',
  int trackId = 1,
  DateTime? completedAt,
}) => CompletionsCompanion.insert(
  profileId: profileId,
  curriculumId: curriculumId,
  sefariaRef: ref,
  stageId: stageId,
  trackType: trackType,
  trackId: trackId,
  completedAt: completedAt ?? DateTime.utc(2026, 5, 13),
  points: const Value(10),
);

void main() {
  group('ParentAnalyticsRepository (default impl)', () {
    late UserDatabase db;
    late ParentAnalyticsRepository repo;

    setUp(() {
      db = UserDatabase(NativeDatabase.memory());
      repo = ParentAnalyticsRepositoryImpl(db);
    });

    tearDown(() => db.close());

    test('getAllCompletions returns rows across every profile', () async {
      await db.completionDao.insertCompletion(
        _completion(profileId: 1, curriculumId: 'mishnayos'),
      );
      await db.completionDao.insertCompletion(
        _completion(profileId: 2, curriculumId: 'mishnayos', ref: 'ref-2'),
      );

      final all = await repo.getAllCompletions(
        scope: CrossProfileScope.syncRestore,
      );
      expect(all, hasLength(2));
      final profileIds = all.map((c) => c.profileId).toSet();
      expect(profileIds, equals({1, 2}));
    });

    test(
      'getCompletionsByCurriculum filters by curriculum, across profiles',
      () async {
        await db.completionDao.insertCompletion(
          _completion(profileId: 1, curriculumId: 'mishnayos'),
        );
        await db.completionDao.insertCompletion(
          _completion(profileId: 2, curriculumId: 'bavli', ref: 'ref-2'),
        );

        final mishna = await repo.getCompletionsByCurriculum(
          'mishnayos',
          scope: CrossProfileScope.parentAnalytics,
        );
        expect(mishna, hasLength(1));
        expect(mishna.first.profileId, 1);
      },
    );

    test(
      'getCompletionsByDateRange filters by date range, across profiles',
      () async {
        await db.completionDao.insertCompletion(
          _completion(
            profileId: 1,
            curriculumId: 'mishnayos',
            completedAt: DateTime.utc(2026, 1, 1),
          ),
        );
        await db.completionDao.insertCompletion(
          _completion(
            profileId: 2,
            curriculumId: 'mishnayos',
            ref: 'ref-2',
            completedAt: DateTime.utc(2026, 6, 1),
          ),
        );

        final inRange = await repo.getCompletionsByDateRange(
          DateTime.utc(2026, 5, 1),
          DateTime.utc(2026, 7, 1),
          scope: CrossProfileScope.parentAnalytics,
        );
        expect(inRange, hasLength(1));
        expect(inRange.first.profileId, 2);
      },
    );

    test('getAggregateCount counts across profiles', () async {
      await db.completionDao.insertCompletion(
        _completion(profileId: 1, curriculumId: 'mishnayos'),
      );
      await db.completionDao.insertCompletion(
        _completion(profileId: 2, curriculumId: 'mishnayos', ref: 'ref-2'),
      );
      await db.completionDao.insertCompletion(
        _completion(profileId: 1, curriculumId: 'bavli', ref: 'ref-3'),
      );

      final count = await repo.getAggregateCount(
        'mishnayos',
        scope: CrossProfileScope.parentAnalytics,
      );
      expect(count, 2);
    });

    test('getTrackBreakdown groups by trackType, across profiles', () async {
      await db.completionDao.insertCompletion(
        _completion(
          profileId: 1,
          curriculumId: 'mishnayos',
          trackType: 'forwards',
        ),
      );
      await db.completionDao.insertCompletion(
        _completion(
          profileId: 2,
          curriculumId: 'mishnayos',
          ref: 'ref-2',
          trackType: 'forwards',
        ),
      );
      await db.completionDao.insertCompletion(
        _completion(
          profileId: 1,
          curriculumId: 'mishnayos',
          ref: 'ref-3',
          trackType: 'reverse',
        ),
      );

      final breakdown = await repo.getTrackBreakdown(
        'mishnayos',
        scope: CrossProfileScope.parentAnalytics,
      );
      expect(breakdown['forwards'], 2);
      expect(breakdown['reverse'], 1);
    });

    test(
      'getCompletionsForContent returns completions by sefariaRef across profiles',
      () async {
        await db.completionDao.insertCompletion(
          _completion(profileId: 1, curriculumId: 'mishnayos', ref: 'Berakhot.1'),
        );
        await db.completionDao.insertCompletion(
          _completion(profileId: 2, curriculumId: 'mishnayos', ref: 'Berakhot.1'),
        );
        await db.completionDao.insertCompletion(
          _completion(profileId: 1, curriculumId: 'mishnayos', ref: 'Berakhot.2'),
        );

        final results = await repo.getCompletionsForContent(
          'Berakhot.1',
          scope: CrossProfileScope.parentAnalytics,
        );
        expect(results, hasLength(2));
        expect(results.every((c) => c.sefariaRef == 'Berakhot.1'), isTrue);
      },
    );

    test(
      'hasCompletionsInDateRange returns true when completions exist in range',
      () async {
        await db.completionDao.insertCompletion(
          _completion(
            profileId: 1,
            curriculumId: 'mishnayos',
            completedAt: DateTime.utc(2026, 3, 15),
          ),
        );

        final has = await repo.hasCompletionsInDateRange(
          DateTime.utc(2026, 3, 1),
          DateTime.utc(2026, 3, 31),
          scope: CrossProfileScope.parentAnalytics,
        );
        expect(has, isTrue);
      },
    );

    test(
      'hasCompletionsInDateRange returns false when no completions in range',
      () async {
        await db.completionDao.insertCompletion(
          _completion(
            profileId: 1,
            curriculumId: 'mishnayos',
            completedAt: DateTime.utc(2026, 1, 1),
          ),
        );

        final has = await repo.hasCompletionsInDateRange(
          DateTime.utc(2026, 6, 1),
          DateTime.utc(2026, 6, 30),
          scope: CrossProfileScope.parentAnalytics,
        );
        expect(has, isFalse);
      },
    );
  });
}

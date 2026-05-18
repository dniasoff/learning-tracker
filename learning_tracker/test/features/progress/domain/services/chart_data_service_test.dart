import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/features/progress/domain/services/chart_data_service.dart';

import '../../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;
  late ChartDataService service;
  late int trackId;
  const profileId = 1;

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db);
    trackId = await db
        .into(db.curriculumTracks)
        .insert(
          CurriculumTracksCompanion.insert(
            profileId: profileId,
            curriculumId: 'mishnayos',
            trackType: 'personal',
            activatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
    service = ChartDataService(db, profileId: profileId);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> insertCompletion({
    required DateTime completedAt,
    String curriculumId = 'mishnayos',
    int points = 10,
    int stageId = 1,
    String sefariaRef = 'ref_1',
    int? trackIdOverride,
  }) => seedCompletion(
    db,
    CompletionsCompanion.insert(
      profileId: profileId,
      curriculumId: curriculumId,
      sefariaRef: sefariaRef,
      stageId: stageId,
      trackType: 'personal',
      trackId: trackIdOverride ?? trackId,
      completedAt: completedAt,
      points: Value(points),
    ),
  );

  group('ChartDataService', () {
    group('getDailyCompletions', () {
      test('returns zero-filled entries for empty range', () async {
        final start = DateTime(2026, 3, 1);
        final end = DateTime(2026, 3, 3);
        final result = await service.getDailyCompletions(
          startDate: start,
          endDate: end,
        );

        expect(result, hasLength(3));
        expect(result.every((d) => d.count == 0), isTrue);
      });

      test('counts completions per day', () async {
        await insertCompletion(completedAt: DateTime(2026, 3, 1, 10));
        await insertCompletion(
          completedAt: DateTime(2026, 3, 1, 14),
          sefariaRef: 'ref_2',
        );
        await insertCompletion(
          completedAt: DateTime(2026, 3, 3, 8),
          sefariaRef: 'ref_3',
        );

        final result = await service.getDailyCompletions(
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 3, 3),
        );

        expect(result, hasLength(3));
        expect(result[0].count, 2); // March 1
        expect(result[1].count, 0); // March 2
        expect(result[2].count, 1); // March 3
      });

      test('filters by curriculumId when provided', () async {
        // Bavli track for the same profile.
        final bavliTrack = await db
            .into(db.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                profileId: profileId,
                curriculumId: 'bavli',
                trackType: 'personal',
                activatedAt: DateTime.utc(2026, 1, 1),
              ),
            );
        await insertCompletion(
          completedAt: DateTime(2026, 3, 1, 10),
          curriculumId: 'bavli',
          trackIdOverride: bavliTrack,
        );
        // A mishnayos completion on the same day must NOT count.
        await insertCompletion(
          completedAt: DateTime(2026, 3, 1, 12),
          curriculumId: 'mishnayos',
          sefariaRef: 'mish_ref',
        );

        final result = await service.getDailyCompletions(
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 3, 1),
          curriculumId: 'bavli',
        );

        expect(result, hasLength(1));
        expect(result[0].count, 1);
      });
    });

    group('getCumulativeProgress', () {
      test('returns monotonically increasing totals', () async {
        await insertCompletion(completedAt: DateTime(2026, 3, 1, 10));
        await insertCompletion(
          completedAt: DateTime(2026, 3, 2, 10),
          sefariaRef: 'ref_2',
        );
        await insertCompletion(
          completedAt: DateTime(2026, 3, 2, 14),
          sefariaRef: 'ref_3',
        );

        final result = await service.getCumulativeProgress(
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 3, 3),
        );

        expect(result, hasLength(3));
        expect(result[0].total, 1);
        expect(result[1].total, 3);
        expect(result[2].total, 3);
      });

      test('includes completions before start date in baseline', () async {
        await insertCompletion(completedAt: DateTime(2026, 2, 28, 10));
        await insertCompletion(
          completedAt: DateTime(2026, 3, 1, 10),
          sefariaRef: 'ref_2',
        );

        final result = await service.getCumulativeProgress(
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 3, 1),
        );

        expect(result, hasLength(1));
        expect(result[0].total, 2); // 1 before + 1 on day
      });
    });

    group('getDailyPoints', () {
      test('returns null for adult mode', () async {
        final result = await service.getDailyPoints(
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 3, 1),
          userMode: UserMode.adult,
        );

        expect(result, isNull);
      });

      test('returns points per day for child mode', () async {
        await insertCompletion(
          completedAt: DateTime(2026, 3, 1, 10),
          points: 5,
        );
        await insertCompletion(
          completedAt: DateTime(2026, 3, 1, 14),
          points: 3,
          sefariaRef: 'ref_2',
        );

        final result = await service.getDailyPoints(
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 3, 1),
          userMode: UserMode.child,
        );

        expect(result, isNotNull);
        expect(result, hasLength(1));
        expect(result![0].points, 8);
      });
    });

    group('getStreakCalendar', () {
      test('returns set of active dates', () async {
        await insertCompletion(completedAt: DateTime(2026, 3, 1, 10));
        await insertCompletion(
          completedAt: DateTime(2026, 3, 1, 14),
          sefariaRef: 'ref_2',
        );
        await insertCompletion(
          completedAt: DateTime(2026, 3, 3, 8),
          sefariaRef: 'ref_3',
        );

        final result = await service.getStreakCalendar(
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 3, 3),
        );

        expect(result, hasLength(2)); // March 1 and March 3
        expect(result.contains(DateTime(2026, 3, 1)), isTrue);
        expect(result.contains(DateTime(2026, 3, 3)), isTrue);
      });
    });
  });
}

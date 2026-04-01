import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/database/daos/goal_dao.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/features/progress/domain/services/chart_data_service.dart';
import 'package:mocktail/mocktail.dart';

class MockUserDatabase extends Mock implements UserDatabase {}

class MockCompletionDao extends Mock implements CompletionDao {}

class MockGoalDao extends Mock implements GoalDao {}

void main() {
  late MockUserDatabase mockDb;
  late MockCompletionDao mockCompletionDao;
  late MockGoalDao mockGoalDao;
  late ChartDataService service;

  setUp(() {
    mockDb = MockUserDatabase();
    mockCompletionDao = MockCompletionDao();
    mockGoalDao = MockGoalDao();
    when(() => mockDb.completionDao).thenReturn(mockCompletionDao);
    when(() => mockDb.goalDao).thenReturn(mockGoalDao);
    service = ChartDataService(mockDb);
  });

  Completion makeCompletion({
    required DateTime completedAt,
    String curriculumId = 'mishnayos',
    int points = 10,
    int stageId = 1,
  }) {
    return Completion(
      id: 0,
      profileId: 0,
      curriculumId: curriculumId,
      sefariaRef: 'ref_1',
      stageId: stageId,
      trackType: 'personal',
      completedAt: completedAt,
      points: points,
    );
  }

  group('ChartDataService', () {
    group('getDailyCompletions', () {
      test('returns zero-filled entries for empty range', () async {
        when(
          () => mockCompletionDao.getAllCompletions(),
        ).thenAnswer((_) async => []);

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
        when(() => mockCompletionDao.getAllCompletions()).thenAnswer(
          (_) async => [
            makeCompletion(completedAt: DateTime(2026, 3, 1, 10)),
            makeCompletion(completedAt: DateTime(2026, 3, 1, 14)),
            makeCompletion(completedAt: DateTime(2026, 3, 3, 8)),
          ],
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
        when(
          () => mockCompletionDao.getCompletionsByCurriculum('bavli'),
        ).thenAnswer(
          (_) async => [
            makeCompletion(
              completedAt: DateTime(2026, 3, 1, 10),
              curriculumId: 'bavli',
            ),
          ],
        );

        final result = await service.getDailyCompletions(
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 3, 1),
          curriculumId: 'bavli',
        );

        expect(result, hasLength(1));
        expect(result[0].count, 1);
        verifyNever(() => mockCompletionDao.getAllCompletions());
      });
    });

    group('getCumulativeProgress', () {
      test('returns monotonically increasing totals', () async {
        when(() => mockCompletionDao.getAllCompletions()).thenAnswer(
          (_) async => [
            makeCompletion(completedAt: DateTime(2026, 3, 1, 10)),
            makeCompletion(completedAt: DateTime(2026, 3, 2, 10)),
            makeCompletion(completedAt: DateTime(2026, 3, 2, 14)),
          ],
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
        when(() => mockCompletionDao.getAllCompletions()).thenAnswer(
          (_) async => [
            makeCompletion(completedAt: DateTime(2026, 2, 28, 10)),
            makeCompletion(completedAt: DateTime(2026, 3, 1, 10)),
          ],
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
        when(() => mockCompletionDao.getAllCompletions()).thenAnswer(
          (_) async => [
            makeCompletion(completedAt: DateTime(2026, 3, 1, 10), points: 5),
            makeCompletion(completedAt: DateTime(2026, 3, 1, 14), points: 3),
          ],
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
        when(() => mockCompletionDao.getAllCompletions()).thenAnswer(
          (_) async => [
            makeCompletion(completedAt: DateTime(2026, 3, 1, 10)),
            makeCompletion(completedAt: DateTime(2026, 3, 1, 14)),
            makeCompletion(completedAt: DateTime(2026, 3, 3, 8)),
          ],
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

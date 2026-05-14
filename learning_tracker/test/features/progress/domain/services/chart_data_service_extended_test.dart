/// Extended tests for ChartDataService covering the getTargetLine method.
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/progress/domain/services/chart_data_service.dart';

import '../../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;
  late ChartDataService service;
  const profileId = 1;

  setUp(() {
    db = inMemoryDb();
    service = ChartDataService(db, profileId: profileId);
  });

  tearDown(() async {
    await db.close();
  });

  // Insert a basic curriculum track (needed for FK if any, but not always required).
  Future<int> insertTrack({String curriculumId = 'mishnayos'}) {
    return db
        .into(db.curriculumTracks)
        .insert(
          CurriculumTracksCompanion.insert(
            profileId: profileId,
            curriculumId: curriculumId,
            trackType: 'personal',
            isActive: const Value(true),
            activatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
  }

  Future<void> insertCompletion({
    String curriculumId = 'mishnayos',
    String sefariaRef = 'Berakhot 1:1',
    DateTime? completedAt,
    int stageId = 1,
    int trackId = 1,
  }) {
    return db
        .into(db.completions)
        .insert(
          CompletionsCompanion.insert(
            profileId: profileId,
            curriculumId: curriculumId,
            sefariaRef: sefariaRef,
            stageId: stageId,
            trackType: 'personal',
            trackId: trackId,
            completedAt: completedAt ?? DateTime.utc(2026, 5, 14),
          ),
        );
  }

  Future<void> insertGoal({
    String curriculumId = 'mishnayos',
    DateTime? createdAt,
    DateTime? targetDate,
    DateTime? updatedAt,
  }) {
    final now = DateTime.utc(2026, 1, 1);
    return db
        .into(db.goals)
        .insert(
          GoalsCompanion.insert(
            profileId: profileId,
            curriculumId: curriculumId,
            trackId: 0,
            createdAt: createdAt ?? now,
            updatedAt: updatedAt ?? now,
            targetDate: Value(targetDate),
          ),
        );
  }

  group('ChartDataService.getTargetLine', () {
    test('returns null when no goals for curriculum', () async {
      final result = await service.getTargetLine(
        curriculumId: 'mishnayos',
        startDate: DateTime(2026, 5, 1),
        endDate: DateTime(2026, 5, 14),
      );
      expect(result, isNull);
    });

    test('returns null when goal has no targetDate', () async {
      await insertGoal(curriculumId: 'mishnayos', targetDate: null);

      final result = await service.getTargetLine(
        curriculumId: 'mishnayos',
        startDate: DateTime(2026, 5, 1),
        endDate: DateTime(2026, 5, 14),
      );
      expect(result, isNull);
    });

    test(
      'returns null when goal targetDate is same as createdAt (0 days)',
      () async {
        final d = DateTime.utc(2026, 5, 14);
        await insertGoal(
          curriculumId: 'mishnayos',
          createdAt: d,
          targetDate: d, // totalDays == 0 → null
        );

        final result = await service.getTargetLine(
          curriculumId: 'mishnayos',
          startDate: DateTime(2026, 5, 1),
          endDate: DateTime(2026, 5, 14),
        );
        expect(result, isNull);
      },
    );

    test(
      'returns target line points when goal and targetDate are set',
      () async {
        final trackId = await insertTrack();
        final goalCreatedAt = DateTime.utc(2026, 5, 1);
        final goalTargetDate = DateTime.utc(2026, 5, 31);

        await insertGoal(
          curriculumId: 'mishnayos',
          createdAt: goalCreatedAt,
          targetDate: goalTargetDate,
        );
        await insertCompletion(
          curriculumId: 'mishnayos',
          trackId: trackId,
          completedAt: DateTime.utc(2026, 5, 10),
        );

        final result = await service.getTargetLine(
          curriculumId: 'mishnayos',
          startDate: DateTime(2026, 5, 5),
          endDate: DateTime(2026, 5, 10),
        );

        expect(result, isNotNull);
        expect(result!.isNotEmpty, isTrue);
        // Should have one entry per day: May 5–10 = 6 days.
        expect(result.length, 6);
      },
    );

    test('target line is monotonically non-decreasing within range', () async {
      final trackId = await insertTrack();
      final goalCreated = DateTime.utc(2026, 1, 1);
      final goalTarget = DateTime.utc(2026, 12, 31);

      await insertGoal(
        curriculumId: 'mishnayos',
        createdAt: goalCreated,
        targetDate: goalTarget,
      );
      for (var i = 1; i <= 10; i++) {
        await insertCompletion(
          curriculumId: 'mishnayos',
          trackId: trackId,
          sefariaRef: 'Berakhot 1:$i',
          completedAt: DateTime.utc(2026, 5, i),
        );
      }

      final result = await service.getTargetLine(
        curriculumId: 'mishnayos',
        startDate: DateTime(2026, 5, 1),
        endDate: DateTime(2026, 5, 10),
      );

      expect(result, isNotNull);
      for (var i = 1; i < result!.length; i++) {
        expect(
          result[i].expectedTotal,
          greaterThanOrEqualTo(result[i - 1].expectedTotal),
        );
      }
    });
  });
}

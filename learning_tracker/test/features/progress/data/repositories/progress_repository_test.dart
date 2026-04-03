import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/features/progress/data/repositories/progress_repository_impl.dart';
import 'package:learning_tracker/features/progress/domain/repositories/progress_repository.dart';

void main() {
  late UserDatabase database;
  late ProgressRepository repository;
  late int trackId;

  setUp(() async {
    database = UserDatabase(NativeDatabase.memory());
    repository = ProgressRepositoryImpl(database: database);

    final trackRow = await database.into(database.curriculumTracks).insertReturning(
      CurriculumTracksCompanion.insert(
        curriculumId: 'bavli',
        trackType: 'personal',
        activatedAt: DateTime.now(),
      ),
    );
    trackId = trackRow.id;
  });

  tearDown(() async {
    await database.close();
  });

  group('ProgressRepository', () {
    group('getTrackBreakdown', () {
      test(
        'returns Map<TrackType, int> with correct counts per track',
        () async {
          // Arrange: Insert completions for different tracks
          await database.completionDao.insertCompletion(
            CompletionsCompanion.insert(
              curriculumId: 'bavli',
              trackId: trackId,
              sefariaRef: 'Berakhot.2a',
              stageId: 1,
              trackType: TrackType.personal.storageKey,
              completedAt: DateTime.now(),
              points: const drift.Value(10),
            ),
          );
          await database.completionDao.insertCompletion(
            CompletionsCompanion.insert(
              curriculumId: 'bavli',
              trackId: trackId,
              sefariaRef: 'Berakhot.2b',
              stageId: 1,
              trackType: TrackType.personal.storageKey,
              completedAt: DateTime.now(),
              points: const drift.Value(10),
            ),
          );
          await database.completionDao.insertCompletion(
            CompletionsCompanion.insert(
              curriculumId: 'bavli',
              trackId: trackId,
              sefariaRef: 'Berakhot.3a',
              stageId: 1,
              trackType: TrackType.school.storageKey,
              completedAt: DateTime.now(),
              points: const drift.Value(10),
            ),
          );

          // Act
          final breakdown = await repository.getTrackBreakdown('bavli');

          // Assert
          expect(breakdown[TrackType.personal], 2);
          expect(breakdown[TrackType.school], 1);
          expect(breakdown[TrackType.tutor], 0);
        },
      );

      test(
        'returns zero counts for inactive tracks that have no completions',
        () async {
          // Arrange: Insert only personal track completions
          await database.completionDao.insertCompletion(
            CompletionsCompanion.insert(
              curriculumId: 'bavli',
              trackId: trackId,
              sefariaRef: 'Berakhot.2a',
              stageId: 1,
              trackType: TrackType.personal.storageKey,
              completedAt: DateTime.now(),
              points: const drift.Value(10),
            ),
          );

          // Act
          final breakdown = await repository.getTrackBreakdown('bavli');

          // Assert
          expect(breakdown[TrackType.personal], 1);
          expect(breakdown[TrackType.school], 0);
          expect(breakdown[TrackType.tutor], 0);
        },
      );

      test(
        'includes completions from deactivated tracks (data preserved)',
        () async {
          // Arrange: Insert completions for a track that might be deactivated
          // Note: Track activation state is managed elsewhere; completions are preserved
          await database.completionDao.insertCompletion(
            CompletionsCompanion.insert(
              curriculumId: 'bavli',
              trackId: trackId,
              sefariaRef: 'Berakhot.2a',
              stageId: 1,
              trackType: TrackType.school.storageKey,
              completedAt: DateTime.now(),
              points: const drift.Value(10),
            ),
          );
          await database.completionDao.insertCompletion(
            CompletionsCompanion.insert(
              curriculumId: 'bavli',
              trackId: trackId,
              sefariaRef: 'Berakhot.2b',
              stageId: 1,
              trackType: TrackType.school.storageKey,
              completedAt: DateTime.now(),
              points: const drift.Value(10),
            ),
          );

          // Act
          final breakdown = await repository.getTrackBreakdown('bavli');

          // Assert: School completions are still included even if track is deactivated
          expect(breakdown[TrackType.school], 2);
        },
      );

      test('returns empty breakdown when no completions exist', () async {
        // Act
        final breakdown = await repository.getTrackBreakdown('bavli');

        // Assert
        expect(breakdown[TrackType.personal], 0);
        expect(breakdown[TrackType.school], 0);
        expect(breakdown[TrackType.tutor], 0);
      });

      test('filters by curriculum correctly', () async {
        // Arrange: Insert completions for different curricula
        await database.completionDao.insertCompletion(
          CompletionsCompanion.insert(
            curriculumId: 'bavli',
            trackId: trackId,
            sefariaRef: 'Berakhot.2a',
            stageId: 1,
            trackType: TrackType.personal.storageKey,
            completedAt: DateTime.now(),
            points: const drift.Value(10),
          ),
        );
        await database.completionDao.insertCompletion(
          CompletionsCompanion.insert(
            curriculumId: 'mishnayos',
            trackId: trackId,
            sefariaRef: 'Berakhot.1.1',
            stageId: 1,
            trackType: TrackType.personal.storageKey,
            completedAt: DateTime.now(),
            points: const drift.Value(10),
          ),
        );

        // Act
        final bavliBreakdown = await repository.getTrackBreakdown('bavli');
        final mishnaBreakdown = await repository.getTrackBreakdown('mishnayos');

        // Assert
        expect(bavliBreakdown[TrackType.personal], 1);
        expect(mishnaBreakdown[TrackType.personal], 1);
      });
    });

    group('getAggregateCount', () {
      test(
        'returns sum across all tracks, matching individual track counts',
        () async {
          // Arrange: Insert completions for different tracks
          await database.completionDao.insertCompletion(
            CompletionsCompanion.insert(
              curriculumId: 'bavli',
              trackId: trackId,
              sefariaRef: 'Berakhot.2a',
              stageId: 1,
              trackType: TrackType.personal.storageKey,
              completedAt: DateTime.now(),
              points: const drift.Value(10),
            ),
          );
          await database.completionDao.insertCompletion(
            CompletionsCompanion.insert(
              curriculumId: 'bavli',
              trackId: trackId,
              sefariaRef: 'Berakhot.2b',
              stageId: 1,
              trackType: TrackType.personal.storageKey,
              completedAt: DateTime.now(),
              points: const drift.Value(10),
            ),
          );
          await database.completionDao.insertCompletion(
            CompletionsCompanion.insert(
              curriculumId: 'bavli',
              trackId: trackId,
              sefariaRef: 'Berakhot.3a',
              stageId: 1,
              trackType: TrackType.school.storageKey,
              completedAt: DateTime.now(),
              points: const drift.Value(10),
            ),
          );

          // Act
          final breakdown = await repository.getTrackBreakdown('bavli');
          final aggregate = await repository.getAggregateCount('bavli');

          // Assert
          final expectedTotal = breakdown.values.fold<int>(
            0,
            (sum, count) => sum + count,
          );
          expect(aggregate, expectedTotal);
          expect(aggregate, 3);
        },
      );

      test('returns 0 when no completions exist', () async {
        // Act
        final aggregate = await repository.getAggregateCount('bavli');

        // Assert
        expect(aggregate, 0);
      });

      test('filters by curriculum correctly', () async {
        // Arrange
        await database.completionDao.insertCompletion(
          CompletionsCompanion.insert(
            curriculumId: 'bavli',
            trackId: trackId,
            sefariaRef: 'Berakhot.2a',
            stageId: 1,
            trackType: TrackType.personal.storageKey,
            completedAt: DateTime.now(),
            points: const drift.Value(10),
          ),
        );
        await database.completionDao.insertCompletion(
          CompletionsCompanion.insert(
            curriculumId: 'mishnayos',
            trackId: trackId,
            sefariaRef: 'Berakhot.1.1',
            stageId: 1,
            trackType: TrackType.personal.storageKey,
            completedAt: DateTime.now(),
            points: const drift.Value(10),
          ),
        );

        // Act
        final bavliCount = await repository.getAggregateCount('bavli');
        final mishnaCount = await repository.getAggregateCount('mishnayos');

        // Assert
        expect(bavliCount, 1);
        expect(mishnaCount, 1);
      });
    });
  });
}

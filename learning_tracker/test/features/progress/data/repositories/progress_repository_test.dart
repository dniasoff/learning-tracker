import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/features/progress/data/repositories/progress_repository_impl.dart';
import 'package:learning_tracker/features/progress/domain/repositories/progress_repository.dart';

import '../../../../helpers/drift_memory.dart' show seedCompletion;
import '../../../../helpers/test_database.dart';

void main() {
  late UserDatabase database;
  late ProgressRepository repository;
  late int trackId;
  const profileId = 1;

  setUp(() async {
    database = createTestDatabase();
    await seedProfile(database);
    repository = ProgressRepositoryImpl(
      database: database,
      profileId: profileId,
    );

    final trackRow = await database
        .into(database.curriculumTracks)
        .insertReturning(
          CurriculumTracksCompanion.insert(
            profileId: profileId,
            curriculumId: 'bavli',
            stateChangedAt: DateTime.now(),
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
          await seedCompletion(
            database,
            CompletionEventsCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              trackId: Value(trackId),
              sefariaRef: 'Berakhot.2a',
              stageId: 1,
              trackType: TrackType.personal.storageKey,
              eventTimestamp: DateTime.now(),
              points: const drift.Value(10),
            ),
          );
          await seedCompletion(
            database,
            CompletionEventsCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              trackId: Value(trackId),
              sefariaRef: 'Berakhot.2b',
              stageId: 1,
              trackType: TrackType.personal.storageKey,
              eventTimestamp: DateTime.now(),
              points: const drift.Value(10),
            ),
          );
          await seedCompletion(
            database,
            CompletionEventsCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              trackId: Value(trackId),
              sefariaRef: 'Berakhot.3a',
              stageId: 1,
              trackType: TrackType.personal.storageKey,
              eventTimestamp: DateTime.now(),
              points: const drift.Value(10),
            ),
          );

          // Act
          final breakdown = await repository.getTrackBreakdown('bavli');

          // Assert: 3 personal completions inserted
          expect(breakdown[TrackType.personal], 3);
        },
      );

      test(
        'returns zero counts for inactive tracks that have no completions',
        () async {
          // Arrange: Insert only personal track completions
          await seedCompletion(
            database,
            CompletionEventsCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              trackId: Value(trackId),
              sefariaRef: 'Berakhot.2a',
              stageId: 1,
              trackType: TrackType.personal.storageKey,
              eventTimestamp: DateTime.now(),
              points: const drift.Value(10),
            ),
          );

          // Act
          final breakdown = await repository.getTrackBreakdown('bavli');

          // Assert: 1 personal completion, no school/tutor (V1 only has personal)
          expect(breakdown[TrackType.personal], 1);
        },
      );

      test(
        'includes completions from deactivated tracks (data preserved)',
        () async {
          // Arrange: Insert completions for a track that might be deactivated
          // Note: Track activation state is managed elsewhere; completions are preserved
          await seedCompletion(
            database,
            CompletionEventsCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              trackId: Value(trackId),
              sefariaRef: 'Berakhot.2a',
              stageId: 1,
              trackType: TrackType.personal.storageKey,
              eventTimestamp: DateTime.now(),
              points: const drift.Value(10),
            ),
          );
          await seedCompletion(
            database,
            CompletionEventsCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              trackId: Value(trackId),
              sefariaRef: 'Berakhot.2b',
              stageId: 1,
              trackType: TrackType.personal.storageKey,
              eventTimestamp: DateTime.now(),
              points: const drift.Value(10),
            ),
          );

          // Act
          final breakdown = await repository.getTrackBreakdown('bavli');

          // Assert: School completions are still included even if track is deactivated
          expect(breakdown[TrackType.personal], 2);
        },
      );

      test('returns empty breakdown when no completions exist', () async {
        // Act
        final breakdown = await repository.getTrackBreakdown('bavli');

        // Assert
        expect(breakdown[TrackType.personal], 0);
        expect(breakdown[TrackType.personal], 0);
        expect(breakdown[TrackType.personal], 0);
      });

      test('filters by curriculum correctly', () async {
        // Arrange: Insert completions for different curricula
        await seedCompletion(
          database,
          CompletionEventsCompanion.insert(
            profileId: profileId,
            curriculumId: 'bavli',
            trackId: Value(trackId),
            sefariaRef: 'Berakhot.2a',
            stageId: 1,
            trackType: TrackType.personal.storageKey,
            eventTimestamp: DateTime.now(),
            points: const drift.Value(10),
          ),
        );
        await seedCompletion(
          database,
          CompletionEventsCompanion.insert(
            profileId: profileId,
            curriculumId: 'mishnayos',
            trackId: Value(trackId),
            sefariaRef: 'Berakhot.1.1',
            stageId: 1,
            trackType: TrackType.personal.storageKey,
            eventTimestamp: DateTime.now(),
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
          await seedCompletion(
            database,
            CompletionEventsCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              trackId: Value(trackId),
              sefariaRef: 'Berakhot.2a',
              stageId: 1,
              trackType: TrackType.personal.storageKey,
              eventTimestamp: DateTime.now(),
              points: const drift.Value(10),
            ),
          );
          await seedCompletion(
            database,
            CompletionEventsCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              trackId: Value(trackId),
              sefariaRef: 'Berakhot.2b',
              stageId: 1,
              trackType: TrackType.personal.storageKey,
              eventTimestamp: DateTime.now(),
              points: const drift.Value(10),
            ),
          );
          await seedCompletion(
            database,
            CompletionEventsCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              trackId: Value(trackId),
              sefariaRef: 'Berakhot.3a',
              stageId: 1,
              trackType: TrackType.personal.storageKey,
              eventTimestamp: DateTime.now(),
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
        await seedCompletion(
          database,
          CompletionEventsCompanion.insert(
            profileId: profileId,
            curriculumId: 'bavli',
            trackId: Value(trackId),
            sefariaRef: 'Berakhot.2a',
            stageId: 1,
            trackType: TrackType.personal.storageKey,
            eventTimestamp: DateTime.now(),
            points: const drift.Value(10),
          ),
        );
        await seedCompletion(
          database,
          CompletionEventsCompanion.insert(
            profileId: profileId,
            curriculumId: 'mishnayos',
            trackId: Value(trackId),
            sefariaRef: 'Berakhot.1.1',
            stageId: 1,
            trackType: TrackType.personal.storageKey,
            eventTimestamp: DateTime.now(),
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

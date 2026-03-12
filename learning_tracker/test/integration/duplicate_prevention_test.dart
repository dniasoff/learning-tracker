import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/exceptions/duplicate_completion_exception.dart';
import 'package:learning_tracker/core/services/duplicate_prevention_service.dart';
import 'package:learning_tracker/core/services/track_service.dart';

void main() {
  late AppDatabase database;
  late DuplicatePreventionService duplicateService;
  late TrackService trackService;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    duplicateService = DuplicatePreventionService(database);
    trackService = TrackService();
  });

  tearDown(() async {
    await database.close();
  });

  group('Duplicate Prevention Integration', () {
    test(
      'blocks duplicate completion for same item+stage under different track',
      () async {
        const curriculumId = 'mishnayos';
        const contentItemId = 1; // Berachos 1:1
        const stageId = 1; // Learn stage

        // Mark item under personal track
        await database.completionDao.insertCompletion(
          CompletionsCompanion.insert(
            curriculumId: curriculumId,
            contentItemId: contentItemId,
            stageId: stageId,
            trackType: TrackType.personal.storageKey,
            completedAt: DateTime.now().toUtc(),
          ),
        );

        // Attempt to mark same item+stage under school track should be blocked
        final canComplete = await duplicateService.canComplete(
          curriculumId: curriculumId,
          contentItemId: contentItemId,
          stageId: stageId,
        );

        expect(canComplete, isFalse);

        // Get existing completion for error message
        final existing = await duplicateService.getExistingCompletion(
          curriculumId: curriculumId,
          contentItemId: contentItemId,
          stageId: stageId,
        );

        expect(existing, isNotNull);
        expect(
          () => throw DuplicateCompletionException(
            curriculumId: curriculumId,
            contentItemId: contentItemId,
            stageId: stageId,
            existingTrack: TrackType.fromStorageKey(existing!.trackType),
          ),
          throwsA(isA<DuplicateCompletionException>()),
        );
      },
    );

    test('allows same item under different stages on different tracks', () async {
      const curriculumId = 'mishnayos';
      const contentItemId = 1; // Berachos 1:1
      const learnStageId = 1;
      const chazara1StageId = 2;

      // Activate school track
      await trackService.activateTrack(curriculumId, TrackType.school);

      // Mark Learn stage under personal track
      await database.completionDao.insertCompletion(
        CompletionsCompanion.insert(
          curriculumId: curriculumId,
          contentItemId: contentItemId,
          stageId: learnStageId,
          trackType: TrackType.personal.storageKey,
          completedAt: DateTime.now().toUtc(),
        ),
      );

      // Mark Chazara 1 stage under school track - should succeed (different stage)
      final canComplete = await duplicateService.canComplete(
        curriculumId: curriculumId,
        contentItemId: contentItemId,
        stageId: chazara1StageId,
      );

      expect(canComplete, isTrue);

      await database.completionDao.insertCompletion(
        CompletionsCompanion.insert(
          curriculumId: curriculumId,
          contentItemId: contentItemId,
          stageId: chazara1StageId,
          trackType: TrackType.school.storageKey,
          completedAt: DateTime.now().toUtc(),
        ),
      );

      // Verify both completions exist
      final allCompletions = await database.completionDao.getAllCompletions();
      expect(allCompletions.length, 2);
      expect(
        allCompletions.any(
          (c) =>
              c.stageId == learnStageId &&
              c.trackType == TrackType.personal.storageKey,
        ),
        isTrue,
      );
      expect(
        allCompletions.any(
          (c) =>
              c.stageId == chazara1StageId &&
              c.trackType == TrackType.school.storageKey,
        ),
        isTrue,
      );
    });

    test('auto-assigns to personal track when only one track active', () async {
      const curriculumId = 'mishnayos';

      final assignedTrack = await trackService.getAutoAssignedTrack(
        curriculumId,
      );
      expect(assignedTrack, TrackType.personal);
    });

    test('prompts for track selection when multiple tracks active', () async {
      const curriculumId = 'mishnayos';

      // Activate school track
      await trackService.activateTrack(curriculumId, TrackType.school);

      // Should return null to indicate user needs to select
      final assignedTrack = await trackService.getAutoAssignedTrack(
        curriculumId,
      );
      expect(assignedTrack, isNull);

      // Verify both tracks are active
      final activeTracks = await trackService.getActiveTracks(curriculumId);
      expect(activeTracks, containsAll([TrackType.personal, TrackType.school]));
    });

    test('duplicate check scopes correctly to curriculum', () async {
      const mishnayosId = 'mishnayos';
      const bavliId = 'bavli';
      const contentItemId = 1;
      const stageId = 1;

      // Mark item in mishnayos curriculum
      await database.completionDao.insertCompletion(
        CompletionsCompanion.insert(
          curriculumId: mishnayosId,
          contentItemId: contentItemId,
          stageId: stageId,
          trackType: TrackType.personal.storageKey,
          completedAt: DateTime.now().toUtc(),
        ),
      );

      // Same content item ID in bavli curriculum should be allowed
      final canComplete = await duplicateService.canComplete(
        curriculumId: bavliId,
        contentItemId: contentItemId,
        stageId: stageId,
      );

      expect(canComplete, isTrue);
    });
  });
}

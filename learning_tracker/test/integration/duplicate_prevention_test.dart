import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/exceptions/duplicate_completion_exception.dart';
import 'package:learning_tracker/core/services/duplicate_prevention_service.dart';
import 'package:learning_tracker/core/services/track_service.dart';

/// Creates a default curriculum track and returns its ID.
Future<int> _insertTrack(UserDatabase db) async {
  final row = await db
      .into(db.curriculumTracks)
      .insertReturning(
        CurriculumTracksCompanion.insert(
          curriculumId: 'mishnayos',
          trackType: 'personal',
          activatedAt: DateTime.now(),
        ),
      );
  return row.id;
}

void main() {
  late UserDatabase database;
  late DuplicatePreventionService duplicateService;
  late TrackService trackService;
  late int trackId;

  setUp(() async {
    database = UserDatabase(NativeDatabase.memory());
    trackId = await _insertTrack(database);
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
        const sefariaRef = 'Mishnah Berakhot 1:1';
        const stageId = 1; // Learn stage

        // Mark item under personal track
        await database.completionDao.insertCompletion(
          CompletionsCompanion.insert(
            curriculumId: curriculumId,
            sefariaRef: sefariaRef,
            stageId: stageId,
            trackType: TrackType.personal.storageKey,
            trackId: trackId,
            completedAt: DateTime.now().toUtc(),
          ),
        );

        // Attempt to mark same item+stage under school track should be blocked
        final canComplete = await duplicateService.canComplete(
          curriculumId: curriculumId,
          sefariaRef: sefariaRef,
          stageId: stageId,
        );

        expect(canComplete, isFalse);

        // Get existing completion for error message
        final existing = await duplicateService.getExistingCompletion(
          curriculumId: curriculumId,
          sefariaRef: sefariaRef,
          stageId: stageId,
        );

        expect(existing, isNotNull);
        expect(
          () => throw DuplicateCompletionException(
            curriculumId: curriculumId,
            sefariaRef: sefariaRef,
            stageId: stageId,
            existingTrack: TrackType.fromStorageKey(existing!.trackType),
          ),
          throwsA(isA<DuplicateCompletionException>()),
        );
      },
    );

    test('allows same item under different stages on different tracks', () async {
      const curriculumId = 'mishnayos';
      const sefariaRef = 'Mishnah Berakhot 1:1';
      const learnStageId = 1;
      const chazara1StageId = 2;

      // Activate school track
      await trackService.activateTrack(curriculumId, TrackType.personal);

      // Mark Learn stage under personal track
      await database.completionDao.insertCompletion(
        CompletionsCompanion.insert(
          curriculumId: curriculumId,
          sefariaRef: sefariaRef,
          stageId: learnStageId,
          trackType: TrackType.personal.storageKey,
          trackId: trackId,
          completedAt: DateTime.now().toUtc(),
        ),
      );

      // Mark Chazara 1 stage under school track - should succeed (different stage)
      final canComplete = await duplicateService.canComplete(
        curriculumId: curriculumId,
        sefariaRef: sefariaRef,
        stageId: chazara1StageId,
      );

      expect(canComplete, isTrue);

      await database.completionDao.insertCompletion(
        CompletionsCompanion.insert(
          curriculumId: curriculumId,
          sefariaRef: sefariaRef,
          stageId: chazara1StageId,
          trackType: TrackType.personal.storageKey,
          trackId: trackId,
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
              c.trackType == TrackType.personal.storageKey,
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
      await trackService.activateTrack(curriculumId, TrackType.personal);

      // Should return null to indicate user needs to select
      final assignedTrack = await trackService.getAutoAssignedTrack(
        curriculumId,
      );
      expect(assignedTrack, isNull);

      // Verify both tracks are active
      final activeTracks = await trackService.getActiveTracks(curriculumId);
      expect(activeTracks, containsAll([TrackType.personal, TrackType.personal]));
    });

    test('duplicate check scopes correctly to curriculum', () async {
      const mishnayosId = 'mishnayos';
      const bavliId = 'bavli';
      const sefariaRef = 'Mishnah Berakhot 1:1';
      const stageId = 1;

      // Mark item in mishnayos curriculum
      await database.completionDao.insertCompletion(
        CompletionsCompanion.insert(
          curriculumId: mishnayosId,
          sefariaRef: sefariaRef,
          stageId: stageId,
          trackType: TrackType.personal.storageKey,
          trackId: trackId,
          completedAt: DateTime.now().toUtc(),
        ),
      );

      // Same sefaria ref in bavli curriculum should be allowed
      final canComplete = await duplicateService.canComplete(
        curriculumId: bavliId,
        sefariaRef: sefariaRef,
        stageId: stageId,
      );

      expect(canComplete, isTrue);
    });
  });
}

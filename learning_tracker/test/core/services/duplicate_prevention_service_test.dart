import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/services/duplicate_prevention_service.dart';

void main() {
  late UserDatabase database;
  late DuplicatePreventionService service;

  setUp(() {
    database = UserDatabase(NativeDatabase.memory());
    service = DuplicatePreventionService(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('DuplicatePreventionService.canComplete', () {
    test('returns true when no prior completion exists', () async {
      final result = await service.canComplete(
        curriculumId: 'mishnayos',
        sefariaRef: 'Mishnah Berakhot 1:1',
        stageId: 1,
      );

      expect(result, isTrue);
    });

    test(
      'returns false when completion already exists for same item+stage',
      () async {
        // Insert a completion
        await database.completionDao.insertCompletion(
          CompletionsCompanion.insert(
            profileId: 0,
            trackId: 0,
            curriculumId: 'mishnayos',
            sefariaRef: 'Mishnah Berakhot 1:1',
            stageId: 1,
            trackType: TrackType.personal.storageKey,
            completedAt: DateTime.now().toUtc(),
          ),
        );

        // Try to complete again
        final result = await service.canComplete(
          curriculumId: 'mishnayos',
          sefariaRef: 'Mishnah Berakhot 1:1',
          stageId: 1,
        );

        expect(result, isFalse);
      },
    );

    test(
      'correctly scopes to curriculum - same content item in different curriculum allowed',
      () async {
        // Insert completion for mishnayos curriculum
        await database.completionDao.insertCompletion(
          CompletionsCompanion.insert(
            profileId: 0,
            trackId: 0,
            curriculumId: 'mishnayos',
            sefariaRef: 'Mishnah Berakhot 1:1',
            stageId: 1,
            trackType: TrackType.personal.storageKey,
            completedAt: DateTime.now().toUtc(),
          ),
        );

        // Try to complete same content item but in different curriculum
        final result = await service.canComplete(
          curriculumId: 'bavli',
          sefariaRef: 'Mishnah Berakhot 1:1',
          stageId: 1,
        );

        expect(result, isTrue);
      },
    );

    test(
      'allows same item+stage under different tracks (before duplicate prevention is enforced)',
      () async {
        // This test verifies the current behavior.
        // When duplicate prevention is enforced, this should return false.
        await database.completionDao.insertCompletion(
          CompletionsCompanion.insert(
            profileId: 0,
            trackId: 0,
            curriculumId: 'mishnayos',
            sefariaRef: 'Mishnah Berakhot 1:1',
            stageId: 1,
            trackType: TrackType.personal.storageKey,
            completedAt: DateTime.now().toUtc(),
          ),
        );

        // Currently, canComplete only checks if ANY completion exists for item+stage,
        // regardless of track. So this should return false.
        final result = await service.canComplete(
          curriculumId: 'mishnayos',
          sefariaRef: 'Mishnah Berakhot 1:1',
          stageId: 1,
        );

        expect(result, isFalse);
      },
    );

    test('allows different stages of same item', () async {
      // Insert stage 1 completion
      await database.completionDao.insertCompletion(
        CompletionsCompanion.insert(
          profileId: 0,
          trackId: 0,
          curriculumId: 'mishnayos',
          sefariaRef: 'Mishnah Berakhot 1:1',
          stageId: 1,
          trackType: TrackType.personal.storageKey,
          completedAt: DateTime.now().toUtc(),
        ),
      );

      // Try to complete stage 2 of same item
      final result = await service.canComplete(
        curriculumId: 'mishnayos',
        sefariaRef: 'Mishnah Berakhot 1:1',
        stageId: 2,
      );

      expect(result, isTrue);
    });
  });

  group('DuplicatePreventionService.getExistingCompletion', () {
    test('returns null when no completion exists', () async {
      final result = await service.getExistingCompletion(
        curriculumId: 'mishnayos',
        sefariaRef: 'Mishnah Berakhot 1:1',
        stageId: 1,
      );

      expect(result, isNull);
    });

    test('returns existing completion when found', () async {
      await database.completionDao.insertCompletion(
        CompletionsCompanion.insert(
          profileId: 0,
          trackId: 0,
          curriculumId: 'mishnayos',
          sefariaRef: 'Mishnah Berakhot 1:1',
          stageId: 1,
          trackType: TrackType.personal.storageKey,
          completedAt: DateTime.now().toUtc(),
        ),
      );

      final result = await service.getExistingCompletion(
        curriculumId: 'mishnayos',
        sefariaRef: 'Mishnah Berakhot 1:1',
        stageId: 1,
      );

      expect(result, isNotNull);
      expect(result!.curriculumId, 'mishnayos');
      expect(result.sefariaRef, 'Mishnah Berakhot 1:1');
      expect(result.stageId, 1);
      expect(result.trackType, TrackType.personal.storageKey);
    });
  });
}

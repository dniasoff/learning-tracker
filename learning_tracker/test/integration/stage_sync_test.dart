import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/tracks/stages/data/repositories/stage_definition_repository_impl.dart';

import '../helpers/test_database.dart' show seedProfile;

/// Creates a default curriculum track and returns its ID.
Future<int> _insertTrack(UserDatabase db) async {
  final row = await db
      .into(db.curriculumTracks)
      .insertReturning(
        CurriculumTracksCompanion.insert(
          profileId: 1,
          curriculumId: 'mishnayos',
          stateChangedAt: DateTimeFactory.nowUtc(),
          activatedAt: DateTimeFactory.nowUtc(),
        ),
      );
  return row.id;
}

void main() {
  late UserDatabase database;
  late int trackId;
  late List<Map<String, dynamic>> pushedSettings;
  late StageDefinitionRepositoryImpl repository;

  const curriculum = CurriculumId.mishnayos;

  setUp(() async {
    database = UserDatabase(NativeDatabase.memory());
    await seedProfile(database);
    trackId = await _insertTrack(database);
    pushedSettings = [];
    // Plan §F Phase 5 deliverable 6 — capture stage-definition push calls
    // via the dedicated `pushStageDefinitions` path. Existing assertions
    // on 'curriculum_id' / 'stages' continue to work against the
    // captured snapshot map.
    repository = StageDefinitionRepositoryImpl(
      stageDao: database.stageDao,
      completionDao: database.completionDao,
      pushStageDefinitions:
          ({
            required int trackId,
            required String curriculumId,
            required List<Map<String, dynamic>> stages,
            required DateTime updatedAt,
          }) async {
            pushedSettings.add({
              'track_id': trackId,
              'curriculum_id': curriculumId,
              'stages': stages,
              'updated_at': updatedAt.toIso8601String(),
            });
          },
    );
  });

  tearDown(() async {
    await database.close();
  });

  group('Stage sync integration', () {
    test(
      'replaceStagesForCurriculum restores stages from Firestore payload',
      () async {
        await repository.initializeDefaults(
          curriculum,
          profileId: 1,
          trackId: trackId,
        );

        // Simulate Firestore payload arriving with 4 stages
        final firestoreStages = [
          StageDefinitionsCompanion.insert(
            profileId: 1,
            curriculumId: curriculum.storageKey,
            trackId: trackId,
            stageOrder: 1,
            stageName: 'Learn',
            schedule: const Value('{"type":"delay","delay_days":0}'),
            isDefault: const Value(true),
          ),
          StageDefinitionsCompanion.insert(
            profileId: 1,
            curriculumId: curriculum.storageKey,
            trackId: trackId,
            stageOrder: 2,
            stageName: 'Chazara 1',
            schedule: const Value('{"type":"delay","delay_days":1}'),
            isDefault: const Value(true),
          ),
          StageDefinitionsCompanion.insert(
            profileId: 1,
            curriculumId: curriculum.storageKey,
            trackId: trackId,
            stageOrder: 3,
            stageName: 'Chazara 2',
            schedule: const Value('{"type":"delay","delay_days":7}'),
            isDefault: const Value(true),
          ),
          StageDefinitionsCompanion.insert(
            profileId: 1,
            curriculumId: curriculum.storageKey,
            trackId: trackId,
            stageOrder: 4,
            stageName: 'Chazara 3',
            schedule: const Value('{"type":"delay","delay_days":30}'),
            isDefault: const Value(false),
          ),
        ];

        await database.stageDao.replaceStagesForCurriculum(
          curriculum.storageKey,
          firestoreStages,
        );

        final restored = await repository.getStagesForCurriculum(curriculum);

        expect(restored, hasLength(4));
        expect(restored.last.stageName, 'Chazara 3');
        expect(restored.last.delayDays, 30);
        expect(restored.last.isDefault, false);
      },
    );

    test('resetToDefaults restores exactly 3 stages and pushes', () async {
      await repository.initializeDefaults(
        curriculum,
        profileId: 1,
        trackId: trackId,
      );
      // Seed a 4th custom stage directly via the DAO (AUD-tracks-12: the
      // repository's addStage was removed as dead code — zero UI callers —
      // so test setup that merely needs an extra stage on disk now inserts
      // through the DAO instead of the deleted repository method).
      await database.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          profileId: 1,
          curriculumId: curriculum.storageKey,
          trackId: trackId,
          stageOrder: 4,
          stageName: 'Custom',
          isDefault: const Value(false),
          schedule: const Value('{"type":"delay","delay_days":60}'),
        ),
      );

      pushedSettings.clear();
      await repository.resetToDefaults(
        curriculum,
        profileId: 1,
        trackId: trackId,
      );

      final stages = await repository.getStagesForCurriculum(curriculum);
      expect(stages, hasLength(3));
      expect(stages.map((s) => s.stageName).toList(), [
        'לימוד',
        'חזרה א׳',
        'חזרה ב׳',
      ]);
      expect(pushedSettings, hasLength(1));
    });
  });
}

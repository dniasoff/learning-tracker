import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/schedule_spec.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/stages/data/repositories/stage_definition_repository_impl.dart';

import '../helpers/test_database.dart' show seedProfile;

/// Creates a default curriculum track and returns its ID.
Future<int> _insertTrack(UserDatabase db) async {
  final row = await db
      .into(db.curriculumTracks)
      .insertReturning(
        CurriculumTracksCompanion.insert(
          profileId: 1,
          curriculumId: 'mishnayos',
          stateChangedAt: DateTime.now(),
          activatedAt: DateTime.now(),
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
    repository = StageDefinitionRepositoryImpl(
      stageDao: database.stageDao,
      completionDao: database.completionDao,
      pushSettings: (settings) async => pushedSettings.add(settings),
    );
  });

  tearDown(() async {
    await database.close();
  });

  group('Stage sync integration', () {
    test(
      'initializeDefaults then addStage — push payload contains all stages',
      () async {
        await repository.initializeDefaults(
          curriculum,
          profileId: 1,
          trackId: trackId,
        );

        pushedSettings.clear();

        final newStage = await repository.addStage(
          curriculum,
          'Chazara 3',
          profileId: 1,
          trackId: trackId,
          schedule: const DelaySchedule(30),
        );

        expect(newStage.stageName, 'Chazara 3');
        expect(newStage.stageOrder, 4);
        expect(newStage.isDefault, false);

        // Push should have been called once with all 4 stages
        expect(pushedSettings, hasLength(1));
        final payload = pushedSettings[0];
        expect(payload['curriculum_id'], curriculum.storageKey);

        final stages = payload['stages'] as List<dynamic>;
        expect(stages, hasLength(4));

        final stage4 =
            stages.firstWhere((s) => (s as Map)['stage_order'] == 4) as Map;
        expect(stage4['stage_name'], 'Chazara 3');
        expect(stage4['delay_days'], 30);
        expect(stage4['is_default'], false);
      },
    );

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
      await repository.addStage(
        curriculum,
        'Custom',
        profileId: 1,
        trackId: trackId,
        schedule: const DelaySchedule(60),
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

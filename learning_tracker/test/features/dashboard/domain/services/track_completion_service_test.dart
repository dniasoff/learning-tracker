import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/dashboard/domain/services/track_completion_service.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_entity.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart'
    as domain_stage;

const _stageDefinition = domain_stage.StageDefinition(
  curriculumId: CurriculumId.mishnayos,
  stageOrder: 1, // learn stage
  stageName: 'Learn',
  delayDays: 0,
  isDefault: true,
);

CompletionEntity _completion({
  required String sefariaRef,
  int stageId = 1,
}) => CompletionEntity(
  curriculumId: CurriculumId.mishnayos,
  sefariaRef: sefariaRef,
  stageId: stageId,
  trackType: 'personal',
  source: CompletionSource.live,
  completedAt: DateTime(2026, 5, 1),
  points: 10,
);

void main() {
  const service = TrackCompletionService();

  // ------------------------------------------------------------------
  // computeTrackPercentage
  // ------------------------------------------------------------------
  group('TrackCompletionService.computeTrackPercentage', () {
    test('returns 0.0 when stages empty', () {
      expect(
        service.computeTrackPercentage(
          stages: [],
          completions: [_completion(sefariaRef: 'Berakhot 1:1')],
          totalItems: 10,
        ),
        0.0,
      );
    });

    test('returns 0.0 when totalItems is 0', () {
      expect(
        service.computeTrackPercentage(
          stages: [_stageDefinition],
          completions: [_completion(sefariaRef: 'Berakhot 1:1')],
          totalItems: 0,
        ),
        0.0,
      );
    });

    test('returns 0.0 when completions is empty', () {
      expect(
        service.computeTrackPercentage(
          stages: [_stageDefinition],
          completions: [],
          totalItems: 10,
        ),
        0.0,
      );
    });

    test('returns 1.0 when single item and all stages done', () {
      expect(
        service.computeTrackPercentage(
          stages: [_stageDefinition],
          completions: [_completion(sefariaRef: 'Berakhot 1:1', stageId: 1)],
          totalItems: 1,
        ),
        1.0,
      );
    });

    test('returns 0.5 when 1 of 2 items done', () {
      expect(
        service.computeTrackPercentage(
          stages: [_stageDefinition],
          completions: [_completion(sefariaRef: 'Berakhot 1:1', stageId: 1)],
          totalItems: 2,
        ),
        0.5,
      );
    });

    test('item not done when missing one required stage', () {
      const learnStage = domain_stage.StageDefinition(
        curriculumId: CurriculumId.mishnayos,
        stageOrder: 1,
        stageName: 'Learn',
        delayDays: 0,
        isDefault: true,
      );
      const chazaraStage = domain_stage.StageDefinition(
        curriculumId: CurriculumId.mishnayos,
        stageOrder: 2,
        stageName: 'Chazara',
        delayDays: 7,
        isDefault: true,
      );
      // Only learn stage (1) done; chazara stage (2) missing.
      final result = service.computeTrackPercentage(
        stages: [learnStage, chazaraStage],
        completions: [_completion(sefariaRef: 'Berakhot 1:1', stageId: 1)],
        totalItems: 1,
      );
      expect(result, 0.0);
    });

    test('item done when all required stages present', () {
      const learnStage = domain_stage.StageDefinition(
        curriculumId: CurriculumId.mishnayos,
        stageOrder: 1,
        stageName: 'Learn',
        delayDays: 0,
        isDefault: true,
      );
      const chazaraStage = domain_stage.StageDefinition(
        curriculumId: CurriculumId.mishnayos,
        stageOrder: 2,
        stageName: 'Chazara',
        delayDays: 7,
        isDefault: true,
      );
      final result = service.computeTrackPercentage(
        stages: [learnStage, chazaraStage],
        completions: [
          _completion(sefariaRef: 'Berakhot 1:1', stageId: 1),
          _completion(sefariaRef: 'Berakhot 1:1', stageId: 2),
        ],
        totalItems: 1,
      );
      expect(result, 1.0);
    });
  });

  // ------------------------------------------------------------------
  // computeCurriculumPercentage
  // ------------------------------------------------------------------
  group('TrackCompletionService.computeCurriculumPercentage', () {
    test('returns 0.0 when totalItems is 0', () {
      expect(
        service.computeCurriculumPercentage(
          byTrack: {
            1: TrackEntry(
              stages: [_stageDefinition],
              completions: [_completion(sefariaRef: 'Berakhot 1:1')],
            ),
          },
          totalItems: 0,
        ),
        0.0,
      );
    });

    test('returns 0.0 when no tracks', () {
      expect(
        service.computeCurriculumPercentage(byTrack: {}, totalItems: 10),
        0.0,
      );
    });

    test('skips track 0 (bulk-mark sentinel)', () {
      final result = service.computeCurriculumPercentage(
        byTrack: {
          0: TrackEntry(
            stages: [_stageDefinition],
            completions: [_completion(sefariaRef: 'Berakhot 1:1')],
          ),
        },
        totalItems: 10,
      );
      expect(result, 0.0);
    });

    test('counts item done when any track has all stages complete', () {
      final result = service.computeCurriculumPercentage(
        byTrack: {
          1: TrackEntry(
            stages: [_stageDefinition],
            completions: [_completion(sefariaRef: 'Berakhot 1:1', stageId: 1)],
          ),
        },
        totalItems: 2,
      );
      expect(result, 0.5);
    });

    test('deduplicates ref appearing in multiple tracks', () {
      // Same ref done in two tracks — should count once.
      final result = service.computeCurriculumPercentage(
        byTrack: {
          1: TrackEntry(
            stages: [_stageDefinition],
            completions: [
              _completion(sefariaRef: 'Berakhot 1:1', stageId: 1),
            ],
          ),
          2: TrackEntry(
            stages: [_stageDefinition],
            completions: [
              _completion(sefariaRef: 'Berakhot 1:1', stageId: 1),
            ],
          ),
        },
        totalItems: 3,
      );
      // 1 unique ref done out of 3 total = 1/3.
      expect(result, closeTo(1 / 3, 0.001));
    });

    test('skips track with empty stages', () {
      // Track 1 has no stage definitions; its completions should not count.
      final result = service.computeCurriculumPercentage(
        byTrack: {
          1: TrackEntry(
            stages: [], // no stages → skip
            completions: [_completion(sefariaRef: 'Berakhot 1:1', stageId: 1)],
          ),
        },
        totalItems: 5,
      );
      expect(result, 0.0);
    });
  });
}

// Regression: a track created WITHOUT a learning-process (chazara) wizard
// result must still be seeded with the primary לימוד stage. Without at least
// one stage, the scheduler's projection does `if (stages.isEmpty) continue;`
// and skips the track entirely, so the dashboard shows "No projection" / 0 due
// despite a valid goal + computed pace (the on-device bug Daniel reported:
// goal set, track-detail shows the required pace, but the dashboard projects
// nothing). A null wizardResult must fall back to a noReview/learn-only seed —
// and must NOT add any chazara stages (chazara is per-track conditional).

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/learning/data/repositories/track_repository_impl.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/goal_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/domain/services/learning_program_service.dart';
import 'package:learning_tracker/features/tracks/domain/services/curriculum_activation_service.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/tracks/setup/domain/services/track_creation_service.dart';
import 'package:learning_tracker/features/tracks/stages/data/repositories/stage_definition_repository_impl.dart';

import '../../../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db); // learner_profiles(id = 1)
  });

  tearDown(() async {
    await db.close();
  });

  TrackCreationService buildService({PushStageDefinitionsFn? pushStages}) =>
      TrackCreationService(
        database: db,
        activationService: CurriculumActivationService(
          database: db,
          pushCurriculumTrack: null,
          trackRepository: TrackRepositoryImpl(database: db),
        ),
        wizardService: LearningProcessWizardService(
          stageDao: db.stageDao,
          learningProgramRepo: LearningProgramRepository.instance,
          profileProgramDao: db.profileProgramDao,
        ),
        goalRepository: GoalRepositoryImpl(database: db),
        stageRepository: StageDefinitionRepositoryImpl(
          stageDao: db.stageDao,
          completionDao: db.completionDao,
          pushStageDefinitions: pushStages,
        ),
        analytics: const NullAnalyticsService(),
      );

  test('track created without a wizard result is seeded with the לימוד stage '
      '(no "No projection")', () async {
    await buildService().createTrack(
      result: const AddTrackResult(
        curriculumId: CurriculumId.mishnayos,
        label: 'Mishnayos',
        studyDays: {1: 'study', 2: 'study'},
        // No wizardResult, no programId — the quick add-track path that
        // previously left the track with zero stages.
      ),
      profileId: 1,
    );

    final tracks = await db.trackDao.getActiveTracksForProfile(1);
    expect(tracks, isNotEmpty, reason: 'the track row must exist');
    final trackId = tracks.first.id;

    final stages = await db.stageDao.getStagesByTrack(trackId);
    expect(
      stages,
      isNotEmpty,
      reason: 'a stage-less track is skipped by the scheduler projection',
    );
    expect(
      stages.map((s) => s.stageName),
      contains('לימוד'),
      reason: 'the primary learning stage must be seeded',
    );
    // Honour the per-track chazara rule: no chazara rounds when the wizard
    // (chazara step) was never run.
    expect(
      stages.length,
      1,
      reason: 'noReview fallback seeds ONLY לימוד — no chazara stages',
    );
  });

  test('track creation pushes the seeded stages to the cloud '
      '(so a tutor mirror / second device projects too)', () async {
    // The seed is local-only; without an explicit push the stage_definitions
    // subcollection stays empty and a tutor pulls zero stages → "No
    // projection". Capture the push to prove createTrack closes that gap.
    final pushed = <Map<String, dynamic>>[];
    int? pushedTrackId;
    String? pushedCurriculum;
    Future<void> spy({
      required int trackId,
      required String curriculumId,
      required List<Map<String, dynamic>> stages,
      required DateTime updatedAt,
    }) async {
      pushedTrackId = trackId;
      pushedCurriculum = curriculumId;
      pushed.addAll(stages);
    }

    await buildService(pushStages: spy).createTrack(
      result: const AddTrackResult(
        curriculumId: CurriculumId.mishnayos,
        label: 'Mishnayos',
        studyDays: {1: 'study'},
      ),
      profileId: 1,
    );

    expect(
      pushed,
      isNotEmpty,
      reason: 'seeded stages must be pushed to Firestore for tutors/devices',
    );
    expect(pushedCurriculum, CurriculumId.mishnayos.storageKey);
    expect(pushedTrackId, isNotNull);
    expect(
      pushed.map((s) => s['stage_name']),
      contains('לימוד'),
      reason: 'the לימוד stage must be in the pushed payload',
    );
  });
}

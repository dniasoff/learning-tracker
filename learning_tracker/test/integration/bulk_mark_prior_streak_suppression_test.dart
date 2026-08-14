/// Integration test for Story 26.27 (DNI-370):
/// Bulk-mark-prior must suppress streak ticks for ALL stages (not just stage 1).
///
/// Acceptance criteria:
///   Given a fresh Firestore profile,
///   When prior completions are written across stages 1, 2, and 3,
///   Then the Firestore streak state returns currentStreak == 0.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/gamification_service_providers.dart';
import 'package:learning_tracker/features/gamification/streak/streak_state_service.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';

import '../helpers/writer_reader_agreement.dart';

const _uid = 'bulk-prior-streak-uid';
const _profileId = '01JQ8M9Y7V3K2N6P4R5T8W0X1Z';

void main() {
  late ProviderContainer container;
  late CompletionRepository repository;
  late StreakStateService streakState;

  setUp(() {
    final rig = activateAccountAndProfile(uid: _uid, profileId: _profileId);
    container = rig.container;
    repository = container.read(completionRepositoryProvider);
    streakState = container.read(streakStateProvider);
    addTearDown(container.dispose);
  });

  group(
    'Story 26.27 (DNI-370) — bulk-mark-prior streak suppression for all stages',
    () {
      test(
        'AC1+AC2: 50 prior completions across stages 1, 2, 3 → currentStreak == 0',
        () async {
          const curriculumId = 'mishnayos';
          const trackType = 'personal';

          final allRefs = List.generate(50, (i) => 'Mishnah Berachot $i:1');
          final stage1Refs = allRefs.sublist(0, 17);
          final stage2Refs = allRefs.sublist(17, 34);
          final stage3Refs = allRefs.sublist(34, 50);

          for (final entry in [
            (stageId: 1, refs: stage1Refs),
            (stageId: 2, refs: stage2Refs),
            (stageId: 3, refs: stage3Refs),
          ]) {
            await repository.bulkMarkComplete(
              BulkCompletionRequest(
                curriculumId: curriculumId,
                sefariaRefs: entry.refs,
                stageId: entry.stageId,
                trackType: trackType,
                awardGamificationPoints: false,
              ),
            );
          }

          final allCompletions = await repository.getCompletionsByCurriculum(
            curriculumId,
          );
          expect(allCompletions, hasLength(50));

          final state = await streakState.read();
          expect(
            state.currentStreak,
            0,
            reason:
                'Prior completions across all stages must not credit a streak '
                '(bulk-mark-prior writes must not create streak events)',
          );
        },
      );

      test(
        'regression: stage-1-only bulk-mark-prior still yields currentStreak == 0',
        () async {
          final refs = List.generate(20, (i) => 'Mishnah Berachot $i:1');

          await repository.bulkMarkComplete(
            BulkCompletionRequest(
              curriculumId: 'mishnayos',
              sefariaRefs: refs,
              stageId: 1,
              trackType: 'personal',
              awardGamificationPoints: false,
            ),
          );

          final state = await streakState.read();
          expect(state.currentStreak, 0);
        },
      );

      test(
        'regression: stage-2 bulk-mark-prior now yields currentStreak == 0 '
        '(was broken before DNI-370)',
        () async {
          final refs = List.generate(5, (i) => 'Mishnah Berachot $i:1');

          await repository.bulkMarkComplete(
            BulkCompletionRequest(
              curriculumId: 'mishnayos',
              sefariaRefs: refs,
              stageId: 1,
              trackType: 'personal',
              awardGamificationPoints: false,
            ),
          );
          await repository.bulkMarkComplete(
            BulkCompletionRequest(
              curriculumId: 'mishnayos',
              sefariaRefs: refs,
              stageId: 2,
              trackType: 'personal',
              awardGamificationPoints: false,
            ),
          );

          final state = await streakState.read();
          expect(
            state.currentStreak,
            0,
            reason: 'Stage-2 bulk-mark-prior must suppress streak (DNI-370)',
          );
        },
      );
    },
  );
}

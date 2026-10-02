// Story 1.24 (DNI-486) AC-1 — a tutor's governed main-track writes go
// through the typed Story 1.10 callables on TutorWriteService, each with
// its own client actionId, after the tutor preflight.

@Tags(['tutor_mode'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_governed_writes.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_write_preflight.dart';

import '../../../../helpers/tutoring/tutor_learning_harness.dart';

void main() {
  group('governed main-track writes → Story 1.10 callables', () {
    test('a study-day replace upserts each day and tombstones the removed '
        'one, each with its own client actionId', () async {
      final h = TutorHarness();
      addTearDown(h.dispose);

      await h.governed.replaceStudyDays(
        upserts: [
          (docId: 'mishnayos_1', data: {'day_of_week': 1}),
        ],
        removedDocIds: ['mishnayos_7'],
      );

      expect(h.invoker.calls.map((c) => c.fn), [
        'tutorDeleteStudyDayConfig',
        'tutorUpsertStudyDayConfig',
      ]);
      final actionIds = h.invoker.calls.map((c) => c.args['actionId']).toSet();
      expect(actionIds, hasLength(2));
    });

    test(
      'a goal edit is tutorUpsertGoal; ending it is tutorDeleteGoal',
      () async {
        final h = TutorHarness();
        addTearDown(h.dispose);

        await h.governed.upsertGoal(goalId: 'g1', data: {'description': 'x'});
        await h.governed.endGoal('g1');

        expect(h.invoker.calls.map((c) => c.fn), [
          'tutorUpsertGoal',
          'tutorDeleteGoal',
        ]);
      },
    );

    test('a refused preflight throws before any call', () async {
      final h = TutorHarness(online: false);
      addTearDown(h.dispose);

      await expectLater(
        h.governed.upsertGoal(goalId: 'g1', data: const {}),
        throwsA(
          isA<TutorGovernedWriteException>().having(
            (e) => e.refusal,
            'refusal',
            isA<TutorPreflightOffline>(),
          ),
        ),
      );
      expect(h.invoker.calls, isEmpty);
    });
  });
}

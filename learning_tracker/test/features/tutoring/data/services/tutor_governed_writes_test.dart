// Story 1.24 (DNI-486) AC-1 — a tutor's governed main-track writes go
// through the typed governed callables on TutorWriteService after the tutor
// preflight: each action is ONE callable with ONE client actionId.

@Tags(['tutor_mode'])
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_governed_writes.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_write_preflight.dart';

import '../../../../helpers/tutoring/tutor_learning_harness.dart';

void main() {
  group('governed main-track writes → Story 1.10 callables', () {
    test('a study-day replace is ONE tutorReplaceStudyDays call: every '
        'upsert and tombstone under one client actionId', () async {
      final h = TutorHarness();
      addTearDown(h.dispose);

      await h.governed.replaceStudyDays(
        curriculumId: 'mishnayos',
        upserts: [
          (docId: 'mishnayos_1', data: {'day_of_week': 1}),
          (docId: 'mishnayos_2', data: {'day_of_week': 2}),
        ],
        removedDocIds: ['mishnayos_7'],
      );

      final call = h.invoker.calls.single;
      expect(call.fn, 'tutorReplaceStudyDays');
      expect(call.args['curriculumId'], 'mishnayos');
      expect(call.args['upserts'], [
        {
          'configId': 'mishnayos_1',
          'configData': {'day_of_week': 1},
        },
        {
          'configId': 'mishnayos_2',
          'configData': {'day_of_week': 2},
        },
      ]);
      expect(call.args['removedConfigIds'], ['mishnayos_7']);
      expect(call.args['actionId'], isA<String>());
    });

    test('a failed replace throws and sends nothing more', () async {
      final h = TutorHarness();
      addTearDown(h.dispose);
      h.invoker.respond = (_) => throw FirebaseFunctionsException(
        code: 'deadline-exceeded',
        message: 'timeout',
      );

      await expectLater(
        h.governed.replaceStudyDays(
          curriculumId: 'mishnayos',
          upserts: [
            (docId: 'mishnayos_1', data: {'day_of_week': 1}),
          ],
          removedDocIds: ['mishnayos_7'],
        ),
        throwsA(isA<TutorGovernedWriteException>()),
      );
      expect(h.invoker.calls, hasLength(1));
    });

    test('an empty replace calls nothing', () async {
      final h = TutorHarness();
      addTearDown(h.dispose);
      await h.governed.replaceStudyDays(curriculumId: 'mishnayos', upserts: []);
      expect(h.invoker.calls, isEmpty);
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

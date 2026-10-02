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

  group('frozen action ids — a retry re-sends the same id (AC-5)', () {
    FirebaseFunctionsException timeout() => FirebaseFunctionsException(
      code: 'deadline-exceeded',
      message: 'timeout',
    );

    test('a timed-out study-day replace is retried with the SAME actionId, '
        'even when the volatile updated_at stamp moved', () async {
      final h = TutorHarness();
      addTearDown(h.dispose);
      var first = true;
      h.invoker.respond = (call) {
        if (first) {
          first = false;
          throw timeout();
        }
        return h.invoker.successFor(call, replayed: true);
      };

      Future<void> save(String stamp) => h.governed.replaceStudyDays(
        curriculumId: 'mishnayos',
        upserts: [
          (docId: 'mishnayos_1', data: {'day_of_week': 1, 'updated_at': stamp}),
        ],
        removedDocIds: ['mishnayos_7'],
      );

      await expectLater(
        save('2026-10-01T09:00:00Z'),
        throwsA(isA<TutorGovernedWriteException>()),
      );
      await save('2026-10-01T09:00:07Z');

      expect(h.invoker.calls, hasLength(2));
      expect(
        h.invoker.calls[1].args['actionId'],
        h.invoker.calls[0].args['actionId'],
      );
    });

    test('a success releases the id: the next identical action is a NEW '
        'action', () async {
      final h = TutorHarness();
      addTearDown(h.dispose);

      await h.governed.upsertGoal(goalId: 'g1', data: {'description': 'x'});
      await h.governed.upsertGoal(goalId: 'g1', data: {'description': 'x'});

      expect(
        h.invoker.calls[1].args['actionId'],
        isNot(h.invoker.calls[0].args['actionId']),
      );
    });

    test(
      'a definitive rejection releases the id (nothing was written)',
      () async {
        final h = TutorHarness();
        addTearDown(h.dispose);
        var first = true;
        h.invoker.respond = (call) {
          if (first) {
            first = false;
            throw FirebaseFunctionsException(
              code: 'invalid-argument',
              message: 'bad',
            );
          }
          return h.invoker.successFor(call);
        };

        await expectLater(
          h.governed.endGoal('g1'),
          throwsA(isA<TutorGovernedWriteException>()),
        );
        await h.governed.endGoal('g1');

        expect(
          h.invoker.calls[1].args['actionId'],
          isNot(h.invoker.calls[0].args['actionId']),
        );
      },
    );

    test('a changed payload after a timeout is a different action', () async {
      final h = TutorHarness();
      addTearDown(h.dispose);
      var first = true;
      h.invoker.respond = (call) {
        if (first) {
          first = false;
          throw timeout();
        }
        return h.invoker.successFor(call);
      };

      await expectLater(
        h.governed.setProfileProgram(
          curriculumId: 'mishnayos',
          data: {'tracking_start_ref': 'a'},
        ),
        throwsA(isA<TutorGovernedWriteException>()),
      );
      await h.governed.setProfileProgram(
        curriculumId: 'mishnayos',
        data: {'tracking_start_ref': 'b'},
      );

      expect(
        h.invoker.calls[1].args['actionId'],
        isNot(h.invoker.calls[0].args['actionId']),
      );
    });

    test('the session ledger outlives a rebuilt writes instance', () async {
      final h = TutorHarness();
      addTearDown(h.dispose);
      final ledger = TutorGovernedActionLedger();
      var n = 0;
      TutorGovernedWrites build() => TutorGovernedWrites(
        selection: h.selection,
        service: h.service,
        preflight: h.preflight,
        clock: () => DateTime.utc(2026, 10, 1, 9),
        newUlid: (_) => 'ULID${n++}',
        ledger: ledger,
      );
      var first = true;
      h.invoker.respond = (call) {
        if (first) {
          first = false;
          throw timeout();
        }
        return h.invoker.successFor(call, replayed: true);
      };

      await expectLater(
        build().endGoal('g1'),
        throwsA(isA<TutorGovernedWriteException>()),
      );
      expect(ledger.length, 1);
      await build().endGoal('g1');

      expect(h.invoker.calls.map((c) => c.args['actionId']), [
        'ULID0',
        'ULID0',
      ]);
      expect(ledger.length, 0);
    });
  });
}

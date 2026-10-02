// Mirror test for `lib/domain/learner_state/completed_units.dart` (DNI-465
// AC-7: completion numbers and retractable siyum completion).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/completed_units.dart';
import 'package:learning_tracker/domain/learner_state/counted_events.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';

import '../../helpers/learner_state/engine_fixtures.dart';

void main() {
  final corpus = mishnayosCorpus();
  const peah1 = 'Mishnah Peah 1:1';
  const peah2 = 'Mishnah Peah 1:2';

  /// Completed units of [events] after counting (voids applied).
  List<CompletedUnit> run(
    List<LearningEvent> events, {
    int? firstStage,
    bool Function(String leaf)? inScope,
  }) => completedUnits(
    corpus: corpus,
    inScope: inScope ?? (_) => true,
    countedLearns: countEvents(events).learns,
    firstStage: firstStage,
  );

  CompletedUnit? unit(List<CompletedUnit> units, Object node) {
    for (final u in units) {
      if (u.unit == node) return u;
    }
    return null;
  }

  group('AC-7 derives completion numbers and retractable siyum completion', () {
    test('completion by a sub-track fires k = 1', () {
      final subTrack = engineUlid(900);
      final units = run([
        engineLearn(1, peah1, source: subTrack, minutes: 1),
        engineLearn(2, peah2, source: subTrack, minutes: 2),
      ]);
      final peahUnit = unit(units, peah)!;
      expect(peahUnit.completionNumber, 1);
      expect(peahUnit.firstCompletedAt, {1: engineAt(2)});
    });

    test('completion by backfill fires k = 1 at its effectiveAt', () {
      final units = run([engineGround(1, peah, minutes: 500)]);
      expect(unit(units, peah)!.firstCompletedAt, {1: engineAt(500)});
      final backdated = run([
        engineLearn(
          2,
          'Mishnah Peah',
          level: 'masechta',
          dateState: DateState.beforeTracking,
          minutes: 500,
          originalMinutes: 7,
        ),
      ]);
      expect(unit(backdated, peah)!.firstCompletedAt, {1: engineAt(7)});
    });

    test('a node event counts once per covered leaf', () {
      final once = run([engineGround(1, berakhot)]);
      expect(unit(once, berakhot)!.completionNumber, 1);
      final twice = run([
        engineGround(1, berakhot, minutes: 1),
        engineGround(2, berakhot, minutes: 2),
      ]);
      expect(unit(twice, berakhot)!.completionNumber, 2);
      expect(unit(twice, berakhot)!.firstCompletedAt, {
        1: engineAt(1),
        2: engineAt(2),
      });
    });

    test('k is the minimum count over the unit leaves', () {
      final units = run([
        engineLearn(1, peah1, minutes: 1),
        engineLearn(2, peah1, minutes: 2),
        engineLearn(3, peah1, minutes: 3),
        engineLearn(4, peah2, minutes: 4),
        engineLearn(5, peah2, minutes: 5),
      ]);
      expect(unit(units, peah)!.completionNumber, 2);
      expect(unit(units, peah)!.firstCompletedAt, {
        1: engineAt(4),
        2: engineAt(5),
      });
    });

    test('events with stage > first are excluded; chazara never yields a '
        'new k = 1', () {
      final units = run([
        engineLearn(1, peah1, stage: 1, minutes: 1),
        engineLearn(2, peah2, stage: 1, minutes: 2),
        engineLearn(3, peah1, stage: 2, minutes: 3),
        engineLearn(4, peah2, stage: 2, minutes: 4),
      ], firstStage: 1);
      expect(unit(units, peah)!.completionNumber, 1);
      expect(unit(units, peah)!.firstCompletedAt, {1: engineAt(2)});

      final chazaraOnly = run([
        engineLearn(1, peah1, stage: 2),
        engineLearn(2, peah2, stage: 2),
      ], firstStage: 1);
      expect(unit(chazaraOnly, peah), isNull);
    });

    test('a void that un-completes a unit removes it; a later re-completion '
        're-adds it with a new first_completed_at(1)', () {
      final base = [
        engineLearn(1, peah1, minutes: 1),
        engineLearn(2, peah2, minutes: 2),
      ];
      expect(unit(run(base), peah)!.firstCompletedAt, {1: engineAt(2)});

      final voided = [...base, engineVoid(3, 2, minutes: 3)];
      expect(unit(run(voided), peah), isNull);

      final again = [...voided, engineLearn(4, peah2, minutes: 40)];
      expect(unit(run(again), peah)!.firstCompletedAt, {1: engineAt(40)});
    });

    test('a seder completes with its last masechta, after it in order', () {
      final units = run([
        engineGround(1, berakhot, minutes: 1),
        engineGround(2, peah, minutes: 2),
      ]);
      expect(units.map((u) => u.unit), [berakhot, peah, zeraim]);
      expect(unit(units, zeraim)!.firstCompletedAt, {1: engineAt(2)});
    });

    test('a unit only partly in scope never completes', () {
      final units = run([
        engineGround(1, zeraim),
      ], inScope: (leaf) => leaf.startsWith('Mishnah Peah'));
      expect(units.map((u) => u.unit), [peah]);
    });

    test('no events, unknown refs or no unit levels give no units', () {
      expect(run(const []), isEmpty);
      expect(run([engineLearn(1, 'Mishnah Nope 1:1')]), isEmpty);
    });

    test('the engine retracts completion when a void removes it', () {
      const engine = LearnerStateEngine();
      final events = [
        engineLearn(1, peah1, minutes: 1),
        engineLearn(2, peah2, source: engineUlid(900), minutes: 2),
      ];
      final complete = engine.run(engineInputs(events: events));
      expect(complete[engineCurriculum]!.completedUnits.single.unit, peah);
      final retracted = engine.run(
        engineInputs(events: [...events, engineVoid(3, 1, minutes: 3)]),
      );
      expect(retracted[engineCurriculum]!.completedUnits, isEmpty);
    });

    test('the engine reads the first stage from live stage docs', () {
      final state = const LearnerStateEngine().run(
        engineInputs(
          events: [
            engineLearn(1, peah1, stage: 2),
            engineLearn(2, peah2, stage: 2),
          ],
          intents: {
            engineCurriculum: engineIntent(
              stages: [engineStage(1), engineStage(2)],
            ),
          },
        ),
      );
      expect(state[engineCurriculum]!.completedUnits, isEmpty);
    });
  });

  group('firstStageOrder', () {
    test('is the lowest live stage_order', () {
      expect(firstStageOrder([engineStage(3), engineStage(1)], const []), 1);
    });

    test('ignores ended or unreadable stage docs', () {
      final ended = MainTrackConfigDoc(
        collection: MainTrackConfigDoc.stages,
        docId: 'x',
        curriculumId: engineCurriculum,
        fields: const {'stage_order': 0},
        endedAt: engineAt(1),
      );
      final unreadable = MainTrackConfigDoc(
        collection: MainTrackConfigDoc.stages,
        docId: 'y',
        curriculumId: engineCurriculum,
        fields: const {'stage_order': 'one'},
      );
      expect(firstStageOrder([ended, unreadable, engineStage(2)], const []), 2);
    });

    test('falls back to the lowest event stage, else null', () {
      expect(
        firstStageOrder(const [], [
          engineLearn(1, peah1, stage: 3),
          engineLearn(2, peah1, stage: 2),
          engineLearn(3, peah1),
        ]),
        2,
      );
      expect(firstStageOrder(const [], [engineLearn(1, peah1)]), isNull);
    });
  });
}

// Mirror test for `lib/domain/learner_state/main_track_position.dart`
// (DNI-465 T3: AD-33 schedulableRefs, current unit and position).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/main_track_position.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';

import '../../helpers/learner_state/engine_fixtures.dart';
import '../../helpers/learner_state_fixtures.dart';

void main() {
  final corpus = mishnayosCorpus();

  group('unitOf', () {
    test('is the innermost unit-level ancestor', () {
      expect(unitOf('Mishnah Berakhot 2:1', corpus), berakhot);
      expect(unitOf('Mishnah Shabbat 1:2', corpus), shabbat);
    });

    test('is null for an unknown leaf', () {
      expect(unitOf('Mishnah Nope 1:1', corpus), isNull);
    });
  });

  group('schedulableRefs', () {
    const order = ['a', 'b', 'c', 'd', 'e'];

    test('drops learnt and held leaves and rotates at start', () {
      expect(
        schedulableRefs(
          order: order,
          learnt: {'b'},
          heldGround: {'e'},
          start: 'c',
        ),
        ['c', 'd', 'a'],
      );
    });

    test('a start outside the order rotates nothing', () {
      expect(schedulableRefs(order: order, learnt: {}, start: 'z'), order);
    });
  });

  group('trackingStartAt', () {
    test('is the latest tracking_start_ref entry of the curriculum', () {
      final history = [
        engineStartEntry(10, 'Mishnah Peah 1:1', minutes: 50),
        engineStartEntry(20, 'Mishnah Berakhot 1:1', minutes: 30),
        ChangeLogEntry(
          id: engineUlid(30),
          entity: GovernedEntity.mainTrackProgram,
          entityId: engineCurriculum,
          actionId: engineUlid(31),
          before: {'profile_programs/$engineCurriculum.program_id': null},
          after: {'profile_programs/$engineCurriculum.program_id': 'p'},
          at: engineAt(90),
          actor: parentActor,
        ),
      ];
      expect(trackingStartAt(history, engineCurriculum), engineAt(50));
      expect(trackingStartAt(history, 'bavli'), isNull);
      expect(trackingStartAt(const [], engineCurriculum), isNull);
    });

    test('reads original_at when present', () {
      final entry = ChangeLogEntry(
        id: engineUlid(10),
        entity: GovernedEntity.mainTrackProgram,
        entityId: engineCurriculum,
        actionId: engineUlid(11),
        before: {'profile_programs/$engineCurriculum.tracking_start_ref': null},
        after: {'profile_programs/$engineCurriculum.tracking_start_ref': 'x'},
        at: engineAt(90),
        originalAt: engineAt(5),
        actor: parentActor,
      );
      expect(trackingStartAt([entry], engineCurriculum), engineAt(5));
    });
  });

  group('deriveMainTrack', () {
    test('with nothing learnt and no start, position is the first leaf', () {
      final record = deriveMainTrack(
        corpus: corpus,
        order: corpus.leaves,
        learnt: const {},
        countedLearns: const [],
      );
      expect(record.position, 'Mishnah Berakhot 1:1');
      expect(record.currentUnit, isNull);
      expect(record.schedulableRefs, corpus.leaves);
    });

    test('the latest main event anchors the unit', () {
      final learns = [
        engineLearn(1, 'Mishnah Shabbat 1:1', stage: 1, minutes: 1),
        engineLearn(2, 'Mishnah Peah 1:1', stage: 1, minutes: 2),
      ];
      final record = deriveMainTrack(
        corpus: corpus,
        order: corpus.leaves,
        learnt: {'Mishnah Shabbat 1:1', 'Mishnah Peah 1:1'},
        countedLearns: learns,
      );
      expect(record.currentUnit, peah);
      expect(record.position, 'Mishnah Peah 1:2');
    });

    test('free ticks (no stage) and chazara (stage > first) never anchor', () {
      final record = deriveMainTrack(
        corpus: corpus,
        order: corpus.leaves,
        learnt: {
          'Mishnah Peah 1:1',
          'Mishnah Shabbat 1:1',
          'Mishnah Berakhot 1:1',
        },
        countedLearns: [
          engineLearn(1, 'Mishnah Peah 1:1', stage: 1, minutes: 1),
          engineLearn(2, 'Mishnah Shabbat 1:1', minutes: 2),
          engineLearn(3, 'Mishnah Berakhot 1:1', stage: 2, minutes: 3),
        ],
        firstStage: 1,
      );
      expect(record.currentUnit, peah);
      expect(record.position, 'Mishnah Peah 1:2');
    });

    test('before-tracking events never anchor', () {
      final record = deriveMainTrack(
        corpus: corpus,
        order: corpus.leaves,
        learnt: {'Mishnah Shabbat 1:1'},
        countedLearns: [
          engineLearn(
            1,
            'Mishnah Shabbat 1:1',
            dateState: DateState.beforeTracking,
          ),
        ],
      );
      expect(record.currentUnit, isNull);
      expect(record.position, 'Mishnah Berakhot 1:1');
    });

    test(
      'engine position follows governed order and start after learn/void',
      () {
        final baseIntent = engineIntent(trackingStartRef: 'Mishnah Peah 1:1');
        MainTrackOrderEntry order(NodeEntry node, int sort) =>
            MainTrackOrderEntry(
              docId: '${engineCurriculum}_${node.level}_${node.ref}',
              curriculumId: engineCurriculum,
              level: node.level,
              ref: node.ref,
              userSortOrder: sort,
              lastChangeId: engineUlid(900 + sort),
            );
        final intent = MainTrackIntent(
          curriculumId: engineCurriculum,
          track: baseIntent.track,
          program: baseIntent.program,
          order: [order(peah, 0), order(berakhot, 1)],
        );
        final inputs = (List<LearningEvent> events) => engineInputs(
          events: events,
          intents: {engineCurriculum: intent},
          intentHistory: [
            engineStartEntry(800, 'Mishnah Peah 1:1', minutes: 2),
          ],
        );
        const engine = LearnerStateEngine();

        final before = engine.run(inputs(const []))[engineCurriculum]!;
        final afterLearn = engine.run(
          inputs([engineLearn(1, 'Mishnah Peah 1:1', stage: 1, minutes: 10)]),
        )[engineCurriculum]!;
        final afterVoid = engine.run(
          inputs([
            engineLearn(1, 'Mishnah Peah 1:1', stage: 1, minutes: 10),
            engineVoid(2, 1, minutes: 20),
          ]),
        )[engineCurriculum]!;

        expect(before.mainTrackPosition, 'Mishnah Peah 1:1');
        expect(afterLearn.mainTrackPosition, 'Mishnah Peah 1:2');
        expect(afterVoid.mainTrackPosition, 'Mishnah Peah 1:1');
        expect(afterLearn.schedulableRefs, isNot(contains('Mishnah Peah 1:1')));
        expect(afterVoid.schedulableRefs, contains('Mishnah Peah 1:1'));
      },
    );

    test('position is null when all leaves are counted', () {
      final leaves = corpus.leaves;
      final state = const LearnerStateEngine().run(
        engineInputs(
          events: [
            for (var i = 0; i < leaves.length; i++)
              engineLearn(i + 1, leaves[i], stage: 1, minutes: i + 1),
          ],
        ),
      )[engineCurriculum]!;

      expect(state.schedulableRefs, isEmpty);
      expect(state.mainTrackPosition, isNull);
    });
  });
}

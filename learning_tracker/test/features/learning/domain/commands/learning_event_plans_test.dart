// Mirror test for
// `lib/features/learning/domain/commands/learning_event_plans.dart`
// (DNI-469 AC-2, AC-4, AC-6: event construction).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_event_plans.dart';
import 'package:learning_tracker/features/learning/domain/commands/unlearn_plan.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state_fixtures.dart';

void main() {
  final now = engineAt(600);
  var seq = 9000;
  CommandStamp stamp() => CommandStamp(
    actor: parentActor,
    nowUtc: now,
    // Descending source: CommandStamp must still hand out ascending ids.
    newUlid: (at) => engineUlid(seq--),
  );

  test('CommandStamp mints ascending ids up front', () {
    final ids = stamp().ids(5);
    expect(ids, [...ids]..sort());
    expect(ids.toSet(), hasLength(5));
  });

  test('earnsPointsEntry: only main dated / catch_up learns', () {
    expect(earnsPointsEntry(engineLearn(1, 'r')), isTrue);
    expect(
      earnsPointsEntry(engineLearn(1, 'r', dateState: DateState.catchUp)),
      isTrue,
    );
    expect(
      earnsPointsEntry(
        engineLearn(1, 'r', dateState: DateState.beforeTracking),
      ),
      isFalse,
    );
    expect(earnsPointsEntry(engineLearn(1, 'r', source: ulidB)), isFalse);
    expect(earnsPointsEntry(engineVoid(2, 1)), isFalse);
  });

  test('planCapture: one event per leaf and per node, fixed time, awards '
      'paired at created_at = recorded_at', () {
    final units = planCapture(
      stamp: stamp(),
      curriculumId: engineCurriculum,
      leaves: ['Mishnah Berakhot 1:1', 'Mishnah Berakhot 1:2'],
      nodes: const [],
      source: LearningEvent.sourceMain,
      dateState: DateState.dated,
      learnedOn: '2026-09-01',
      stage: null,
      amount: 10,
    );
    expect(units, hasLength(2));
    for (final u in units) {
      final e = u.events.single;
      expect(e.learnedOn, '2026-09-01');
      expect(effectiveAt(e), now);
      expect(u.awards.single.eventId, e.id);
      expect(u.awards.single.amount, 10);
      expect(u.awards.single.createdAt, now);
      expect(u.awards.single.docId, 'pts_${e.id}');
    }
  });

  test('planCapture before_tracking: node events carry level and null '
      'learned_on, and no award', () {
    final units = planCapture(
      stamp: stamp(),
      curriculumId: engineCurriculum,
      leaves: const [],
      nodes: const [berakhot],
      source: LearningEvent.sourceMain,
      dateState: DateState.beforeTracking,
      learnedOn: '2026-09-01',
      stage: null,
      amount: 10,
    );
    final e = units.single.events.single;
    expect(e.level, 'masechta');
    expect(e.ref, berakhot.ref);
    expect(e.learnedOn, isNull);
    expect(units.single.awards, isEmpty);
    expect(e.toStorage(), isNotEmpty, reason: 'valid AD-52 event');
  });

  test('copyOf and a non-re-date replacement keep effectiveAt(original)', () {
    final original = engineLearn(1, 'Mishnah Berakhot 1:1', minutes: 30);
    final copy = copyOf(stamp(), engineUlid(50), original);
    expect(effectiveAt(copy), effectiveAt(original));
    expect(rawRecordedAtForSkewRule(copy), now);
    expect(copy.learnedOn, original.learnedOn);

    final moved = replacementOf(
      stamp(),
      engineUlid(51),
      original,
      const ResolvedReplacement(
        ref: 'Mishnah Berakhot 1:2',
        level: null,
        source: LearningEvent.sourceMain,
        dateState: DateState.dated,
        learnedOn: '2026-09-01',
        stage: null,
        redate: false,
      ),
    );
    expect(effectiveAt(moved), effectiveAt(original));
    expect(moved.ref, 'Mishnah Berakhot 1:2');
  });

  test('a re-date replacement is stamped now (no original_recorded_at)', () {
    final original = engineLearn(1, 'Mishnah Berakhot 1:1', minutes: 30);
    final redated = replacementOf(
      stamp(),
      engineUlid(52),
      original,
      const ResolvedReplacement(
        ref: 'Mishnah Berakhot 1:1',
        level: null,
        source: LearningEvent.sourceMain,
        dateState: DateState.catchUp,
        learnedOn: '2026-08-29',
        stage: null,
        redate: true,
      ),
    );
    expect(effectiveAt(redated), now);
  });

  test('planUnlearnWrites: re-issues before the node void, inherited '
      'effective instant, then leaf voids', () {
    final node = engineGround(1, zeraim, minutes: 5);
    final leaf = engineLearn(2, 'Mishnah Berakhot 1:2');
    final plan = planUnlearn(
      curriculumId: engineCurriculum,
      leafSet: {'Mishnah Berakhot 1:2'},
      counted: [node, leaf],
      corpus: mishnayosCorpus(),
    );
    final units = planUnlearnWrites(stamp(), plan);
    expect(units, hasLength(2));
    final nodeUnit = units.first.events;
    expect(nodeUnit.last.targetId, node.id);
    for (final r in nodeUnit.take(nodeUnit.length - 1)) {
      expect(r.dateState, DateState.beforeTracking);
      expect(effectiveAt(r), effectiveAt(node));
      expect(r.learnedOn, isNull);
      expect(r.level, isNotNull);
    }
    expect(units.last.events.single.targetId, leaf.id);
    expect(units.expand((u) => u.awards), isEmpty);
  });

  test('LearningLogView: voided, counted and lock-ignored', () {
    // The configured New York fixture's Shabbos contains engineAt(6000).
    final kept = engineLearn(1, 'a');
    final voided = engineLearn(2, 'b');
    final locked = engineLearn(3, 'c', minutes: 6000);
    final view = LearningLogView.of(
      [kept, voided, engineVoid(4, 2), locked],
      c0SettingsHistory(),
      engineAt(9000),
    );
    expect(view.isCounted(kept.id), isTrue);
    expect(view.isVoided(voided.id), isTrue);
    expect(view.isLockIgnored(locked.id), isTrue);
    expect(view.byId, hasLength(4));
  });

  test('a tutor device history supplies lock windows independently of the '
      'target learner history', () {
    final target = c0NoLocationHistory();
    final deviceUser = c0SettingsHistory();
    final locked = engineLearn(5, 'device-lock', minutes: 6000);
    final view = LearningLogView.of(
      [locked],
      target,
      engineAt(9000),
      lockSettingsHistories: [deviceUser],
    );

    expect(view.isLockIgnored(locked.id), isTrue);
  });
}

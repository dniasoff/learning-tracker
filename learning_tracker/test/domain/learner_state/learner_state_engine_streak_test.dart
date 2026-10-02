// DNI-479 (Story 1.17) AC-1 / AC-4: the per-curriculum streak as the
// engine derives it on `LearnerState` (AD-40). The `streakDay` and
// `curriculumStreak` rules themselves are covered in streak_test.dart
// (DNI-466); this file checks what reaches each curriculum's state.
//
// The learner is in Lakewood (America/New_York, EDT in late March 2026).
// Mon 03-23 .. Thu 03-26 are ordinary weekdays; Shabbos is 03-28.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';

import '../../helpers/learner_state/engine_fixtures.dart';
import '../../helpers/learner_state/lock_fixtures.dart';
import '../../helpers/learner_state_fixtures.dart';

const _tanach = 'tanach';

InMemoryCorpus _tanachCorpus() => InMemoryCorpus(_tanach, const [
  CorpusNode(NodeEntry(level: 'sefer', ref: 'Genesis'), [
    CorpusNode(NodeEntry(level: 'chapter', ref: 'Genesis 1')),
    CorpusNode(NodeEntry(level: 'chapter', ref: 'Genesis 2')),
  ]),
]);

/// 11:00 EDT on 2026-03-[day].
DateTime _morning(int day) => DateTime.utc(2026, 3, day, 15);

String _date(int day) => '2026-03-${day.toString().padLeft(2, '0')}';

var _next = 0;

LearningEvent _learn(
  int day, {
  String curriculumId = engineCurriculum,
  String source = LearningEvent.sourceMain,
  DateState dateState = DateState.dated,
  DateTime? at,
}) => LearningEvent.learn(
  id: engineUlid(++_next),
  curriculumId: curriculumId,
  ref: curriculumId == _tanach ? 'Genesis 1' : 'Mishnah Berakhot 1:1',
  source: source,
  dateState: dateState,
  learnedOn: dateState == DateState.beforeTracking ? null : _date(day),
  stage: 1,
  recordedAt: at ?? _morning(day),
  actor: parentActor,
);

LearningEvent _void(LearningEvent target, int day) => LearningEvent.voidOf(
  id: engineUlid(++_next),
  targetId: target.id,
  recordedAt: _morning(day).add(const Duration(hours: 1)),
  actor: parentActor,
);

void main() {
  const engine = LearnerStateEngine();
  final history = constantHistory(lakewood);

  LearnerState run(List<LearningEvent> events, {int today = 26}) => engine.run(
    engineInputs(
      events: events,
      intents: {
        engineCurriculum: engineIntent(),
        _tanach: engineIntent(curriculumId: _tanach),
      },
      corpora: {engineCurriculum: mishnayosCorpus(), _tanach: _tanachCorpus()},
      settingsHistory: history,
      nowUtc: _morning(today),
    ),
  );

  group('AC-1: one streak per curriculum', () {
    test('each curriculum carries its own streak; switching switches it', () {
      final state = run([
        for (final d in [23, 24, 25, 26]) _learn(d),
        for (final d in [25, 26]) _learn(d, curriculumId: _tanach),
      ]);
      expect(
        state[engineCurriculum]!.streak,
        const CurriculumStreak(current: 4, best: 4, lastDay: '2026-03-26'),
      );
      expect(
        state[_tanach]!.streak,
        const CurriculumStreak(current: 2, best: 2, lastDay: '2026-03-26'),
      );
    });

    test('learning in one curriculum never extends another', () {
      final state = run([
        _learn(24),
        _learn(25, curriculumId: _tanach),
        _learn(26),
      ]);
      // Mishnayos missed 03-25 (only Tanach was learnt that day).
      expect(state[engineCurriculum]!.streak!.current, 1);
      expect(state[engineCurriculum]!.streak!.best, 1);
      expect(state[_tanach]!.streak!.current, 1);
    });

    test('a curriculum that is not evaluated has no streak', () {
      final state = engine.run(
        engineInputs(
          events: [_learn(26, curriculumId: 'bavli')],
          settingsHistory: history,
          nowUtc: _morning(26),
        ),
      );
      expect(state['bavli']!.evaluated, isFalse);
      expect(state['bavli']!.streak, isNull);
      expect(state[engineCurriculum]!.streak, isNotNull);
    });
  });

  group('AC-1: days that never count', () {
    test('a sub-track-only day does not extend or keep the streak', () {
      final subTrack = engineUlid(900);
      final state = run([
        _learn(23),
        _learn(24, source: subTrack),
        _learn(25),
        _learn(26),
      ]);
      expect(
        state[engineCurriculum]!.streak,
        const CurriculumStreak(current: 2, best: 2, lastDay: '2026-03-26'),
      );
      // The sub-track learning still counts for the learnt set.
      expect(state[engineCurriculum]!.learntLeaves, isNotEmpty);
    });

    test('a before_tracking day does not add a streak day', () {
      final state = run([
        _learn(24, dateState: DateState.beforeTracking),
        _learn(25),
        _learn(26),
      ]);
      expect(state[engineCurriculum]!.streak!.current, 2);
      expect(state[engineCurriculum]!.streak!.best, 2);
    });

    test('only before_tracking learning is a zero streak', () {
      final state = run([_learn(26, dateState: DateState.beforeTracking)]);
      expect(
        state[engineCurriculum]!.streak,
        const CurriculumStreak(current: 0, best: 0),
      );
    });
  });

  group('AC-1: voided and uncounted events do not survive derivation', () {
    test('a voided main event no longer keeps its day', () {
      final yesterday = _learn(25);
      final events = [_learn(24), yesterday, _learn(26)];
      expect(run(events)[engineCurriculum]!.streak!.current, 3);
      final voided = run([...events, _void(yesterday, 26)]);
      expect(
        voided[engineCurriculum]!.streak,
        const CurriculumStreak(current: 1, best: 1, lastDay: '2026-03-26'),
      );
    });

    test('a backdated tick does not repair a missed day', () {
      final state = run([
        _learn(24),
        // Recorded on 03-26 for 03-25: dated, but not on its effective day.
        _learn(25, at: _morning(26)),
        _learn(26),
      ]);
      expect(state[engineCurriculum]!.streak!.current, 1);
    });

    test('an event recorded inside a lock is lock-ignored', () {
      // Shabbos 03-28 13:00 EDT: inside the lock.
      final inLock = _learn(28, at: DateTime.utc(2026, 3, 28, 17));
      final state = run([_learn(27), inLock], today: 27);
      expect(state.lockIgnoredEventIds, contains(inLock.id));
      final later = run([_learn(27), inLock], today: 29);
      expect(later[engineCurriculum]!.streak!.lastDay, '2026-03-27');
    });
  });
}

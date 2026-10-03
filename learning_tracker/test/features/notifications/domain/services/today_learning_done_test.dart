// Mirror test for
// `lib/features/notifications/domain/services/today_learning_done.dart`
// (DNI-482 AC-5: "today's learning is done" is a LearnerState projection;
// counted learning counts, voided and lock-ignored learning does not).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/notifications/domain/services/today_learning_done.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/fake_learner_state.dart';
import '../../../../helpers/learner_state_fixtures.dart';

const _engine = LearnerStateEngine();

// Tue 2026-09-08 (unlocked) and Sat 2026-09-05 (inside the UTC
// no-location learner's Shabbos lock), both 10:00Z.
const _tuesday = 7 * 1440 + 600;
const _shabbos = 4 * 1440 + 600;

void main() {
  final history = c0SettingsHistory();

  test('a counted learn on today\'s civil date is done', () {
    final state = _engine.run(
      engineInputs(
        events: [
          engineLearn(
            1,
            'Mishnah Berakhot 1:1',
            minutes: _tuesday,
            learnedOn: '2026-09-08',
          ),
        ],
        nowUtc: engineAt(_tuesday + 120),
      ),
    );
    expect(state.today, '2026-09-08');
    expect(learnedToday(state, history), isTrue);
    expect(
      learnedToday(state, history, curriculumId: engineCurriculum),
      isTrue,
    );
    expect(learnedToday(state, history, curriculumId: 'bavli'), isFalse);
    expect(learnedToday(state, history, day: '2026-09-07'), isFalse);
  });

  test('a voided learn does not count', () {
    final state = _engine.run(
      engineInputs(
        events: [
          engineLearn(
            1,
            'Mishnah Berakhot 1:1',
            minutes: _tuesday,
            learnedOn: '2026-09-08',
          ),
          engineVoid(2, 1, minutes: _tuesday + 5),
        ],
        nowUtc: engineAt(_tuesday + 120),
      ),
    );
    expect(learnedToday(state, history), isFalse);
  });

  test('a learn stamped inside a lock does not count', () {
    final state = _engine.run(
      engineInputs(
        events: [
          engineLearn(
            1,
            'Mishnah Berakhot 1:1',
            minutes: _shabbos,
            learnedOn: '2026-09-05',
          ),
        ],
        nowUtc: engineAt(_shabbos + 120),
      ),
    );
    expect(state.lockIgnoredEventIds, {engineUlid(1)});
    expect(learnedToday(state, history), isFalse);
  });

  test('prior learning entered today (before_tracking) is not today\'s '
      'learning', () {
    final state = _engine.run(
      engineInputs(
        events: [engineGround(1, berakhot1, minutes: _tuesday)],
        nowUtc: engineAt(_tuesday + 120),
      ),
    );
    expect(learnedToday(state, history), isFalse);
  });

  test('a sub-track learn counts like any other source', () {
    final state = fakeLearnerState(
      today: '2026-09-08',
      countedLearns: [
        engineLearn(
          1,
          'Mishnah Peah 1:1',
          minutes: _tuesday,
          source: engineUlid(900),
          learnedOn: '2026-09-08',
        ),
      ],
    );
    expect(learnedToday(state, history), isTrue);
  });

  test('an incomplete state is not-ready, never "not done"', () {
    expect(
      () => learnedToday(null, history),
      throwsA(isA<LearnerStateNotReadyException>()),
    );
  });

  test('the effective instant decides the day', () {
    final state = fakeLearnerState(
      today: '2026-09-01',
      countedLearns: [
        // Recorded on Tuesday, but an undo copy of Monday's learning.
        LearningEvent.learn(
          id: engineUlid(1),
          curriculumId: engineCurriculum,
          ref: 'Mishnah Berakhot 1:1',
          source: LearningEvent.sourceMain,
          dateState: DateState.dated,
          learnedOn: '2026-09-01',
          recordedAt: engineAt(_tuesday),
          originalRecordedAt: engineAt(600),
          actor: parentActor,
        ),
      ],
    );
    expect(learnedToday(state, history), isTrue);
    expect(learnedToday(state, history, day: '2026-09-08'), isFalse);
  });
}

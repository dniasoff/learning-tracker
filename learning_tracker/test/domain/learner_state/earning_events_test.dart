// Mirror test for `lib/domain/learner_state/earning_events.dart` (DNI-468,
// Story 1.6): the stage-7 rule functions on their own. The engine-level
// acceptance cases (AC-1 to AC-3) are in learner_state_engine_test.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/earning_events.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/main_track_config_history.dart';
import 'package:learning_tracker/domain/learner_state/review_schedule.dart';

import '../../helpers/learner_state/c0_fixtures.dart';
import '../../helpers/learner_state/engine_fixtures.dart';

void main() {
  const b11 = 'Mishnah Berakhot 1:1';
  const b12 = 'Mishnah Berakhot 1:2';
  final corpus = mishnayosCorpus();
  final settings = c0SettingsHistory();

  group('canEarn', () {
    test('only main dated or catch_up learn events', () {
      expect(canEarn(engineLearn(1, b11)), isTrue);
      expect(
        canEarn(engineLearn(1, b11, dateState: DateState.catchUp)),
        isTrue,
      );
      expect(
        canEarn(engineLearn(1, b11, dateState: DateState.beforeTracking)),
        isFalse,
      );
      expect(canEarn(engineLearn(1, b11, source: engineUlid(70))), isFalse);
      expect(canEarn(engineVoid(2, 1)), isFalse);
    });
  });

  group('firstLearningEarners', () {
    test('does not depend on the input order', () {
      final events = [
        engineLearn(3, b12, minutes: 30),
        engineLearn(2, b11, minutes: 20),
        engineLearn(1, b11, source: engineUlid(70), minutes: 10),
      ];
      expect(firstLearningEarners(events, corpus), {engineUlid(3)});
      expect(firstLearningEarners(events.reversed, corpus), {engineUlid(3)});
    });

    test('an unknown ref or a container ref covers no leaf', () {
      expect(
        firstLearningEarners([
          engineLearn(1, 'Mishnah Nowhere 1:1'),
          engineLearn(2, 'Mishnah Berakhot 1'),
        ], corpus),
        isEmpty,
      );
    });

    test('a node event covering only leaves already learnt earns nothing', () {
      expect(
        firstLearningEarners([
          engineLearn(1, b11),
          engineGround(2, berakhot1, minutes: 10),
          engineLearn(3, 'Mishnah Berakhot 1:3', minutes: 20),
        ], corpus),
        {engineUlid(1)},
      );
    });
  });

  group('reviewEarningDate', () {
    test('a dated event uses the civil date of effectiveAt', () {
      // learned_on is ignored for a dated event: 2026-09-02T10:00Z.
      expect(
        reviewEarningDate(
          engineLearn(1, b11, minutes: 1440 + 600, learnedOn: '2026-09-09'),
          settings,
        ),
        '2026-09-02',
      );
      // A copy is judged on its original instant.
      expect(
        reviewEarningDate(
          engineLearn(1, b11, minutes: 3 * 1440, originalMinutes: 600),
          settings,
        ),
        '2026-09-01',
      );
    });

    test('a catch_up event also uses effectiveAt, not learned_on', () {
      // Recorded 2026-09-03T10:00Z, catching up the 2nd.
      expect(
        reviewEarningDate(
          engineLearn(
            1,
            b11,
            minutes: 2 * 1440 + 600,
            dateState: DateState.catchUp,
            learnedOn: '2026-09-02',
          ),
          settings,
        ),
        '2026-09-03',
      );
    });
  });

  group('reviewEarners', () {
    test('an empty schedule earns nothing', () {
      expect(
        reviewEarners(
          countedLearns: [engineLearn(1, b11, stage: 2)],
          corpus: corpus,
          reviews: ReviewSchedule(const []),
          firstStageAt: (_) => 1,
          settingsHistory: settings,
        ),
        isEmpty,
      );
    });

    test('a rolling attempt outside the window does not use up the pair', () {
      // Window 1 on stage 2: 1:2 opened later, so on the 1st only 1:2 is
      // due. The attempt on 1:1 that day is not due (though the schedule
      // took it as the step completion); once 1:2 is done on the 2nd, 1:1
      // leads the window on the 3rd and its attempt then earns.
      ReviewStep step(
        String leaf,
        int openedMinutes,
        int opener,
        String done,
      ) => ReviewStep(
        leaf: leaf,
        stageOrder: 2,
        scheduleType: StageScheduleType.rolling,
        openedOn: '2026-09-01',
        openedAt: engineAt(openedMinutes),
        openedBy: engineUlid(opener),
        dueFrom: '2026-09-01',
        windowSize: 1,
        completedOn: done,
      );
      final reviews = ReviewSchedule([
        step(b11, 600, 1, '2026-09-01'),
        step(b12, 660, 2, '2026-09-02'),
      ]);
      expect(
        reviewEarners(
          countedLearns: [
            engineLearn(3, b11, stage: 2, minutes: 720),
            engineLearn(4, b12, stage: 2, minutes: 1440 + 600),
            engineLearn(5, b11, stage: 2, minutes: 2 * 1440 + 600),
          ],
          corpus: corpus,
          reviews: reviews,
          firstStageAt: (_) => 1,
          settingsHistory: settings,
        ),
        {engineUlid(4), engineUlid(5)},
      );
      // The schedule itself still reports 1:1 as done.
      expect(reviews.dueOn('2026-09-03'), isEmpty);
    });

    test('with no stage in force nothing is a review', () {
      expect(
        curriculumEarningEventIds(
          countedLearns: [
            engineLearn(1, b11, source: engineUlid(70)),
            engineLearn(2, b11, stage: 2, minutes: 10),
          ],
          corpus: corpus,
          settingsHistory: settings,
          reviews: ReviewSchedule(const []),
          firstStageAt: (_) => null,
        ),
        isEmpty,
      );
    });
  });
}

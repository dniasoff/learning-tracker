// Mirror test for `lib/domain/learner_state/earning_events.dart` (DNI-468,
// Story 1.6): the stage-7 rule functions on their own. The engine-level
// acceptance cases (AC-1 to AC-3) are in learner_state_engine_test.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/earning_events.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
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

    test('a catch_up event uses its learned_on day', () {
      expect(
        reviewEarningDate(
          engineLearn(
            1,
            b11,
            minutes: 2 * 1440,
            dateState: DateState.catchUp,
            learnedOn: '2026-09-02',
          ),
          settings,
        ),
        '2026-09-02',
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

// Mirror test for `lib/domain/learner_state/streak.dart` (DNI-466 AC-6).
//
// The learner is in Lakewood (America/New_York, EDT in late March 2026).
// Locks used: Shabbos 03-28 (Fri 03-27 evening → Sat night), Pesach
// 04-02..04-04 and yom tov 04-08/04-09 followed by Shabbos 04-11.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/domain/learner_state/streak.dart';

import '../../helpers/learner_state/c0_fixtures.dart';
import '../../helpers/learner_state/engine_fixtures.dart';
import '../../helpers/learner_state/lock_fixtures.dart';
import '../../helpers/learner_state_fixtures.dart';

var _next = 0;

LearningEvent _learn(
  String learnedOn,
  DateTime recordedAt, {
  DateState dateState = DateState.dated,
  String source = LearningEvent.sourceMain,
  DateTime? original,
}) => LearningEvent.learn(
  id: engineUlid(++_next),
  curriculumId: engineCurriculum,
  ref: 'Mishnah Berakhot 1:1',
  source: source,
  dateState: dateState,
  learnedOn: dateState == DateState.beforeTracking ? null : learnedOn,
  stage: 1,
  recordedAt: recordedAt,
  originalRecordedAt: original,
  actor: parentActor,
);

/// 11:00 EDT on 2026-[month]-[day].
DateTime _morning(int month, int day) => DateTime.utc(2026, month, day, 15);

void main() {
  final h = constantHistory(lakewood);
  final locks = lockWindows(
    h,
    DateTime.utc(2026, 3),
    DateTime.utc(2026, 4, 30),
  );

  String? day(LearningEvent e, {List<LockWindow>? using}) =>
      streakDay(e, settingsHistory: h, locks: using ?? locks);

  group('streakDay: dated', () {
    test('counts on learned_on when it is the effective civil date', () {
      expect(day(_learn('2026-03-24', _morning(3, 24))), '2026-03-24');
    });

    test('a backdated tick never counts', () {
      expect(day(_learn('2026-03-23', _morning(3, 24))), isNull);
      expect(day(_learn('2026-03-25', _morning(3, 24))), isNull);
    });

    test('day boundaries are the learner-local midnight', () {
      // 23:59:59.999999 EDT on 03-24, then 00:00 EDT on 03-25.
      final lastInstant = DateTime.utc(
        2026,
        3,
        25,
        4,
      ).subtract(const Duration(microseconds: 1));
      expect(day(_learn('2026-03-24', lastInstant)), '2026-03-24');
      expect(day(_learn('2026-03-24', DateTime.utc(2026, 3, 25, 4))), isNull);
      expect(
        day(_learn('2026-03-25', DateTime.utc(2026, 3, 25, 4))),
        '2026-03-25',
      );
    });

    test('original_recorded_at, not recorded_at, sets the day', () {
      // An undo copy re-issued two days later keeps its original day.
      expect(
        day(_learn('2026-03-24', _morning(3, 26), original: _morning(3, 24))),
        '2026-03-24',
      );
      // A copy recorded today of a learn from two days ago is backdated.
      expect(
        day(_learn('2026-03-24', _morning(3, 24), original: _morning(3, 22))),
        isNull,
      );
    });

    test('an event inside a lock never counts', () {
      expect(day(_learn('2026-03-28', _morning(3, 28))), isNull);
    });
  });

  group('streakDay: catch_up', () {
    LearningEvent catchUp(String learnedOn, DateTime at) =>
        _learn(learnedOn, at, dateState: DateState.catchUp);

    test('counts a locked day caught up inside its window', () {
      // Motzei Shabbos and Sunday are both in the window.
      expect(
        day(catchUp('2026-03-28', DateTime.utc(2026, 3, 29, 2))),
        '2026-03-28',
      );
      expect(day(catchUp('2026-03-28', _morning(3, 29))), '2026-03-28');
    });

    test('a late catch-up does not count', () {
      expect(day(catchUp('2026-03-28', _morning(3, 30))), isNull);
    });

    test('only a locked day of an earlier lock can be caught up', () {
      // Friday is the erev, not a locked day.
      expect(day(catchUp('2026-03-27', _morning(3, 29))), isNull);
      // No lock at all.
      expect(day(catchUp('2026-03-28', _morning(3, 29)), using: []), isNull);
      // A catch-up recorded during the lock it would catch up.
      expect(day(catchUp('2026-03-28', _morning(3, 28))), isNull);
    });

    test('every day of a three-day lock can be caught up', () {
      for (final d in ['2026-04-02', '2026-04-03', '2026-04-04']) {
        expect(day(catchUp(d, _morning(4, 5))), d);
      }
    });

    test('a yom tov catch-up still counts after the Shabbos that follows', () {
      // Yom tov 04-08/04-09, free Friday, Shabbos 04-11: the yom tov
      // window pauses through Shabbos and ends with Sunday 04-12.
      expect(day(catchUp('2026-04-08', _morning(4, 10))), '2026-04-08');
      expect(day(catchUp('2026-04-09', _morning(4, 12))), '2026-04-09');
      expect(day(catchUp('2026-04-09', _morning(4, 13))), isNull);
      // But not from inside that Shabbos.
      expect(day(catchUp('2026-04-09', _morning(4, 11))), isNull);
    });
  });

  group('streakDay: never counts', () {
    test('before_tracking, sub-track sources and voids', () {
      expect(
        day(
          _learn(
            '2026-03-24',
            _morning(3, 24),
            dateState: DateState.beforeTracking,
          ),
        ),
        isNull,
      );
      expect(day(_learn('2026-03-24', _morning(3, 24), source: ulidD)), isNull);
      final voidEvent = LearningEvent.voidOf(
        id: engineUlid(999),
        targetId: engineUlid(1),
        recordedAt: _morning(3, 24),
        actor: parentActor,
      );
      expect(day(voidEvent), isNull);
    });

    test('a UTC learner gets UTC civil dates', () {
      final utc = c0SettingsHistory();
      final e = _learn('2026-03-24', DateTime.utc(2026, 3, 24, 23, 30));
      expect(streakDay(e, settingsHistory: utc, locks: const []), '2026-03-24');
      // The same instant is still 03-24 in New York, but 03-25 in Jerusalem.
      expect(
        streakDay(
          e,
          settingsHistory: constantHistory(jerusalem),
          locks: const [],
        ),
        isNull,
      );
    });
  });

  group('curriculumStreak', () {
    CurriculumStreak streak(List<LearningEvent> events, DateTime now) =>
        curriculumStreak(events, settingsHistory: h, locks: locks, nowUtc: now);

    LearningEvent dated(int month, int d) => _learn(
      '2026-${month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}',
      _morning(month, d),
    );

    test('no streak days is a zero streak', () {
      expect(
        streak(const [], _morning(3, 25)),
        const CurriculumStreak(current: 0, best: 0),
      );
    });

    test('runs back from today; today not yet learnt does not break it', () {
      final events = [
        for (final d in [16, 17, 18, 19]) dated(3, d),
        for (final d in [22, 23, 24]) dated(3, d),
      ];
      expect(
        streak(events, _morning(3, 25)),
        const CurriculumStreak(current: 3, best: 4, lastDay: '2026-03-24'),
      );
      expect(
        streak([...events, dated(3, 25)], DateTime.utc(2026, 3, 25, 20)),
        const CurriculumStreak(current: 4, best: 4, lastDay: '2026-03-25'),
      );
      // A missed day yesterday ends it.
      expect(streak(events, _morning(3, 26)).current, 0);
    });

    test('duplicates and backdated copies of a day count once', () {
      final events = [
        dated(3, 23),
        dated(3, 23),
        _learn('2026-03-23', _morning(3, 24)), // backdated: no day
        dated(3, 24),
      ];
      expect(streak(events, _morning(3, 24)).current, 2);
      expect(streak(events, _morning(3, 24)).best, 2);
    });

    test('a locked day caught up in its window keeps the streak', () {
      final events = [
        dated(3, 26),
        dated(3, 27),
        _learn('2026-03-28', _morning(3, 29), dateState: DateState.catchUp),
        dated(3, 29),
        dated(3, 30),
      ];
      expect(streak(events, _morning(3, 30)).current, 5);
    });

    test('a locked day not caught up breaks it once its window closes', () {
      final events = [dated(3, 26), dated(3, 27), dated(3, 29), dated(3, 30)];
      expect(streak(events, _morning(3, 30)).current, 2);
      expect(streak(events, _morning(3, 30)).best, 2);
    });

    test('a locked day whose catch-up is pending does not break it', () {
      final events = [dated(3, 26), dated(3, 27)];
      // Sunday morning: Shabbos may still be caught up.
      expect(streak(events, _morning(3, 29)).current, 2);
      // During Shabbos itself.
      expect(streak(events, _morning(3, 28)).current, 2);
      // Monday, window closed, Shabbos not caught up.
      expect(streak(events, _morning(3, 30)).current, 0);
    });

    test('only main-source events build the streak', () {
      final events = [
        dated(3, 23),
        _learn('2026-03-24', _morning(3, 24), source: ulidD),
      ];
      expect(
        streak(events, _morning(3, 24)),
        const CurriculumStreak(current: 1, best: 1, lastDay: '2026-03-23'),
      );
    });
  });
}

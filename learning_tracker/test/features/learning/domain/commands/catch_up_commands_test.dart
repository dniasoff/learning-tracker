// DNI-506 (Story 3.3) T1 / T1.1: the catch-up action's window rule (AC-3,
// AC-5) and leaf validation (AC-1).
//
// The learner has a configured New York location. Shabbos 2026-10-10 locks
// from candle-lighting through havdalah, so its catch-up window ends at the
// end of Sunday 2026-10-11 learner-local.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/features/learning/domain/commands/catch_up_commands.dart';

import '../../../../helpers/learner_state/catch_up_card_harness.dart';
import '../../../../helpers/learner_state/lock_fixtures.dart';
import '../../../../helpers/learner_state_fixtures.dart';

LockWindow _shabbosLock() => lockWindows(
  catchUpHistory,
  catchUpZone.at(DateTime.utc(2026, 10, 9)),
  catchUpZone.at(DateTime.utc(2026, 10, 12)),
).single;

CatchUpAction _action({LockWindow? lock, List<CatchUpLeaf>? leaves}) =>
    CatchUpAction(
      lock: lock ?? _shabbosLock(),
      mode: CatchUpMode.all,
      lockedDaysOffered: 1,
      leaves:
          leaves ??
          const [
            CatchUpLeaf(
              curriculumId: 'mishnayos',
              ref: 'Mishnah Berakhot 2:1',
              source: 'main',
              learnedOn: catchUpShabbos,
              stage: 1,
            ),
            CatchUpLeaf(
              curriculumId: 'mishnayos',
              ref: 'Mishnah Peah 1:1',
              source: ulidB,
              learnedOn: catchUpShabbos,
            ),
          ],
    );

DateTime _local(int day, int hour, [int minute = 0]) =>
    catchUpZone.at(DateTime.utc(2026, 10, day), hour: hour, minute: minute);

void main() {
  group('AC-3: the catch-up window at the tap instant', () {
    test('a tap on Sunday inside the window is accepted', () {
      expect(
        checkCatchUp(_action(), catchUpHistory, catchUpSunday),
        CatchUpCheck.ok,
      );
    });

    test('23:59 on Sunday, the last day of the window, is accepted', () {
      expect(
        checkCatchUp(_action(), catchUpHistory, _local(11, 23, 59)),
        CatchUpCheck.ok,
      );
    });

    test('the window\'s last instant is in, the next one is out', () {
      final window = catchUpWindow(_shabbosLock(), catchUpHistory);
      expect(
        checkCatchUp(_action(), catchUpHistory, window.endUtc),
        CatchUpCheck.ok,
      );
      expect(
        checkCatchUp(
          _action(),
          catchUpHistory,
          window.endUtc.add(const Duration(milliseconds: 1)),
        ),
        CatchUpCheck.ended,
      );
    });

    test('a stale screen confirmed at 00:01 after the window is refused', () {
      expect(
        checkCatchUp(_action(), catchUpHistory, _local(12, 0, 1)),
        CatchUpCheck.ended,
      );
    });

    test('a tap before the lock ends is refused', () {
      final lock = _shabbosLock();
      expect(
        checkCatchUp(_action(), catchUpHistory, lock.endUtc),
        CatchUpCheck.ended,
      );
    });

    test('a lock the settings no longer produce is refused as ended', () {
      final real = _shabbosLock();
      final moved = LockWindow(
        real.startUtc.add(const Duration(minutes: 5)),
        real.endUtc,
      );
      expect(
        checkCatchUp(_action(lock: moved), catchUpHistory, catchUpSunday),
        CatchUpCheck.ended,
      );
    });

    test('the window is judged in the learner zone, not UTC', () {
      // 03:30Z Monday is still Sunday 23:30 in New York (EDT).
      final sundayNight = DateTime.utc(2026, 10, 12, 3, 30);
      expect(
        checkCatchUp(_action(), catchUpHistory, sundayNight),
        CatchUpCheck.ok,
      );
      // ... and a learner who moved to Jerusalem keeps the lock's own
      // window (the settings in force at L.end).
      final moved = movedHistory(
        newYorkLocated,
        catchUpSunday.subtract(const Duration(hours: 1)),
        jerusalem,
      );
      expect(checkCatchUp(_action(), moved, _local(11, 12)), CatchUpCheck.ok);
    });
  });

  group('AC-1: leaf validation', () {
    CatchUpCheck check(CatchUpLeaf leaf) =>
        checkCatchUp(_action(leaves: [leaf]), catchUpHistory, catchUpSunday);

    test('a leaf dated to the day the lock starts on is invalid', () {
      expect(
        check(
          const CatchUpLeaf(
            curriculumId: 'mishnayos',
            ref: 'Mishnah Berakhot 2:1',
            source: 'main',
            learnedOn: '2026-10-09',
          ),
        ),
        CatchUpCheck.invalid,
      );
    });

    test('a stage on a sub-track leaf is invalid', () {
      expect(
        check(
          const CatchUpLeaf(
            curriculumId: 'mishnayos',
            ref: 'Mishnah Peah 1:1',
            source: ulidB,
            learnedOn: catchUpShabbos,
            stage: 1,
          ),
        ),
        CatchUpCheck.invalid,
      );
    });

    test('a source that is neither main nor a ULID is invalid', () {
      expect(
        check(
          const CatchUpLeaf(
            curriculumId: 'mishnayos',
            ref: 'Mishnah Peah 1:1',
            source: 'rebbe',
            learnedOn: catchUpShabbos,
          ),
        ),
        CatchUpCheck.invalid,
      );
    });

    test('an empty ref or curriculum is invalid', () {
      expect(
        check(
          const CatchUpLeaf(
            curriculumId: 'mishnayos',
            ref: '',
            source: 'main',
            learnedOn: catchUpShabbos,
          ),
        ),
        CatchUpCheck.invalid,
      );
      expect(
        check(
          const CatchUpLeaf(
            curriculumId: '',
            ref: 'Mishnah Berakhot 2:1',
            source: 'main',
            learnedOn: catchUpShabbos,
          ),
        ),
        CatchUpCheck.invalid,
      );
    });

    test('an empty action passes the window rule', () {
      expect(
        checkCatchUp(_action(leaves: []), catchUpHistory, catchUpSunday),
        CatchUpCheck.ok,
      );
    });
  });

  test('curricula lists each curriculum once, in leaf order', () {
    final action = _action(
      leaves: const [
        CatchUpLeaf(
          curriculumId: 'mishnayos',
          ref: 'a',
          source: 'main',
          learnedOn: catchUpShabbos,
        ),
        CatchUpLeaf(
          curriculumId: 'bavli',
          ref: 'b',
          source: 'main',
          learnedOn: catchUpShabbos,
        ),
        CatchUpLeaf(
          curriculumId: 'mishnayos',
          ref: 'c',
          source: 'main',
          learnedOn: catchUpShabbos,
        ),
      ],
    );
    expect(action.curricula, ['mishnayos', 'bavli']);
  });
}

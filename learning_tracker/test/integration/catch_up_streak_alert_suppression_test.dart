// Story 3.5 (DNI-508) T4/T6, AC-10 (NFR-18): while a catch-up card is
// pending, a curriculum whose only streak gap is that card's locked day
// gets no streak-at-risk alert — the child gets the one catch-up reminder,
// not streak pressure. Unrelated gaps and other curricula still follow the
// independent alert rule (DNI-479), and the suppression ends with the
// card's catch-up window.
//
// Real lockWindows / catchUpCardWindowsAt over fixed histories; a fixed
// clock; the alert port records what would be shown.
@Tags(['notifications'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/features/notifications/domain/services/curriculum_streak_alerts.dart';
import 'package:learning_tracker/features/notifications/domain/services/streak_alert_service.dart';

import '../helpers/learner_state/catch_up_card_harness.dart';
import '../helpers/learner_state/engine_fixtures.dart';
import '../helpers/learner_state/fake_learner_state.dart';
import '../helpers/learner_state/lock_fixtures.dart';
import '../helpers/learner_state_fixtures.dart';

const _mishnayos = 'mishnayos';
const _bavli = 'bavli';

class _Alerts implements StreakAlertNotifications {
  final scheduled = <(String, String)>[];
  final cancelled = <String>[];

  @override
  Future<void> schedule({
    required String profileId,
    required String curriculumId,
    required DateTime fireAtUtc,
    required String title,
    required String body,
  }) async => scheduled.add((curriculumId, body));

  @override
  Future<void> cancel({
    required String profileId,
    required String curriculumId,
  }) async => cancelled.add(curriculumId);

  @override
  Future<void> cancelAll(String profileId) async {}
}

class _Markers implements StreakAlertMarkers {
  final markers = <String, String>{};

  @override
  Future<String?> read(String profileId, String curriculumId) async =>
      markers[curriculumId];

  @override
  Future<void> write(String p, String c, String marker) async =>
      markers[c] = marker;

  @override
  Future<void> clear(String p, String c) async => markers.remove(c);

  @override
  Future<void> clearAll(String p) async => markers.clear();
}

FakeCurriculumState _curriculum(String id, String lastDay, {int current = 4}) =>
    FakeCurriculumState(
      curriculumId: id,
      evaluated: true,
      streak: CurriculumStreak(
        current: current,
        best: current,
        lastDay: lastDay,
      ),
    );

void main() {
  late _Alerts alerts;
  late DateTime now;

  setUp(() {
    alerts = _Alerts();
    now = catchUpSunday; // Sunday 2026-10-11 12:00 NY, the card is pending
  });

  Future<Map<String, StreakAlertOutcome>> evaluate(
    Map<String, CurriculumState> curricula, {
    LearnerSettingsHistory? history,
    List<LearningEvent> countedLearns = const [],
  }) =>
      StreakAlertService(
        notifications: alerts,
        markers: _Markers(),
        profileId: profileUlid,
        clock: () => now,
      ).evaluateAll(
        state: fakeLearnerState(
          curricula: curricula,
          countedLearns: countedLearns,
          nowUtc: now,
        ),
        settingsHistory: history ?? catchUpHistory,
        hour: 21,
        minute: 0,
        title: 'Streak at risk',
        localizedBody: (n) => 'Your $n-day streak is at risk!',
      );

  test('the only gap is the pending Shabbos: no alert for that curriculum, '
      'while an unrelated curriculum still follows the alert rule', () async {
    final outcomes = await evaluate({
      // Last streak day Friday; Shabbos is caught up only on the card.
      _mishnayos: _curriculum(_mishnayos, '2026-10-09'),
      // Already caught up Shabbos: today alone is at risk.
      _bavli: _curriculum(_bavli, catchUpShabbos),
    });
    expect(outcomes[_mishnayos], StreakAlertOutcome.catchUpPending);
    expect(outcomes[_bavli], StreakAlertOutcome.scheduled);
    expect(alerts.scheduled.map((s) => s.$1), [_bavli]);
    expect(alerts.cancelled, contains(_mishnayos));
  });

  test('a gap with a non-locked day is not covered', () async {
    final outcomes = await evaluate({
      // Thursday last: Friday (not a locked day) is missing too.
      _mishnayos: _curriculum(_mishnayos, '2026-10-08'),
    });
    expect(outcomes[_mishnayos], StreakAlertOutcome.scheduled);
  });

  test('a catch-up already recorded for the curriculum is not pending', () {
    // The card part is complete, so the lock day is not a pending gap.
    final caughtUp = LearningEvent.learn(
      id: engineUlid(1),
      curriculumId: _mishnayos,
      ref: 'Mishnah Berakhot 1:1',
      source: LearningEvent.sourceMain,
      dateState: DateState.catchUp,
      learnedOn: catchUpShabbos,
      stage: 1,
      recordedAt: catchUpSunday.subtract(const Duration(hours: 1)),
      actor: parentActor,
    );
    expect(
      catchUpCoversStreakGap(
        curriculumId: _mishnayos,
        streak: const CurriculumStreak(
          current: 4,
          best: 4,
          lastDay: '2026-10-09',
        ),
        today: '2026-10-11',
        settingsHistory: catchUpHistory,
        state: fakeLearnerState(countedLearns: [caughtUp], nowUtc: now),
        atUtc: catchUpZone.at(DateTime.utc(2026, 10, 11), hour: 21),
      ),
      isFalse,
    );
  });

  test('suppression ends with the catch-up window', () async {
    // Tuesday: the Shabbos card expired at 00:00 Tuesday (no-location
    // fallback keeps it through Monday).
    now = catchUpZone.at(DateTime.utc(2026, 10, 13), hour: 12);
    final outcomes = await evaluate({
      _mishnayos: _curriculum(_mishnayos, '2026-10-09'),
    });
    expect(outcomes[_mishnayos], StreakAlertOutcome.scheduled);
  });

  test('Motzei Shabbos: today is the pending locked day', () async {
    final lakewoodHistory = constantHistory(lakewood);
    final lock = lockWindows(
      lakewoodHistory,
      catchUpZone.at(DateTime.utc(2026, 10, 10), hour: 12),
      catchUpZone.at(DateTime.utc(2026, 10, 10), hour: 12),
    ).single;
    now = lock.endUtc.add(const Duration(minutes: 5));
    final outcomes = await evaluate({
      _mishnayos: _curriculum(_mishnayos, '2026-10-09'),
    }, history: lakewoodHistory);
    expect(outcomes[_mishnayos], StreakAlertOutcome.catchUpPending);
    expect(alerts.scheduled, isEmpty); // no streak-pressure copy
  });
}

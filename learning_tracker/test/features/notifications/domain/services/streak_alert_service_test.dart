// DNI-479 (Story 1.17) AC-2: the streak-at-risk alert is per evaluated
// curriculum, at most once per learner-local civil day per curriculum, and
// never inside a lock window.
//
// The learner is in Lakewood (America/New_York, EDT in late March 2026).
// Wed 03-25 and Thu 03-26 are ordinary weekdays; Shabbos 03-28 starts at
// candle lighting on Fri 03-27 (about 19:00 EDT).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/notifications/domain/services/curriculum_streak_alerts.dart';
import 'package:learning_tracker/features/notifications/domain/services/streak_alert_service.dart';

import '../../../../helpers/learner_state/fake_learner_state.dart';
import '../../../../helpers/learner_state/lock_fixtures.dart';
import '../../../../helpers/learner_state_fixtures.dart';

const _profileId = '01JQ8M9Y7V3K2N6P4R5T8W0X1Z';
const _mishnayos = 'mishnayos';
const _bavli = 'bavli';

class _Scheduled {
  _Scheduled(this.curriculumId, this.fireAtUtc, this.title, this.body);
  final String curriculumId;
  final DateTime fireAtUtc;
  final String title;
  final String body;
}

class _RecordingAlerts implements StreakAlertNotifications {
  final scheduled = <_Scheduled>[];
  final cancelled = <String>[];
  final cancelledProfiles = <String>[];

  @override
  Future<void> schedule({
    required String profileId,
    required String curriculumId,
    required DateTime fireAtUtc,
    required String title,
    required String body,
  }) async {
    expect(profileId, _profileId);
    scheduled.add(_Scheduled(curriculumId, fireAtUtc, title, body));
  }

  @override
  Future<void> cancel({
    required String profileId,
    required String curriculumId,
  }) async => cancelled.add(curriculumId);

  @override
  Future<void> cancelAll(String profileId) async =>
      cancelledProfiles.add(profileId);
}

class _MemoryMarkers implements StreakAlertMarkers {
  final markers = <String, String>{};

  @override
  Future<String?> read(String profileId, String curriculumId) async =>
      markers['$profileId/$curriculumId'];

  @override
  Future<void> write(
    String profileId,
    String curriculumId,
    String marker,
  ) async => markers['$profileId/$curriculumId'] = marker;

  @override
  Future<void> clear(String profileId, String curriculumId) async =>
      markers.remove('$profileId/$curriculumId');

  @override
  Future<void> clearAll(String profileId) async =>
      markers.removeWhere((k, _) => k.startsWith('$profileId/'));
}

class _RecordingAnalytics extends AnalyticsService {
  final events = <(String, Map<String, Object?>?)>[];

  @override
  Future<void> logEvent(String name, {Map<String, Object?>? parameters}) async {
    events.add((name, parameters));
  }
}

/// [hour]:[minute] EDT on 2026-03-[day] (UTC−4).
DateTime _edt(int day, int hour, [int minute = 0]) =>
    DateTime.utc(2026, 3, day, hour + 4, minute);

FakeCurriculumState _curriculum(
  String id, {
  int current = 3,
  String? lastDay = '2026-03-24',
  bool evaluated = true,
}) => FakeCurriculumState(
  curriculumId: id,
  evaluated: evaluated,
  streak: evaluated
      ? CurriculumStreak(current: current, best: current, lastDay: lastDay)
      : null,
);

void main() {
  final history = constantHistory(lakewood);
  late _RecordingAlerts alerts;
  late _MemoryMarkers markers;
  late _RecordingAnalytics analytics;
  late DateTime now;

  StreakAlertService service() => StreakAlertService(
    notifications: alerts,
    markers: markers,
    profileId: _profileId,
    clock: () => now,
    analytics: analytics,
  );

  Future<StreakAlertOutcome> evaluate(
    String curriculumId,
    CurriculumStreak? streak, {
    int hour = 21,
    int minute = 0,
  }) => service().evaluate(
    curriculumId: curriculumId,
    streak: streak,
    settingsHistory: history,
    hour: hour,
    minute: minute,
    title: 'title',
    localizedBody: (n) => 'body $n',
  );

  const atRisk = CurriculumStreak(current: 3, best: 5, lastDay: '2026-03-24');

  setUp(() {
    alerts = _RecordingAlerts();
    markers = _MemoryMarkers();
    analytics = _RecordingAnalytics();
    now = _edt(25, 12); // Wed 03-25, noon EDT.
  });

  group('AC-2: one alert per evaluated curriculum', () {
    test('two curricula at risk are evaluated independently', () async {
      final outcomes = await service().evaluateAll(
        state: fakeLearnerState(
          curricula: {
            _mishnayos: _curriculum(_mishnayos),
            _bavli: _curriculum(_bavli, current: 7),
          },
        ),
        settingsHistory: history,
        hour: 21,
        minute: 0,
        title: 'title',
        localizedBody: (n) => 'body $n',
      );
      expect(outcomes, {
        _mishnayos: StreakAlertOutcome.scheduled,
        _bavli: StreakAlertOutcome.scheduled,
      });
      expect(alerts.scheduled.map((s) => s.curriculumId), [_mishnayos, _bavli]);
      expect(alerts.scheduled.map((s) => s.body), ['body 3', 'body 7']);
    });

    test(
      'a curriculum already kept today gets no alert; the other does',
      () async {
        final outcomes = await service().evaluateAll(
          state: fakeLearnerState(
            curricula: {
              _mishnayos: _curriculum(_mishnayos, lastDay: '2026-03-25'),
              _bavli: _curriculum(_bavli),
            },
          ),
          settingsHistory: history,
          hour: 21,
          minute: 0,
        );
        expect(outcomes[_mishnayos], StreakAlertOutcome.notAtRisk);
        expect(outcomes[_bavli], StreakAlertOutcome.scheduled);
        expect(alerts.scheduled.single.curriculumId, _bavli);
        expect(alerts.cancelled, contains(_mishnayos));
      },
    );

    test('counted learning today from LearnerState keeps the streak safe '
        'even before it is a streak day (DNI-482 AC-5)', () async {
      final today = LearningEvent.learn(
        id: '01JQ8M9Y7V3K2N6P4R5T8W0X2A',
        curriculumId: _mishnayos,
        ref: 'Mishnah Berakhot 1:1',
        source: '01JQ8M9Y7V3K2N6P4R5T8W0X2B', // a sub-track
        dateState: DateState.dated,
        learnedOn: '2026-03-25',
        recordedAt: _edt(25, 9),
        actor: parentActor,
      );
      final outcomes = await service().evaluateAll(
        state: fakeLearnerState(
          curricula: {
            _mishnayos: _curriculum(_mishnayos),
            _bavli: _curriculum(_bavli),
          },
          countedLearns: [today],
          countedEventIds: {today.id},
        ),
        settingsHistory: history,
        hour: 21,
        minute: 0,
      );
      expect(outcomes[_mishnayos], StreakAlertOutcome.notAtRisk);
      expect(outcomes[_bavli], StreakAlertOutcome.scheduled);
    });

    test('a curriculum the engine does not evaluate is cancelled', () async {
      final outcomes = await service().evaluateAll(
        state: fakeLearnerState(
          curricula: {_bavli: _curriculum(_bavli, evaluated: false)},
        ),
        settingsHistory: history,
        hour: 21,
        minute: 0,
      );
      expect(outcomes, isEmpty);
      expect(alerts.scheduled, isEmpty);
      expect(alerts.cancelled, [_bavli]);
    });

    test('no running streak means no alert', () async {
      expect(
        await evaluate(_mishnayos, const CurriculumStreak(current: 0, best: 4)),
        StreakAlertOutcome.notAtRisk,
      );
      expect(await evaluate(_mishnayos, null), StreakAlertOutcome.notAtRisk);
      expect(alerts.scheduled, isEmpty);
    });

    test(
      'the alert fires at the alert time on the learner civil day',
      () async {
        await evaluate(_mishnayos, atRisk);
        // 21:00 EDT on 03-25 is 01:00Z on 03-26.
        expect(alerts.scheduled.single.fireAtUtc, DateTime.utc(2026, 3, 26, 1));
        expect(alerts.scheduled.single.title, 'title');
        expect(analytics.events.single.$1, AnalyticsEvent.notificationFired);
      },
    );

    test('an alert time already past schedules nothing', () async {
      now = _edt(25, 22);
      expect(await evaluate(_mishnayos, atRisk), StreakAlertOutcome.tooLate);
      expect(alerts.scheduled, isEmpty);
    });

    test(
      'moving the alert time into the past cancels the pending alert',
      () async {
        expect(
          await evaluate(_mishnayos, atRisk),
          StreakAlertOutcome.scheduled,
        );
        // 19:30 EDT: the alert time moves from 21:00 to 19:00, already past.
        now = _edt(25, 19, 30);
        expect(
          await evaluate(_mishnayos, atRisk, hour: 19),
          StreakAlertOutcome.tooLate,
        );
        expect(alerts.cancelled, [_mishnayos]);
        expect(markers.markers, isEmpty);
        // The stale marker no longer blocks moving the time back to 21:00.
        expect(
          await evaluate(_mishnayos, atRisk),
          StreakAlertOutcome.scheduled,
        );
        expect(alerts.scheduled, hasLength(2));
      },
    );

    test('an alert that already fired is left in the tray', () async {
      await evaluate(_mishnayos, atRisk);
      now = _edt(25, 21, 30); // The 21:00 alert has fired.
      expect(await evaluate(_mishnayos, atRisk), StreakAlertOutcome.tooLate);
      expect(alerts.cancelled, isEmpty);
    });

    test('an unreadable marker is cancelled when too late', () async {
      markers.markers['$_profileId/$_mishnayos'] = 'garbage';
      now = _edt(25, 22);
      expect(await evaluate(_mishnayos, atRisk), StreakAlertOutcome.tooLate);
      expect(alerts.cancelled, [_mishnayos]);
      expect(markers.markers, isEmpty);
    });
  });

  group('AC-2: at most once per civil day per curriculum', () {
    test('repeated evaluation on one civil day schedules one alert', () async {
      expect(await evaluate(_mishnayos, atRisk), StreakAlertOutcome.scheduled);
      now = _edt(25, 15);
      expect(
        await evaluate(_mishnayos, atRisk),
        StreakAlertOutcome.alreadyScheduled,
      );
      now = _edt(25, 20, 59);
      expect(
        await evaluate(_mishnayos, atRisk),
        StreakAlertOutcome.alreadyScheduled,
      );
      expect(alerts.scheduled, hasLength(1));
      expect(analytics.events, hasLength(1));
    });

    test('the next civil day permits one more', () async {
      await evaluate(_mishnayos, atRisk);
      now = _edt(26, 9);
      const nextDay = CurriculumStreak(
        current: 3,
        best: 5,
        lastDay: '2026-03-25',
      );
      expect(await evaluate(_mishnayos, nextDay), StreakAlertOutcome.scheduled);
      expect(
        await evaluate(_mishnayos, nextDay),
        isNot(StreakAlertOutcome.scheduled),
      );
      expect(alerts.scheduled, hasLength(2));
      expect(alerts.scheduled.last.fireAtUtc, DateTime.utc(2026, 3, 27, 1));
    });

    test('learning today cancels the alert; voiding it re-arms it', () async {
      await evaluate(_mishnayos, atRisk);
      const keptToday = CurriculumStreak(
        current: 4,
        best: 5,
        lastDay: '2026-03-25',
      );
      expect(
        await evaluate(_mishnayos, keptToday),
        StreakAlertOutcome.notAtRisk,
      );
      expect(alerts.cancelled, [_mishnayos]);
      // Same civil day, same identity: still at most one pending alert.
      expect(await evaluate(_mishnayos, atRisk), StreakAlertOutcome.scheduled);
      expect(alerts.scheduled.map((s) => s.fireAtUtc).toSet(), {
        DateTime.utc(2026, 3, 26, 1),
      });
    });

    test('a changed alert time reschedules under the same identity', () async {
      await evaluate(_mishnayos, atRisk);
      expect(
        await evaluate(_mishnayos, atRisk, hour: 20),
        StreakAlertOutcome.scheduled,
      );
      expect(alerts.scheduled.last.fireAtUtc, DateTime.utc(2026, 3, 26));
    });

    test(
      'cancelAlert cancels every curriculum and forgets the markers',
      () async {
        await evaluate(_mishnayos, atRisk);
        await service().cancelAlert();
        expect(alerts.cancelledProfiles, [_profileId]);
        expect(markers.markers, isEmpty);
        expect(
          await evaluate(_mishnayos, atRisk),
          StreakAlertOutcome.scheduled,
        );
      },
    );
  });

  group('AC-2: never inside a lockWindows window', () {
    test('no alert is scheduled while now is inside a lock', () async {
      now = _edt(28, 12); // Shabbos afternoon.
      const friday = CurriculumStreak(
        current: 3,
        best: 3,
        lastDay: '2026-03-27',
      );
      expect(
        await evaluate(_mishnayos, friday),
        StreakAlertOutcome.lockSuppressed,
      );
      expect(alerts.scheduled, isEmpty);
      expect(alerts.cancelled, [_mishnayos]);
    });

    test('an alert time inside the coming lock is suppressed', () async {
      now = _edt(27, 12); // Friday noon; Shabbos starts before 21:00.
      const thursday = CurriculumStreak(
        current: 3,
        best: 3,
        lastDay: '2026-03-26',
      );
      expect(
        await evaluate(_mishnayos, thursday),
        StreakAlertOutcome.lockSuppressed,
      );
      // An alert before candle lighting is allowed.
      expect(
        await evaluate(_mishnayos, thursday, hour: 15),
        StreakAlertOutcome.scheduled,
      );
    });
  });
}

// Story 3.5 (DNI-508) T1/T6: the one CatchUpReminderScheduler — schedule
// identity from `lockWindows` (AC-1), one reminder per continuous lock
// (AC-2), stacked locks fire once each (AC-4), settings changes and removed
// profiles (AC-6), idempotent re-arm and missed ends (AC-7), no permission
// prompt (AC-8), copy and payload (AC-9), empty cards (AC-3).
//
// Deterministic UTC instants and learner-zone fixtures; no wall clock.

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/catch_up_card_projection.dart';
import 'package:learning_tracker/domain/learner_state/erev_window.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/features/sacred_time/data/repositories/shared_prefs_catch_up_reminder_ledger.dart';
import 'package:learning_tracker/features/sacred_time/domain/services/catch_up_reminder_scheduler.dart';

import '../../../../helpers/catch_up_reminder_fakes.dart';
import '../../../../helpers/learner_state/lock_fixtures.dart';
import '../../../../helpers/learner_state_fixtures.dart';

DateTime _day(int y, int m, int d) => DateTime.utc(y, m, d);

final _ny = LearnerZone.of('America/New_York');
final _jlm = LearnerZone.of('Asia/Jerusalem');

const _p1 = profileUlid;
const _p2 = ulidA;

/// Copy that records the kind and name it was built from.
CatchUpReminderCopy _copy(ErevKind kind, String name) =>
    (title: '${kind.name} over', body: '$name, record what you learnt?');

void main() {
  late FakeCatchUpNotifications notifications;
  late MemoryCatchUpLedger ledger;
  late DateTime now;
  late CatchUpReminderScheduler scheduler;

  setUp(() {
    notifications = FakeCatchUpNotifications();
    ledger = MemoryCatchUpLedger();
    now = _ny.at(_day(2026, 10, 7), hour: 12); // Wednesday
    scheduler = CatchUpReminderScheduler(
      notifications: notifications,
      ledger: ledger,
      clock: () => now,
    );
  });

  Future<CatchUpReminderReconcileResult> run(
    List<CatchUpReminderTarget> targets, {
    Set<String>? onDevice,
    bool rearm = false,
  }) => scheduler.reconcile(
    targets: targets,
    onDeviceProfileIds: onDevice ?? {for (final t in targets) t.profileId},
    copy: _copy,
    rearm: rearm,
  );

  CatchUpReminderTarget target(
    String profileId,
    LearnerSettingsHistory? history, {
    String name = 'Avi',
    CatchUpCardContentCheck? hasCardContent,
  }) => CatchUpReminderTarget(
    profileId: profileId,
    displayName: name,
    history: history,
    hasCardContent: hasCardContent,
  );

  group('AC-1: one reminder per profile per lock, at L.end', () {
    test('every upcoming lock in the horizon, from lockWindows only', () async {
      final h = constantHistory(lakewood);
      await run([target(_p1, h)]);
      final expected = lockWindows(h, now, now.add(catchUpReminderHorizon));
      expect(expected, hasLength(2)); // Shabbos 10-10 and 10-17
      expect(
        notifications.schedules.map((s) => s.fireAtUtc),
        expected.map((l) => l.endUtc),
      );
      expect(notifications.schedules.map((s) => s.id).toSet(), hasLength(2));
    });

    test('each profile on the device gets its own reminders and ids', () async {
      await run([
        target(_p1, constantHistory(lakewood), name: 'Avi'),
        target(_p2, constantHistory(jerusalem), name: 'Dina'),
      ]);
      final byProfile = <String, List<ScheduleCall>>{};
      for (final s in notifications.schedules) {
        (byProfile[s.profileId] ??= []).add(s);
      }
      expect(byProfile.keys, unorderedEquals([_p1, _p2]));
      expect(byProfile[_p1], hasLength(2));
      expect(byProfile[_p2], hasLength(2));
      final ids = notifications.schedules.map((s) => s.id).toSet();
      expect(ids, hasLength(4)); // no collision across profiles or locks
      // Jerusalem's Shabbos ends hours before Lakewood's.
      expect(
        byProfile[_p2]!.first.fireAtUtc.isBefore(
          byProfile[_p1]!.first.fireAtUtc,
        ),
        isTrue,
      );
    });

    test('the lock in force now is reminded at its end', () async {
      final h = constantHistory(lakewood);
      now = _ny.at(_day(2026, 10, 10), hour: 12); // Shabbos afternoon
      await run([target(_p1, h)]);
      final lock = lockWindows(h, now, now).single;
      expect(notifications.schedules.first.fireAtUtc, lock.endUtc);
    });

    test('across the autumn DST change the end is the UTC instant', () async {
      // Shabbos 2026-10-31 ends the night before US DST ends.
      final h = constantHistory(lakewood);
      now = _ny.at(_day(2026, 10, 28), hour: 12);
      await run([target(_p1, h)]);
      final lock = lockWindows(
        h,
        _ny.at(_day(2026, 10, 31), hour: 12),
        _ny.at(_day(2026, 10, 31), hour: 12),
      ).single;
      expect(notifications.schedules.first.fireAtUtc, lock.endUtc);
    });
  });

  group('AC-2: yom tov chained into Shabbos is one reminder', () {
    test('diaspora Pesach Thu-Fri + Shabbos: one, at the final end', () async {
      final h = constantHistory(lakewood);
      now = _ny.at(_day(2027, 4, 20), hour: 12);
      await run([target(_p1, h)]);
      final chained = lockWindows(
        h,
        _ny.at(_day(2027, 4, 22), hour: 12),
        _ny.at(_day(2027, 4, 24), hour: 12),
      ).single;
      expect(lockedDays(chained, h), hasLength(3));
      final inChain = notifications.schedules.where(
        (s) => !s.fireAtUtc.isBefore(chained.startUtc) &&
            !s.fireAtUtc.isAfter(chained.endUtc),
      );
      expect(inChain.map((s) => s.fireAtUtc), [chained.endUtc]);
      expect(inChain.single.title, '${ErevKind.yomTovAndShabbos.name} over');
    });
  });

  group('AC-4: stacked locks fire once each', () {
    // Israel: yom tov Thu 2027-04-22, then Shabbos 2027-04-24 (lock B).
    final h = constantHistory(jerusalem);

    test("B's reminder at B.end; A's is consumed and never re-sent", () async {
      now = _jlm.at(_day(2027, 4, 20), hour: 12);
      await run([target(_p1, h)]);
      final [a, b] = lockWindows(
        h,
        _jlm.at(_day(2027, 4, 22), hour: 12),
        _jlm.at(_day(2027, 4, 24), hour: 12),
      );
      final fires = notifications.schedules.map((s) => s.fireAtUtc).toList();
      expect(fires, containsAll([a.endUtc, b.endUtc]));

      // Friday: A ended (its card is pending); A is consumed.
      now = _jlm.at(_day(2027, 4, 23), hour: 9);
      notifications.calls.clear();
      final friday = await run([target(_p1, h)], rearm: true);
      expect(friday.consumed, [catchUpReminderKey(_p1, a)]);
      expect(
        notifications.schedules.map((s) => s.fireAtUtc),
        isNot(contains(a.endUtc)),
      );

      // Sunday: B ended too and A's card resumes beside B's — neither is
      // scheduled again, on a plain run or a re-arm.
      now = _jlm.at(_day(2027, 4, 25), hour: 9);
      expect(catchUpCardWindowsAt(h, now), hasLength(2));
      notifications.calls.clear();
      await run([target(_p1, h)]);
      await run([target(_p1, h)], rearm: true);
      expect(
        notifications.schedules.map((s) => s.fireAtUtc),
        isNot(anyOf(contains(a.endUtc), contains(b.endUtc))),
      );
      expect(ledger.state.consumed.keys, containsAll([
        catchUpReminderKey(_p1, a),
        catchUpReminderKey(_p1, b),
      ]));
    });
  });

  group('AC-6: settings changes and removed profiles', () {
    Future<void> expectRescheduled(LearnerSettingsHistory moved) async {
      await run([target(_p1, constantHistory(lakewood))]);
      final before = Map.of(notifications.osPending);
      notifications.calls.clear();
      await run([target(_p1, moved)]);
      final locks = lockWindows(moved, now, now.add(catchUpReminderHorizon));
      // The pending set is exactly the new lockWindows output.
      expect(
        notifications.osPending.values.map((s) => s.fireAtUtc).toList()
          ..sort(),
        [for (final l in locks) l.endUtc],
      );
      // Every cancel precedes every schedule.
      final firstSchedule = notifications.calls.indexWhere(
        (c) => c is ScheduleCall,
      );
      final lastCancel = notifications.calls.lastIndexWhere(
        (c) => c is CancelCall,
      );
      if (firstSchedule >= 0 && lastCancel >= 0) {
        expect(lastCancel, lessThan(firstSchedule));
      }
      expect(notifications.osPending, isNot(equals(before)));
    }

    test('a moved location', () async {
      final moved = movedHistory(
        lakewood,
        now.subtract(const Duration(hours: 1)),
        lockSettings(latitude: 34.05, longitude: -118.24, inIsrael: false),
      );
      await expectRescheduled(moved);
    });

    test('a new IANA time_zone', () async {
      final moved = movedHistory(
        lakewood,
        now.subtract(const Duration(hours: 1)),
        lockSettings(
          timeZone: 'Europe/London',
          latitude: 51.5074,
          longitude: -0.1278,
          inIsrael: false,
        ),
      );
      await expectRescheduled(moved);
    });

    test('in_israel flipped before a two-day yom tov', () async {
      // End of Pesach 2027 at Lakewood coordinates: the diaspora chains
      // Thu-Fri yom tov into Shabbos (one lock); in Israel yom tov is Thu
      // only, so Thu and Shabbos are two locks.
      now = _ny.at(_day(2027, 4, 19), hour: 12);
      final israel = lockSettings(
        latitude: 40.0821,
        longitude: -74.2097,
        inIsrael: true,
      );
      final moved = movedHistory(
        lakewood,
        now.subtract(const Duration(hours: 1)),
        israel,
      );
      await run([target(_p1, constantHistory(lakewood))]);
      final diaspora = notifications.osPending.length;
      await run([target(_p1, moved)]);
      // Israel: yom tov Thu and Shabbos are two locks, not one chain.
      expect(notifications.osPending.length, diaspora + 1);
    });

    test('a profile removed from the device loses every reminder', () async {
      await run([
        target(_p1, constantHistory(lakewood)),
        target(_p2, constantHistory(lakewood)),
      ]);
      final p2Ids = {
        for (final s in notifications.schedules)
          if (s.profileId == _p2) s.id,
      };
      notifications.calls.clear();
      await run([target(_p1, constantHistory(lakewood))], onDevice: {_p1});
      expect(notifications.cancels.map((c) => c.id).toSet(), p2Ids);
      expect(notifications.schedules, isEmpty);
      expect(ledger.state.pending.where((e) => e.profileId == _p2), isEmpty);
    });

    test('an unreadable history keeps that profile as it is', () async {
      await run([target(_p1, constantHistory(lakewood))]);
      final pending = ledger.state.pending;
      notifications.calls.clear();
      await run([target(_p1, null)]);
      expect(notifications.calls, isEmpty);
      expect(ledger.state.pending, pending);
    });
  });

  group('AC-7: idempotent recovery, no late send', () {
    test('a second run with the same inputs changes nothing', () async {
      final h = constantHistory(lakewood);
      await run([target(_p1, h)]);
      notifications.calls.clear();
      await run([target(_p1, h)]);
      expect(notifications.calls, isEmpty);
    });

    test('a re-arm (start, resume, boot) reuses the same ids', () async {
      final h = constantHistory(lakewood);
      await run([target(_p1, h)]);
      final first = {
        for (final s in notifications.schedules) s.fireAtUtc: s.id,
      };
      notifications
        ..calls.clear()
        ..osPending.clear(); // the OS lost them (e.g. force-stop)
      await run([target(_p1, h)], rearm: true);
      expect({
        for (final s in notifications.schedules) s.fireAtUtc: s.id,
      }, first);
      expect(notifications.cancels, isEmpty);
    });

    test('a missed L.end is consumed, never scheduled late', () async {
      final h = constantHistory(lakewood);
      await run([target(_p1, h)]);
      final lock = lockWindows(h, now, now.add(catchUpReminderHorizon)).first;
      // The device was off over Motzei Shabbos; it boots on Sunday.
      now = _ny.at(_day(2026, 10, 11), hour: 9);
      notifications.calls.clear();
      final result = await run([target(_p1, h)], rearm: true);
      expect(result.consumed, [catchUpReminderKey(_p1, lock)]);
      expect(
        notifications.schedules.every((s) => s.fireAtUtc.isAfter(now)),
        isTrue,
      );
      expect(
        notifications.schedules.map((s) => s.fireAtUtc),
        isNot(contains(lock.endUtc)),
      );
      expect(notifications.cancels, isEmpty); // a shown one stays shown
    });

    test('two locks never share an id slot', () async {
      final h = constantHistory(lakewood);
      now = _ny.at(_day(2027, 4, 15), hour: 12);
      for (var i = 0; i < 6; i++) {
        await run([target(_p1, h)]);
        now = now.add(const Duration(days: 3));
      }
      final ids = ledger.state.pending.map((e) => e.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });
  });

  group('AC-8: permission is checked, never requested', () {
    test('denied or undetermined: nothing is scheduled', () async {
      notifications.permitted = false;
      await run([target(_p1, constantHistory(lakewood))]);
      expect(notifications.schedules, isEmpty);
      expect(notifications.permissionChecks, 1);
      expect(ledger.state.pending, isEmpty);
      // Granted later: the next run schedules them.
      notifications.permitted = true;
      await run([target(_p1, constantHistory(lakewood))]);
      expect(notifications.schedules, hasLength(2));
    });
  });

  group('AC-9: copy and payload', () {
    test('built from the lock kind and display name; payload is the '
        'profile id only', () async {
      await run([target(_p1, constantHistory(lakewood), name: 'Avi')]);
      final s = notifications.schedules.first;
      expect(s.title, '${ErevKind.shabbos.name} over');
      expect(s.body, 'Avi, record what you learnt?');
      expect(s.profileId, _p1);
    });

    test('a changed copy (locale, name) is re-scheduled under its id', () async {
      final h = constantHistory(lakewood);
      await run([target(_p1, h, name: 'Avi')]);
      final ids = notifications.schedules.map((s) => s.id).toList();
      notifications.calls.clear();
      await run([target(_p1, h, name: 'Avraham')]);
      expect(notifications.schedules.map((s) => s.id), ids);
      expect(notifications.cancels, isEmpty);
    });

    test('the ledger stores no name or copy', () {
      final raw = encodeCatchUpReminderLedger(
        CatchUpReminderLedgerState(
          pending: [
            CatchUpReminderEntry(
              key: '$_p1|2026-10-09T21:50:00.000Z',
              profileId: _p1,
              id: 1050,
              fireAtUtc: DateTime.utc(2026, 10, 10, 23, 59),
              copyHash: 42,
            ),
          ],
          consumed: {'k': DateTime.utc(2026, 10, 3)},
        ),
      );
      expect(raw, isNot(contains('Avi')));
      final back = decodeCatchUpReminderLedger(raw);
      expect(back.pending.single.id, 1050);
      expect(back.consumed['k'], DateTime.utc(2026, 10, 3));
    });
  });

  group('AC-3: a card that would be empty gets no reminder', () {
    test('known empty: not scheduled; becoming empty cancels it', () async {
      final h = constantHistory(lakewood);
      var hasContent = true;
      Future<bool?> check(CatchUpCardWindow _) async => hasContent;
      await run([target(_p1, h, hasCardContent: check)]);
      expect(notifications.osPending, hasLength(2));
      hasContent = false;
      await run([target(_p1, h, hasCardContent: check)]);
      expect(notifications.osPending, isEmpty);
    });

    test('unknown content (an inactive profile) is scheduled', () async {
      await run([
        target(
          _p1,
          constantHistory(lakewood),
          hasCardContent: (_) async => null,
        ),
      ]);
      expect(notifications.osPending, hasLength(2));
    });
  });
}

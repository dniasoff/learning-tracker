// Story 3.5 (DNI-508) T4/T6, AC-3 (and AC-4): a reminder is scheduled only
// for a card that will list something. The card is read exactly as the
// Learn tab reads it (the shared planner's lists for the locked days, the
// live LearnerState, the sub-track read), so a card that would be empty
// gets no reminder and a plan that empties withdraws the pending one. A
// reminder fires once: after L.end it is consumed, and no later run —
// plain or re-arm — sends it again before the card expires.
//
// Real scheduler, sync effect and catch-up card projection; fake
// notification port, in-memory ledger, fixed clock.
@Tags(['notifications'])
library;

import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/features/profiles/profiles.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/account_lock_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/catch_up_reminder_providers.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';

import '../helpers/catch_up_reminder_fakes.dart';
import '../helpers/learner_state/catch_up_card_harness.dart';
import '../helpers/learner_state/fake_learner_state.dart';

class _Resumes extends CatchUpReminderResumeCount {
  @override
  int build() => 0;

  void resume() => state++;
}

void main() {
  // Wednesday before Shabbos 2026-10-10 (no-location fallback lock).
  final wednesday = catchUpZone.at(DateTime.utc(2026, 10, 7), hour: 12);
  final lock = lockWindows(
    catchUpHistory,
    catchUpZone.at(DateTime.utc(2026, 10, 10), hour: 12),
    catchUpZone.at(DateTime.utc(2026, 10, 10), hour: 12),
  ).single;

  late FakeCatchUpNotifications notifications;
  late MemoryCatchUpLedger ledger;
  late DateTime now;
  late LiveSource<Map<String, List<DailyTask>>> plan;
  late ProviderContainer container;

  setUp(() {
    notifications = FakeCatchUpNotifications();
    ledger = MemoryCatchUpLedger();
    now = wednesday;
    plan = LiveSource({
      catchUpShabbos: [plannedTask('Mishnah Berakhot 2:1')],
    });
  });

  tearDown(() => container.dispose());

  Future<void> settle() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
      try {
        await container.read(catchUpReminderSyncEffectProvider.future);
      } on Object {
        // a superseded run
      }
    }
  }

  Future<void> start() async {
    final planStream = StreamProvider<Map<String, List<DailyTask>>>(
      (ref) => plan.stream(),
    );
    container = ProviderContainer(
      overrides: [
        ...catchUpOverrides(
          states: (_) => Stream.value(fakeLearnerState(nowUtc: now)),
          clock: () => now,
          // The shared planner, live: a plan change re-reads the card.
          planner: (ref, dates) async {
            final byDate = await ref.watch(planStream.future);
            return [for (final d in dates) byDate[d] ?? const []];
          },
        ),
        lockDrivingScopesProvider.overrideWithValue(AsyncData([catchUpScope])),
        profileListStreamProvider.overrideWith(
          (ref) => Stream.value([
            LearnerProfileEntity(
              profileId: catchUpScope.profileId,
              displayName: 'Avi',
              mode: ProfileMode.child,
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
            ),
          ]),
        ),
        learnerLockSettingsProvider.overrideWith(
          (ref, scope) => Stream.value(catchUpHistory),
        ),
        catchUpReminderNotificationsProvider.overrideWithValue(notifications),
        catchUpReminderLedgerProvider.overrideWithValue(ledger),
        catchUpReminderClockProvider.overrideWithValue(() => now),
        catchUpReminderResumeCountProvider.overrideWith(_Resumes.new),
        currentAppLocaleProvider.overrideWithValue(const Locale('en')),
      ],
    )..listen(catchUpReminderSyncEffectProvider, (_, _) {});
    await settle();
  }

  List<ScheduleCall> forLock() => [
    for (final s in notifications.osPending.values)
      if (s.fireAtUtc == lock.endUtc) s,
  ];

  test('a card that will list something: one neutral reminder at L.end', () async {
    await start();
    final reminder = forLock().single;
    expect(reminder.title, 'Shabbos is over');
    expect(reminder.body, 'Avi, record what you learnt?');
    expect(reminder.profileId, catchUpScope.profileId);
  });

  test('a card that would be empty gets no reminder', () async {
    plan.value = const {};
    await start();
    expect(forLock(), isEmpty);
  });

  test('a plan that empties withdraws the pending reminder before it '
      'fires', () async {
    await start();
    final id = forLock().single.id;
    notifications.calls.clear();
    plan.value = const {};
    await settle();
    expect(notifications.cancels.map((c) => c.id), contains(id));
    expect(forLock(), isEmpty);
  });

  test('fired once: after L.end nothing re-sends it, plain or re-arm, '
      'while the card is pending or complete', () async {
    await start();
    expect(forLock(), hasLength(1));
    notifications.calls.clear();
    now = catchUpSunday; // the card is pending
    container.invalidate(catchUpReminderSyncEffectProvider);
    await settle();
    (container.read(catchUpReminderResumeCountProvider.notifier) as _Resumes)
        .resume();
    await settle();
    expect(
      notifications.schedules.where((s) => s.fireAtUtc == lock.endUtc),
      isEmpty,
    );
    expect(notifications.cancels, isEmpty); // a shown one stays in the tray
    expect(ledger.state.consumed, hasLength(1));
  });
}

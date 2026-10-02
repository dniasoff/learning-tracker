/// Regression test for AUD-notifications-03 (SM-7).
///
/// BEFORE: `streakAlertServiceProvider` was a plain (non-family) `@riverpod`
/// provider locked to `activeProfileIdProvider`'s profile.
/// `allProfilesReminderBootstrap`, which must handle every INACTIVE profile,
/// could not use it and hand-constructed a second `StreakAlertService`
/// instance instead — so a test overriding `streakAlertServiceProvider` had
/// zero effect on inactive-profile scheduling, and any future required
/// dependency added to the constructor had to be kept in sync by hand at
/// both call sites.
///
/// AFTER: `streakAlertServiceProvider` is family-parameterized by
/// `profileId` and used at BOTH call sites (`streakAlertSyncEffect` for the
/// active profile, `allProfilesReminderBootstrap` for every inactive one).
///
/// DNI-479: the streak-alert branch for an inactive profile now cancels its
/// per-curriculum alerts (its LearnerState is not loaded on this device).
///
/// This test drives `allProfilesReminderBootstrap` with two profiles — one
/// active (skipped by the bootstrap) and one inactive — and overrides
/// `streakAlertServiceProvider(<inactive id>)` with a fake. Proving the fake
/// is the instance actually used demonstrates the family override reaches
/// inactive-profile scheduling (the acceptance criterion this finding names).
@Tags(['needs_flutter'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/notifications/domain/repositories/notification_preferences_repository.dart';
import 'package:learning_tracker/features/notifications/domain/services/curriculum_streak_alerts.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_gateway.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_scheduler.dart';
import 'package:learning_tracker/features/notifications/domain/services/streak_alert_service.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz_lib;

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/fake_learner_state.dart';
import '../../../../helpers/learner_state/lock_fixtures.dart';
import '../../../../helpers/learner_state_fixtures.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

/// Records the per-profile schedule/cancel calls without touching the OS
/// notification stack. Mirrors reminder_sync_sacred_time_test.dart's fake.
class _RecordingNotificationGateway implements NotificationGateway {
  final List<String> cancelledBatchProfiles = [];
  final List<String> cancelledDailyProfiles = [];

  @override
  Future<void> cancelBatchRemindersForProfile(String profileId) async {
    cancelledBatchProfiles.add(profileId);
  }

  @override
  Future<void> cancelDailyReminderForProfile(String profileId) async {
    cancelledDailyProfiles.add(profileId);
  }

  // ── Unused stubs ─────────────────────────────────────────────────────────

  @override
  Future<bool> initialize({
    void Function(String? payload)? onNotificationTap,
  }) => Future.value(false);

  @override
  Future<bool> requestPermission() => Future.value(false);

  @override
  Future<bool> hasPermission() => Future.value(false);

  @override
  Future<void> scheduleDailyReminderForProfile({
    required String profileId,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> scheduleBatchRemindersForProfile({
    required String profileId,
    required List<tz_lib.TZDateTime> fireTimes,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> scheduleStreakAlertForProfile({
    required String profileId,
    required int hour,
    required int minute,
    required String body,
    String title = 'Streak at Risk!',
  }) async {}

  @override
  Future<void> cancelStreakAlertForProfile(String profileId) async {}
}

class _MockStreakAlertService extends Mock implements StreakAlertService {}

LearnerProfileEntity _profile(String profileId) {
  final now = DateTime.utc(2026, 1, 1);
  return LearnerProfileEntity(
    profileId: profileId,
    displayName: 'Profile $profileId',
    mode: ProfileMode.adult,
    avatar: '',
    createdAt: now,
    updatedAt: now,
  );
}

const activeProfileId = '01ARZ3NDEKTSV4RRFFQ69G5FAV';
const inactiveProfileId = '01ARZ3NDEKTSV4RRFFQ69G5FB0';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('overriding streakAlertServiceProvider(profileId) for one INACTIVE '
      'profile observably changes allProfilesReminderBootstrap behavior for '
      'that profile (AUD-notifications-03)', () async {
    // Reminder disabled for the inactive profile so the daily-reminder
    // branch takes the trivial cancelForProfile() path — the streak branch
    // (routed through the family provider under test) is what this test
    // exercises. Streak alert enabled: the streak branch still only cancels.
    SharedPreferences.setMockInitialValues({
      NotificationPreferencesRepository.reminderEnabledKey(inactiveProfileId):
          false,
      NotificationPreferencesRepository.streakAlertEnabledKey(
        inactiveProfileId,
      ): true,
      NotificationPreferencesRepository.streakAlertHourKey(inactiveProfileId):
          21,
      NotificationPreferencesRepository.streakAlertMinuteKey(inactiveProfileId):
          0,
    });

    final gateway = _RecordingNotificationGateway();
    final fakeStreakService = _MockStreakAlertService();
    when(() => fakeStreakService.cancelAlert()).thenAnswer((_) async {});

    final container = ProviderContainer(
      overrides: [
        selectedProfileIdProvider.overrideWithValue(activeProfileId),
        currentAppLocaleProvider.overrideWithValue(const Locale('en')),
        notificationServiceProvider.overrideWithValue(gateway),
        notificationSchedulerProvider.overrideWithValue(
          NotificationScheduler(service: gateway),
        ),
        isSacredTimeActiveProvider.overrideWithValue(false),
        profileListStreamProvider.overrideWith(
          (ref) => Stream.value([
            _profile(activeProfileId),
            _profile(inactiveProfileId),
          ]),
        ),
        // The finding's fix under test: a family provider that
        // allProfilesReminderBootstrap can override PER inactive profile.
        streakAlertServiceProvider(
          inactiveProfileId,
        ).overrideWithValue(fakeStreakService),
      ],
    );
    addTearDown(container.dispose);

    // Keep the autoDispose profileListStreamProvider alive across the
    // await below — container.read(...future) alone has no listener, so
    // Riverpod can schedule-dispose it before its (overridden) Stream's
    // first value is delivered, throwing "disposed during loading".
    final sub = container.listen(profileListStreamProvider, (_, _) {});
    addTearDown(sub.close);

    await container.read(allProfilesReminderBootstrapProvider.future);

    // The fake registered for the inactive profile's family instance was
    // actually used by allProfilesReminderBootstrap — proving the override
    // reaches inactive-profile scheduling. Before this fix, the function
    // hand-constructed its own StreakAlertService(...) and no override of
    // any provider could ever intercept that call.
    //
    // DNI-479: the alert is per curriculum, from the profile's own
    // LearnerState, which is not loaded for an inactive profile — so the
    // bootstrap cancels that profile's streak alerts instead of evaluating
    // another profile's streak.
    verify(() => fakeStreakService.cancelAlert()).called(1);

    // The daily-reminder branch (unrelated to this finding) confirms the
    // inactive profile's OTHER scheduling still ran normally alongside it.
    expect(gateway.cancelledDailyProfiles, contains(inactiveProfileId));
  });

  group('streakAlertSyncEffect (DNI-479 AC-2)', () {
    // Wed 2026-03-25, noon EDT, in Lakewood: no lock until Friday.
    final now = DateTime.utc(2026, 3, 25, 16);
    final scope = c0Scope();

    ProviderContainer effectContainer({
      required _RecordingStreakAlerts alerts,
      String selected = profileUlid,
      bool failLocks = false,
      Future<LearnerScope?> Function()? readScope,
    }) {
      SharedPreferences.setMockInitialValues({
        NotificationPreferencesRepository.streakAlertEnabledKey(selected): true,
        NotificationPreferencesRepository.streakAlertHourKey(selected): 21,
        NotificationPreferencesRepository.streakAlertMinuteKey(selected): 0,
      });
      // One marker store per container: it outlives the service instance,
      // as the device-local store does, without leaking across tests.
      final markers = _MemoryStreakAlertMarkers();
      final container = ProviderContainer(
        overrides: [
          selectedProfileIdProvider.overrideWithValue(selected),
          currentAppLocaleProvider.overrideWithValue(const Locale('en')),
          streakAlertServiceProvider(selected).overrideWith(
            (ref) => StreakAlertService(
              notifications: alerts,
              markers: markers,
              profileId: selected,
              clock: () => now,
            ),
          ),
          // The scope is read through [readScope] when given, so a test
          // can change the active learner and invalidate the scope.
          activeLearnerScopeProvider.overrideWith(
            (ref) => readScope?.call() ?? Future.value(scope),
          ),
          learnerStateProvider.overrideWith(
            (ref, _) => Stream.value(
              fakeLearnerState(
                curricula: {
                  for (final c in ['mishnayos', 'bavli'])
                    c: FakeCurriculumState(
                      curriculumId: c,
                      streak: const CurriculumStreak(
                        current: 2,
                        best: 2,
                        lastDay: '2026-03-24',
                      ),
                    ),
                },
              ),
            ),
          ),
          learnerLockSettingsProvider.overrideWith(
            (ref, _) => failLocks
                ? Stream.error(StateError('history unreadable'))
                : Stream.value(constantHistory(lakewood)),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('schedules one alert per curriculum at risk, once per day', () async {
      final alerts = _RecordingStreakAlerts();
      final container = effectContainer(alerts: alerts);

      await container.read(streakAlertSyncEffectProvider.future);
      expect(alerts.scheduled, ['mishnayos', 'bavli']);

      // A re-run on the same civil day schedules nothing new.
      container.invalidate(streakAlertSyncEffectProvider);
      await container.read(streakAlertSyncEffectProvider.future);
      expect(alerts.scheduled, ['mishnayos', 'bavli']);
    });

    test('another profile in view (tutored session) is not evaluated, and '
        "the selected profile's alerts are cancelled", () async {
      final alerts = _RecordingStreakAlerts();
      final container = effectContainer(
        alerts: alerts,
        selected: activeProfileId,
      );
      await container.read(streakAlertSyncEffectProvider.future);
      expect(alerts.scheduled, isEmpty);
      expect(alerts.cancelledAll, [activeProfileId]);
    });

    for (final (name, LearnerScope? next) in [
      (
        'a tutored session',
        LearnerScope(ownerUid: 'owner-uid', profileId: activeProfileId),
      ),
      ('no active learner', null),
    ]) {
      test('an alert scheduled earlier is cancelled when $name '
          'replaces the selected profile as the active learner', () async {
        final alerts = _RecordingStreakAlerts();
        LearnerScope? current = scope;
        final container = effectContainer(
          alerts: alerts,
          readScope: () async => current,
        );

        await container.read(streakAlertSyncEffectProvider.future);
        expect(alerts.scheduled, ['mishnayos', 'bavli']);
        expect(alerts.cancelledAll, isEmpty);

        current = next;
        container.invalidate(activeLearnerScopeProvider);
        await container.read(streakAlertSyncEffectProvider.future);
        expect(alerts.cancelledAll, [profileUlid]);

        // Back as the active learner: the cancelled alerts are rescheduled.
        current = scope;
        container.invalidate(activeLearnerScopeProvider);
        await container.read(streakAlertSyncEffectProvider.future);
        expect(alerts.scheduled, ['mishnayos', 'bavli', 'mishnayos', 'bavli']);
      });
    }

    test(
      'a run superseded while awaiting the scope touches no alert',
      () async {
        final alerts = _RecordingStreakAlerts();
        final release = Completer<LearnerScope?>();
        var first = true;
        final container = effectContainer(
          alerts: alerts,
          readScope: () {
            if (!first) return Future.value(null);
            first = false;
            return release.future;
          },
        );
        final sub = container.listen(streakAlertSyncEffectProvider, (_, _) {});
        addTearDown(sub.close);

        // The first run waits on the scope; a newer run (no active learner)
        // cancels; then the stale run's scope resolves to the profile.
        await Future<void>.delayed(Duration.zero);
        container.invalidate(activeLearnerScopeProvider);
        await container.read(streakAlertSyncEffectProvider.future);
        expect(alerts.log, ['cancelAll $profileUlid']);

        release.complete(scope);
        await pumpEventQueue();
        expect(alerts.log, ['cancelAll $profileUlid']);
      },
    );

    test('a newer run that cancels acts after an evaluation already in '
        'flight, so no stale alert survives', () async {
      final gate = Completer<void>();
      final alerts = _RecordingStreakAlerts(gate: gate.future);
      LearnerScope? current = scope;
      final container = effectContainer(
        alerts: alerts,
        readScope: () async => current,
      );
      final sub = container.listen(streakAlertSyncEffectProvider, (_, _) {});
      addTearDown(sub.close);

      // The first run is scheduling (held at the gate) when the profile
      // stops being the active learner.
      await pumpEventQueue();
      expect(alerts.log, isEmpty);
      current = null;
      container.invalidate(activeLearnerScopeProvider);
      await pumpEventQueue();

      gate.complete();
      await container.read(streakAlertSyncEffectProvider.future);
      await pumpEventQueue();
      expect(alerts.log, [
        'schedule mishnayos',
        'schedule bavli',
        'cancelAll $profileUlid',
      ]);
    });

    test('an unreadable lock-settings history fails closed', () async {
      final alerts = _RecordingStreakAlerts();
      final container = effectContainer(alerts: alerts, failLocks: true);
      await expectLater(
        container.read(streakAlertSyncEffectProvider.future),
        throwsA(isA<StateError>()),
      );
      expect(alerts.scheduled, isEmpty);
      expect(alerts.cancelledAll, [profileUlid]);
    });
  });
}

class _RecordingStreakAlerts implements StreakAlertNotifications {
  _RecordingStreakAlerts({this.gate});

  /// Holds every schedule until it completes, when given.
  final Future<void>? gate;
  final scheduled = <String>[];
  final cancelledAll = <String>[];

  /// Every schedule and cancel-all, in order.
  final log = <String>[];

  @override
  Future<void> schedule({
    required String profileId,
    required String curriculumId,
    required DateTime fireAtUtc,
    required String title,
    required String body,
  }) async {
    await gate;
    scheduled.add(curriculumId);
    log.add('schedule $curriculumId');
  }

  @override
  Future<void> cancel({
    required String profileId,
    required String curriculumId,
  }) async {}

  @override
  Future<void> cancelAll(String profileId) async {
    cancelledAll.add(profileId);
    log.add('cancelAll $profileId');
  }
}

class _MemoryStreakAlertMarkers implements StreakAlertMarkers {
  final _markers = <String, String>{};

  @override
  Future<String?> read(String profileId, String curriculumId) async =>
      _markers['$profileId/$curriculumId'];

  @override
  Future<void> write(
    String profileId,
    String curriculumId,
    String marker,
  ) async => _markers['$profileId/$curriculumId'] = marker;

  @override
  Future<void> clear(String profileId, String curriculumId) async =>
      _markers.remove('$profileId/$curriculumId');

  @override
  Future<void> clearAll(String profileId) async =>
      _markers.removeWhere((k, _) => k.startsWith('$profileId/'));
}

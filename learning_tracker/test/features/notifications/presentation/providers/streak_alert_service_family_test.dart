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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
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
import '../../../../helpers/learner_state/learner_state_overrides.dart';
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
    }) {
      SharedPreferences.setMockInitialValues({
        NotificationPreferencesRepository.streakAlertEnabledKey(selected): true,
        NotificationPreferencesRepository.streakAlertHourKey(selected): 21,
        NotificationPreferencesRepository.streakAlertMinuteKey(selected): 0,
      });
      final container = ProviderContainer(
        overrides: [
          selectedProfileIdProvider.overrideWithValue(selected),
          currentAppLocaleProvider.overrideWithValue(const Locale('en')),
          streakAlertServiceProvider(selected).overrideWith(
            (ref) => StreakAlertService(
              notifications: alerts,
              markers: _MemoryStreakAlertMarkers(),
              profileId: selected,
              clock: () => now,
            ),
          ),
          ...learnerStateOverrides(
            scope: scope,
            state: fakeLearnerState(
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
            lockSettings: failLocks ? null : constantHistory(lakewood),
          ),
          if (failLocks)
            learnerLockSettingsProvider.overrideWith(
              (ref, _) => Stream.error(StateError('history unreadable')),
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

    test(
      'another profile in view (tutored session) is not evaluated',
      () async {
        final alerts = _RecordingStreakAlerts();
        final container = effectContainer(
          alerts: alerts,
          selected: activeProfileId,
        );
        await container.read(streakAlertSyncEffectProvider.future);
        expect(alerts.scheduled, isEmpty);
        expect(alerts.cancelledAll, isEmpty);
      },
    );

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
  final scheduled = <String>[];
  final cancelledAll = <String>[];

  @override
  Future<void> schedule({
    required String profileId,
    required String curriculumId,
    required DateTime fireAtUtc,
    required String title,
    required String body,
  }) async => scheduled.add(curriculumId);

  @override
  Future<void> cancel({
    required String profileId,
    required String curriculumId,
  }) async {}

  @override
  Future<void> cancelAll(String profileId) async => cancelledAll.add(profileId);
}

class _MemoryStreakAlertMarkers implements StreakAlertMarkers {
  static final _markers = <String, String>{};

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

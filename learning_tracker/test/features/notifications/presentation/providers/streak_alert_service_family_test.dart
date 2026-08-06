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
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/notifications/domain/repositories/notification_preferences_repository.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_gateway.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_scheduler.dart';
import 'package:learning_tracker/features/notifications/domain/services/streak_alert_service.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz_lib;

// ── Fakes ─────────────────────────────────────────────────────────────────────

/// Records the per-profile schedule/cancel calls without touching the OS
/// notification stack. Mirrors reminder_sync_sacred_time_test.dart's fake.
class _RecordingNotificationGateway implements NotificationGateway {
  final List<int> cancelledBatchProfiles = [];
  final List<int> cancelledDailyProfiles = [];

  @override
  Future<void> cancelBatchRemindersForProfile(int profileId) async {
    cancelledBatchProfiles.add(profileId);
  }

  @override
  Future<void> cancelDailyReminderForProfile(int profileId) async {
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
    required int profileId,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> scheduleBatchRemindersForProfile({
    required int profileId,
    required List<tz_lib.TZDateTime> fireTimes,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> scheduleStreakAlertForProfile({
    required int profileId,
    required int hour,
    required int minute,
    required String body,
    String title = 'Streak at Risk!',
  }) async {}

  @override
  Future<void> cancelStreakAlertForProfile(int profileId) async {}
}

class _MockStreakAlertService extends Mock implements StreakAlertService {}

ProfileModel _profile(int id) {
  final now = DateTime.utc(2026, 1, 1);
  return ProfileModel(
    id: id,
    ulid: 'ulid-$id',
    accountId: 1,
    displayName: 'Profile $id',
    mode: 'adult',
    avatarIndex: 0,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('overriding streakAlertServiceProvider(profileId) for one INACTIVE '
      'profile observably changes allProfilesReminderBootstrap behavior for '
      'that profile (AUD-notifications-03)', () async {
    const activeProfileId = 1;
    const inactiveProfileId = 5;

    // Reminder disabled for the inactive profile so the daily-reminder
    // branch takes the trivial cancelForProfile() path — the streak branch
    // (routed through the family provider under test) is what this test
    // exercises. Streak alert enabled so evaluate() actually runs.
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
    when(
      () => fakeStreakService.evaluate(
        hour: any(named: 'hour'),
        minute: any(named: 'minute'),
        title: any(named: 'title'),
        localizedBody: any(named: 'localizedBody'),
      ),
    ).thenAnswer((_) async {});
    when(() => fakeStreakService.cancelAlert()).thenAnswer((_) async {});

    final container = ProviderContainer(
      overrides: [
        activeProfileIdProvider.overrideWithValue(activeProfileId),
        currentAppLocaleProvider.overrideWithValue(const Locale('en')),
        notificationServiceProvider.overrideWithValue(gateway),
        notificationSchedulerProvider.overrideWithValue(
          NotificationScheduler(service: gateway),
        ),
        isSacredTimeActiveProvider.overrideWithValue(false),
        outboxSyncWriteFacadeProvider.overrideWithValue(null),
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
    verify(
      () => fakeStreakService.evaluate(
        hour: 21,
        minute: 0,
        title: any(named: 'title'),
        localizedBody: any(named: 'localizedBody'),
      ),
    ).called(1);
    verifyNever(() => fakeStreakService.cancelAlert());

    // The daily-reminder branch (unrelated to this finding) confirms the
    // inactive profile's OTHER scheduling still ran normally alongside it.
    expect(gateway.cancelledDailyProfiles, contains(inactiveProfileId));
  });
}

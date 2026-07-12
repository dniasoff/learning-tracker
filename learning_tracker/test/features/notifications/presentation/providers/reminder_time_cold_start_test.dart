// Regression test for ST-1: ReminderTime / StreakAlertTime cold-start
// sentinel-profileId race.
//
// SYMPTOM: After saving a custom reminder time (e.g. 08:30) under a real
// profile id (e.g. 42), relaunching the app shows the default time (19:00)
// because ReminderTime._loadFromPrefs() calls ref.read(activeProfileIdProvider)
// which returns 0 (cold-start sentinel) before the real profile resolves.
// The pref is read under id=0 (no stored value → default 19:00).  When the
// profile resolves to 42, build() is NOT re-invoked because activeProfileIdProvider
// was never watched — so the real pref (08:30) is never loaded.
//
// Same race applies to StreakAlertTime.
//
// ROOT CAUSE: ReminderTime.build() and StreakAlertTime.build() use ref.read
// (not ref.watch) to obtain the profile id, so they never rebuild when the
// profile resolves.
//
// FIX UNDER TEST: build() must call ref.watch(activeProfileIdProvider) so
// that a 0→real-id transition triggers a rebuild and re-reads from the
// correct per-profile key.
//
// TESTS:
//   T1. ReminderTime: after profile resolves 0→42, loads saved time for id=42.
//   T2. StreakAlertTime: after profile resolves 0→7, loads saved time for id=7.
//   T3. ReminderTime: mid-session profile switch reloads from new profile key.

library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/notifications/domain/repositories/notification_preferences_repository.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Mutable notifier stub (mirrors reminder_enabled_cold_start_test.dart).
// ---------------------------------------------------------------------------

class _MutableProfileId extends ActiveProfileId {
  final int _initial;
  _MutableProfileId(this._initial);

  @override
  int build() => _initial;

  void set(int id) => state = id;
}

(ProviderContainer, _MutableProfileId) _makeContainer({required int startId}) {
  late _MutableProfileId notifier;
  final container = ProviderContainer(
    overrides: [
      activeProfileIdProvider.overrideWith(() {
        notifier = _MutableProfileId(startId);
        return notifier;
      }),
      outboxSyncWriteFacadeProvider.overrideWithValue(null),
    ],
  );
  container.read(activeProfileIdProvider);
  return (container, notifier);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ST-1. Cold-start race — time providers', () {
    // -----------------------------------------------------------------------
    // T1. ReminderTime: 0 → real id
    // -----------------------------------------------------------------------
    test('T1. ReminderTime: loads stored time for real profile (42) after '
        'profile resolves from 0 → 42', () async {
      // Profile 42 has a custom reminder at 08:30; profile 0 has nothing.
      SharedPreferences.setMockInitialValues({
        NotificationPreferencesRepository.reminderHourKey(42): 8,
        NotificationPreferencesRepository.reminderMinuteKey(42): 30,
      });

      final (container, notifier) = _makeContainer(startId: 0);
      addTearDown(container.dispose);

      // AUD-notifications-02: reminderTimeProvider is an AsyncNotifier that
      // genuinely awaits SharedPreferences — await `.future` for the settled
      // value at each stage instead of listen()+arbitrary-delay.
      //
      // Cold-start read — profile=0 → no stored value → default 19:00.
      final initial = await container.read(reminderTimeProvider.future);
      expect(initial.hour, 19, reason: 'Cold-start default should be 19:00');

      // Simulate profile resolving to real id.
      notifier.set(42);

      // After profile resolves, must show 08:30 — NOT 19:00.
      final resolved = await container.read(reminderTimeProvider.future);
      expect(
        resolved.hour,
        8,
        reason:
            'ReminderTime must reload from profile 42 prefs (08:xx) after '
            'activeProfileIdProvider resolves from 0 to 42',
      );
      expect(
        resolved.minute,
        30,
        reason:
            'ReminderTime must reload from profile 42 prefs (xx:30) after '
            'activeProfileIdProvider resolves from 0 to 42',
      );
    });

    // -----------------------------------------------------------------------
    // T2. StreakAlertTime: 0 → real id
    // -----------------------------------------------------------------------
    test('T2. StreakAlertTime: loads stored time for real profile (7) after '
        'profile resolves from 0 → 7', () async {
      SharedPreferences.setMockInitialValues({
        NotificationPreferencesRepository.streakAlertHourKey(7): 22,
        NotificationPreferencesRepository.streakAlertMinuteKey(7): 15,
      });

      final (container, notifier) = _makeContainer(startId: 0);
      addTearDown(container.dispose);

      final initial = await container.read(streakAlertTimeProvider.future);
      expect(initial.hour, 21, reason: 'Cold-start default should be 21:00');

      notifier.set(7);

      final resolved = await container.read(streakAlertTimeProvider.future);
      expect(
        resolved.hour,
        22,
        reason:
            'StreakAlertTime must reload from profile 7 prefs (22:xx) '
            'after activeProfileIdProvider resolves from 0 to 7',
      );
      expect(
        resolved.minute,
        15,
        reason:
            'StreakAlertTime must reload from profile 7 prefs (xx:15) '
            'after activeProfileIdProvider resolves from 0 to 7',
      );
    });

    // -----------------------------------------------------------------------
    // T3. ReminderTime: mid-session profile switch
    // -----------------------------------------------------------------------
    test(
      'T3. ReminderTime: mid-session profile switch reloads from new key',
      () async {
        // Profile 1: default time (no stored key); profile 2: 06:00.
        SharedPreferences.setMockInitialValues({
          NotificationPreferencesRepository.reminderHourKey(2): 6,
          NotificationPreferencesRepository.reminderMinuteKey(2): 0,
        });

        final (container, notifier) = _makeContainer(startId: 1);
        addTearDown(container.dispose);

        expect(
          (await container.read(reminderTimeProvider.future)).hour,
          19,
          reason: 'Profile 1 has no stored time → default 19:00',
        );

        notifier.set(2);

        expect(
          (await container.read(reminderTimeProvider.future)).hour,
          6,
          reason: 'After switching to profile 2, time must be 06:00',
        );
      },
    );
  });
}

// Regression test for ST-1: ReminderTime / StreakAlertTime cold-start
// profile-selection race.
//
// SYMPTOM: After saving a custom reminder time (e.g. 08:30) under a real
// profile ULID, relaunching the app shows the default time (19:00) because
// ReminderTime.build() used to read the selected profile before it resolved.
// The pref was read under the no-profile sentinel (no stored value → default
// 19:00). When the profile resolved, build() was not re-invoked because the
// profile provider was never watched — so the real pref (08:30) was not loaded.
//
// Same race applies to StreakAlertTime.
//
// ROOT CAUSE: ReminderTime.build() and StreakAlertTime.build() used ref.read
// (not ref.watch) to obtain the selected profile id, so they never rebuilt
// when the profile resolved.
//
// FIX UNDER TEST: build() must watch selectedProfileIdProvider so that a
// null→real-ULID transition triggers a rebuild and re-reads from the
// correct per-profile key.
//
// TESTS:
//   T1. ReminderTime: after a profile ULID resolves, loads its saved time.
//   T2. StreakAlertTime: after a profile ULID resolves, loads its saved time.
//   T3. ReminderTime: mid-session profile switch reloads from new profile key.

library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/notifications/domain/repositories/notification_preferences_repository.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Mutable notifier stub (mirrors reminder_enabled_cold_start_test.dart).
// ---------------------------------------------------------------------------

const _profile7 = '01ARZ3NDEKTSV4RRFFQ69G5FB6';
const _profile42 = '01ARZ3NDEKTSV4RRFFQ69G5FC0';
const _profile1 = '01ARZ3NDEKTSV4RRFFQ69G5FB0';

class _MutableProfileId extends SelectedProfileId {
  final String? _initial;
  _MutableProfileId(this._initial);

  @override
  String? build() => _initial;

  void set(String? id) => state = id;
}

(ProviderContainer, _MutableProfileId) _makeContainer({
  required String? startId,
}) {
  late _MutableProfileId notifier;
  final container = ProviderContainer(
    overrides: [
      selectedProfileIdProvider.overrideWith(() {
        notifier = _MutableProfileId(startId);
        return notifier;
      }),
    ],
  );
  container.read(selectedProfileIdProvider);
  return (container, notifier);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ST-1. Cold-start race — time providers', () {
    // -----------------------------------------------------------------------
    // T1. ReminderTime: no selected profile → real ULID
    // -----------------------------------------------------------------------
    test(
      'T1. ReminderTime: loads stored time after profile resolves',
      () async {
      // The real ULID has a custom reminder at 08:30; no-profile has nothing.
      SharedPreferences.setMockInitialValues({
        NotificationPreferencesRepository.reminderHourKey(_profile42): 8,
        NotificationPreferencesRepository.reminderMinuteKey(_profile42): 30,
      });

      final (container, notifier) = _makeContainer(startId: null);
      addTearDown(container.dispose);

      // AUD-notifications-02: reminderTimeProvider is an AsyncNotifier that
      // genuinely awaits SharedPreferences — await `.future` for the settled
      // value at each stage instead of listen()+arbitrary-delay.
      //
      // Cold-start read — no selected profile → no stored value → default 19:00.
      final initial = await container.read(reminderTimeProvider.future);
      expect(initial.hour, 19, reason: 'Cold-start default should be 19:00');

      // Simulate the profile resolving to its real ULID.
      notifier.set(_profile42);

      // After the profile resolves, must show 08:30 — NOT 19:00.
      final resolved = await container.read(reminderTimeProvider.future);
      expect(
        resolved.hour,
        8,
        reason:
            'ReminderTime must reload from the real profile prefs (08:xx) '
            'after selectedProfileIdProvider resolves from null to its ULID',
      );
      expect(
        resolved.minute,
        30,
        reason:
            'ReminderTime must reload from the real profile prefs (xx:30) '
            'after selectedProfileIdProvider resolves from null to its ULID',
      );
      },
    );

    // -----------------------------------------------------------------------
    // T2. StreakAlertTime: no selected profile → real ULID
    // -----------------------------------------------------------------------
    test(
      'T2. StreakAlertTime: loads stored time after profile resolves',
      () async {
        SharedPreferences.setMockInitialValues({
          NotificationPreferencesRepository.streakAlertHourKey(_profile7): 22,
          NotificationPreferencesRepository.streakAlertMinuteKey(_profile7): 15,
        });

        final (container, notifier) = _makeContainer(startId: null);
        addTearDown(container.dispose);

        final initial = await container.read(streakAlertTimeProvider.future);
        expect(initial.hour, 21, reason: 'Cold-start default should be 21:00');

        notifier.set(_profile7);

        final resolved = await container.read(streakAlertTimeProvider.future);
        expect(
          resolved.hour,
          22,
          reason:
              'StreakAlertTime must reload from the real profile prefs (22:xx) '
              'after selectedProfileIdProvider resolves from null to its ULID',
        );
        expect(
          resolved.minute,
          15,
          reason:
              'StreakAlertTime must reload from the real profile prefs (xx:15) '
              'after selectedProfileIdProvider resolves from null to its ULID',
        );
      },
    );

    // -----------------------------------------------------------------------
    // T3. ReminderTime: mid-session profile switch
    // -----------------------------------------------------------------------
    test(
      'T3. ReminderTime: mid-session profile switch reloads from new key',
      () async {
        // Profile 1: default time (no stored key); the new ULID: 06:00.
        SharedPreferences.setMockInitialValues({
          NotificationPreferencesRepository.reminderHourKey(_profile42): 6,
          NotificationPreferencesRepository.reminderMinuteKey(_profile42): 0,
        });

        final (container, notifier) = _makeContainer(startId: _profile1);
        addTearDown(container.dispose);

        expect(
          (await container.read(reminderTimeProvider.future)).hour,
          19,
          reason: 'Profile 1 has no stored time → default 19:00',
        );

        notifier.set(_profile42);

        expect(
          (await container.read(reminderTimeProvider.future)).hour,
          6,
          reason: 'After switching to the new profile, time must be 06:00',
        );
      },
    );
  });
}

// Regression test for: ReminderEnabled cold-start profile-selection race
//
// SYMPTOM (iter10): After setting daily_reminder_enabled_<profile-ulid>=false
// and relaunching the app, the toggle shows ON because ReminderEnabled.build()
// read the selected profile before it resolved. The pref was therefore read
// under the no-profile sentinel instead of the real ULID, and the default
// (true) was returned.
//
// ROOT CAUSE: build() never watched selectedProfileIdProvider, so the provider
// was never rebuilt when the profile resolved from null → real ULID.
//
// FIX UNDER TEST: build() must watch selectedProfileIdProvider so that:
//   1. On first build (no selected profile) the provider reads prefs under the
//      no-profile sentinel.
//   2. When the profile resolves to its ULID, build() is re-invoked and reads
//      prefs again under the correct ULID.
//
// TESTS:
//   K1. (RED before fix) Provider cold-starts without a selected profile,
//       resolves to a real ULID, and must converge to its persisted value
//       (false), NOT the default (true) or the no-profile value.
//   K2. Same contract for StreakAlertEnabled.
//   K3. Same contract for RewardNotificationEnabled.
//   K4. Profile switch mid-session: changing selectedProfileId re-loads prefs
//       from the new profile's key.

library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/notifications/domain/repositories/notification_preferences_repository.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Mutable notifier stub — lets tests drive the profile id through lifecycle.
// ---------------------------------------------------------------------------

/// A mutable [SelectedProfileId] that can be updated after build, simulating
/// the real app resolving the profile id asynchronously after cold start.
const _profile7 = '01ARZ3NDEKTSV4RRFFQ69G5FB6';
const _profile15 = '01ARZ3NDEKTSV4RRFFQ69G5FB9';
const _profile42 = '01ARZ3NDEKTSV4RRFFQ69G5FC0';
const _profile1 = '01ARZ3NDEKTSV4RRFFQ69G5FB0';

class _MutableProfileId extends SelectedProfileId {
  final String? _initial;

  _MutableProfileId(this._initial);

  @override
  String? build() => _initial;

  void set(String? id) => state = id;
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

/// Creates a container with a [_MutableProfileId] starting at [startId].
/// Returns the container and the notifier so tests can drive profile changes.
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
  // Force the notifier to be created.
  container.read(selectedProfileIdProvider);
  return (container, notifier);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // -------------------------------------------------------------------------
  // K1. ReminderEnabled cold-start race fix
  // -------------------------------------------------------------------------

  group('K. Cold-start profile-id persistence', () {
    test('K1. ReminderEnabled: value stored under real ULID is loaded after '
        'profile resolves from null', () async {
      // Pre-populate SharedPreferences: the real ULID has reminder DISABLED.
      // No selected profile has no stored value (defaults to true).
      SharedPreferences.setMockInitialValues({
        NotificationPreferencesRepository.reminderEnabledKey(_profile42): false,
      });

      final (container, notifier) = _makeContainer(startId: null);
      addTearDown(container.dispose);

      // AUD-notifications-02: reminderEnabledProvider is an AsyncNotifier
      // that genuinely awaits SharedPreferences — await `.future` for the
      // settled value at each stage instead of listen()+arbitrary-delay.
      //
      // Trigger build at cold-start with no selected profile — default true.
      expect(await container.read(reminderEnabledProvider.future), isTrue);

      // Simulate the app resolving the real profile id.
      notifier.set(_profile42);

      // After the profile resolves, state MUST be false (the persisted value).
      expect(
        await container.read(reminderEnabledProvider.future),
        isFalse,
        reason:
            'ReminderEnabled should reload prefs under the real profile ULID '
            'after selectedProfileIdProvider resolves from null',
      );
    });

    // -------------------------------------------------------------------------
    // K2. StreakAlertEnabled cold-start race fix
    // -------------------------------------------------------------------------

    test(
      'K2. StreakAlertEnabled: value stored under real ULID is loaded after '
      'profile resolves from null',
      () async {
        SharedPreferences.setMockInitialValues({
          NotificationPreferencesRepository.streakAlertEnabledKey(_profile7): false,
        });

        final (container, notifier) = _makeContainer(startId: null);
        addTearDown(container.dispose);

        expect(await container.read(streakAlertEnabledProvider.future), isTrue);

        notifier.set(_profile7);

        expect(
          await container.read(streakAlertEnabledProvider.future),
          isFalse,
          reason:
              'StreakAlertEnabled should reload prefs under the real profile ULID '
              'after selectedProfileIdProvider resolves from null',
        );
      },
    );

    // -------------------------------------------------------------------------
    // K3. RewardNotificationEnabled cold-start race fix
    // -------------------------------------------------------------------------

    test(
      'K3. RewardNotificationEnabled: value stored under real ULID is loaded '
      'after profile resolves from null',
      () async {
        SharedPreferences.setMockInitialValues({
          NotificationPreferencesRepository.rewardNotificationEnabledKey(
            _profile15,
          ): false,
        });

        final (container, notifier) = _makeContainer(startId: null);
        addTearDown(container.dispose);

        expect(
          await container.read(rewardNotificationEnabledProvider.future),
          isTrue,
        );

        notifier.set(_profile15);

        expect(
          await container.read(rewardNotificationEnabledProvider.future),
          isFalse,
          reason:
              'RewardNotificationEnabled should reload prefs under the real '
              'profile ULID after selectedProfileIdProvider resolves from null',
        );
      },
    );

    // -------------------------------------------------------------------------
    // K4. Mid-session profile switch
    // -------------------------------------------------------------------------

    test(
      'K4. Mid-session profile switch: changing selectedProfileId reloads prefs '
      'from the new profile key',
      () async {
        // Profile 1: reminder enabled (no key = default true)
        // The new ULID: reminder disabled.
        SharedPreferences.setMockInitialValues({
          NotificationPreferencesRepository.reminderEnabledKey(_profile42): false,
        });

        final (container, notifier) = _makeContainer(startId: _profile1);
        addTearDown(container.dispose);

        // Profile 1 has no stored value → default true.
        expect(await container.read(reminderEnabledProvider.future), isTrue);

        // Switch to the new profile ULID.
        notifier.set(_profile42);

        // After switch, must load profile 2's value (false).
        expect(
          await container.read(reminderEnabledProvider.future),
          isFalse,
          reason:
              'Profile switch must reload the persisted false value for the '
              'new profile ULID',
        );
      },
    );
  });
}

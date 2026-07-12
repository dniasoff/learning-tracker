// Regression test for: ReminderEnabled cold-start profile-id=0 race
//
// SYMPTOM (iter10): After setting daily_reminder_enabled_<id>=false and
// relaunching the app, the toggle shows ON because ReminderEnabled._loadFromPrefs
// called ref.read(activeProfileIdProvider) which returned 0 (cold-start sentinel)
// before the real profile id was resolved.  The pref was therefore read under
// profileId=0 instead of the real id, and the default (true) was returned.
//
// ROOT CAUSE: build() never watched activeProfileIdProvider, so the provider
// was never rebuilt when the profile resolved from 0 → real id.
//
// FIX UNDER TEST: build() must call ref.watch(activeProfileIdProvider) and
// pass the resolved id into _loadFromPrefs so that:
//   1. On first build (id=0) the provider reads prefs under id=0.
//   2. When the profile resolves to the real id, build() is re-invoked and
//      _loadFromPrefs runs again under the correct id.
//
// TESTS:
//   K1. (RED before fix) Provider cold-starts at id=0, resolves to real id 42,
//       and must converge to the persisted value for id=42 (false), NOT the
//       default (true) or the id=0 pref.
//   K2. Same contract for StreakAlertEnabled.
//   K3. Same contract for RewardNotificationEnabled.
//   K4. Profile switch mid-session: changing activeProfileId re-loads prefs
//       from the new profile's key.

library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/notifications/domain/repositories/notification_preferences_repository.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Mutable notifier stub — lets tests drive the profile id through lifecycle.
// ---------------------------------------------------------------------------

/// A mutable [ActiveProfileId] that can be updated after build, simulating
/// the real app resolving the profile id asynchronously after cold start.
class _MutableProfileId extends ActiveProfileId {
  final int _initial;

  _MutableProfileId(this._initial);

  @override
  int build() => _initial;

  void set(int id) => state = id;
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

/// Creates a container with a [_MutableProfileId] starting at [startId].
/// Returns the container and the notifier so tests can drive profile changes.
(ProviderContainer, _MutableProfileId) _makeContainer({required int startId}) {
  late _MutableProfileId notifier;
  final container = ProviderContainer(
    overrides: [
      activeProfileIdProvider.overrideWith(() {
        notifier = _MutableProfileId(startId);
        return notifier;
      }),
      // Disable cloud sync so we don't need full sync dependencies.
      outboxSyncWriteFacadeProvider.overrideWithValue(null),
    ],
  );
  // Force the notifier to be created.
  container.read(activeProfileIdProvider);
  return (container, notifier);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // -------------------------------------------------------------------------
  // K1. ReminderEnabled cold-start race fix
  // -------------------------------------------------------------------------

  group('K. Cold-start profile-id persistence', () {
    test('K1. ReminderEnabled: value stored under real id (42) is loaded after '
        'profile resolves from 0 → 42', () async {
      // Pre-populate SharedPreferences: profile 42 has reminder DISABLED.
      // Profile 0 has no stored value (defaults to true).
      SharedPreferences.setMockInitialValues({
        NotificationPreferencesRepository.reminderEnabledKey(42): false,
      });

      final (container, notifier) = _makeContainer(startId: 0);
      addTearDown(container.dispose);

      // AUD-notifications-02: reminderEnabledProvider is an AsyncNotifier
      // that genuinely awaits SharedPreferences — await `.future` for the
      // settled value at each stage instead of listen()+arbitrary-delay.
      //
      // Trigger build at cold-start id=0 — default true, no pref for id=0.
      expect(await container.read(reminderEnabledProvider.future), isTrue);

      // Simulate the app resolving the real profile id.
      notifier.set(42);

      // After profile resolves to 42, state MUST be false (the persisted value).
      expect(
        await container.read(reminderEnabledProvider.future),
        isFalse,
        reason:
            'ReminderEnabled should reload prefs under profile 42 after '
            'activeProfileIdProvider resolves from 0 to 42',
      );
    });

    // -------------------------------------------------------------------------
    // K2. StreakAlertEnabled cold-start race fix
    // -------------------------------------------------------------------------

    test(
      'K2. StreakAlertEnabled: value stored under real id (7) is loaded after '
      'profile resolves from 0 → 7',
      () async {
        SharedPreferences.setMockInitialValues({
          NotificationPreferencesRepository.streakAlertEnabledKey(7): false,
        });

        final (container, notifier) = _makeContainer(startId: 0);
        addTearDown(container.dispose);

        expect(await container.read(streakAlertEnabledProvider.future), isTrue);

        notifier.set(7);

        expect(
          await container.read(streakAlertEnabledProvider.future),
          isFalse,
          reason:
              'StreakAlertEnabled should reload prefs under profile 7 after '
              'activeProfileIdProvider resolves from 0 to 7',
        );
      },
    );

    // -------------------------------------------------------------------------
    // K3. RewardNotificationEnabled cold-start race fix
    // -------------------------------------------------------------------------

    test(
      'K3. RewardNotificationEnabled: value stored under real id (15) is loaded '
      'after profile resolves from 0 → 15',
      () async {
        SharedPreferences.setMockInitialValues({
          NotificationPreferencesRepository.rewardNotificationEnabledKey(15):
              false,
        });

        final (container, notifier) = _makeContainer(startId: 0);
        addTearDown(container.dispose);

        expect(
          await container.read(rewardNotificationEnabledProvider.future),
          isTrue,
        );

        notifier.set(15);

        expect(
          await container.read(rewardNotificationEnabledProvider.future),
          isFalse,
          reason:
              'RewardNotificationEnabled should reload prefs under profile 15 '
              'after activeProfileIdProvider resolves from 0 to 15',
        );
      },
    );

    // -------------------------------------------------------------------------
    // K4. Mid-session profile switch
    // -------------------------------------------------------------------------

    test(
      'K4. Mid-session profile switch: changing activeProfileId reloads prefs '
      'from the new profile key',
      () async {
        // Profile 1: reminder enabled (no key = default true)
        // Profile 2: reminder disabled
        SharedPreferences.setMockInitialValues({
          NotificationPreferencesRepository.reminderEnabledKey(2): false,
        });

        final (container, notifier) = _makeContainer(startId: 1);
        addTearDown(container.dispose);

        // Profile 1 has no stored value → default true.
        expect(await container.read(reminderEnabledProvider.future), isTrue);

        // Switch to profile 2.
        notifier.set(2);

        // After switch, must load profile 2's value (false).
        expect(
          await container.read(reminderEnabledProvider.future),
          isFalse,
          reason:
              'Profile switch from 1 → 2 must reload the persisted false value '
              'for profile 2',
        );
      },
    );
  });
}

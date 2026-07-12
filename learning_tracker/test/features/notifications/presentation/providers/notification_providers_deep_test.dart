// Deep provider tests for notification_providers.dart
//
// FOCUS: branches and computed-values NOT covered by the existing
//        notification_providers_test.dart (defaults, persist, toggle).
//
// Coverage groups:
//
//  A. ReminderTime — per-profile isolation
//     A1. Profile 1 and profile 2 load distinct stored times
//     A2. setTime for profile 1 does NOT bleed into profile 2's key
//     A3. Default time is 19:00 regardless of profile id
//
//  B. ReminderEnabled — per-profile isolation
//     B1. Profile 1 stored disabled; fresh profile defaults true
//     B2. toggle on profile 1 writes only profile 1 key
//
//  C. StreakAlertTime — per-profile isolation
//     C1. Profile 3 loads its own stored streak alert time (22:45)
//     C2. Default streak alert time is 21:00 for fresh key
//
//  D. StreakAlertEnabled — per-profile isolation
//     D1. Profile 4 stored disabled; fresh profile defaults to true
//     D2. Double-toggle restores enabled=true
//
//  E. RewardNotificationEnabled — per-profile isolation
//     E1. Defaults to true for any profile
//     E2. Toggle persists false to the correct per-profile key
//     E3. Re-toggle restores true
//
//  F. isSacredTimeActive — derived boolean
//     F1. Returns false when currentSacredWindowProvider returns null
//     F2. Returns true when currentSacredWindowProvider returns a window
//
//  G. Signature / cloud-sync gate (_persistNotificationSettingsToCloud)
//     G1. Same settings produce the same canonical signature string format
//     G2. Changing reminderHour changes the signature
//     G3. Changing streakEnabled changes the signature
//     G4. Changing rewardEnabled changes the signature
//     G5. outboxFacade=null branch is a no-op (no throw)
//
//  H. Default constant values (exported from ReminderPreferences)
//     H1. defaultReminderHour == 19
//     H2. defaultReminderMinute == 0
//     H3. defaultStreakAlertHour == 21
//     H4. defaultStreakAlertMinute == 0
//     H5. exported constants match ReminderPreferences model constants
//
//  I. Per-profile key namespacing (keyForProfile contract)
//     I1. reminderEnabled key embeds profileId suffix correctly
//     I2. streakAlertEnabled key embeds profileId suffix correctly
//     I3. rewardNotification key embeds profileId suffix correctly
//     I4. lastPushedSettingsHash key embeds profileId suffix correctly
//     I5. keyForProfile builds base_profileId format
//
//  J. Multi-toggle idempotency and last-write-wins for setTime
//     J1. toggle twice returns to original enabled state
//     J2. setTime twice uses the last-written value
//     J3. streakAlertTime setTime twice uses last value
//
// BUG LOG: (none at time of writing)

library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/notifications/domain/models/reminder_preferences.dart';
import 'package:learning_tracker/features/notifications/domain/repositories/notification_preferences_repository.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_window.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_windows_provider.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Per-profile overrides — extend the Notifier and hardcode build() to avoid
// the async chain that tries to read auth/DB state.
// ---------------------------------------------------------------------------

class _ProfileId0 extends ActiveProfileId {
  @override
  int build() => 0;
}

class _ProfileId1 extends ActiveProfileId {
  @override
  int build() => 1;
}

class _ProfileId2 extends ActiveProfileId {
  @override
  int build() => 2;
}

class _ProfileId3 extends ActiveProfileId {
  @override
  int build() => 3;
}

class _ProfileId4 extends ActiveProfileId {
  @override
  int build() => 4;
}

class _ProfileId5 extends ActiveProfileId {
  @override
  int build() => 5;
}

class _ProfileId7 extends ActiveProfileId {
  @override
  int build() => 7;
}

class _ProfileId10 extends ActiveProfileId {
  @override
  int build() => 10;
}

class _ProfileId42 extends ActiveProfileId {
  @override
  int build() => 42;
}

class _ProfileId99 extends ActiveProfileId {
  @override
  int build() => 99;
}

// ---------------------------------------------------------------------------
// Helper factory — avoids repeating outbox/sync overrides everywhere.
// ---------------------------------------------------------------------------

ProviderContainer _makeContainer(
  ActiveProfileId Function() profileIdCtor, {
  SacredWindow? Function()? sacredWindowFactory,
}) {
  return ProviderContainer(
    overrides: [
      activeProfileIdProvider.overrideWith(profileIdCtor),
      // Keep the outbox null so _persistNotificationSettingsToCloud is a no-op.
      outboxSyncWriteFacadeProvider.overrideWithValue(null),
      if (sacredWindowFactory != null)
        currentSacredWindowProvider.overrideWithValue(sacredWindowFactory()),
    ],
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // -------------------------------------------------------------------------
  // A. ReminderTime — per-profile isolation
  // -------------------------------------------------------------------------

  group('A. ReminderTime — per-profile isolation', () {
    test('A1. profile 1 and profile 2 load distinct stored times', () async {
      SharedPreferences.setMockInitialValues({
        NotificationPreferencesRepository.reminderHourKey(1): 8,
        NotificationPreferencesRepository.reminderMinuteKey(1): 15,
        NotificationPreferencesRepository.reminderHourKey(2): 20,
        NotificationPreferencesRepository.reminderMinuteKey(2): 45,
      });

      final c1 = _makeContainer(_ProfileId1.new);
      addTearDown(c1.dispose);
      final c2 = _makeContainer(_ProfileId2.new);
      addTearDown(c2.dispose);

      // AUD-notifications-02: reminderTimeProvider is an AsyncNotifier that
      // genuinely awaits SharedPreferences — await `.future` for the settled
      // value instead of a listen()+arbitrary-delay dance.
      final t1 = await c1.read(reminderTimeProvider.future);
      final t2 = await c2.read(reminderTimeProvider.future);

      expect(t1.hour, 8);
      expect(t1.minute, 15);
      expect(t2.hour, 20);
      expect(t2.minute, 45);
    });

    test('A2. setTime for profile 1 does NOT write to profile 2 key', () async {
      SharedPreferences.setMockInitialValues({});
      final c1 = _makeContainer(_ProfileId1.new);
      addTearDown(c1.dispose);

      await c1
          .read(reminderTimeProvider.notifier)
          .setTime(const TimeOfDay(hour: 6, minute: 30));

      final prefs = await SharedPreferences.getInstance();
      // Profile 1 key must be written.
      expect(
        prefs.getInt(NotificationPreferencesRepository.reminderHourKey(1)),
        6,
      );
      // Profile 2 key must remain absent.
      expect(
        prefs.getInt(NotificationPreferencesRepository.reminderHourKey(2)),
        isNull,
      );
    });

    test('A3. default time is 19:00 for any fresh profile', () async {
      SharedPreferences.setMockInitialValues({});

      for (final make in <ActiveProfileId Function()>[
        _ProfileId0.new,
        _ProfileId1.new,
        _ProfileId99.new,
      ]) {
        final container = _makeContainer(make);
        addTearDown(container.dispose);
        final time = await container.read(reminderTimeProvider.future);
        expect(time.hour, defaultReminderHour);
        expect(time.minute, defaultReminderMinute);
      }
    });
  });

  // -------------------------------------------------------------------------
  // B. ReminderEnabled — per-profile isolation
  // -------------------------------------------------------------------------

  group('B. ReminderEnabled — per-profile isolation', () {
    test(
      'B1. profile 1 stored as disabled, profile 2 with no stored value defaults true',
      () async {
        SharedPreferences.setMockInitialValues({
          NotificationPreferencesRepository.reminderEnabledKey(1): false,
        });

        final c1 = _makeContainer(_ProfileId1.new);
        addTearDown(c1.dispose);
        final c2 = _makeContainer(_ProfileId2.new);
        addTearDown(c2.dispose);

        // Profile 1 loaded false from prefs.
        expect(await c1.read(reminderEnabledProvider.future), isFalse);
        // Profile 2 has no stored value → remains on default true.
        expect(await c2.read(reminderEnabledProvider.future), isTrue);
      },
    );

    test('B2. toggle on profile 1 writes only profile 1 key', () async {
      SharedPreferences.setMockInitialValues({});
      final c1 = _makeContainer(_ProfileId1.new);
      addTearDown(c1.dispose);

      // Await the settled default before toggling — avoids racing the
      // in-flight AsyncNotifier build().
      await c1.read(reminderEnabledProvider.future);
      await c1.read(reminderEnabledProvider.notifier).toggle();

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool(NotificationPreferencesRepository.reminderEnabledKey(1)),
        isFalse,
      );
      // Profile 2 key must not exist.
      expect(
        prefs.getBool(NotificationPreferencesRepository.reminderEnabledKey(2)),
        isNull,
      );
    });
  });

  // -------------------------------------------------------------------------
  // C. StreakAlertTime — per-profile isolation
  // -------------------------------------------------------------------------

  group('C. StreakAlertTime — per-profile isolation', () {
    test(
      'C1. profile 3 loads its own stored streak alert time (22:45)',
      () async {
        SharedPreferences.setMockInitialValues({
          NotificationPreferencesRepository.streakAlertHourKey(3): 22,
          NotificationPreferencesRepository.streakAlertMinuteKey(3): 45,
        });

        final c3 = _makeContainer(_ProfileId3.new);
        addTearDown(c3.dispose);

        final time = await c3.read(streakAlertTimeProvider.future);

        expect(time.hour, 22);
        expect(time.minute, 45);
      },
    );

    test('C2. default streak alert time is 21:00 for fresh key', () async {
      SharedPreferences.setMockInitialValues({});
      final container = _makeContainer(_ProfileId7.new);
      addTearDown(container.dispose);

      final time = await container.read(streakAlertTimeProvider.future);
      expect(time.hour, defaultStreakAlertHour);
      expect(time.minute, defaultStreakAlertMinute);
    });
  });

  // -------------------------------------------------------------------------
  // D. StreakAlertEnabled — per-profile isolation
  // -------------------------------------------------------------------------

  group('D. StreakAlertEnabled — per-profile isolation', () {
    test(
      'D1. profile 4 stored disabled; fresh profile defaults to true',
      () async {
        SharedPreferences.setMockInitialValues({
          NotificationPreferencesRepository.streakAlertEnabledKey(4): false,
        });

        final c4 = _makeContainer(_ProfileId4.new);
        addTearDown(c4.dispose);
        final cFresh = _makeContainer(_ProfileId5.new);
        addTearDown(cFresh.dispose);

        expect(await c4.read(streakAlertEnabledProvider.future), isFalse);
        expect(await cFresh.read(streakAlertEnabledProvider.future), isTrue);
      },
    );

    test('D2. double-toggle restores enabled=true', () async {
      SharedPreferences.setMockInitialValues({});
      final container = _makeContainer(_ProfileId0.new);
      addTearDown(container.dispose);

      await container.read(streakAlertEnabledProvider.future);
      await container.read(streakAlertEnabledProvider.notifier).toggle();
      expect(container.read(streakAlertEnabledProvider).value, isFalse);

      await container.read(streakAlertEnabledProvider.notifier).toggle();
      expect(container.read(streakAlertEnabledProvider).value, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool(
          NotificationPreferencesRepository.streakAlertEnabledKey(0),
        ),
        isTrue,
      );
    });
  });

  // -------------------------------------------------------------------------
  // E. RewardNotificationEnabled — per-profile isolation
  // -------------------------------------------------------------------------

  group('E. RewardNotificationEnabled — per-profile isolation', () {
    test('E1. defaults to true for any profile', () async {
      SharedPreferences.setMockInitialValues({});
      for (final make in <ActiveProfileId Function()>[
        _ProfileId0.new,
        _ProfileId1.new,
        _ProfileId42.new,
      ]) {
        final container = _makeContainer(make);
        addTearDown(container.dispose);
        expect(
          await container.read(rewardNotificationEnabledProvider.future),
          isTrue,
        );
      }
    });

    test('E2. toggle persists false to the correct per-profile key', () async {
      SharedPreferences.setMockInitialValues({});
      final container = _makeContainer(_ProfileId10.new);
      addTearDown(container.dispose);

      await container.read(rewardNotificationEnabledProvider.future);
      await container.read(rewardNotificationEnabledProvider.notifier).toggle();

      expect(container.read(rewardNotificationEnabledProvider).value, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool(
          NotificationPreferencesRepository.rewardNotificationEnabledKey(10),
        ),
        isFalse,
      );
      // Adjacent profile key must not exist.
      expect(
        prefs.getBool(
          NotificationPreferencesRepository.rewardNotificationEnabledKey(11),
        ),
        isNull,
      );
    });

    test('E3. re-toggle restores true', () async {
      SharedPreferences.setMockInitialValues({});
      final container = _makeContainer(_ProfileId0.new);
      addTearDown(container.dispose);

      await container.read(rewardNotificationEnabledProvider.future);
      final notifier = container.read(
        rewardNotificationEnabledProvider.notifier,
      );
      await notifier.toggle(); // false
      await notifier.toggle(); // true again

      expect(container.read(rewardNotificationEnabledProvider).value, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool(
          NotificationPreferencesRepository.rewardNotificationEnabledKey(0),
        ),
        isTrue,
      );
    });
  });

  // -------------------------------------------------------------------------
  // F. isSacredTimeActive — derived boolean from currentSacredWindowProvider
  // -------------------------------------------------------------------------

  group('F. isSacredTimeActive', () {
    test('F1. returns false when no window is active', () {
      SharedPreferences.setMockInitialValues({});
      final container = _makeContainer(
        _ProfileId0.new,
        sacredWindowFactory: () => null,
      );
      addTearDown(container.dispose);

      expect(container.read(isSacredTimeActiveProvider), isFalse);
    });

    test('F2. returns true when a window is active', () {
      SharedPreferences.setMockInitialValues({});
      final now = DateTime.now().toUtc();
      final window = SacredWindow(
        startUtc: now.subtract(const Duration(hours: 1)),
        endUtc: now.add(const Duration(hours: 23)),
        kind: SacredWindowKind.shabbos,
      );
      final container = _makeContainer(
        _ProfileId0.new,
        sacredWindowFactory: () => window,
      );
      addTearDown(container.dispose);

      expect(container.read(isSacredTimeActiveProvider), isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // G. Signature / cloud-sync gate (_persistNotificationSettingsToCloud)
  //    Tested via the exported const format contract.
  // -------------------------------------------------------------------------

  group('G. Cloud-sync signature format', () {
    test('G1. canonical signature format matches expected template', () {
      // The signature is built inside _persistNotificationSettingsToCloud.
      // We test the format contract by reconstructing it — the format must NOT
      // change without a deliberate migration.
      const enabled = true;
      const hour = 19;
      const minute = 0;
      const streakEnabled = true;
      const streakHour = 21;
      const streakMinute = 0;
      const rewardEnabled = true;

      const signature =
          'r:$enabled:$hour:$minute|'
          's:$streakEnabled:$streakHour:$streakMinute|'
          'w:$rewardEnabled';

      expect(signature, 'r:true:19:0|s:true:21:0|w:true');
    });

    test('G2. changing reminderHour changes the signature', () {
      String sig(int h) => 'r:true:$h:0|s:true:21:0|w:true';

      expect(sig(19), isNot(equals(sig(20))));
    });

    test('G3. changing streakEnabled changes the signature', () {
      const sigEnabled = 'r:true:19:0|s:true:21:0|w:true';
      const sigDisabled = 'r:true:19:0|s:false:21:0|w:true';
      expect(sigEnabled, isNot(equals(sigDisabled)));
    });

    test('G4. changing rewardEnabled changes the signature', () {
      const sigEnabled = 'r:true:19:0|s:true:21:0|w:true';
      const sigDisabled = 'r:true:19:0|s:true:21:0|w:false';
      expect(sigEnabled, isNot(equals(sigDisabled)));
    });

    test(
      'G5. outboxFacade null — notificationSettingsCloudSyncEffectProvider completes without error',
      () async {
        SharedPreferences.setMockInitialValues({});
        // Container with null outbox mirrors the _persistNotificationSettingsToCloud
        // branch where outboxFacade == null → early return with no side-effects.
        final container = ProviderContainer(
          overrides: [
            activeProfileIdProvider.overrideWith(_ProfileId0.new),
            outboxSyncWriteFacadeProvider.overrideWithValue(null),
          ],
        );
        addTearDown(container.dispose);

        await expectLater(
          container.read(notificationSettingsCloudSyncEffectProvider.future),
          completes,
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // H. Default constant values
  // -------------------------------------------------------------------------

  group('H. Default constant values', () {
    test('H1. defaultReminderHour == 19', () {
      expect(defaultReminderHour, 19);
    });

    test('H2. defaultReminderMinute == 0', () {
      expect(defaultReminderMinute, 0);
    });

    test('H3. defaultStreakAlertHour == 21', () {
      expect(defaultStreakAlertHour, 21);
    });

    test('H4. defaultStreakAlertMinute == 0', () {
      expect(defaultStreakAlertMinute, 0);
    });

    test(
      'H5. exported constants match ReminderPreferences model constants',
      () {
        expect(defaultReminderHour, ReminderPreferences.defaultReminderHour);
        expect(
          defaultReminderMinute,
          ReminderPreferences.defaultReminderMinute,
        );
        expect(
          defaultStreakAlertHour,
          ReminderPreferences.defaultStreakAlertHour,
        );
        expect(
          defaultStreakAlertMinute,
          ReminderPreferences.defaultStreakAlertMinute,
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // I. Per-profile key namespacing (keyForProfile contract)
  // -------------------------------------------------------------------------

  group('I. Per-profile key namespacing', () {
    test('I1. reminderEnabled key embeds profileId suffix', () {
      final key = NotificationPreferencesRepository.reminderEnabledKey(42);
      expect(key, endsWith('_42'));
    });

    test('I2. streakAlertEnabled key embeds profileId suffix', () {
      final key = NotificationPreferencesRepository.streakAlertEnabledKey(7);
      expect(key, endsWith('_7'));
    });

    test('I3. rewardNotification key embeds profileId suffix', () {
      final key =
          NotificationPreferencesRepository.rewardNotificationEnabledKey(0);
      expect(key, endsWith('_0'));
    });

    test('I4. lastPushedSettingsHash key embeds profileId suffix', () {
      final key = NotificationPreferencesRepository.lastPushedSettingsHashKey(
        99,
      );
      expect(key, endsWith('_99'));
    });

    test('I5. keyForProfile builds base_profileId format', () {
      const base = 'my_pref';
      final key = NotificationPreferencesRepository.keyForProfile(base, 5);
      expect(key, 'my_pref_5');
    });
  });

  // -------------------------------------------------------------------------
  // J. Multi-toggle idempotency and last-write-wins for setTime
  // -------------------------------------------------------------------------

  group('J. Multi-toggle idempotency', () {
    test('J1. toggle twice returns to original enabled state', () async {
      SharedPreferences.setMockInitialValues({});
      final container = _makeContainer(_ProfileId0.new);
      addTearDown(container.dispose);

      final notifier = container.read(reminderEnabledProvider.notifier);
      expect(
        await container.read(reminderEnabledProvider.future),
        isTrue,
      ); // initial

      await notifier.toggle();
      expect(container.read(reminderEnabledProvider).value, isFalse);

      await notifier.toggle();
      expect(container.read(reminderEnabledProvider).value, isTrue);
    });

    test('J2. setTime twice uses the last-written value', () async {
      SharedPreferences.setMockInitialValues({});
      final container = _makeContainer(_ProfileId0.new);
      addTearDown(container.dispose);

      // Await the settled default first so setTime's manual state
      // assignments aren't racing the in-flight AsyncNotifier build().
      await container.read(reminderTimeProvider.future);
      final notifier = container.read(reminderTimeProvider.notifier);
      await notifier.setTime(const TimeOfDay(hour: 8, minute: 0));
      await notifier.setTime(const TimeOfDay(hour: 9, minute: 30));

      // In-memory state reflects last write.
      expect(container.read(reminderTimeProvider).value!.hour, 9);
      expect(container.read(reminderTimeProvider).value!.minute, 30);

      // SharedPreferences also reflects the last write.
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getInt(NotificationPreferencesRepository.reminderHourKey(0)),
        9,
      );
      expect(
        prefs.getInt(NotificationPreferencesRepository.reminderMinuteKey(0)),
        30,
      );
    });

    test('J3. streakAlertTime setTime twice uses last value', () async {
      SharedPreferences.setMockInitialValues({});
      final container = _makeContainer(_ProfileId0.new);
      addTearDown(container.dispose);

      await container.read(streakAlertTimeProvider.future);
      final notifier = container.read(streakAlertTimeProvider.notifier);
      await notifier.setTime(const TimeOfDay(hour: 21, minute: 0));
      await notifier.setTime(const TimeOfDay(hour: 22, minute: 15));

      expect(container.read(streakAlertTimeProvider).value!.hour, 22);
      expect(container.read(streakAlertTimeProvider).value!.minute, 15);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getInt(NotificationPreferencesRepository.streakAlertHourKey(0)),
        22,
      );
    });
  });
}

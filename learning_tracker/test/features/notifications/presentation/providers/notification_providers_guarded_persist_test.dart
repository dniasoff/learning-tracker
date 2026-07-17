// Regression test for AUD-core-preferences-04 (SM-5).
//
// `ReminderEnabled.toggle` (and, identically, `ReminderTime.setTime`,
// `StreakAlertEnabled.toggle`, `StreakAlertTime.setTime`,
// `RewardNotificationEnabled.toggle`) previously assigned
// `state = AsyncData(next)` optimistically and then `await`ed the
// SharedPreferences write with NO enclosing try/catch or `AsyncValue.guard`:
// a write failure was an unobserved Future rejection, and the toggle
// silently reverted on next launch with zero diagnostic trail.
//
// BEFORE the fix: a failing SharedPreferences write left `state` at
// `AsyncData(next)` (the optimistic, never-persisted value) with no
// diagnostic trail — this test would see `state` still hold the failed
// optimistic value instead of surfacing the failure.
// AFTER the fix: `toggle()` derives its terminal state from a single
// `AsyncValue.guard`-wrapped call (`_guardedPersist`), so a write failure
// surfaces as `AsyncError` (never a silently-wrong `AsyncData`) and is
// logged via `AppLogger` before that.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../../../../helpers/throwing_shared_preferences_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReminderEnabled.toggle — AUD-core-preferences-04 (SM-5)', () {
    late SharedPreferencesStorePlatform originalStore;

    setUp(() {
      originalStore = SharedPreferencesStorePlatform.instance;
    });

    tearDown(() {
      SharedPreferencesStorePlatform.instance = originalStore;
    });

    test('a failing SharedPreferences write surfaces as AsyncError (never a '
        'silently-wrong AsyncData) and the returned Future never rejects '
        'unobserved', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Settle build()'s genuine async load before swapping in the
      // throwing store.
      final before = await container.read(reminderEnabledProvider.future);

      SharedPreferencesStorePlatform.instance = ThrowingSharedPreferencesStore(
        {},
      );

      Object? caughtError;
      await runZonedGuarded(() async {
        await container.read(reminderEnabledProvider.notifier).toggle();
      }, (error, stack) => caughtError = error);

      expect(
        caughtError,
        isNull,
        reason:
            'toggle() must not let the SharedPreferences write failure '
            'escape as an unobserved Future rejection (got: $caughtError)',
      );

      final settled = container.read(reminderEnabledProvider);
      expect(
        settled.hasError,
        isTrue,
        reason:
            'a write failure must surface as AsyncError, not silently '
            'settle into AsyncData(next) as if the write had succeeded — '
            'that would show the user a toggle value that was never '
            'actually persisted',
      );
      expect(
        settled.value,
        isNot(!before),
        reason:
            'the failed optimistic value must not be observable as the '
            'settled state',
      );
    });

    test('a successful write still updates state normally (control case — the '
        'guard must not mask a genuine successful persist)', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final before = await container.read(reminderEnabledProvider.future);

      await container.read(reminderEnabledProvider.notifier).toggle();

      final settled = container.read(reminderEnabledProvider);
      expect(settled.hasError, isFalse);
      expect(settled.value, !before);
    });
  });
}

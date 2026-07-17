// Regression test for AUD-core-preferences-04 (EH-2).
//
// `ShowNikudPref.set` (and, identically, `UseHebrewTerms.set`,
// `UseHebrewDate.set`, `CurrentTransliterationVariant.set`,
// `CurrentFontSize.set`) previously assigned `state = value` optimistically
// and then `await`ed the SharedPreferences write with NO enclosing
// try/catch: a write failure was an unobserved Future rejection, and the
// change silently reverted on next launch with zero explanation to a user
// who believed they had already saved it.
//
// BEFORE the fix: a failing SharedPreferences write left `state` at the
// optimistic (never-persisted) value with no diagnostic trail — this test
// would see `state` NOT roll back.
// AFTER the fix (`guardedPersist`, lib/core/utils/guarded_persist.dart):
// `set()` catches the failure, logs it, and rolls `state` back to the last
// successfully-persisted value.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../../helpers/throwing_shared_preferences_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ShowNikudPref.set — AUD-core-preferences-04 (EH-2)', () {
    late SharedPreferencesStorePlatform originalStore;

    setUp(() {
      originalStore = SharedPreferencesStorePlatform.instance;
    });

    tearDown(() {
      SharedPreferencesStorePlatform.instance = originalStore;
    });

    test('a failing SharedPreferences write rolls back the optimistic state '
        'change and the returned Future never rejects unobserved', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          activeProfileIdProvider.overrideWithValue(1),
          // Isolate the test to the SharedPreferences write path — no
          // Firebase/sync I/O involved either way.
          syncWriteFacadeProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      // Settle build()'s synchronous defaultValue + the async
      // _bindObserver read before swapping in the throwing store, so the
      // baseline we assert against is the real settled value.
      container.read(showNikudPrefProvider);
      await pumpEventQueue();
      final before = container.read(showNikudPrefProvider);

      SharedPreferencesStorePlatform.instance = ThrowingSharedPreferencesStore(
        {},
      );

      Object? caughtError;
      await runZonedGuarded(() async {
        await container.read(showNikudPrefProvider.notifier).set(!before);
      }, (error, stack) => caughtError = error);

      expect(
        caughtError,
        isNull,
        reason:
            'set() must not let the SharedPreferences write failure '
            'escape as an unobserved Future rejection (got: $caughtError)',
      );
      expect(
        container.read(showNikudPrefProvider),
        before,
        reason:
            'state must roll back to the last successfully-persisted '
            'value on a write failure — otherwise the UI shows a value '
            'that was never actually saved, and it silently reverts on '
            'next launch with no explanation',
      );
    });

    test('a successful write still updates state normally (control case — the '
        'guard must not mask a genuine successful persist)', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          activeProfileIdProvider.overrideWithValue(1),
          // Isolate the test to the SharedPreferences write path — no
          // Firebase/sync I/O involved either way.
          syncWriteFacadeProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      container.read(showNikudPrefProvider);
      await pumpEventQueue();
      final before = container.read(showNikudPrefProvider);

      await container.read(showNikudPrefProvider.notifier).set(!before);

      expect(container.read(showNikudPrefProvider), !before);
    });
  });
}

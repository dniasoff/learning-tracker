// Regression test for AUD-core-preferences-04 (EH-2).
//
// `SacredLocationNotifier.setManualCity` (and, identically,
// `setManualCoords`, `detect`'s success branch, and
// `InIsraelNotifier.setInIsrael`) previously assigned `state = loc`
// optimistically and then `await`ed the SharedPreferences write chain with
// NO enclosing try/catch: a write failure was an unobserved Future
// rejection, and — per the finding — "a lost write means the
// in-Israel/location flag used for Sacred-Time window calculations silently
// reverts".
//
// BEFORE the fix: a failing SharedPreferences write left `state` at the
// optimistic (never-persisted) location — this test would see `state` NOT
// roll back.
// AFTER the fix (`guardedPersist`): a write failure logs + rolls `state`
// back to the last successfully-persisted location.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_location_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../../helpers/throwing_shared_preferences_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(
    'SacredLocationNotifier.setManualCity — AUD-core-preferences-04 (EH-2)',
    () {
      late SharedPreferencesStorePlatform originalStore;

      setUp(() {
        originalStore = SharedPreferencesStorePlatform.instance;
        SharedPreferences.setMockInitialValues({});
      });

      tearDown(() {
        SharedPreferencesStorePlatform.instance = originalStore;
        SharedPreferences.setMockInitialValues({});
      });

      test(
        'a failing SharedPreferences write rolls back the optimistic '
          'location and the returned Future never rejects unobserved',
        () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);

          // Establish the null baseline first (no location set yet).
          expect(container.read(sacredLocationProvider), isNull);

          SharedPreferencesStorePlatform.instance =
              ThrowingSharedPreferencesStore({});

          Object? caughtError;
          await runZonedGuarded(() async {
            await container
                .read(sacredLocationProvider.notifier)
                .setManualCity(
                  latitude: 32.0853,
                  longitude: 34.7818,
                  cityLabel: 'Tel Aviv',
                  countryCode: 'IL',
                );
          }, (error, stack) => caughtError = error,);

          expect(
            caughtError,
            isNull,
            reason:
                'setManualCity() must not let the SharedPreferences write '
                'failure escape as an unobserved Future rejection '
                '(got: $caughtError)',
          );
          expect(
            container.read(sacredLocationProvider),
            isNull,
            reason:
                'state must roll back to the last successfully-persisted '
                'value (null, here) on a write failure — otherwise the UI '
                'shows a city that was never actually saved, and the '
                'Sacred-Time window calculation silently uses an unpersisted '
                'location that reverts on next launch',
          );
        },
      );

      test('a successful write still updates state normally (control case — '
          'the guard must not mask a genuine successful persist)', () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await container
            .read(sacredLocationProvider.notifier)
            .setManualCity(
              latitude: 32.0853,
              longitude: 34.7818,
              cityLabel: 'Tel Aviv',
              countryCode: 'IL',
            );

        final loc = container.read(sacredLocationProvider);
        expect(loc, isNotNull);
        expect(loc!.cityLabel, 'Tel Aviv');
      });
    },
  );
}

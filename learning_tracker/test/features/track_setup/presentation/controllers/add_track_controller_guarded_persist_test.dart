// Regression test for AUD-core-preferences-04 (EH-2).
//
// `AddTrackController._persist()` is fired fire-and-forget (no `await`, no
// `unawaited()`) from `_advance()`, `goBack()`, and `onConfirmationComplete`
// so navigation is never blocked on disk I/O. Previously its body had no
// try/catch at all, so a SharedPreferences write failure became an
// unobserved Future rejection.
//
// BEFORE the fix: a failing SharedPreferences write inside the
// fire-and-forget `_persist()` triggered by `goBack()` surfaced as an
// uncaught async error in the ambient zone.
// AFTER the fix: `_persist()`'s whole body is wrapped in try/catch — its
// own Future never rejects, so `goBack()`'s fire-and-forget call is always
// safe regardless of write outcome. Wizard navigation (the in-memory
// `state` — the actual source of truth) is unaffected either way.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/controllers/add_track_controller.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/controllers/add_track_flow_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../../../../helpers/throwing_shared_preferences_store.dart';

ProviderContainer _makeContainer() => ProviderContainer();

AddTrackControllerProvider _provider() =>
    addTrackControllerProvider(1, isOnboarding: false);

AddTrackController _notifier(ProviderContainer c) =>
    c.read(_provider().notifier);

void main() {
  group(
    'AddTrackController.goBack() → _persist() — AUD-core-preferences-04 (EH-2)',
    () {
      late SharedPreferencesStorePlatform originalStore;

      setUp(() {
        originalStore = SharedPreferencesStorePlatform.instance;
        SharedPreferences.setMockInitialValues({});
      });

      tearDown(() {
        SharedPreferencesStorePlatform.instance = originalStore;
      });

      test('a failing SharedPreferences write inside the fire-and-forget '
          '_persist() never surfaces as an unhandled async error, and '
          'navigation still proceeds normally', () async {
        final c = _makeContainer();
        addTearDown(c.dispose);

        // Reach ProgramChoiceState (one step in) so goBack() has
        // somewhere to go back FROM, exercising the real _advance() ->
        // _persist() fire-and-forget path first.
        _notifier(c).onCurriculumSelected(CurriculumId.bavli);
        expect(c.read(_provider()), isA<ProgramChoiceState>());

        SharedPreferencesStorePlatform.instance =
            ThrowingSharedPreferencesStore({});

        Object? caughtError;
        await runZonedGuarded(() async {
          final moved = _notifier(c).goBack();
          expect(moved, isTrue);
          // Give the fire-and-forget _persist() Future room to run to
          // completion (or, pre-fix, to reject) inside this zone.
          await pumpEventQueue();
        }, (error, stack) => caughtError = error);

        expect(
          caughtError,
          isNull,
          reason:
              'a SharedPreferences write failure inside the '
              'fire-and-forget _persist() must never surface as an '
              'unhandled async error (got: $caughtError)',
        );
        expect(
          c.read(_provider()),
          isA<CurriculumChoiceState>(),
          reason:
              'navigation (the actual source of truth) must succeed '
              'regardless of whether the best-effort restore-snapshot '
              'write landed',
        );
      });
    },
  );
}

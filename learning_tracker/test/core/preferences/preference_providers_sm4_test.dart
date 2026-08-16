/// Regression test for AUD-core-preferences-06 (SM-4).
///
/// `_bindObserver`'s `pref.read(profileId).then(onValue)` resolves after an
/// unguarded `await` inside `ProfileScopedPreference.read` (which awaits
/// `SharedPreferences.getInstance()`). If the surrounding provider's
/// `ProviderContainer` is disposed while that read is still in flight, the
/// pending `.then(onValue)` continuation resumes and touches `state` on a
/// disposed `Ref`, throwing `UnmountedRefException` (SM-4,
/// docs/coding-standards.md).
///
/// BEFORE the fix: onValue unconditionally writes `state`, so the scenario
/// below surfaces an uncaught `UnmountedRefException`.
/// AFTER the fix: `_bindObserver`'s onValue wrapper no-ops once
/// `ref.mounted` is false.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/preferences/hebrew_date_preference.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A [HebrewDatePreference] whose [read] hangs on an externally-held
/// [Completer] instead of resolving immediately. This lets the test dispose
/// the [ProviderContainer] WHILE the read is still pending, then resolve it
/// afterwards — reproducing the post-await race SM-4 guards against,
/// deterministically (mirrors `_GatedReminderEnabled` in
/// `test/features/notifications/presentation/providers/notification_effects_sm4_test.dart`,
/// AUD-notifications-01).
class _GatedHebrewDatePreference extends HebrewDatePreference {
  _GatedHebrewDatePreference(this._gate);
  final Completer<bool> _gate;

  @override
  Future<bool> read(String profileId) => _gate.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('UseHebrewDate: onValue no-ops when the container is disposed before '
      'pref.read() resolves, instead of throwing UnmountedRefException '
      '(AUD-core-preferences-06, SM-4)', () async {
    SharedPreferences.setMockInitialValues({});
    final gate = Completer<bool>();

    final container = ProviderContainer(
      overrides: [
        activeProfileIdProvider.overrideWithValue('01J6Q2H4A8M7K3P9R5T6V8WXY7'),
        hebrewDatePreferenceProvider.overrideWithValue(
          _GatedHebrewDatePreference(gate),
        ),
      ],
    );

    Object? caughtError;
    await runZonedGuarded(
      () async {
        // Triggers UseHebrewDate.build() -> _bindObserver -> pref.read(1),
        // which suspends on the still-open gate.
        container.read(useHebrewDateProvider);

        // Dispose the container WHILE the read is still pending — the
        // notifier's Ref becomes unmounted before pref.read() settles.
        container.dispose();

        // Now let the pending read resolve. Its `.then(onValue)`
        // continuation fires after the container (and its Ref) is gone.
        gate.complete(true);

        // Flush the microtask queue so the continuation actually runs
        // before we assert.
        await Future<void>.delayed(Duration.zero);
      },
      (error, stack) {
        caughtError = error;
      },
    );

    expect(
      caughtError,
      isNull,
      reason:
          'onValue must no-op once ref.mounted is false instead of '
          'throwing (got: $caughtError)',
    );
  });
}

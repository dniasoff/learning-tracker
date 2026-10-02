// Mirror test for
// `lib/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart`
// (C0, DNI-524 AC-5).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/provider_settle.dart';

void main() {
  test('learnerLockSettingsProvider is a stub resolving to AsyncError '
      '(DNI-470)', () async {
    final container = ProviderContainer.test();
    expect(
      await settledAsync(container, learnerLockSettingsProvider(c0Scope())),
      isAsyncC0Stub('DNI-470', 'learnerLockSettingsProvider'),
    );
  });

  test('an override is read per scope', () async {
    final history = c0SettingsHistory();
    final container = ProviderContainer.test(
      overrides: [
        learnerLockSettingsProvider.overrideWith(
          (ref, scope) => Stream.value(history),
        ),
      ],
    );
    final value = await settledAsync(
      container,
      learnerLockSettingsProvider(c0Scope()),
    );
    expect(value.value, same(history));
  });
}

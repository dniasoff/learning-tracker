// Mirror test for
// `lib/features/learning/presentation/providers/learning_command_providers.dart`
// (C0, DNI-524 AC-5).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';

import '../../../../helpers/learner_state/provider_settle.dart';

void main() {
  test('captureGateProvider is the real LockWindowCaptureGate', () {
    final container = ProviderContainer.test();
    expect(container.read(captureGateProvider), isA<LockWindowCaptureGate>());
  });

  test('learningCommandsProvider is a stub resolving to AsyncError '
      '(DNI-469)', () async {
    final container = ProviderContainer.test();
    expect(
      await settledAsync(container, learningCommandsProvider),
      isAsyncC0Stub('DNI-469', 'learningCommandsProvider'),
    );
  });

  test('learningAnalyticsProvider is a stub that throws on read '
      '(DNI-469)', () {
    final container = ProviderContainer.test();
    Object? caught;
    try {
      container.read(learningAnalyticsProvider);
    } on Object catch (e) {
      caught = e;
    }
    expect(caught, isNotNull);
    expect(
      caught.toString(),
      contains('C0 stub: learningAnalyticsProvider (filled by DNI-469)'),
    );
  });
}

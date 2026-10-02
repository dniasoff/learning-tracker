// Mirror test for
// `lib/features/learner_state/presentation/providers/learner_state_provider.dart`
// (C0, DNI-524 AC-5).
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/provider_settle.dart';

void main() {
  final now = DateTime.utc(2026, 9, 1, 12);

  test('learnerStateEngineProvider is the real const engine', () {
    final container = ProviderContainer.test();
    expect(
      container.read(learnerStateEngineProvider),
      same(const LearnerStateEngine()),
    );
  });

  group('stubs resolve to AsyncError without crashing the container', () {
    test('corporaProvider (DNI-474)', () async {
      final container = ProviderContainer.test();
      expect(
        await settledAsync(container, corporaProvider),
        isAsyncC0Stub('DNI-474', 'corporaProvider'),
      );
    });

    test('learnerStateProvider (DNI-474)', () async {
      final container = ProviderContainer.test();
      expect(
        await settledAsync(container, learnerStateProvider(c0Scope())),
        isAsyncC0Stub('DNI-474', 'learnerStateProvider'),
      );
    });
  });

  group('activeLearnerStateProvider', () {
    test('is AsyncData(null) while no learner is active', () async {
      final container = ProviderContainer.test(
        overrides: [
          activeLearnerScopeProvider.overrideWith((ref) async => null),
        ],
      );
      expect(
        await settledAsync(container, activeLearnerStateProvider),
        const AsyncData<LearnerState?>(null),
      );
    });

    test('forwards learnerStateProvider for the active scope', () async {
      final state = LearnerState.empty(now);
      final requested = <LearnerScope>[];
      final container = ProviderContainer.test(
        overrides: [
          activeLearnerScopeProvider.overrideWith((ref) async => c0Scope()),
          learnerStateProvider.overrideWith((ref, scope) {
            requested.add(scope);
            return Stream.value(state);
          }),
        ],
      );
      final value = await settledAsync(container, activeLearnerStateProvider);
      expect(value.value, same(state));
      expect(requested, [c0Scope()]);
    });

    test('forwards the stub error when learnerStateProvider is not '
        'overridden', () async {
      final container = ProviderContainer.test(
        overrides: [
          activeLearnerScopeProvider.overrideWith((ref) async => c0Scope()),
        ],
      );
      expect(
        await settledAsync(container, activeLearnerStateProvider),
        isAsyncC0Stub('DNI-474', 'learnerStateProvider'),
      );
    });

    test('forwards a scope error', () async {
      final container = ProviderContainer.test(
        overrides: [
          activeLearnerScopeProvider.overrideWith(
            (ref) async => throw StateError('no grant'),
          ),
        ],
      );
      final value = await settledAsync(container, activeLearnerStateProvider);
      expect(value, isA<AsyncError<LearnerState?>>());
      expect(value.error, isA<StateError>());
    });

    test('is loading while the scope resolves', () {
      final container = ProviderContainer.test(
        overrides: [
          activeLearnerScopeProvider.overrideWith(
            (ref) => Completer<LearnerScope?>().future,
          ),
        ],
      );
      expect(
        container.read(activeLearnerStateProvider),
        isA<AsyncLoading<LearnerState?>>(),
      );
    });
  });
}

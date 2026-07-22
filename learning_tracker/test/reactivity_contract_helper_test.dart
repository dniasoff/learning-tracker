/// Self-test for the R5 reactivity-contract helper
/// (`test/helpers/reactivity_contract.dart`).
///
/// Lives directly under `test/` (not `test/helpers/`) so its `main()` never
/// collides with `test/helpers/golden_font_loader_test.dart`'s under the
/// AUD-t-cross-12 duplicate-top-level-function gate — mirrors
/// `test/infrastructure_test.dart`'s precedent of a loose, non-lib-mirrored
/// test file for cross-cutting test infrastructure.
///
/// Uses tiny synthetic providers (no DB, no app wiring) to pin down the
/// helper's own contract in isolation from any real feature:
///   - a SYNC derived provider that watches the tick -> PASSES.
///   - a SYNC derived provider that does NOT watch the tick -> the helper
///     itself must FAIL the assertion (proves the helper actually detects
///     missing reactivity, not just that it never fails).
///   - the same pair for an ASYNC (FutureProvider) derived provider.
@Tags(['riverpod', 'contract'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/reactivity_contract.dart';

/// Monotonically-increasing tick, mirroring the shape of the real
/// `completionCommittedProvider` (`Riverpod(keepAlive: true)` Notifier).
class _TickNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void tick() => state = state + 1;
}

final _tickProvider = NotifierProvider<_TickNotifier, int>(_TickNotifier.new);

// -- sync providers ----------------------------------------------------

/// Reactive: re-derives from the tick, so it re-executes when it changes.
final _syncReactiveProvider = Provider<int>((ref) {
  final tick = ref.watch(_tickProvider);
  return tick * 10;
});

/// Stale by construction: never watches the tick, so it never re-executes.
final _syncStaleProvider = Provider<int>((_) => 42);

// -- async (FutureProvider) providers ------------------------------------

/// Reactive: re-derives from the tick.
final _asyncReactiveProvider = FutureProvider<int>((ref) async {
  final tick = ref.watch(_tickProvider);
  return tick * 100;
});

/// Stale by construction: never watches the tick.
final _asyncStaleProvider = FutureProvider<int>((_) async => 7);

Future<void> _mutate(ProviderContainer container) async {
  container.read(_tickProvider.notifier).tick();
}

void main() {
  group('expectRebuildsOn — sync providers', () {
    test('passes for a provider that watches the tick', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await expectRebuildsOn(
        container,
        _syncReactiveProvider,
        () => _mutate(container),
      );
    });

    test('fails (surfaces the missing ref.watch) for a provider that does '
        'NOT watch the tick', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await expectLater(
        expectRebuildsOn(
          container,
          _syncStaleProvider,
          () => _mutate(container),
        ),
        throwsA(isA<TestFailure>()),
      );
    });
  });

  group('expectRebuildsOn — async (FutureProvider) providers', () {
    test('passes for a provider that watches the tick', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await expectRebuildsOn(
        container,
        _asyncReactiveProvider,
        () => _mutate(container),
      );
    });

    test('fails (surfaces the missing ref.watch) for a provider that does '
        'NOT watch the tick', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await expectLater(
        expectRebuildsOn(
          container,
          _asyncStaleProvider,
          () => _mutate(container),
        ),
        throwsA(isA<TestFailure>()),
      );
    });
  });
}

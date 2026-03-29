import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/learning/presentation/providers/optimistic_completion_provider.dart';

void main() {
  group('OptimisticCompletionState', () {
    test('add inserts key into state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(
        optimisticCompletionStateProvider.notifier,
      );
      final key = optimisticKey(
        sefariaRef: 'Genesis.1',
        stageId: 1,
        trackType: 'learn',
      );

      notifier.add(key);

      final state = container.read(optimisticCompletionStateProvider);
      expect(state.contains(key), isTrue);
    });

    test('remove rolls back key from state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(
        optimisticCompletionStateProvider.notifier,
      );
      final key = optimisticKey(
        sefariaRef: 'Genesis.1',
        stageId: 1,
        trackType: 'learn',
      );

      notifier.add(key);
      expect(
        container.read(optimisticCompletionStateProvider).contains(key),
        isTrue,
      );

      notifier.remove(key);
      expect(
        container.read(optimisticCompletionStateProvider).contains(key),
        isFalse,
      );
    });

    test('rapid completions — 5 distinct keys all tracked', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(
        optimisticCompletionStateProvider.notifier,
      );

      for (var i = 1; i <= 5; i++) {
        final key = optimisticKey(
          sefariaRef: 'Genesis.$i',
          stageId: 1,
          trackType: 'learn',
        );
        notifier.add(key);
      }

      final state = container.read(optimisticCompletionStateProvider);
      expect(state, hasLength(5));
    });

    test('optimisticKey produces unique keys per ref+stage+track', () {
      final k1 = optimisticKey(
        sefariaRef: 'Gen.1',
        stageId: 1,
        trackType: 'learn',
      );
      final k2 = optimisticKey(
        sefariaRef: 'Gen.1',
        stageId: 2,
        trackType: 'learn',
      );
      final k3 = optimisticKey(
        sefariaRef: 'Gen.1',
        stageId: 1,
        trackType: 'chazara',
      );

      expect(k1, isNot(equals(k2)));
      expect(k1, isNot(equals(k3)));
      expect(k2, isNot(equals(k3)));
    });

    test('duplicate add is idempotent', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(
        optimisticCompletionStateProvider.notifier,
      );
      final key = optimisticKey(
        sefariaRef: 'Genesis.1',
        stageId: 1,
        trackType: 'learn',
      );

      notifier.add(key);
      notifier.add(key);

      final state = container.read(optimisticCompletionStateProvider);
      expect(state, hasLength(1));
    });
  });
}

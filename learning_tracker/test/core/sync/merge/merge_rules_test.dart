import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/merge/merge_rules.dart';

void main() {
  group('lwwMerge', () {
    test('remote newer → remote wins', () {
      final result = lwwMerge(
        local: 'old',
        remote: 'new',
        localUpdatedAt: DateTime.utc(2026, 1, 1),
        remoteUpdatedAt: DateTime.utc(2026, 2, 1),
      );
      expect(result.winner, 'new');
      expect(result.wasConflict, isTrue);
    });

    test('local newer → local wins', () {
      final result = lwwMerge(
        local: 'newer-local',
        remote: 'stale',
        localUpdatedAt: DateTime.utc(2026, 3, 1),
        remoteUpdatedAt: DateTime.utc(2026, 1, 1),
      );
      expect(result.winner, 'newer-local');
    });

    test('equal timestamps prefer local (no flapping)', () {
      final ts = DateTime.utc(2026, 1, 1);
      final result = lwwMerge(
        local: 'local',
        remote: 'remote',
        localUpdatedAt: ts,
        remoteUpdatedAt: ts,
      );
      expect(result.winner, 'local');
    });
  });

  group('mergeForwardMaxInt', () {
    test('picks larger value (progress never decreases)', () {
      expect(mergeForwardMaxInt(5, 10), 10);
      expect(mergeForwardMaxInt(100, 42), 100);
    });
  });

  group('mergeForwardMaxDate', () {
    test('picks later date', () {
      final a = DateTime.utc(2026, 1, 1);
      final b = DateTime.utc(2026, 2, 1);
      expect(mergeForwardMaxDate(a, b), b);
      expect(mergeForwardMaxDate(b, a), b);
    });
  });

  group('remoteIsNewer (sync engine predicate)', () {
    test('strictly newer remote → true', () {
      expect(
        remoteIsNewer(
          localUpdatedAt: DateTime.utc(2026, 1, 1),
          remoteUpdatedAt: DateTime.utc(2026, 2, 1),
        ),
        isTrue,
      );
    });

    test('equal timestamps → false (no flapping)', () {
      final ts = DateTime.utc(2026, 1, 1);
      expect(remoteIsNewer(localUpdatedAt: ts, remoteUpdatedAt: ts), isFalse);
    });

    test('older remote → false', () {
      expect(
        remoteIsNewer(
          localUpdatedAt: DateTime.utc(2026, 3, 1),
          remoteUpdatedAt: DateTime.utc(2026, 1, 1),
        ),
        isFalse,
      );
    });

    test('null local → remote always wins', () {
      expect(
        remoteIsNewer(
          localUpdatedAt: null,
          remoteUpdatedAt: DateTime.utc(2026, 1, 1),
        ),
        isTrue,
      );
    });

    test('null remote → never wins', () {
      expect(
        remoteIsNewer(
          localUpdatedAt: DateTime.utc(2026, 1, 1),
          remoteUpdatedAt: null,
        ),
        isFalse,
      );
    });
  });

  group('mergeForwardUnion', () {
    test('strictly additive union', () {
      expect(
        mergeForwardUnion<int>([1, 2, 3], [3, 4, 5]),
        equals({1, 2, 3, 4, 5}),
      );
    });
    test('empty sides handled', () {
      expect(mergeForwardUnion<int>(const [], [1]), equals({1}));
      expect(mergeForwardUnion<int>([1], const []), equals({1}));
    });
  });
}

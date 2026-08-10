/// Tests for [SyncPushException] — AUD-core-sync-33.
///
/// The `committed` field is the accounting `OutboxProcessor` relies on to
/// guarantee "committed rows are never re-pushed or dead-lettered" (H3).
/// This suite asserts that guarantee is enforced by the type itself — a
/// defensive copy inside the constructor — rather than depending on every
/// caller remembering to pass an already-immutable list.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/exceptions/sync_push_exception.dart';

void main() {
  group('SyncPushException.committed defensive copy', () {
    test('mutating the original growable list after construction does NOT '
        'affect .committed (AUD-core-sync-33)', () {
      final original = <String>['key1', 'key2'];
      final exception = SyncPushException(
        committed: original,
        pushCause: Exception('push failed'),
      );

      // Mutate the ORIGINAL list reference after the exception was built.
      original.add('key3-injected-after-construction');
      original.removeAt(0);

      expect(
        exception.committed,
        orderedEquals(['key1', 'key2']),
        reason:
            '.committed must reflect the state at construction time, not '
            'live mutations to whatever list reference the caller passed',
      );
    });

    test('.committed is unmodifiable — mutating it directly throws', () {
      final exception = SyncPushException(
        committed: ['a', 'b'],
        pushCause: Exception('push failed'),
      );

      expect(() => exception.committed.add('c'), throwsUnsupportedError);
    });

    test(
      'committed.length and toString() reflect the constructor argument',
      () {
        final exception = SyncPushException(
          committed: ['a', 'b', 'c'],
          pushCause: Exception('push failed'),
        );

        expect(exception.committed, hasLength(3));
        expect(exception.toString(), contains('committed: 3'));
        expect(exception.message, contains('3 committed item(s)'));
      },
    );
  });
}

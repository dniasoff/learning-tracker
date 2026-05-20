/// Tests for OfflineQueue — retired W2.35.
///
/// OfflineQueue was deleted in W2.35 (DNI-334/335 sync rework).
/// Equivalent invariant coverage:
/// - Outbox drains to 0: OutboxProcessor integration tests.
/// - Enqueue/flush: outbox_processor_test.dart.
library;

import 'package:test/test.dart';

void main() {
  group(
    'OfflineQueue',
    skip: 'Retired W2.35 — OfflineQueue deleted; see OutboxProcessor tests',
    () {
      test('placeholder', () {});
    },
  );
}

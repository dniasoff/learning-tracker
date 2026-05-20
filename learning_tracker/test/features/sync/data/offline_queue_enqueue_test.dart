/// Tests for OfflineQueue enqueue methods — retired W2.35.
///
/// OfflineQueue was deleted in W2.35 (DNI-334/335 sync rework).
/// Enqueue-path coverage lives in outbox_processor_test.dart.
library;

import 'package:test/test.dart';

void main() {
  group(
    'OfflineQueue enqueue',
    skip: 'Retired W2.35 — OfflineQueue deleted; see OutboxProcessor tests',
    () {
      test('placeholder', () {});
    },
  );
}

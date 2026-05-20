/// I-5 migration gate — schema v18 → v19.
///
/// sync_queue table was removed in Wave 3; these tests are superseded.
library;

import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'v18→v19: entityKey dedup on sync_queue',
    skip: 'sync_queue table removed in Wave 3 schema rebuild',
    () {
      test('enqueue without entityKey produces null entityKey row', () {});
      test(
        'enqueueWithKey replaces the existing row for the same entityKey',
        () {},
      );
      test('enqueueWithKey keeps both rows for different entityKeys', () {});
      test('null-key and keyed rows coexist without conflict', () {});
    },
  );
}

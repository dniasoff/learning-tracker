// The old DAO loop-write checker targeted the removed user Drift database.
// Keep this test as an explicit architecture boundary check for the current
// Firestore-backed track-order path.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('track-order writes use the current Firestore adapter', () {
    final currentRepository = File(
      'lib/data/repositories/firestore_track_learning_order_repository.dart',
    );
    final legacyDao = File(
      'lib/core/database/daos/track_learning_order_dao.dart',
    );
    final legacyTable = File(
      'lib/core/database/tables/track_learning_order.dart',
    );

    expect(currentRepository.existsSync(), isTrue);
    final source = currentRepository.readAsStringSync();
    expect(source, contains('class FirestoreTrackLearningOrderRepository'));
    expect(source, isNot(contains('await into(')));
    expect(legacyDao.existsSync(), isFalse);
    expect(legacyTable.existsSync(), isFalse);
  });
}

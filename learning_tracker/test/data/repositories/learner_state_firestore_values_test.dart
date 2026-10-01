/// Unit tests for the Firestore ⇄ domain value conversion.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/repositories/learner_state_firestore_values.dart';

void main() {
  final instant = DateTime.utc(2026, 9, 1, 8, 30, 15, 123, 456);

  test('DateTime ⇄ Timestamp, recursively, preserving the UTC instant', () {
    final domain = <String, Object?>{
      'at': instant,
      'nested': {
        'list': [instant, 1, 'x', null],
      },
      'n': 3,
    };
    final stored = toFirestoreMap(domain);
    expect(stored['at'], Timestamp.fromDate(instant));
    expect(
      ((stored['nested']! as Map)['list']! as List).first,
      Timestamp.fromDate(instant),
    );
    final back = fromFirestoreMap(stored);
    expect(back, domain);
    expect((back['at']! as DateTime).isUtc, isTrue);
  });

  test('local DateTimes are stored as the same instant', () {
    expect(toFirestoreValue(instant.toLocal()), Timestamp.fromDate(instant));
  });
}

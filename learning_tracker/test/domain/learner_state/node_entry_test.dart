/// Unit tests for [NodeEntry].
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';

void main() {
  test('round-trips exactly level / ref', () {
    const entry = NodeEntry(level: 'seder', ref: 'Zeraim');
    expect(entry.toStorage(), {'level': 'seder', 'ref': 'Zeraim'});
    expect(NodeEntry.fromStorage(entry.toStorage()), entry);
  });

  test('rejects empty, missing or unknown keys', () {
    for (final bad in <Map<String, Object?>>[
      {'level': '', 'ref': 'x'},
      {'level': 'perek'},
      {'level': 'perek', 'ref': 'x', 'sort': 1},
      {'level': 1, 'ref': 'x'},
    ]) {
      expect(
        () => NodeEntry.fromStorage(bad),
        throwsA(isA<StorageFormatException>()),
        reason: '$bad',
      );
    }
    expect(
      const NodeEntry(level: 'perek', ref: '').toStorage,
      throwsA(isA<StorageFormatException>()),
    );
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every production parent Actor constructor carries a session id', () {
    final constructor = RegExp(
      r'Actor\((?:(?!\);).)*?role:\s*ActorRole\.parent'
      r'(?:(?!\);).)*?\);',
      dotAll: true,
    );
    final parentConstructors = <String, String>{};
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final match in constructor.allMatches(source)) {
        parentConstructors[entity.path] = match.group(0)!;
      }
    }

    expect(parentConstructors, isNotEmpty);
    for (final entry in parentConstructors.entries) {
      expect(
        entry.value,
        contains('sessionId:'),
        reason: '${entry.key} constructs a parent actor without its proof',
      );
    }
  });
}

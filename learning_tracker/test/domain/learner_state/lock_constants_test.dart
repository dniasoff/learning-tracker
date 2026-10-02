// Mirror test for `lib/domain/learner_state/lock_constants.dart`
// (DNI-466 AC-1): the lock margins have one source of truth.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/lock_constants.dart';

Directory _lib() => Directory('lib').existsSync()
    ? Directory('lib')
    : Directory('learning_tracker/lib');

Iterable<(String, String)> _sources(Directory root) sync* {
  for (final entity in root.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      yield (
        entity.path.substring(entity.path.indexOf('lib/')),
        entity.readAsStringSync(),
      );
    }
  }
}

void main() {
  test('the margins are exactly 10 minutes each', () {
    expect(lockStartBeforeCandleLighting, const Duration(minutes: 10));
    expect(lockEndAfterTzeis, const Duration(minutes: 10));
  });

  test('lock_constants.dart is the only definition of a lock margin', () {
    final decl = RegExp(
      r'^(?:const|final)\s+(?:Duration\s+)?'
      r'(lockStartBeforeCandleLighting|lockEndAfterTzeis)\s*=',
      multiLine: true,
    );
    final found = [
      for (final (path, text) in _sources(_lib()))
        for (final m in decl.allMatches(text)) '$path: ${m.group(1)}',
    ]..sort();
    const file = 'lib/domain/learner_state/lock_constants.dart';
    expect(found, [
      '$file: lockEndAfterTzeis',
      '$file: lockStartBeforeCandleLighting',
    ]);
  });

  test('the domain lock rules use the constants and no 18/15 offset', () {
    final domain = Directory('${_lib().path}/domain');
    final legacy = RegExp(
      'candleOffsetMin|cushionMin|setCandleLightingOffset|'
      r'Duration\(minutes:\s*(?:15|18)\)',
    );
    final offenders = [
      for (final (path, text) in _sources(domain))
        if (legacy.hasMatch(text)) path,
    ];
    expect(offenders, isEmpty);

    final rules = File(
      '${domain.path}/learner_state/lock_windows.dart',
    ).readAsStringSync();
    expect(rules, contains('lockStartBeforeCandleLighting'));
    expect(rules, contains('lockEndAfterTzeis'));
    expect(
      RegExp(r'Duration\(minutes:').hasMatch(rules),
      isFalse,
      reason: 'lock_windows.dart must not define its own minute offset',
    );
  });
}

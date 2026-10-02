// C0 (DNI-524) AC-3: the exact inventory of `c0Stub(owner, what)` call
// sites under lib/.
//
// A spine story that fills a stub deletes the `c0Stub` call AND its row
// below in the same commit (C0 contract-change protocol, rule 5); no story
// other than C0 adds a row. DNI-490 (cutover) deletes this test with
// `c0_stub.dart`, and the R15 `c0Stub` entry then passes `--enforce`.
//
// A repo-wide static audit that walks Directory('lib') (the R7 checker's
// documented tree-walking exemption). That each stub throws its message
// is checked behaviourally by the stub's own mirror test.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Stub map of DNI-524, one row per call site: `(owner, what)`.
const _inventory = <(String, String)>[
  // DNI-474 (1.12)
  ('DNI-474', 'corporaProvider'),
  ('DNI-474', 'learnerStateProvider'),
];

/// The library that declares `c0Stub` (not a call site).
const _definition = 'lib/domain/learner_state/c0_stub.dart';

/// A literal call: `c0Stub('owner', 'what')`, formatter line breaks and a
/// trailing comma allowed.
final _call = RegExp(r"c0Stub\(\s*'([^']+)'\s*,\s*'([^']+)'\s*,?\s*\)");

/// Any mention of the identifier followed by a call parenthesis.
final _anyCall = RegExp(r'\bc0Stub\s*\(');

String _key((String, String) row) => '${row.$1} | ${row.$2}';

void main() {
  final root = Directory('lib').existsSync()
      ? Directory('lib')
      : Directory('learning_tracker/lib');

  test('every c0Stub call site under lib/ is exactly the Stub map', () {
    final found = <String>[];
    final nonLiteral = <String>[];
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.substring(entity.path.indexOf('lib/'));
      final text = entity.readAsStringSync();
      final literal = _call.allMatches(text).toList();
      var calls = _anyCall.allMatches(text).length;
      if (path == _definition) calls -= 1; // the declaration itself
      if (calls != literal.length) {
        nonLiteral.add('$path: $calls calls, ${literal.length} literal');
      }
      for (final m in literal) {
        found.add(_key((m.group(1)!, m.group(2)!)));
      }
    }
    expect(
      nonLiteral,
      isEmpty,
      reason: 'every c0Stub call must pass two string literals',
    );
    expect(
      found..sort(),
      (_inventory.map(_key).toList()..sort()),
      reason:
          'A filled stub deletes its row here in the same commit; no '
          'story other than C0 (DNI-524) adds a c0Stub call.',
    );
  });

  test('the inventory names each stub once and only spine owners', () {
    final whats = _inventory.map((r) => r.$2).toList();
    expect(whats.toSet(), hasLength(whats.length));
    expect(
      _inventory.map((r) => r.$1).toSet(),
      everyElement(
        isIn(const {
          'DNI-465',
          'DNI-466',
          'DNI-467',
          'DNI-468',
          'DNI-469',
          'DNI-470',
          'DNI-474',
        }),
      ),
    );
  });
}

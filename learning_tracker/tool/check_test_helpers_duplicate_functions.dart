/// AUD-t-cross-12 Rule-0 checker — test/helpers/ top-level function
/// duplication guard.
///
/// AUD-t-cross-12 found `seedProfile`/`seedProfileZero` defined
/// byte-for-byte identically in both test/helpers/drift_memory.dart and
/// test/helpers/test_database.dart, forcing 23 dependent test files to use
/// `show`/`hide` import combinators to dodge the resulting ambiguous-name
/// collision (drift_memory.dart's own doc comment already says it — not
/// test_database.dart — is "the canonical entry point"). Its acceptance
/// criteria name this checker: "A grep check (candidate for make audit)
/// fails if two files under test/helpers/ define a top-level function with
/// the same name."
///
/// Scope: every `*.dart` file directly under test/helpers/ — exactly the
/// directory the finding names. A PUBLIC top-level function (no leading
/// underscore) declared in one file only conflicts with another file's
/// declaration of the SAME name when imported together; a private (`_`)
/// helper is library-scoped and can never collide across files, so it is
/// excluded. A `export '...' show name;` re-export (the finding's own
/// recommended fix shape) is not a redeclaration and does not trip this
/// check — only a second `ReturnType name(` definition does.
///
/// Usage:
///   dart run tool/check_test_helpers_duplicate_functions.dart
///
/// Exit codes:
///   0 — no public top-level function name is defined in more than one file
///   1 — one or more names collide (prints the offending files:lines)
library;

import 'dart:io';

/// Matches a top-level (column-0) function declaration of the shape
/// `ReturnType functionName(` — e.g. `Future<void> seedProfile(` or
/// `UserDatabase inMemoryDb(`. The return-type character class deliberately
/// excludes `=`, so a top-level variable initializer that happens to call a
/// constructor (`final foo = Something(...)`) never matches.
final _topLevelFunctionDecl = RegExp(
  r'^[A-Za-z_][\w<>,?\s]*?\s+([a-zA-Z][a-zA-Z0-9_]*)\s*\(',
);

void main() {
  final dir = Directory('test/helpers');
  if (!dir.existsSync()) {
    stderr.writeln(
      'ERROR: test/helpers/ not found — run from learning_tracker/.',
    );
    exit(1);
  }

  final files =
      dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  // name -> [ "path:line", ... ]
  final sitesByName = <String, List<String>>{};

  for (final file in files) {
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final match = _topLevelFunctionDecl.firstMatch(lines[i]);
      if (match == null) continue;
      final name = match.group(1)!;
      if (name.startsWith('_')) continue; // private — no cross-file conflict
      sitesByName.putIfAbsent(name, () => []).add('${file.path}:${i + 1}');
    }
  }

  final violations = <String>[];
  sitesByName.forEach((name, sites) {
    if (sites.length > 1) {
      violations.add('$name: ${sites.join(', ')}');
    }
  });
  violations.sort();

  if (violations.isNotEmpty) {
    stderr.writeln(
      'test/helpers/ duplicate top-level function check FAILED — the same '
      'public function name is (re)defined in more than one file under '
      'test/helpers/ (AUD-t-cross-12). Keep exactly one definition and have '
      'the other file `export` (or `import`) it instead of redeclaring it:',
    );
    for (final v in violations) {
      stderr.writeln('  $v');
    }
    exit(1);
  }

  stdout.writeln(
    'test/helpers/ duplicate top-level function check passed — every '
    'public top-level function under test/helpers/ is defined in exactly '
    'one file.',
  );
}

/// EH-4 avoid-catching-errors checker — AUD-core-database-16.
///
/// `docs/coding-standards.md` EH-4: "Catch with typed `on <Type> catch`
/// clauses; never catch `Error` subtypes; throw only `Exception`/`Error`
/// subclasses." The project-wide `avoid_catching_errors` analyzer lint named
/// in EH-4's Lint Baseline table cannot be flipped on globally yet (other
/// pre-existing catches elsewhere are out of scope for this finding). This
/// checker instead enforces the "never catch an Error subtype" half of EH-4
/// precisely where AUD-core-database-16 fixed it:
/// `DeviceAccountX.accountTier` (`lib/core/database/registry/
/// device_registry_database.dart`) used to wrap `AccountTier.fromStorageKey`
/// in `on ArgumentError catch (_) { return AccountTier.local; }` —
/// `ArgumentError` is an [Error] subtype, and EH-4 says Errors are
/// programming-bug signals meant to crash loudly, not be caught as control
/// flow. The fix replaces the try/catch with the non-throwing
/// `AccountTier.tryFromStorageKey` accessor, so the checker's job is simply
/// to prove no catch clause in the scoped file(s) names an Error-subtype
/// type (`Error` itself, or anything following Dart's own `*Error` naming
/// convention: `ArgumentError`, `StateError`, `RangeError`, `TypeError`,
/// `UnsupportedError`, ...).
///
/// Usage:
///   dart run tool/check_eh4_avoid_catching_errors.dart
///
/// Exit codes:
///   0 — no catch clause in the scoped file(s) names an Error-subtype type.
///   1 — one or more Error-subtype catches remain (prints file:line).
library;

import 'dart:io';

/// The exact file AUD-core-database-16 fixes. Deliberately NOT `lib/`-wide —
/// see the file doc comment above.
const _targetFiles = [
  'lib/core/database/registry/device_registry_database.dart',
];

/// Matches `on <Type> catch (...)` / `on <Type> { ... }` clauses, capturing
/// the type name (a possible generic suffix like `<int>` is stripped before
/// the Error-subtype check).
final _onClausePattern = RegExp(r'\bon\s+([\w<>.]+)\s*(?:catch\s*\(|\{)');

bool _looksLikeErrorType(String rawType) {
  final base = rawType.split('<').first.trim();
  final simpleName = base.split('.').last;
  return simpleName == 'Error' || simpleName.endsWith('Error');
}

void main() {
  final violations = <String>[];

  for (final relPath in _targetFiles) {
    final file = File(relPath);
    if (!file.existsSync()) {
      stderr.writeln(
        'ERROR: $relPath not found — run from the learning_tracker/ directory',
      );
      exit(1);
    }
    final content = file.readAsStringSync();
    final stripped = _stripComments(content);

    for (final match in _onClausePattern.allMatches(stripped)) {
      final type = match.group(1)!;
      if (!_looksLikeErrorType(type)) continue;
      final line = _lineNumber(stripped, match.start);
      violations.add(
        '$relPath:$line: catches `$type`, an Error subtype — EH-4 forbids '
        'catching Error subtypes (they signal programming bugs and must '
        'crash loudly, not be folded into control flow). Expose a '
        'non-throwing accessor instead (see '
        'AccountTier.tryFromStorageKey for the established pattern).',
      );
    }
  }

  if (violations.isNotEmpty) {
    stderr.writeln('EH-4 avoid-catching-errors check FAILED:');
    for (final v in violations..sort()) {
      stderr.writeln('  $v');
    }
    exit(1);
  }

  stdout.writeln(
    'EH-4 avoid-catching-errors check passed — no catch clause in '
    '${_targetFiles.join(', ')} names an Error-subtype type.',
  );
}

/// 1-indexed line number of [index] within [source].
int _lineNumber(String source, int index) =>
    '\n'.allMatches(source.substring(0, index)).length + 1;

/// Blanks out `//` and `/* */` comments (replacing non-newline characters
/// with spaces so line numbers are preserved), leaving string literal
/// contents untouched. Duplicated (rather than shared) to match this
/// project's established single-file `dart run` checker convention — see
/// the typed-catch checker's identical helper.
String _stripComments(String source) {
  final buffer = StringBuffer();
  var i = 0;
  final n = source.length;
  while (i < n) {
    final c = source[i];
    final next = i + 1 < n ? source[i + 1] : '';

    if (c == "'" || c == '"') {
      final quote = c;
      final triple =
          i + 2 < n && source[i + 1] == quote && source[i + 2] == quote;
      final closer = triple ? quote * 3 : quote;
      buffer.write(source.substring(i, i + closer.length));
      i += closer.length;
      while (i < n && !source.startsWith(closer, i)) {
        if (source[i] == r'\' && i + 1 < n) {
          buffer.write(source[i]);
          buffer.write(source[i + 1]);
          i += 2;
          continue;
        }
        buffer.write(source[i]);
        i++;
      }
      if (i < n) {
        buffer.write(closer);
        i += closer.length;
      }
      continue;
    }

    if (c == '/' && next == '/') {
      while (i < n && source[i] != '\n') {
        buffer.write(' ');
        i++;
      }
      continue;
    }

    if (c == '/' && next == '*') {
      i += 2;
      while (i < n &&
          !(source[i] == '*' && i + 1 < n && source[i + 1] == '/')) {
        buffer.write(source[i] == '\n' ? '\n' : ' ');
        i++;
      }
      i += 2; // consume closing */
      continue;
    }

    buffer.write(c);
    i++;
  }
  return buffer.toString();
}

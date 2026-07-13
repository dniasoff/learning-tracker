/// DB-2 transaction-safety checker (AUD-onboarding-06).
///
/// DB-2 (docs/coding-standards.md): "Any operation performing more than one
/// write runs inside a single `transaction()`, with every statement
/// awaited." A crash between two un-transacted writes leaves the local
/// (offline-first, no-server-reconciliation) database permanently
/// half-written.
///
/// This script flags any method whose own body contains **two or more**
/// awaited mutation-shaped calls (`insert*`, `delete*`, `update*`, `write*`,
/// `upsert*`, `replace*`, `remove*`, `set*`, `mark*`, `tombstone*`,
/// `expunge*`, `save*`, `enqueue*`, `push*`, `create*`, or the Drift
/// delete-statement terminal `.go(`) with **no** enclosing `transaction(` /
/// `runTransaction(` / `.batch(` call anywhere in that same method body. The
/// mutation call may be receiver-qualified (`db.deleteFoo(`) or a bare
/// same-class call with an implicit `this` receiver (`await removeAccount(`,
/// `await setLastActiveAccountId(`) — DAO classes like
/// `DeviceRegistryDatabase` call their own sibling write methods without an
/// explicit `this.` prefix, so both shapes must count.
///
/// Heuristic, not a full parser: methods are located by brace-depth
/// scanning (a `{` opened directly inside a class body, i.e. at nesting
/// depth 1, whose preceding statement head ends in `)` optionally followed
/// by `async`/`async*` and is not a control-flow keyword). A method's own
/// body includes any closures nested inside it (e.g. the callback passed to
/// `.transaction(() async { ... })`), so wrapping a sequence of writes in a
/// transaction *within the same method* is correctly recognised as
/// satisfying DB-2 — this is why the fix for AUD-onboarding-06 moves each
/// Drift write for a given operation into the same method that opens its
/// transaction, rather than scattering them across private helpers whose
/// bodies the checker (correctly) cannot see are transaction-enclosed.
///
/// Scope (deliberate, Rule 0 "ship the checker when you first apply the
/// rule"): `lib/features/onboarding/domain/services/` — the exact area of
/// AUD-onboarding-06's two violations (`learning_process_wizard_service.dart`,
/// `bulk_prior_completion_service.dart`) — plus
/// `lib/core/database/registry/` — the exact area of AUD-core-database-08's
/// violation (`device_registry_database.dart`'s `removeAccount` and
/// `dedupeByEmail`). A codebase-wide DB-2 rollout risks surfacing a large
/// pre-existing-violation backlog unrelated to either finding (mirroring the
/// audit's own precedent of introducing new checks scoped/warn-only against
/// legacy debt — checks 14/15 in this Makefile); widening this checker's
/// scope further is a follow-up, not part of either fix.
///
/// Usage:
///   dart run tool/check_db_transactions.dart
///
/// Exit codes:
///   0 — every method in scope with >=2 awaited mutation calls has an
///       enclosing transaction()/batch() in its own body
///   1 — one or more methods violate DB-2 (prints file:line + method name)
library;

import 'dart:io';

/// Directories scanned for DB-2 violations — see the scope note above.
const _scanDirs = [
  'lib/features/onboarding/domain/services',
  'lib/core/database/registry',
];

/// Method-selector prefixes treated as "mutation-shaped" calls, plus the
/// exact-match Drift delete-statement terminal `go`.
const _writeVerbPrefixes = [
  'insert',
  'delete',
  'update',
  'upsert',
  'write',
  'replace',
  'remove',
  'set',
  'mark',
  'tombstone',
  'expunge',
  'save',
  'enqueue',
  'push',
  'create',
];

final _writeCallPattern = RegExp(
  r'await\s+(?:[^;{}]*?\.)?(?:' +
      _writeVerbPrefixes.map((v) => '$v\\w*').join('|') +
      r'|go)\s*\(',
);

final _transactionPattern = RegExp(r'[Tt]ransaction\(|\.batch\(');

const _controlFlowKeywords = {'if', 'for', 'while', 'switch', 'catch'};

void main() {
  final dartFiles = <File>[];
  for (final scanDir in _scanDirs) {
    final dir = Directory(scanDir);
    if (!dir.existsSync()) {
      stderr.writeln('ERROR: $scanDir not found — run from learning_tracker/');
      exit(1);
    }
    dartFiles.addAll(
      dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !f.path.endsWith('.g.dart'))
          .where((f) => !f.path.endsWith('.freezed.dart')),
    );
  }
  dartFiles.sort((a, b) => a.path.compareTo(b.path));

  final violations = <String>[];

  for (final file in dartFiles) {
    final relPath = file.path.replaceFirst(RegExp(r'^\.[\\/]'), '');
    final stripped = _stripComments(file.readAsStringSync());

    for (final body in _extractTopLevelMethodBodies(stripped)) {
      final writeMatches = _writeCallPattern.allMatches(body.text).toList();
      if (writeMatches.length < 2) continue;
      if (_transactionPattern.hasMatch(body.text)) continue;

      final line =
          '\n'.allMatches(stripped.substring(0, body.signatureStart)).length +
          1;
      violations.add(
        '$relPath:$line: ${body.methodName}() has '
        '${writeMatches.length} awaited mutation calls '
        '(${writeMatches.map((m) => m.group(0)!.trim()).join(', ')}) '
        'with no enclosing transaction()/batch() — DB-2 requires wrapping '
        'multi-statement writes in a single transaction so a crash '
        'mid-sequence cannot leave the local DB half-written.',
      );
    }
  }

  if (violations.isNotEmpty) {
    stderr.writeln('DB-2 transaction-safety check FAILED:');
    for (final v in violations) {
      stderr.writeln('  $v');
    }
    exit(1);
  }

  stdout.writeln(
    'DB-2 transaction-safety check passed — every multi-write method in '
    '${_scanDirs.map((d) => '$d/').join(', ')} has an enclosing '
    'transaction().',
  );
}

class _MethodBody {
  _MethodBody({
    required this.text,
    required this.signatureStart,
    required this.methodName,
  });

  final String text;
  final int signatureStart;
  final String methodName;
}

/// Finds every method whose body opens directly inside a class (brace
/// nesting depth 1) and returns its full body text (including any nested
/// closures) plus the source offset of its signature, for line-number
/// reporting.
///
/// Tracks paren depth alongside brace depth so a `{`/`}` belonging to an
/// optional-named-parameter list (`foo(int a, {required int b})` — Dart
/// parameter lists use braces too) or a default-value literal inside one is
/// never mistaken for a block boundary; only braces seen at paren depth 0
/// affect [blockDepth] / the tracked statement start.
List<_MethodBody> _extractTopLevelMethodBodies(String source) {
  final results = <_MethodBody>[];
  var blockDepth = 0;
  var parenDepth = 0;
  var statementStart = 0;
  var i = 0;
  final n = source.length;

  while (i < n) {
    final c = source[i];
    if (c == '(') {
      parenDepth++;
    } else if (c == ')') {
      if (parenDepth > 0) parenDepth--;
    } else if (c == '{' && parenDepth == 0) {
      if (blockDepth == 1) {
        final head = source.substring(statementStart, i).trimRight();
        final name = _methodNameIfSignature(head);
        if (name != null) {
          final close = _matchingBrace(source, i);
          if (close != -1) {
            results.add(
              _MethodBody(
                text: source.substring(i + 1, close),
                signatureStart: statementStart,
                methodName: name,
              ),
            );
          }
        }
      }
      blockDepth++;
      statementStart = i + 1;
    } else if (c == '}' && parenDepth == 0) {
      blockDepth--;
      statementStart = i + 1;
    } else if (c == ';' && parenDepth == 0) {
      statementStart = i + 1;
    }
    i++;
  }
  return results;
}

/// Returns the index of the `}` matching the `{` at [openIdx], or -1.
/// Paren-depth-guarded for the same reason as [_extractTopLevelMethodBodies]
/// — a nested local function declaration with named parameters would
/// otherwise desync the brace count.
int _matchingBrace(String source, int openIdx) {
  var depth = 1;
  var parenDepth = 0;
  for (var j = openIdx + 1; j < source.length; j++) {
    final c = source[j];
    if (c == '(') {
      parenDepth++;
    } else if (c == ')') {
      if (parenDepth > 0) parenDepth--;
    } else if (c == '{' && parenDepth == 0) {
      depth++;
    } else if (c == '}' && parenDepth == 0) {
      depth--;
      if (depth == 0) return j;
    }
  }
  return -1;
}

/// If [head] (the text immediately before a `{`) looks like a method
/// signature — ends in `)` (optionally followed by `async`/`async*`/`sync*`)
/// whose parameter list is not owned by a control-flow keyword — returns
/// the method name. Otherwise returns null (class body, if/for/while/
/// switch/catch block, etc.).
String? _methodNameIfSignature(String head) {
  final asyncStripped = head.replaceFirst(RegExp(r'\s+(async\*?|sync\*)$'), '');
  if (!asyncStripped.endsWith(')')) return null;

  var depth = 0;
  var idx = asyncStripped.length - 1;
  for (; idx >= 0; idx--) {
    final c = asyncStripped[idx];
    if (c == ')') {
      depth++;
    } else if (c == '(') {
      depth--;
      if (depth == 0) break;
    }
  }
  if (idx <= 0) return null;

  final before = asyncStripped.substring(0, idx).trimRight();
  final m = RegExp(r'([A-Za-z_$][A-Za-z0-9_$]*)$').firstMatch(before);
  if (m == null) return null;
  final name = m.group(1)!;
  if (_controlFlowKeywords.contains(name)) return null;
  return name;
}

/// Blanks out `//` and `/* */` comments (replacing non-newline characters
/// with spaces so line numbers are preserved), while leaving string literal
/// contents untouched. Mirrors `tool/check_analytics_catalog.dart`'s
/// `_stripComments` (duplicated rather than shared — both are single-file
/// `dart run` scripts with no shared library target).
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

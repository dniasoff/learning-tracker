/// EH-2 / SM-5 unguarded-persistence checker (AUD-core-preferences-04).
///
/// The finding: 9 plain-value/AsyncValue `Notifier` mutation methods across
/// 6 files optimistically assigned `state` and then `await`ed a
/// SharedPreferences write / DAO call / `OnboardingStep.save`-or-`load` with
/// NO enclosing `try`/`AsyncValue.guard`/`guardedPersist` anywhere in the
/// same method body — a write failure was an unobserved `Future` rejection,
/// and the change silently reverted on next launch with zero diagnostic
/// trail. See docs/coding-standards.md EH-2 ("a raw exception must never
/// propagate into presentation") and SM-5 (`AsyncValue.guard` for
/// `AsyncValue`-shaped state).
///
/// This script flags any `Future<void>` method whose own body — opened
/// directly inside a class (a `Notifier`/`AsyncNotifier` method), i.e. NOT
/// a bare top-level function — contains an `await <prefs-or-dao-call>` with
/// no `try {`, `AsyncValue.guard(`, or `guardedPersist(`/`_guardedPersist(`/
/// `_guardedLoad(` occurring EARLIER in the same body text. Heuristic, not a
/// full parser (Rule 0 "a cheap textual first pass ahead of a real
/// custom_lint AST rule" — see the finding's acceptance criteria): a
/// same-body `try`/guard-call appearing anywhere before the awaited call is
/// treated as covering it, mirroring the position-insensitive style already
/// used by `tool/check_db_transactions.dart`'s `transaction(`/`.batch(`
/// check but restricted to genuinely PRECEDING guard tokens per this
/// finding's literal AC wording ("not preceded by an open try earlier in
/// the same method body").
///
/// Scope (deliberate, Rule 0 "ship the checker when you first apply the
/// rule"): the exact 6 files AUD-core-preferences-04 named, plus (for the
/// checker's own Rule-0 self-test — see
/// `test/tool/check_guarded_persist_test.dart`) any `.dart` file dropped
/// into `test/fixtures/audit/guarded_persist/` (empty in the committed
/// tree, so it contributes zero violations by default). A codebase-wide
/// sweep for this shape is future work, not part of this finding.
///
/// Usage:
///   dart run tool/check_guarded_persist.dart
///
/// Exit codes:
///   0 — no unguarded `await <prefs-or-dao-call>` found in a `Future<void>`
///       Notifier method across the scanned files
///   1 — one or more violations found (prints file:line + method name)
library;

import 'dart:io';

/// The exact files this finding named — see the class doc comment.
const _scanFiles = [
  'lib/core/preferences/preference_providers.dart',
  'lib/features/notifications/presentation/providers/notification_providers.dart',
  'lib/features/sacred_time/presentation/providers/sacred_location_provider.dart',
  'lib/features/scheduler/presentation/providers/scheduler_providers.dart',
  'lib/features/tracks/setup/presentation/controllers/add_track_controller.dart',
  'lib/features/onboarding/presentation/providers/onboarding_controller.dart',
];

/// Additional directory scanned purely so this checker's own Rule-0
/// self-test (`test/tool/check_guarded_persist_test.dart`) can drop a
/// disposable fixture file, run the checker against it, and delete it —
/// without touching any of the 6 real production files above. Empty by
/// default.
const _fixtureScanDir = 'test/fixtures/audit/guarded_persist';

/// Pre-existing violations OUTSIDE AUD-core-preferences-04's named 21 sites
/// that a full scan of the 6 scoped files also surfaces. Not part of this
/// finding's evidence/acceptance-criteria list — fixing them here would be
/// a drive-by (scope discipline), so they are baselined the same way
/// `tool/check_notifications_sync_effect_overrides.dart` (AUD-t-notifications-01)
/// baselines its own pre-existing out-of-scope hits, keeping this checker a
/// ratchet against regression in the finding's OWN territory rather than a
/// silent no-op or a drive-by-forcing hard gate. Shrink as each is burned
/// down by its own finding.
///
///   * add_track_controller.dart:clearSaved() — `Future<void> clearSaved()`
///     loops `await prefs.remove(key)` with no guard. Reachable (called by
///     `add_track_flow_screen.dart` on wizard completion/exit), but NOT
///     named in AUD-core-preferences-04's evidence or the 21-site count
///     (only `_persist()`, reached via `_advance()`/`goBack()`, is named for
///     this file) — logged as a candidate follow-up, not fixed here.
const _baseline = {
  'lib/features/tracks/setup/presentation/controllers/add_track_controller.dart|clearSaved',
};

/// Persistence-shaped call verbs this checker treats as risky: a
/// SharedPreferences setter/remove, a `ProfileScopedPreference`/DAO-style
/// `write*(`, or an `OnboardingStep`-shaped `save(`/`load(`. Optionally
/// receiver-qualified (`prefs.setBool(`, `state.steps[i].load(`) or bare
/// (`save(ref)` inside the declaring class itself).
final _persistCallPattern = RegExp(
  r'await\s+(?:[A-Za-z_$][\w$]*(?:\[[^\]]*\])?\.)*'
  r'(?:set(?:Bool|Int|Double|String|StringList)|remove|write\w*|save|load)\s*\(',
);

/// Guard tokens recognised as covering an awaited persistence call anywhere
/// later in the same method body: a hand-rolled `try` block, the canonical
/// SM-5 `AsyncValue.guard(`, or this finding's own `guardedPersist(` helper
/// (`lib/core/utils/guarded_persist.dart`) under any of its call-site names
/// used in the 6 scanned files (`guardedPersist(`, the notification
/// providers' file-private `_guardedPersist(`, the onboarding controller's
/// file-private `_guardedLoad(`).
final _guardTokenPattern = RegExp(
  r'\btry\s*\{|AsyncValue\.guard\(|_?guardedPersist\(|_guardedLoad\(',
);

const _controlFlowKeywords = {'if', 'for', 'while', 'switch', 'catch'};

void main() {
  final files = <File>[];
  for (final relPath in _scanFiles) {
    final f = File(relPath);
    if (!f.existsSync()) {
      stderr.writeln('ERROR: $relPath not found — run from learning_tracker/');
      exit(1);
    }
    files.add(f);
  }

  final fixtureDir = Directory(_fixtureScanDir);
  if (fixtureDir.existsSync()) {
    files.addAll(
      fixtureDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart')),
    );
  }

  final violations = <String>[];

  for (final file in files) {
    final relPath = file.path.replaceFirst(RegExp(r'^\.[\\/]'), '');
    final stripped = _stripComments(file.readAsStringSync());

    for (final body in _extractFutureVoidMethodBodies(stripped)) {
      if (_baseline.contains('$relPath|${body.methodName}')) continue;
      for (final match in _persistCallPattern.allMatches(body.text)) {
        final guardedBefore = _guardTokenPattern
            .allMatches(body.text)
            .any((g) => g.start < match.start);
        if (guardedBefore) continue;

        final line =
            '\n'.allMatches(stripped.substring(0, body.signatureStart)).length +
            1;
        violations.add(
          '$relPath:$line: ${body.methodName}() has an unguarded '
          '"${match.group(0)!.trim()}" — a Future<void> Notifier method with '
          'no try{}/AsyncValue.guard(/guardedPersist( earlier in the same '
          'body means a write failure is an unobserved Future rejection '
          '(EH-2 / SM-5, AUD-core-preferences-04).',
        );
      }
    }
  }

  if (violations.isNotEmpty) {
    stderr.writeln('guarded-persist check FAILED:');
    for (final v in violations) {
      stderr.writeln('  $v');
    }
    exit(1);
  }

  stdout.writeln(
    'guarded-persist check passed — every Future<void> Notifier method in '
    'the AUD-core-preferences-04 scope guards its persistence call.',
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
/// nesting depth 1 — i.e. NOT a bare top-level function) AND whose return
/// type is exactly `Future<void>`. Mirrors
/// `check_db_transactions.dart`'s `_extractTopLevelMethodBodies` brace/paren
/// scanning, with an added return-type filter.
List<_MethodBody> _extractFutureVoidMethodBodies(String source) {
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
        if (name != null && _isFutureVoidSignature(head, name)) {
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

/// True when [head] (the text immediately before a method's `{`) declares
/// [name] with return type exactly `Future<void>` (allowing an arbitrary
/// prefix — annotations like `@override`, leading whitespace/newlines).
bool _isFutureVoidSignature(String head, String name) {
  return RegExp(
    r'Future<void>\s+' + RegExp.escape(name) + r'\s*\(',
  ).hasMatch(head);
}

/// Returns the index of the `}` matching the `{` at [openIdx], or -1.
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

/// If [head] looks like a method signature — ends in `)` (optionally
/// followed by `async`/`async*`/`sync*`) whose parameter list is not owned
/// by a control-flow keyword — returns the method name. Otherwise null
/// (class body, if/for/while/switch/catch block, etc.).
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
/// contents untouched. Duplicated from `tool/check_db_transactions.dart` —
/// both are single-file `dart run` scripts with no shared library target.
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

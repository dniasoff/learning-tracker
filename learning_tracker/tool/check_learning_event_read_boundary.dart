/// AD-35 "Reads" / DNI-474 AC-2 learning-event read-boundary gate.
///
/// `learning_events/{ulid}` is the only record of learning, and nothing but
/// the repository layer queries it: screens, planner and reports read
/// `LearnerState` (ARCHITECTURE-SPINE.md § Consistency Conventions,
/// "Reads"). This gate fails when any `lib/**` Dart file outside
/// `lib/data/repositories/` names the collection to query it:
///
/// * Rule Q1 — a string literal that IS the collection name
///   (`'learning_events'`) or a path with a `/learning_events` segment
///   (`'users/$uid/learner_profiles/$p/learning_events'`);
/// * Rule Q2 — a reference to the collection-name constant
///   `kLearningEventsCollection`;
/// * Rule Q3 — an import of the Firestore query implementation
///   (`firestore_learning_event_repository.dart`) from outside `lib/data/`
///   (the provider wiring in `lib/data/firestore/` may construct it;
///   `LearnerState` consumers depend on the port only).
///
/// Comments are ignored, and so are prose strings that merely mention the
/// collection (an exception message `'learning_events/$id already exists'`
/// is not a query: Q1 needs the whole literal or a `/`-prefixed segment).
///
/// Zero-tolerance (no baseline): the boundary starts clean.
///
/// Usage:
///   dart run tool/check_learning_event_read_boundary.dart [--root <dir>]
///
/// `--root` is the package directory to scan (default: the current one);
/// the test points it at disposable fixture trees.
///
/// Exit codes: 0 — clean; 1 — violations (listed); 2 — bad arguments.
library;

import 'dart:io';

/// The repository layer: the only place a query may name the collection.
const repositoryDir = 'lib/data/repositories/';

/// Where the Firestore implementation may be imported (repositories and
/// the `lib/data/firestore/` provider wiring).
const dataDir = 'lib/data/';

const _collection = 'learning_events';
const _constant = 'kLearningEventsCollection';
const _implementation = 'firestore_learning_event_repository.dart';

/// One violation.
final class Violation {
  Violation(this.rule, this.path, this.line, this.snippet);

  final String rule;
  final String path;
  final int line;
  final String snippet;

  @override
  String toString() => '  [$rule] $path:$line  $snippet';
}

/// The violations in [source] of the file at the package-relative [path].
List<Violation> scanSource(String path, String source) {
  final inRepositories = path.startsWith(repositoryDir);
  final inData = path.startsWith(dataDir);
  if (inRepositories) return const [];
  final lexed = _lex(source);
  final out = <Violation>[];
  int lineOf(int offset) =>
      '\n'.allMatches(source.substring(0, offset)).length + 1;

  for (final literal in lexed.strings) {
    final text = literal.text;
    final isQuery =
        text == _collection || RegExp('/$_collection(?:/|\$)').hasMatch(text);
    if (!isQuery) continue;
    out.add(Violation('Q1', path, lineOf(literal.offset), "'$text'"));
  }
  for (final m in RegExp('\\b$_constant\\b').allMatches(lexed.code)) {
    out.add(Violation('Q2', path, lineOf(m.start), _constant));
  }
  if (!inData) {
    final directive = RegExp(
      r'''^[ \t]*(?:import|export)\b[^;]*;''',
      multiLine: true,
    );
    for (final m in directive.allMatches(lexed.codeWithStrings)) {
      if (m.group(0)!.contains(_implementation)) {
        out.add(Violation('Q3', path, lineOf(m.start), m.group(0)!.trim()));
      }
    }
  }
  return out;
}

/// The violations under `<root>/lib`.
List<Violation> scanTree(Directory root) {
  final lib = Directory('${root.path}/lib');
  if (!lib.existsSync()) return const [];
  final out = <Violation>[];
  final files =
      lib
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    final path = file.path
        .substring(root.path.length + 1)
        .replaceAll(Platform.pathSeparator, '/');
    out.addAll(scanSource(path, file.readAsStringSync()));
  }
  return out;
}

void main(List<String> args) {
  var root = Directory.current;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--root' && i + 1 < args.length) {
      root = Directory(args[++i]);
    } else {
      stderr.writeln(
        'usage: check_learning_event_read_boundary.dart [--root <dir>]',
      );
      exit(2);
    }
  }
  final violations = scanTree(root);
  if (violations.isEmpty) {
    stdout.writeln(
      'Learning-event read boundary OK — only $repositoryDir queries '
      '$_collection (AD-35 "Reads", DNI-474).',
    );
    return;
  }
  stderr
    ..writeln(
      'Learning-event read boundary FAILED — ${violations.length} '
      'violation(s); query $_collection only in $repositoryDir and read '
      'LearnerState everywhere else:',
    )
    ..writeAll(violations, '\n')
    ..writeln();
  exit(1);
}

// ---------------------------------------------------------------------------
// Lexing: split Dart source into code (comments and string bodies blanked),
// code-with-strings (comments blanked) and string literals.
// ---------------------------------------------------------------------------

final class _Literal {
  _Literal(this.offset, this.text);
  final int offset;
  final String text;
}

final class _Lexed {
  _Lexed(this.code, this.codeWithStrings, this.strings);
  final String code;
  final String codeWithStrings;
  final List<_Literal> strings;
}

_Lexed _lex(String s) {
  final code = StringBuffer();
  final withStrings = StringBuffer();
  final strings = <_Literal>[];
  var i = 0;
  void blank(int from, int to, {bool keepInStrings = false}) {
    for (var k = from; k < to; k++) {
      final ch = s[k] == '\n' ? '\n' : ' ';
      code.write(ch);
      withStrings.write(keepInStrings ? s[k] : ch);
    }
  }

  while (i < s.length) {
    if (s.startsWith('//', i)) {
      final end = s.indexOf('\n', i);
      final stop = end < 0 ? s.length : end;
      blank(i, stop);
      i = stop;
      continue;
    }
    if (s.startsWith('/*', i)) {
      var depth = 0;
      var j = i;
      while (j < s.length) {
        if (s.startsWith('/*', j)) {
          depth++;
          j += 2;
        } else if (s.startsWith('*/', j)) {
          depth--;
          j += 2;
          if (depth == 0) break;
        } else {
          j++;
        }
      }
      blank(i, j);
      i = j;
      continue;
    }
    final raw =
        s[i] == 'r' && i + 1 < s.length && (s[i + 1] == "'" || s[i + 1] == '"');
    final q = raw ? i + 1 : i;
    if (s[q] == "'" || s[q] == '"') {
      final triple = s.startsWith(s[q] * 3, q);
      final delimiter = triple ? s[q] * 3 : s[q];
      var j = q + delimiter.length;
      while (j < s.length && !s.startsWith(delimiter, j)) {
        if (!raw && s[j] == r'\') j++;
        j++;
      }
      final bodyStart = q + delimiter.length;
      final bodyEnd = j.clamp(bodyStart, s.length);
      strings.add(_Literal(i, s.substring(bodyStart, bodyEnd)));
      final end = (j + delimiter.length).clamp(0, s.length);
      blank(i, end, keepInStrings: true);
      i = end;
      continue;
    }
    code.write(s[i]);
    withStrings.write(s[i]);
    i++;
  }
  return _Lexed(code.toString(), withStrings.toString(), strings);
}

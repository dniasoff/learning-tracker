/// AD-23 / AD-28 dependency-direction gate, plus the AD-35 pure-domain
/// guard (sub-tracks story 1.1, DNI-463).
///
/// Two hard rules, both zero-tolerance (no baseline, no ratchet):
///
/// ## Rule A — features never reach the data-access ring directly
///
/// Story 2.6 (`docs/planning/epics-firestore-migration-phase0.md`). Binds
/// AD-23 ("dependencies flow only downward. No edge may be added against
/// the arrows." — `Features --> Repositories --> {Data-access ring, Domain}`,
/// never `Features --> Data-access ring` directly) and AD-28 ("AD-23
/// dependency direction: a grep/analyzer check that no `lib/features/**` or
/// `lib/domain/**` file imports the data-access ring past a repository
/// interface.").
///
/// Any `lib/features/**/*.dart` file (that is NOT itself inside a
/// feature's own `data/repositories/` implementation directory — the
/// repository layer, `R` in the AD-23 diagram, is exactly the code
/// permitted to depend on the data-access ring, `A` — and is not a
/// generated `.g.dart` / `.freezed.dart` file) that imports
/// `package:learning_tracker/data/firestore/...` fails.
///
/// ## Rule B — `lib/domain/**` is pure Dart (AD-35)
///
/// `LearnerStateEngine` is a pure function run once per profile; every
/// learner's numbers come from it. Nothing under `lib/domain/**` may depend
/// on Firestore, Firebase, Flutter, Riverpod or the data layer. Any
/// `lib/domain/**/*.dart` file — at any depth, generated files INCLUDED,
/// with no `data/repositories/` exemption — whose import or export
/// directive (including conditional-import URIs) names one of these
/// families fails:
///
///   * `package:cloud_firestore...`        (cloud_firestore)
///   * `package:firebase_*...`             (firebase_*)
///   * `package:flutter/...`               (flutter/)
///   * `package:flutter_riverpod...`       (flutter_riverpod)
///   * `package:riverpod*...`              (riverpod*)
///   * `package:learning_tracker/data/...` (learning_tracker/data/**)
///
/// Relative URIs are resolved against the importing file first, so
/// `import '../../data/firestore/doc_ids.dart';` from `lib/domain/**` is
/// caught exactly like its `package:` spelling.
///
/// ## Hard gate, not a ratchet
///
/// Both rules start at zero confirmed sites. AD-23's rule — "no edge may be
/// added against the arrows" — and AD-35's purity requirement are genuine
/// zero-tolerance boundaries, not a debt paydown, so any match fails the
/// check, always.
///
/// Usage:
///   dart run tool/check_dependency_direction.dart
///   dart run tool/check_dependency_direction.dart --report
///
/// Exit codes:
///   0 — no violation found
///   1 — one or more violations found (prints the list)
library;

import 'dart:io';

/// Rule A: the data-access ring feature code must reach only through a
/// repository interface, never directly.
const _dataAccessRingImportPrefix = 'package:learning_tracker/data/firestore/';

/// Within `lib/features/`, a file under one of these path segments IS the
/// repository layer (`R` in the AD-23 diagram) — the one layer permitted to
/// depend on the data-access ring (`R --> A` is an allowed edge).
const _repositoryDirSegment = '/data/repositories/';

/// Rule B: forbidden import families for `lib/domain/**`, as
/// `(family label, URI prefix)` pairs. The label is what the failure output
/// names, so each family is individually identifiable.
///
/// `package:flutter/` keeps its trailing slash so it cannot swallow
/// `flutter_riverpod` (its own family) or unrelated `flutter_*` packages;
/// `package:riverpod` and `package:firebase_` deliberately have none so the
/// whole `riverpod*` / `firebase_*` package families match. The
/// `cloud_firestore` and `flutter_riverpod` prefixes are likewise
/// unbounded on purpose: `cloud_firestore_platform_interface`,
/// `cloud_firestore_web` and any `flutter_riverpod_*` add-on are the same
/// Firestore / Riverpod dependency and must not slip into the domain.
const domainForbiddenFamilies = <(String, String)>[
  ('cloud_firestore', 'package:cloud_firestore'),
  ('firebase_*', 'package:firebase_'),
  ('flutter/', 'package:flutter/'),
  ('flutter_riverpod', 'package:flutter_riverpod'),
  ('riverpod*', 'package:riverpod'),
  ('learning_tracker/data/**', 'package:learning_tracker/data/'),
];

/// Returns the forbidden family label [uri] belongs to, or `null` when the
/// URI is allowed inside `lib/domain/**`. [uri] must already be canonical
/// (see [_canonicalUri]).
String? domainForbiddenFamily(String uri) {
  for (final (label, prefix) in domainForbiddenFamilies) {
    if (uri.startsWith(prefix)) return label;
  }
  return null;
}

/// An `import`/`export` directive, from the keyword up to its terminating
/// `;` — spanning lines, so `import\n  'package:flutter/...';` and
/// conditional imports (`import 'a.dart' if (dart.library.io) 'b.dart';`)
/// are captured whole. Matched against [_stripComments] output, so
/// commented-out directives (`// import ...`, `/* import ... */`) never
/// match and an inline comment before a directive cannot hide it.
final _directive = RegExp(
  r'''^[ \t]*(?:import|export)\b([^;]*);''',
  multiLine: true,
);

/// Every quoted string inside a directive is a URI (combinators such as
/// `show`/`hide`/`as` are bare identifiers).
final _quotedUri = RegExp('''['"]([^'"]+)['"]''');

class _Match {
  _Match(this.rule, this.path, this.line, this.snippet);
  final String rule;
  final String path;
  final int line;
  final String snippet;

  @override
  String toString() => '$path:$line: [$rule] $snippet';
}

String _normalize(String path) => path.replaceAll(r'\', '/');

List<File> _dartFilesUnder(String dirPath) {
  final dir = Directory(dirPath);
  if (!dir.existsSync()) return const [];
  final files = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => _normalize(f.path).endsWith('.dart'))
      .toList();
  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
}

/// Rule A scan set: `lib/features/**` minus generated files and the
/// repository-implementation layer.
List<File> _featureFiles() => _dartFilesUnder('lib/features').where((f) {
  final p = _normalize(f.path);
  if (p.endsWith('.g.dart') || p.endsWith('.freezed.dart')) return false;
  // The repository-implementation layer is permitted to depend on the
  // data-access ring (AD-23: R --> A).
  if (p.contains(_repositoryDirSegment)) return false;
  return true;
}).toList();

/// Rule B scan set: every `.dart` file under `lib/domain/**`, generated
/// files included — no exemption may let a domain import through.
List<File> _domainFiles() => _dartFilesUnder('lib/domain');

/// Resolves a relative [uri] written in [filePath] (a `lib/...` path) to
/// its `package:learning_tracker/...` spelling, so relative and package
/// spellings of the same import are judged identically. Non-relative URIs
/// (`package:`, `dart:`) are returned unchanged.
String _canonicalUri(String filePath, String uri) {
  if (uri.contains(':')) return uri;
  final segments = filePath.split('/')..removeLast();
  for (final part in uri.split('/')) {
    if (part == '.' || part.isEmpty) continue;
    if (part == '..') {
      if (segments.isNotEmpty) segments.removeLast();
    } else {
      segments.add(part);
    }
  }
  if (segments.isNotEmpty && segments.first == 'lib') {
    return 'package:learning_tracker/${segments.skip(1).join('/')}';
  }
  return uri;
}

/// Returns [source] with every comment blanked out (newlines kept, so line
/// numbers are unchanged) while string literals — including triple-quoted
/// and raw strings — are copied through intact. A small lexer rather than a
/// regex: it drops `// import ...` lines and (nested) `/* ... */` blocks,
/// sees through an inline comment placed before a directive, and is not
/// fooled by `//` or `/*` appearing inside a string.
String _stripComments(String source) {
  final out = StringBuffer();
  final n = source.length;
  var i = 0;

  void blank(int from, int to) {
    for (var k = from; k < to; k++) {
      out.write(source[k] == '\n' ? '\n' : ' ');
    }
  }

  while (i < n) {
    final c = source[i];
    if (source.startsWith('//', i)) {
      final eol = source.indexOf('\n', i);
      final stop = eol == -1 ? n : eol;
      blank(i, stop);
      i = stop;
    } else if (source.startsWith('/*', i)) {
      var depth = 1;
      var j = i + 2;
      while (j < n && depth > 0) {
        if (source.startsWith('/*', j)) {
          depth++;
          j += 2;
        } else if (source.startsWith('*/', j)) {
          depth--;
          j += 2;
        } else {
          j++;
        }
      }
      blank(i, j);
      i = j;
    } else if (c == "'" || c == '"') {
      final raw = i > 0 && source[i - 1] == 'r';
      final quote = source.startsWith(c * 3, i) ? c * 3 : c;
      var j = i + quote.length;
      while (j < n && !source.startsWith(quote, j)) {
        if (!raw && source[j] == r'\' && j + 1 < n) {
          j += 2;
          continue;
        }
        if (quote.length == 1 && source[j] == '\n') break;
        j++;
      }
      if (j < n && source.startsWith(quote, j)) j += quote.length;
      out.write(source.substring(i, j));
      i = j;
    } else {
      out.write(c);
      i++;
    }
  }
  return out.toString();
}

/// Yields `(1-based line, directive text, canonical URI)` for every URI in
/// every import/export directive of [source].
Iterable<(int, String, String)> _directiveUris(
  String filePath,
  String rawSource,
) sync* {
  final source = _stripComments(rawSource);
  for (final d in _directive.allMatches(source)) {
    final line = '\n'.allMatches(source.substring(0, d.start)).length + 1;
    final text = d.group(0)!.trim().replaceAll(RegExp(r'\s+'), ' ');
    for (final u in _quotedUri.allMatches(d.group(1)!)) {
      yield (line, text, _canonicalUri(filePath, u.group(1)!));
    }
  }
}

String? _read(File file) {
  // A concurrently-running fixture-based test elsewhere in the suite may
  // delete its own scratch file between this scan's directory listing
  // and this read (TOCTOU) — skip rather than crash.
  try {
    return file.readAsStringSync();
  } on FileSystemException {
    return null;
  }
}

List<_Match> _findMatches() {
  final matches = <_Match>[];

  for (final file in _featureFiles()) {
    final path = _normalize(file.path);
    final source = _read(file);
    if (source == null) continue;
    for (final (line, text, uri) in _directiveUris(path, source)) {
      if (!uri.startsWith(_dataAccessRingImportPrefix)) continue;
      matches.add(_Match('AD-23 features->data/firestore', path, line, text));
    }
  }

  for (final file in _domainFiles()) {
    final path = _normalize(file.path);
    final source = _read(file);
    if (source == null) continue;
    for (final (line, text, uri) in _directiveUris(path, source)) {
      final family = domainForbiddenFamily(uri);
      if (family == null) continue;
      matches.add(_Match('AD-35 domain purity: $family', path, line, text));
    }
  }

  return matches;
}

void main(List<String> args) {
  final report = args.contains('--report');
  final matches = _findMatches();

  if (report) {
    for (final m in matches) {
      stdout.writeln(m);
    }
    stdout.writeln('--- ${matches.length} dependency-direction violation(s)');
    return;
  }

  if (matches.isNotEmpty) {
    final featureHits = matches.where((m) => m.rule.startsWith('AD-23'));
    final domainHits = matches.where((m) => m.rule.startsWith('AD-35'));
    stderr.writeln(
      'Dependency-direction check FAILED — ${matches.length} violation(s).',
    );
    if (featureHits.isNotEmpty) {
      stderr.writeln(
        '\n[AD-23, AD-28] ${featureHits.length} lib/features/** file '
        'import(s) of the data-access ring ($_dataAccessRingImportPrefix...) '
        'directly instead of depending on a repository interface. '
        'Dependencies flow only downward: Features --> Repositories --> '
        '{data-access ring, domain} — no edge may be added against the '
        'arrows. Route the dependency through a repository interface instead '
        '(or, if this file IS a repository implementation, move it under its '
        "feature's data/repositories/ directory, which this check exempts).",
      );
    }
    if (domainHits.isNotEmpty) {
      stderr.writeln(
        '\n[AD-35 domain purity] ${domainHits.length} lib/domain/** '
        'import(s) of a forbidden family '
        '(${domainForbiddenFamilies.map((f) => f.$1).join(', ')}). '
        'lib/domain/** is pure Dart: the learner-state engine must never '
        'depend on Firestore, Firebase, Flutter, Riverpod or the data layer. '
        'Pass the data in as plain values or declare a port under '
        'lib/domain/**/ports/ and implement it outside lib/domain/. There is '
        'no baseline and no generated-file exemption.',
      );
    }
    stderr.writeln('\nViolating site(s):');
    for (final m in matches) {
      stderr.writeln('  $m');
    }
    exit(1);
  }

  stdout.writeln(
    'Dependency-direction check passed — no lib/features/** file imports '
    'the data-access ring directly (AD-23/AD-28) and lib/domain/** is free '
    'of Firestore/Firebase/Flutter/Riverpod/data-layer imports (AD-35).',
  );
}

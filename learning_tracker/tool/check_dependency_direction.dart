/// AD-23 / AD-28 dependency-direction gate — no `lib/features/**` (outside
/// its own repository-implementation dirs) or `lib/domain/**` file imports
/// the data-access ring directly.
///
/// Story 2.6 (`docs/planning/epics-firestore-migration-phase0.md`). Binds
/// AD-23 ("dependencies flow only downward. No edge may be added against
/// the arrows." — `Features --> Repositories --> {Data-access ring, Domain}`,
/// never `Features --> Data-access ring` directly) and AD-28 ("AD-23
/// dependency direction: a grep/analyzer check that no `lib/features/**` or
/// `lib/domain/**` file imports the data-access ring past a repository
/// interface.").
///
/// ## What this catches
///
/// Any `lib/features/**/*.dart` file (that is NOT itself inside a
/// feature's own `data/repositories/` implementation directory — the
/// repository layer, `R` in the AD-23 diagram, is exactly the code
/// permitted to depend on the data-access ring, `A`) or any
/// `lib/domain/**/*.dart` file, that imports
/// `package:learning_tracker/data/firestore/...` — today's concrete
/// data-access ring (`doc_ids.dart`, `conflict.dart`, and whatever lands
/// there through the rest of the migration).
///
/// `lib/domain/**` does not exist yet as of Story 2.6 (Phase 1+ builds it
/// per the Structural Seed target tree) — scanning it now is a no-op that
/// becomes load-bearing the moment the directory appears, with no further
/// edit to this checker required.
///
/// ## Hard gate, not a ratchet
///
/// Unlike the MCF-11 and bare-instance checkers, this one starts at zero
/// confirmed sites on the Phase-0 tree (verified: no `lib/features/` file
/// outside `data/repositories/` imports `lib/data/firestore/` today, and
/// `lib/domain/` does not exist). AD-23's rule — "no edge may be added
/// against the arrows" — is a genuine zero-tolerance boundary going
/// forward, not a debt paydown, so this is a hard gate: any match fails the
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

/// The data-access ring feature/domain code must reach only through a
/// repository interface, never directly.
const _dataAccessRingImportPrefix = 'package:learning_tracker/data/firestore/';

/// Within `lib/features/`, a file under one of these path segments IS the
/// repository layer (`R` in the AD-23 diagram) — the one layer permitted to
/// depend on the data-access ring (`R --> A` is an allowed edge).
const _repositoryDirSegment = '/data/repositories/';

final _importLine = RegExp(r'''^\s*import\s+['"]([^'"]+)['"]''');

class _Match {
  _Match(this.path, this.line, this.snippet);
  final String path;
  final int line;
  final String snippet;

  @override
  String toString() => '$path:$line: $snippet';
}

List<File> _scanFiles() {
  final files = <File>[];
  for (final dirPath in const ['lib/features', 'lib/domain']) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) continue;
    files.addAll(
      dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.replaceAll(r'\', '/').endsWith('.dart'))
          .where((f) {
            final p = f.path.replaceAll(r'\', '/');
            if (p.endsWith('.g.dart') || p.endsWith('.freezed.dart')) {
              return false;
            }
            // The repository-implementation layer is permitted to depend
            // on the data-access ring (AD-23: R --> A).
            if (p.contains(_repositoryDirSegment)) return false;
            return true;
          }),
    );
  }
  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
}

List<_Match> _findMatches() {
  final matches = <_Match>[];
  for (final file in _scanFiles()) {
    final path = file.path.replaceAll(r'\', '/');
    // A concurrently-running fixture-based test elsewhere in the suite may
    // delete its own scratch file between this scan's directory listing
    // and this read (TOCTOU) — skip rather than crash.
    List<String> lines;
    try {
      lines = file.readAsLinesSync();
    } on FileSystemException {
      continue;
    }
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final m = _importLine.firstMatch(line);
      if (m == null) continue;
      final importUri = m.group(1)!;
      if (!importUri.startsWith(_dataAccessRingImportPrefix)) continue;
      matches.add(_Match(path, i + 1, line.trim()));
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
    stderr.writeln(
      'Dependency-direction check FAILED (AD-23, AD-28) — '
      '${matches.length} lib/features/**|lib/domain/** file(s) import the '
      'data-access ring ($_dataAccessRingImportPrefix...) directly instead '
      'of depending on a repository interface. Dependencies flow only '
      'downward: Features --> Repositories --> {data-access ring, domain} '
      '— no edge may be added against the arrows. Route the dependency '
      'through a repository interface instead (or, if this file IS a '
      'repository implementation, move it under its feature\'s '
      'data/repositories/ directory, which this check exempts).',
    );
    stderr.writeln('Violating site(s):');
    for (final m in matches) {
      stderr.writeln('  $m');
    }
    exit(1);
  }

  stdout.writeln(
    'Dependency-direction check passed — no lib/features/**|lib/domain/** '
    'file imports the data-access ring directly (AD-23/AD-28).',
  );
}

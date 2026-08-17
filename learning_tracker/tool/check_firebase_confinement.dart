/// AD-3 / AD-28 Firebase-confinement gate (Rule 3: "Firebase symbols
/// confined to core/ Firebase modules") — retargeted by Story 2.6.
///
/// Story 2.6 (`docs/planning/epics-firestore-migration-phase0.md`). Binds
/// AD-3 ("feature/service/provider files MUST NOT import `cloud_firestore`.
/// ... An import-boundary lint (CI gate) enforces the allowed-directory
/// list.") and AD-28 ("AD-3 import boundary: retarget the shipped
/// `no-firebase-outside-core` grep (DNI-387) from `lib/core/sync|auth` to
/// the new allowed-dir list `lib/data/firestore/**`,
/// `lib/data/repositories/**`; feature/service/provider files importing
/// `cloud_firestore` fail the gate.").
///
/// This is the single source of truth backing BOTH `make audit` checks
/// 1/15 and 2/15 — kept as one script (invoked with `--auth` or
/// `--storage`) instead of two independently hand-copied grep pipelines, to
/// avoid the exact "hand-copied predicate drift" class this repo's
/// architecture spine repeatedly warns about (AUD-t-cross-68).
///
/// ## `--auth`: no `package:firebase_auth` import outside the allow-list
///
/// Allow-list: `lib/core/auth/`, `lib/core/sync/` (retained legacy — see
/// below), `lib/features/auth/` (pre-existing, unrelated to this story's
/// AC correction, left as-is), `lib/data/firestore/`,
/// `lib/data/repositories/` (widened per AD-28).
///
/// ## `--storage`: no `FirebaseFirestore`/`FirebaseStorage`/`cloud_firestore`
/// symbol outside the allow-list
///
/// Allow-list: `lib/core/sync/`, `lib/core/auth/` (retained legacy — the
/// 12.2k-line pre-Phase-1 sync engine is not deleted until Phase 6),
/// `lib/data/firestore/`, `lib/data/repositories/` (widened per AD-28).
///
/// **The former blanket `lib/core/providers/` and `lib/features/`
/// carve-outs are RETIRED** (Story 2.6's AC correction) — a
/// feature/service/provider file importing `cloud_firestore` now actually
/// fails this gate, instead of being silently exempt. Comment-only lines
/// (doc-comment prose mentioning these symbols, e.g. "does not import
/// cloud_firestore directly") are excluded so the widened `lib/features/`
/// scan does not false-positive on prose.
///
/// **Known pre-existing offender, narrowly whitelisted (not fixed — out of
/// this story's scope to touch `lib/`):**
/// `lib/core/providers/firebase_providers.dart` imports
/// `package:firebase_storage` and calls `FirebaseStorage.instance` directly.
/// It was previously masked by the blanket `lib/core/providers/` carve-out
/// this story retires; Story 2.6 surfaced it, reported it, and did not fix
/// it (see the story's compact report). Tracked separately, not yet in this
/// gate.
///
/// Usage:
///   dart run tool/check_firebase_confinement.dart --auth
///   dart run tool/check_firebase_confinement.dart --storage
///   dart run tool/check_firebase_confinement.dart --auth --report
///   dart run tool/check_firebase_confinement.dart --storage --report
///
/// Exit codes:
///   0 — no violation found
///   1 — one or more violations found (prints the list)
library;

import 'dart:io';

const _authImportPattern = 'package:firebase_auth';

final _storagePattern = RegExp(
  r'\b(FirebaseFirestore|FirebaseStorage|firebase_firestore|firebase_storage|cloud_firestore)\b',
);

final _commentLine = RegExp(r'^\s*//');

/// The single pre-existing, narrowly-whitelisted offender surfaced by
/// retiring the `lib/core/providers/` blanket carve-out. See the file
/// doc-comment above.
const _storageWhitelistedFile = 'lib/core/providers/firebase_providers.dart';

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
  for (final dirPath in const ['lib', 'tool/lib']) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) continue;
    files.addAll(
      dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.replaceAll(r'\', '/').endsWith('.dart')),
    );
  }
  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
}

bool _underAny(String path, List<String> prefixes) =>
    prefixes.any((p) => path.startsWith(p) || path.contains('/$p'));

List<_Match> _findAuthMatches() {
  const allowed = [
    'lib/core/auth/',
    'lib/features/auth/',
    'lib/data/firestore/',
    'lib/data/repositories/',
  ];
  final matches = <_Match>[];
  for (final file in _scanFiles()) {
    final path = file.path.replaceAll(r'\', '/');
    if (path.endsWith('.g.dart') || path.endsWith('.freezed.dart')) continue;
    if (_underAny(path, allowed)) continue;
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
      if (lines[i].contains(_authImportPattern)) {
        matches.add(_Match(path, i + 1, lines[i].trim()));
      }
    }
  }
  return matches;
}

List<_Match> _findStorageMatches() {
  const allowed = [
    'lib/core/auth/',
    'lib/data/firestore/',
    'lib/data/repositories/',
  ];
  final matches = <_Match>[];
  for (final file in _scanFiles()) {
    final path = file.path.replaceAll(r'\', '/');
    if (path.endsWith('.g.dart')) continue;
    if (_underAny(path, allowed)) continue;
    if (path == _storageWhitelistedFile) continue;
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
      if (_commentLine.hasMatch(line)) continue;
      if (_storagePattern.hasMatch(line)) {
        matches.add(_Match(path, i + 1, line.trim()));
      }
    }
  }
  return matches;
}

void main(List<String> args) {
  final report = args.contains('--report');
  final auth = args.contains('--auth');
  final storage = args.contains('--storage');

  if (auth == storage) {
    stderr.writeln(
      'Usage: dart run tool/check_firebase_confinement.dart (--auth|--storage) [--report]',
    );
    exit(2);
  }

  final matches = auth ? _findAuthMatches() : _findStorageMatches();
  final label = auth
      ? 'firebase_auth import'
      : 'FirebaseFirestore/FirebaseStorage/cloud_firestore symbol';

  if (report) {
    for (final m in matches) {
      stdout.writeln(m);
    }
    stdout.writeln('--- ${matches.length} $label confinement violation(s)');
    return;
  }

  if (matches.isNotEmpty) {
    stderr.writeln(
      'Firebase-confinement check FAILED (AD-3, AD-28) — ${matches.length} '
      '$label site(s) found outside the allowed-dir list. Firebase symbols '
      'are confined to lib/core/auth/, lib/data/firestore/, and '
      'lib/data/repositories/ — a feature/service/provider file must '
      'depend on a repository interface instead of importing Firebase '
      'directly.',
    );
    stderr.writeln('Violating site(s):');
    for (final m in matches) {
      stderr.writeln('  $m');
    }
    exit(1);
  }

  stdout.writeln(
    'Firebase-confinement check ($label) passed — 0 violations (AD-3/AD-28).',
  );
}

/// AD-2 / AD-28 bare-Firebase-instance ratchet — flags a bare
/// `FirebaseFirestore.instance` / `FirebaseAuth.instance` singleton touch
/// outside the (not-yet-built) `AccountFirebase` registry.
///
/// Story 2.6 (`docs/planning/epics-firestore-migration-phase0.md`). Binds
/// AD-2 ("no service, repository, or feature may touch a bare
/// `FirebaseFirestore.instance` / `FirebaseAuth.instance`. All access
/// resolves through the active account's handle:
/// `accountFirebase(activeAccountId).firestore`... Exactly one place
/// (`AccountFirebase` registry) constructs and caches handles.") and AD-28
/// ("AD-2 bare-instance ban: a grep for `FirebaseFirestore.instance` /
/// `FirebaseAuth.instance` outside the `AccountFirebase` registry.").
///
/// ## What this catches
///
/// Any `FirebaseFirestore.instance` or `FirebaseAuth.instance` token in
/// `lib/**/*.dart`, on a line that is not itself a comment (so doc-comment
/// prose mentioning these symbols — e.g. "does not import cloud_firestore
/// directly" style notes — does not trip the gate).
///
/// ## The exempt path does not exist yet — that is by design
///
/// AD-1/AD-2/AD-18/AD-24 name a single `AccountFirebase` registry
/// (`lib/data/firestore/account_firebase.dart` per the Structural Seed
/// target tree in `ARCHITECTURE-SPINE.md`) as the ONE place permitted to
/// resolve Firebase handles — including, per AD-1, "the default app is
/// reserved for pre-auth/registry concerns only", which may legitimately
/// touch the bare singleton for the *default* (non-named) app case. Phase 0
/// does not build that registry (Phase 1 does — see the plan). This
/// checker's exempt-path constant is set to that future file path now, so
/// the gate is correct on day one of Phase 1 with zero further edits here.
/// Until that file exists, the exclusion is a no-op.
///
/// ## RATCHET, not a hard zero-tolerance gate
///
/// Same shape as `MCF-11 identity-safety ratchet`,
/// `check_r7_source_text_assertion_ratchet.dart`, and
/// `check_raw_color_literal_ratchet.dart`: today's tree already has 3
/// legitimate bare-instance sites in the still-live pre-Phase-1 sync/auth
/// engine (`lib/core/auth/firebase_auth_gateway_impl.dart`,
/// `lib/core/sync/providers/firestore_instance_provider.dart` x2) — that is
/// the CURRENT design, correct until the registry replaces it. Baselining
/// these is what makes `make audit` green today (nothing in the baseline is
/// NEW); the whole point of a standing ratchet is that it stops the count
/// from growing, not that it retroactively fixes Phase-0 debt in the same
/// change. The baseline COUNT is the pinned ceiling — maintainers burn it
/// down by routing a call site through `accountFirebase(...)` once the
/// registry lands, and re-run with `--update-baseline` to lock the win in;
/// it must never be raised to paper over a NEW site.
///
/// Usage:
///   dart run tool/check_bare_firebase_instance_ratchet.dart
///   dart run tool/check_bare_firebase_instance_ratchet.dart --report
///   dart run tool/check_bare_firebase_instance_ratchet.dart --update-baseline
///
/// Exit codes (ratchet mode):
///   0 — match count is at or below the tracked baseline
///   1 — match count exceeds the tracked baseline (prints the new list)
library;

import 'dart:io';

const _baselinePath = 'tool/bare_firebase_instance_baseline.txt';

/// The future `AccountFirebase` registry (Phase 1 — does not exist in
/// Phase 0). Carved out entirely, mirroring the MCF-11 checker's `merge/`
/// exemption, so this checker is correct on day one of Phase 1 without a
/// further edit.
const _exemptPath = 'lib/data/firestore/account_firebase.dart';

final _instanceToken = RegExp(
  r'\b(FirebaseFirestore|FirebaseAuth)\.instance\b',
);

final _commentLine = RegExp(r'^\s*//');

class _Match {
  _Match(this.path, this.line, this.snippet);
  final String path;
  final int line;
  final String snippet;

  @override
  String toString() => '$path:$line: $snippet';
}

List<File> _libFiles() {
  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    stderr.writeln('ERROR: lib/ not found — run from learning_tracker/.');
    exit(2);
  }
  return libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.replaceAll(r'\', '/').endsWith('.dart'))
      .where((f) {
        final p = f.path.replaceAll(r'\', '/');
        return !p.endsWith('.g.dart') &&
            !p.endsWith('.freezed.dart') &&
            p != _exemptPath &&
            !p.endsWith('/$_exemptPath');
      })
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

List<_Match> _findMatches() {
  final matches = <_Match>[];
  for (final file in _libFiles()) {
    final path = file.path.replaceAll(r'\', '/');
    // A concurrently-running fixture-based test elsewhere in the suite may
    // delete its own scratch file between this scan's directory listing
    // and this read (TOCTOU) — skip rather than crash; it was never a real
    // site if it no longer exists.
    List<String> lines;
    try {
      lines = file.readAsLinesSync();
    } on FileSystemException {
      continue;
    }
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (_commentLine.hasMatch(line)) continue;
      if (!_instanceToken.hasMatch(line)) continue;
      matches.add(_Match(path, i + 1, line.trim()));
    }
  }
  return matches;
}

int _readBaseline() {
  final file = File(_baselinePath);
  if (!file.existsSync()) return 0;
  final dataLine = file.readAsLinesSync().firstWhere(
    (l) => l.trim().isNotEmpty && !l.trim().startsWith('#'),
    orElse: () => '0',
  );
  return int.tryParse(dataLine.trim()) ?? 0;
}

void main(List<String> args) {
  final report = args.contains('--report');
  final updateBaseline = args.contains('--update-baseline');

  final matches = _findMatches();
  final actual = matches.length;

  if (report) {
    for (final m in matches) {
      stdout.writeln(m);
    }
    stdout.writeln('--- $actual bare-Firebase-instance site(s)');
    return;
  }

  if (updateBaseline) {
    File(_baselinePath).writeAsStringSync(
      '# AD-2 / AD-28 bare-Firebase-instance ratchet baseline — generated\n'
      '# by tool/check_bare_firebase_instance_ratchet.dart\n'
      '# --update-baseline. Tracks the count of confirmed bare\n'
      '# FirebaseFirestore.instance / FirebaseAuth.instance sites outside\n'
      '# the (Phase 1) AccountFirebase registry\n'
      '# (lib/data/firestore/account_firebase.dart). The number only goes\n'
      '# DOWN — lower it only by routing a site through\n'
      '# accountFirebase(activeAccountId) once the registry lands, or by\n'
      '# deleting dead code, never by raising it to paper over a NEW site.\n'
      '$actual\n',
    );
    stdout.writeln('Baseline updated to $actual.');
    return;
  }

  final baseline = _readBaseline();
  if (actual > baseline) {
    stderr.writeln(
      'Bare-Firebase-instance ratchet FAILED (AD-2, AD-28) — $actual '
      'bare FirebaseFirestore.instance/FirebaseAuth.instance site(s) '
      'found, up from the tracked baseline of $baseline. Every Firestore/'
      'Auth handle must resolve through the active account\'s '
      'AccountFirebase registry (accountFirebase(activeAccountId)), never '
      'a bare singleton — this is the historical uid-under-live-listeners '
      'PERMISSION_DENIED flood class. Route the new call site through the '
      'registry (or, until Phase 1 lands it, through the existing '
      'core/sync|auth injection point it will migrate to) instead of the '
      'bare singleton. If you deliberately closed an existing site and '
      'lowered the count, re-run with --update-baseline to lock the win '
      'in.',
    );
    stderr.writeln('New/still-present matching site(s):');
    for (final m in matches) {
      stderr.writeln('  $m');
    }
    exit(1);
  }

  stdout.writeln(
    'Bare-Firebase-instance ratchet passed — $actual site(s) '
    '(tracked baseline: $baseline, AD-2/AD-28).',
  );
}

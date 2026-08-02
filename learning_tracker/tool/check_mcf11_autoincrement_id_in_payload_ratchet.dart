/// MCF-11 / AD-5 landmine ratchet — device-local Drift autoincrement ids
/// embedded inside a synced payload, on paths outside `lib/core/sync/merge/`.
///
/// Story 2.4 (`docs/planning/epics-firestore-migration-phase0.md`). Binds
/// AD-5 ("no autoincrement id may appear inside any payload... An audit
/// sweeps for autoincrement-id-in-payload landmines outside merge/ (MCF-11
/// class) before cutover") and AD-28 ("the MCF-11 landmine sweep becomes a
/// standing grep gate — not a one-time audit").
///
/// ## What this catches
///
/// `lib/core/database/tables/{learner_profiles,curriculum_tracks,
/// accounts}.dart` define `id => integer().autoIncrement()()` — a per-device
/// SQLite counter with no cross-device meaning. `docs/planning/
/// drift-to-firestore-migration-baseline.md` (MCF-4, "Highest-leverage
/// structural fact") documents that these ids leak into synced payloads
/// under aliases (`profile_id`→`LearnerProfiles.id`, `track_id`→
/// `CurriculumTracks.id`, `account_id`→`Accounts.id`, `child_profile_id`→
/// `LearnerProfiles.id` again for tutor grants) and are only made safe by
/// remap logic living in `lib/core/sync/merge/` (`resolveLocalTrackId`,
/// `_resolveLocalAccountId`) — the exact "Bug 1" identity-remap defect that
/// once bounced a user to the first-launch splash screen.
///
/// This checker greps every `lib/**/*.dart` file OUTSIDE
/// `lib/core/sync/merge/` for a `Map` literal entry whose STRING KEY is one
/// of `track_id` / `trackId` / `account_id` / `accountId` /
/// `child_profile_id` / `childProfileId`, where the VALUE expression itself
/// names one of `trackId` / `accountId` / `childProfileId` or ends in a bare
/// `.id` access — i.e. the payload key is fed directly from the
/// corresponding autoincrement-typed model/row field.
///
/// `profile_id` / `profileId` is deliberately NOT a trigger key here (see
/// the sweep report, `docs/test-artifacts/mcf11-autoincrement-id-in-payload-
/// sweep.md`, "Scoping notes") — it is overwhelmingly used throughout the
/// app as a required scoping/routing parameter (DAO queries, log `fields:`,
/// path segments) rather than payload identity, and folding it in would
/// swamp the signal. `learner_profiles`' own doc-id/identity redesign is
/// AD-5's separate "profile-scoped stable key (ULID)" tracked item.
///
/// A `Map` literal that is the value of a `fields:` named parameter (this
/// codebase's `AppLogger` structured-logging convention, e.g.
/// `AppLogger.instance.warning(event: ..., fields: {'trackId': trackId})`)
/// is excluded — it is a diagnostic log payload, never written to Firestore.
///
/// ## RATCHET, not a hard zero-tolerance gate
///
/// Same shape as `check_r7_source_text_assertion_ratchet.dart` and
/// `check_raw_color_literal_ratchet.dart`: the sweep (see the report above)
/// found real, already-load-bearing sites — every `EntityCodec.encode()` in
/// `lib/core/sync/codec/` embeds `profile_id`, five of them also embed
/// `track_id`, `LearnerProfileCodec` embeds `account_id` — this is the
/// CURRENT sync engine's design, protected today only by the merge/ remap,
/// pending AD-25's canonical-stable-key redesign. Baselining these (and the
/// handful of other confirmed sites the report enumerates) is what makes
/// `make audit` "green... not yet tripping any real code" per the Story 2.4
/// AC: nothing in that baseline is NEW, and the whole point of a standing
/// gate is that it stops the count from growing, not that it retroactively
/// fixes Phase-0 debt in the same change. The baseline COUNT is the pinned
/// ceiling — maintainers burn it down by routing a site through the
/// canonical remap/codec layer (or removing dead code, e.g. a superseded
/// hand-copied serializer) and re-running with `--update-baseline`; it must
/// never be raised to paper over a NEW site.
///
/// Usage:
///   dart run tool/check_mcf11_autoincrement_id_in_payload_ratchet.dart
///   dart run tool/check_mcf11_autoincrement_id_in_payload_ratchet.dart --report
///   dart run tool/check_mcf11_autoincrement_id_in_payload_ratchet.dart --update-baseline
///
/// Exit codes (ratchet mode):
///   0 — match count is at or below the tracked baseline
///   1 — match count exceeds the tracked baseline (prints the new list)
library;

import 'dart:io';

const _baselinePath = 'tool/mcf11_autoincrement_id_in_payload_baseline.txt';

/// Directory prefix carved out entirely — the protected remap layer itself
/// is where these ids are legitimately consumed, not a landmine site.
const _exemptDirPrefix = 'lib/core/sync/merge/';

final _keyOpener = RegExp(
  r'''['"](track_id|trackId|account_id|accountId|child_profile_id|childProfileId)['"]\s*:\s*''',
);

/// A value expression that itself names the dangerous field, or ends in a
/// bare `.id` access (e.g. `profile.id`, `child.id`).
final _dangerousValue = RegExp(
  r'\b(trackId|accountId|childProfileId)\b|\.\s*id\b|^\s*id\s*$',
);

final _fieldsParamBefore = RegExp(r'\bfields\s*:\s*$');

/// Returns the text of the map-literal VALUE starting at [start] (just
/// after the matched key's `:`), ending at the first top-level `,` or `}` —
/// bracket-balance only (same rigor as `check_r7_source_text_assertion_
/// ratchet.dart`'s `_statementEnd`), good enough for well-formatted Dart.
String _valueSpan(String content, int start) {
  var depth = 0;
  var i = start;
  for (; i < content.length; i++) {
    final ch = content[i];
    if (ch == '(' || ch == '[' || ch == '{') {
      depth++;
    } else if (ch == ')' || ch == ']' || ch == '}') {
      if (depth == 0) break;
      depth--;
    } else if (ch == ',' && depth == 0) {
      break;
    }
  }
  return content.substring(start, i);
}

/// True when the `{` opening the map literal enclosing [keyMatchStart] is
/// itself the value of a `fields:` named parameter (this repo's AppLogger
/// structured-logging convention) — a diagnostic payload, not a Firestore
/// write.
bool _isLoggingFieldsMap(String content, int keyMatchStart) {
  var depth = 0;
  for (var i = keyMatchStart - 1; i >= 0; i--) {
    final ch = content[i];
    if (ch == '}') {
      depth++;
    } else if (ch == '{') {
      if (depth == 0) {
        final start = (i - 40).clamp(0, content.length);
        return _fieldsParamBefore.hasMatch(content.substring(start, i));
      }
      depth--;
    }
  }
  return false;
}

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
            !p.startsWith(_exemptDirPrefix) &&
            !p.contains('/$_exemptDirPrefix');
      })
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

List<_Match> _findMatches() {
  final matches = <_Match>[];
  for (final file in _libFiles()) {
    final path = file.path.replaceAll(r'\', '/');
    final content = file.readAsStringSync();
    for (final m in _keyOpener.allMatches(content)) {
      if (_isLoggingFieldsMap(content, m.start)) continue;
      final value = _valueSpan(content, m.end);
      if (!_dangerousValue.hasMatch(value.trim())) continue;
      final line = '\n'.allMatches(content.substring(0, m.start)).length + 1;
      final snippet = content
          .substring(m.start, m.end + value.length)
          .trim()
          .replaceAll(RegExp(r'\s+'), ' ');
      matches.add(_Match(path, line, snippet));
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
    stdout.writeln(
      '--- $actual autoincrement-id-in-payload site(s) outside merge/',
    );
    return;
  }

  if (updateBaseline) {
    File(_baselinePath).writeAsStringSync(
      '# MCF-11 / AD-5 autoincrement-id-in-payload ratchet baseline —\n'
      '# generated by\n'
      '# tool/check_mcf11_autoincrement_id_in_payload_ratchet.dart\n'
      '# --update-baseline. Tracks the count of confirmed sites outside\n'
      '# lib/core/sync/merge/ where a track_id/account_id/child_profile_id\n'
      '# payload key is fed directly from the corresponding device-local\n'
      '# Drift autoincrement field (docs/planning/drift-to-firestore-\n'
      '# migration-baseline.md MCF-4/MCF-11; docs/test-artifacts/\n'
      '# mcf11-autoincrement-id-in-payload-sweep.md). The number only goes\n'
      '# DOWN — lower it only by routing a site through the canonical\n'
      '# codec/remap layer or deleting dead code, never by raising it to\n'
      '# paper over a NEW site.\n'
      '$actual\n',
    );
    stdout.writeln('Baseline updated to $actual.');
    return;
  }

  final baseline = _readBaseline();
  if (actual > baseline) {
    stderr.writeln(
      'MCF-11 autoincrement-id-in-payload ratchet FAILED (AD-5, AD-28, '
      'docs/planning/drift-to-firestore-migration-baseline.md MCF-4/'
      'MCF-11) — $actual site(s) outside lib/core/sync/merge/ feed a '
      'track_id/account_id/child_profile_id payload key directly from a '
      'device-local Drift autoincrement field, up from the tracked '
      'baseline of $baseline. A device-local id has no meaning on another '
      'device — this is the identity-remap class that once bounced a '
      'user to the first-launch splash screen (Bug 1). Route the write '
      'through the canonical codec (lib/core/sync/codec/) or a '
      'lib/core/sync/merge/ remap instead of embedding the raw '
      'autoincrement value, or remove the site if it is dead code. If '
      'you deliberately closed an existing site and lowered the count, '
      're-run with --update-baseline to lock the win in.',
    );
    stderr.writeln('New/still-present matching site(s):');
    for (final m in matches) {
      stderr.writeln('  $m');
    }
    exit(1);
  }

  stdout.writeln(
    'MCF-11 autoincrement-id-in-payload ratchet passed — $actual site(s) '
    'outside merge/ (tracked baseline: $baseline, AD-5/AD-28, '
    'docs/test-artifacts/mcf11-autoincrement-id-in-payload-sweep.md).',
  );
}

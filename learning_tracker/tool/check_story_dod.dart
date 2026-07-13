/// Story Definition-of-Done checker — AUD-docs-24 (AG-9).
///
/// docs/coding-standards.md's AG-9 requires non-trivial agent changes to
/// carry verification evidence. AUD-docs-24 found 16 epic-21 stories under
/// `docs/stories/implementation/` carrying `Status: done` while every
/// Tasks/Subtasks checkbox is left unchecked (`- [ ]`, never `- [x]`) and
/// the Dev Agent Record section is the unfilled template stub (bare
/// `### Agent Model Used` / `### Completion Notes List` / `### Change Log`
/// headers, no content) — no verifiable completion trail a reviewer or
/// future incident investigator could check the "done" claim against,
/// unlike every other done/review story in the folder.
///
/// This is a RATCHET, not a full-repo hard-fail — the same shape as
/// `tool/check_test_mirroring.dart` (AG-5): rewriting the historical files
/// retroactively is out of scope (see AUD-docs-24's own recommendation,
/// "Not worth rewriting 16 historical files retroactively"). The
/// pre-existing backlog is captured in [_baseline] below; the checker
/// hard-fails only on a file NOT in that baseline that ships
/// `Status: done`/`review` with an unchecked Tasks/Subtasks line or an
/// empty Dev Agent Record — i.e. it stops the epic-21 pattern from
/// recurring (AUD-docs-24's acceptance criterion: "New stories merged
/// after this finding are not left with Status: done and a blank Dev
/// Agent Record") while leaving the historical backlog for a future,
/// dedicated backfill pass.
///
/// Scope: only `docs/stories/implementation/*.md` files using the plain
/// top-of-file `Status: <value>` line convention are scanned — the exact
/// convention AUD-docs-24's evidence files and their cited "good" siblings
/// (DNI-333/334/335/340/342/381, which carry a populated Dev Agent Record)
/// all use. A handful of files in the same directory use a different
/// `**Status:** value` / `## Status` convention (e.g. DNI-339, DNI-379,
/// DNI-380 — a separate, Epic-27 test-infrastructure documentation
/// lineage); AUD-docs-24 neither evidences nor discusses that convention,
/// so it is left alone here — a candidate follow-up, not this finding's
/// scope.
///
/// Usage (from `learning_tracker/`):
///   dart run tool/check_story_dod.dart            # ratchet check
///   dart run tool/check_story_dod.dart --report    # print full list, exit 0
///
/// Exit codes (ratchet mode):
///   0 — no non-baselined violation found
///   1 — one or more NEW violations found (prints file + reason)
library;

import 'dart:io';

/// Pre-existing backlog this checker tolerates (AUD-docs-24's own 16
/// evidence files, plus one file the AC's literal wording newly surfaces):
///
/// `16-1-pace-based-goal-mode.md` ships `Status: done` with 2 unchecked
/// Tasks/Subtasks lines — but unlike the epic-21 stub pattern, each is
/// individually annotated with a "— skipped (reason)" note, and the file
/// carries a fully populated Dev Agent Record (Agent Model Used, Debug Log
/// References, Completion Notes List, File List all filled in). A
/// materially different, far less severe case than epic-21's blank-stub
/// pattern, and out of AUD-docs-24's named scope to rewrite — captured
/// here so the ratchet does not retroactively fail on it.
///
/// Shrink this set as each file is backfilled with real verification
/// evidence; never add to it to paper over a NEW violation.
const _baseline = <String>{
  '16-1-pace-based-goal-mode.md',
  '21-1-device-account-registry.md',
  '21-2-per-account-database-isolation.md',
  '21-3-session-auto-resume.md',
  '21-4-session-persistence.md',
  '21-5-unified-signup-email-password.md',
  '21-6-unified-signup-google.md',
  '21-7-unified-signin-smart-routing.md',
  '21-8-unified-signin-google.md',
  '21-9-account-picker-screen.md',
  '21-10-signout-to-picker.md',
  '21-11-add-account-from-picker.md',
  '21-12-upgrade-multi-account.md',
  '21-13-remove-cloud-from-device.md',
  '21-14-delete-local-account.md',
  '21-15-delete-cloud-account-full.md',
  '21-16-cloud-function-deletion.md',
};

/// Relative to `learning_tracker/` (this script's assumed cwd — matches
/// every other `tool/check_*.dart` script, all run via `dart run
/// tool/check_*.dart` from `make audit`).
const _storiesDirPath = '../docs/stories/implementation';

final _statusLine = RegExp(r'^Status:\s*(\S+)', caseSensitive: false);
final _unchecked = RegExp(r'^\s*-\s*\[\s\]');
final _sectionHeader = RegExp(r'^##\s+');
final _tasksHeader = RegExp(r'^##\s+Tasks\b');
final _devAgentRecordHeader = RegExp(r'^##\s+Dev Agent Record\b');

class _Violation {
  _Violation(this.fileName, this.reasons);
  final String fileName;
  final List<String> reasons;
}

_Violation? _check(File file) {
  final lines = file.readAsLinesSync();

  String? status;
  for (final line in lines) {
    final m = _statusLine.firstMatch(line);
    if (m != null) {
      status = m.group(1)!.toLowerCase();
      break;
    }
  }
  if (status != 'done' && status != 'review') return null;

  // Locate "## Tasks" / "## Tasks / Subtasks" and scan for an unchecked
  // '- [ ]' line before the next '## ' section header.
  var taskStart = -1;
  for (var i = 0; i < lines.length; i++) {
    if (_tasksHeader.hasMatch(lines[i])) {
      taskStart = i + 1;
      break;
    }
  }
  var hasUnchecked = false;
  if (taskStart != -1) {
    for (var i = taskStart; i < lines.length; i++) {
      if (_sectionHeader.hasMatch(lines[i])) break;
      if (_unchecked.hasMatch(lines[i])) {
        hasUnchecked = true;
        break;
      }
    }
  }

  // Locate "## Dev Agent Record" and check whether it contains anything
  // besides blank lines and bare '###' subsection headers before the next
  // '## ' section header (or EOF). A missing section counts as empty too.
  var recordStart = -1;
  for (var i = 0; i < lines.length; i++) {
    if (_devAgentRecordHeader.hasMatch(lines[i])) {
      recordStart = i + 1;
      break;
    }
  }
  var recordEmpty = true;
  if (recordStart != -1) {
    for (var i = recordStart; i < lines.length; i++) {
      if (_sectionHeader.hasMatch(lines[i])) break;
      final trimmed = lines[i].trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith('###')) continue;
      recordEmpty = false;
      break;
    }
  }

  final reasons = <String>[];
  if (hasUnchecked) {
    reasons.add(
      "unchecked '- [ ]' line in Tasks/Subtasks while Status: $status",
    );
  }
  if (recordEmpty) {
    reasons.add(
      recordStart == -1
          ? 'no Dev Agent Record section at all while Status: $status'
          : 'Dev Agent Record section has only empty headers while '
                'Status: $status',
    );
  }
  if (reasons.isEmpty) return null;
  return _Violation(file.uri.pathSegments.last, reasons);
}

void main(List<String> args) {
  final report = args.contains('--report');
  final dir = Directory(_storiesDirPath);
  if (!dir.existsSync()) {
    stderr.writeln(
      'ERROR: $_storiesDirPath not found — run from the learning_tracker/ '
      'directory',
    );
    exit(2);
  }

  final mdFiles =
      dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.md'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final violations = <_Violation>[];
  for (final file in mdFiles) {
    final v = _check(file);
    if (v != null) violations.add(v);
  }

  if (report) {
    for (final v in violations) {
      stdout.writeln('${v.fileName}: ${v.reasons.join('; ')}');
    }
    stdout.writeln(
      '--- ${violations.length} docs/stories/implementation/*.md '
      'violation(s) total (AG-9)',
    );
    return;
  }

  final newViolations = violations
      .where((v) => !_baseline.contains(v.fileName))
      .toList();

  if (newViolations.isNotEmpty) {
    stderr.writeln(
      'AG-9 (docs/coding-standards.md) — a docs/stories/implementation/*.md '
      'file with Status: done/review must not ship an unchecked '
      'Tasks/Subtasks line or an empty Dev Agent Record (AUD-docs-24):',
    );
    for (final v in newViolations) {
      stderr.writeln('  ${v.fileName}: ${v.reasons.join('; ')}');
    }
    stderr.writeln(
      '\nEither check off the completed tasks and fill in the Dev Agent '
      'Record before merging Status: done/review, or if this is a '
      'deliberate, reviewed addition to the tracked historical backlog, '
      'add the file name to _baseline in tool/check_story_dod.dart (team '
      'sign-off required — this widens the ratchet).',
    );
    exit(1);
  }

  stdout.writeln(
    'AG-9 story-DoD ratchet OK: ${violations.length} violation(s), all '
    'within the tracked baseline (0 new).',
  );
}

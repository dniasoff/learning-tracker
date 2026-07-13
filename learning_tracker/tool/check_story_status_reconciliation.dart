/// Story-status reconciliation checker — AUD-docs-06.
///
/// `docs/status/sprint-status.yaml` is the tracker-of-record for epic/story
/// status; each story also carries its own `Status:` header in
/// `docs/stories/implementation/*.md`. When sprint-status.yaml says `done`
/// but the story file's own header still reads a template default
/// (`ready-for-dev`, `backlog`, `todo`, or `in-progress`), one of the two is
/// lying — either the story never actually shipped (sprint-status.yaml is
/// wrong) or the file just never got its Dev Agent Record backfilled
/// (harmless but confusing). AUD-docs-06's concrete case: 10 Epic-19 story
/// files sat at `Status: ready-for-dev` with blank Dev Agent Records while
/// sprint-status.yaml marked all of them `done` — one of them (19-10) turned
/// out to be genuinely incomplete (confirmed-dead code the story's own AC-4
/// says to delete was still present), not just an undocumented pass.
///
/// This is a **cheap, heuristic** Rule-0 doc-lint, not a full parser:
///   * Only top-level, non-epic story keys are read from sprint-status.yaml
///     (lines matching `  <key>: <status>` under the `# Epic N:` comment
///     blocks) — epic-level rows (`epic-N:`) and retrospective rows
///     (`epic-N-retrospective:`) are skipped.
///   * A story key maps to a file by exact filename match
///     (`docs/stories/implementation/<key>.md`). Keys with no matching file
///     are skipped — nothing to reconcile against.
///   * A MISMATCH is: sprint-status.yaml says `done` AND the file's own
///     `Status:` header is one of `ready-for-dev`/`backlog`/`todo`/
///     `in-progress` (the "still looks unstarted" bucket). `review`,
///     `superseded`, and `done` on the file side are treated as
///     already-concluded and NOT flagged — widening to those would surface
///     a much larger pre-existing backlog outside this finding's scope and
///     turn a precise doc-lint into noise.
///
/// Ratchet baseline: mismatches that predate/are outside AUD-docs-06's scope
/// are recorded in [_baselinePath] exactly like
/// `tool/check_stale_story_file_targets.dart`'s AG-5 ratchet — the check
/// fails only on a NEW mismatch, not on the pre-existing backlog.
///
/// Usage:
///   dart run tool/check_story_status_reconciliation.dart            # ratchet check
///   dart run tool/check_story_status_reconciliation.dart --report    # print all mismatches, exit 0
///   dart run tool/check_story_status_reconciliation.dart --update-baseline
///
/// Exit codes (ratchet mode):
///   0 — no NEW story-status mismatch found
///   1 — one or more NEW mismatches found (prints them)
library;

import 'dart:io';

/// Baseline of already-known mismatches (pre-existing backlog outside
/// AUD-docs-06's scope). See the file-level doc comment.
const _baselinePath = 'tool/story_status_reconciliation_baseline.txt';

/// File-side `Status:` values treated as "still looks unstarted" — a
/// mismatch when sprint-status.yaml says `done`.
const _unstartedStatuses = {'ready-for-dev', 'backlog', 'todo', 'in-progress'};

final _statusHeaderPattern = RegExp(r'^Status:\s*(.+?)\s*$', multiLine: true);
// Matches `  <key>: <value>` (two-space-indented story/epic rows), capturing
// the key and the value up to an optional trailing `#` comment.
final _yamlRowPattern = RegExp(
  r'^  ([a-zA-Z0-9][\w.-]*):\s*([a-zA-Z][\w-]*)',
);

class _Mismatch {
  _Mismatch({required this.storyKey, required this.yamlStatus, required this.fileStatus});

  final String storyKey;
  final String yamlStatus;
  final String fileStatus;

  /// Baseline key: `<storyKey>\t<fileStatus>`.
  String get key => '$storyKey\t$fileStatus';
}

Map<String, String> _readSprintStatusStories(String yamlContent) {
  final stories = <String, String>{};
  for (final line in yamlContent.split('\n')) {
    final match = _yamlRowPattern.firstMatch(line);
    if (match == null) continue;
    final key = match.group(1)!;
    final value = match.group(2)!;
    // Skip epic-level and retrospective rows — only per-story keys matter.
    if (key.startsWith('epic-')) continue;
    if (key.endsWith('-retrospective')) continue;
    stories[key] = value;
  }
  return stories;
}

String? _extractFileStatus(String content) {
  final match = _statusHeaderPattern.firstMatch(content);
  if (match == null) return null;
  return match.group(1)!.trim().toLowerCase();
}

Set<String> _readBaseline() {
  final file = File(_baselinePath);
  if (!file.existsSync()) return <String>{};
  return file
      .readAsLinesSync()
      .where((l) => l.trim().isNotEmpty && !l.trimLeft().startsWith('#'))
      .toSet();
}

void _writeBaseline(List<_Mismatch> mismatches) {
  final buffer = StringBuffer()
    ..writeln('# AUD-docs-06 story-status-reconciliation baseline — generated')
    ..writeln('# by tool/check_story_status_reconciliation.dart --update-baseline.')
    ..writeln('# Pre-existing backlog only. A NEW mismatch not listed here fails')
    ..writeln('# `make audit`. Burn this list down over time — do NOT add fresh')
    ..writeln('# entries to paper over a new mismatch.');
  for (final m in mismatches) {
    buffer.writeln(m.key);
  }
  File(_baselinePath).writeAsStringSync(buffer.toString());
}

void main(List<String> args) {
  final report = args.contains('--report');
  final updateBaseline = args.contains('--update-baseline');

  final yamlFile = File('../docs/status/sprint-status.yaml');
  final storiesDir = Directory('../docs/stories/implementation');
  if (!yamlFile.existsSync() || !storiesDir.existsSync()) {
    stderr.writeln(
      'ERROR: ../docs/status/sprint-status.yaml or '
      '../docs/stories/implementation not found — run from the '
      'learning_tracker/ directory',
    );
    exit(2);
  }

  final yamlStories = _readSprintStatusStories(yamlFile.readAsStringSync());

  final allMismatches = <_Mismatch>[];
  for (final entry in yamlStories.entries) {
    if (entry.value != 'done') continue; // only "done" claims are checked
    final storyFile = File('${storiesDir.path}/${entry.key}.md');
    if (!storyFile.existsSync()) continue; // nothing to reconcile against
    final fileStatus = _extractFileStatus(storyFile.readAsStringSync());
    if (fileStatus == null) continue;
    if (_unstartedStatuses.contains(fileStatus)) {
      allMismatches.add(
        _Mismatch(storyKey: entry.key, yamlStatus: entry.value, fileStatus: fileStatus),
      );
    }
  }
  allMismatches.sort((a, b) => a.storyKey.compareTo(b.storyKey));

  if (updateBaseline) {
    _writeBaseline(allMismatches);
    stdout.writeln(
      'Baseline updated: ${allMismatches.length} mismatch(es) recorded in '
      '$_baselinePath',
    );
    return;
  }

  if (report) {
    for (final m in allMismatches) {
      stdout.writeln(
        '${m.storyKey}: sprint-status.yaml says "${m.yamlStatus}" but the '
        'story file\'s own Status header says "${m.fileStatus}"',
      );
    }
    stdout.writeln('--- ${allMismatches.length} mismatch(es) total');
    return;
  }

  final baseline = _readBaseline();
  final newMismatches = allMismatches.where((m) => !baseline.contains(m.key)).toList();

  if (newMismatches.isNotEmpty) {
    stderr.writeln(
      'AUD-docs-06 story-status-reconciliation check FAILED — '
      'sprint-status.yaml marks a story "done" while its own Status header '
      'disagrees, not in the tracked baseline ($_baselinePath):',
    );
    for (final m in newMismatches) {
      stderr.writeln(
        '  ${m.storyKey}: yaml="${m.yamlStatus}" file="${m.fileStatus}"',
      );
    }
    stderr.writeln(
      '\nEither the story is genuinely incomplete (fix sprint-status.yaml to '
      'match reality, as AUD-docs-06 did for 19-10-navigation-state-cleanup), '
      'or the file\'s Status header + Dev Agent Record just needs backfilling '
      'to match the shipped reality — or, if this is a reviewed, deliberate '
      'pre-existing backlog entry, regenerate the baseline with `dart run '
      'tool/check_story_status_reconciliation.dart --update-baseline`.',
    );
    exit(1);
  }

  stdout.writeln(
    'AUD-docs-06 story-status-reconciliation check OK: '
    '${allMismatches.length} mismatch(es), all within the tracked baseline '
    '(0 new).',
  );
}

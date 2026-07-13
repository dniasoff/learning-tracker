/// Stale-story-target checker — AUD-docs-03.
///
/// A `docs/stories/implementation/*.md` story marked `Status: ready-for-dev`
/// (or `backlog`/`todo`) is presented as live, pickable backlog. Its
/// "Key Files" table names `lib/` files the story expects a developer to
/// modify/audit/verify. If the codebase has moved on and one of those files
/// no longer exists anywhere under `lib/` (deleted, not merely renamed —
/// AUD-docs-03's concrete case: `lib/features/sync/data/sync_engine.dart`,
/// deleted during the SyncOrchestrator+outbox rewrite, still targeted by
/// stories 19-8/19-9), a developer or agent that picks up the story burns a
/// cycle trying to resurrect deleted architecture.
///
/// This is a **cheap, heuristic** Rule-0 doc-lint (recommendation text,
/// AUD-docs-03), not a full parser:
///   * Only the `### Key Files` (or `## Key Files ...` / `#### Key Files
///     ...`) markdown table is read — the other "**File:**" inline markers
///     scattered through Tasks/Dev-Notes sections are not parsed (too
///     ambiguous whether they mean "modify" or "create").
///   * A row is in scope only if at least one backtick-quoted cell token
///     starts with `lib/` (checks run "against lib/", per the finding's
///     acceptance criteria — `test/`, `pubspec.yaml`, etc. are out of
///     scope).
///   * Rows whose Action column says "Create" or "Delete" are skipped: a
///     `Create` target is expected to be absent (it doesn't exist YET); a
///     `Delete` target being absent already just means the deletion already
///     happened (ahead of, not behind, the plan) — neither is the "prescribe
///     editing a resurrected deleted architecture" failure mode this check
///     exists to catch.
///   * A row is satisfied if ANY of its backtick-quoted tokens resolves,
///     either as an exact path (relative to `learning_tracker/`, the cwd
///     this script is run from) or by basename anywhere under `lib/`
///     (tolerates a file having moved/been renamed to a new directory,
///     which is normal refactor churn, not the deleted-architecture failure
///     mode). This also lets a row like
///     `` `lib/core/database/app_database.dart` (or `user_database.dart`) ``
///     resolve on its second alternative.
///
/// Ratchet baseline: some ready-for-dev stories unrelated to AUD-docs-03
/// already have stale-but-renamed-not-deleted targets (pre-existing drift,
/// e.g. 19-6's `connectivity_service.dart` — renamed to
/// `connectivity_gateway.dart`, a different basename the heuristic above
/// cannot bridge). Those are a known adjacent backlog, not this finding's
/// scope (AUD-docs-03 names only 19-8/19-9) — tracked in
/// [_baselinePath] exactly like `tool/check_test_mirroring.dart`'s AG-5
/// ratchet, so the check fails only on a NEW violation, not on the
/// pre-existing backlog.
///
/// Usage:
///   dart run tool/check_stale_story_file_targets.dart            # ratchet check
///   dart run tool/check_stale_story_file_targets.dart --report    # print all violations, exit 0
///   dart run tool/check_stale_story_file_targets.dart --update-baseline
///
/// Exit codes (ratchet mode):
///   0 — no NEW stale ready-for-dev/backlog/todo story target found
///   1 — one or more NEW violations found (prints them)
library;

import 'dart:io';

/// Baseline of already-known violations (the pre-existing backlog outside
/// AUD-docs-03's scope). See the file-level doc comment.
const _baselinePath = 'tool/story_stale_file_targets_baseline.txt';

/// Statuses that present a story as live, pickable backlog (per the
/// finding's "Tier-4 triage protocol: presents-as-current vs
/// point-in-time").
const _staleBackedStatuses = {'ready-for-dev', 'backlog', 'todo'};

final _statusPattern = RegExp(r'^Status:\s*(.+?)\s*$', multiLine: true);
final _keyFilesHeadingPattern = RegExp(
  r'^#{2,4}\s*Key Files\b.*$',
  multiLine: true,
);
final _headingPattern = RegExp(r'^#{1,6}\s', multiLine: true);
final _backtickPattern = RegExp('`([^`]+)`');

class _Violation {
  _Violation({
    required this.docFile,
    required this.primaryTarget,
    required this.action,
    required this.candidates,
  });

  final String docFile;
  final String primaryTarget;
  final String action;
  final List<String> candidates;

  /// Baseline key: `<docFile>\t<primaryTarget>`.
  String get key => '$docFile\t$primaryTarget';
}

String? _extractStatus(String content) {
  final match = _statusPattern.firstMatch(content);
  if (match == null) return null;
  return match.group(1)!.trim().toLowerCase();
}

/// Returns the raw text of the first `Key Files` table section, or null.
String? _extractKeyFilesSection(String content) {
  final headingMatch = _keyFilesHeadingPattern.firstMatch(content);
  if (headingMatch == null) return null;
  final start = headingMatch.end;
  final nextHeading = _headingPattern
      .allMatches(content, start)
      .where((m) => m.start >= start)
      .firstOrNull;
  final end = nextHeading?.start ?? content.length;
  return content.substring(start, end);
}

List<_Violation> _checkDoc(String docFile, String content, Directory libDir) {
  final status = _extractStatus(content);
  if (status == null || !_staleBackedStatuses.contains(status)) return [];

  final section = _extractKeyFilesSection(content);
  if (section == null) return [];

  final violations = <_Violation>[];

  for (final rawLine in section.split('\n')) {
    final line = rawLine.trim();
    if (!line.startsWith('|')) continue;
    // Header row (`| File | Action |`) and separator row (`|---|---|`).
    final cellsRaw = line.split('|');
    if (cellsRaw.length < 4) continue; // need leading/trailing empty + 2 cells
    final fileCell = cellsRaw[1].trim();
    final actionCell = cellsRaw.length > 2 ? cellsRaw[2].trim() : '';
    if (fileCell.replaceAll('-', '').trim().isEmpty) continue; // separator row
    if (fileCell.toLowerCase() == 'file') continue; // header row

    final tokens = _backtickPattern
        .allMatches(fileCell)
        .map((m) => m.group(1)!.trim())
        .toList();
    if (tokens.isEmpty) continue;

    final inScope = tokens.any((t) => t.startsWith('lib/'));
    if (!inScope) continue;

    final actionLower = actionCell.toLowerCase();
    if (RegExp(r'\bcreate\b').hasMatch(actionLower)) continue;
    if (RegExp(r'\bdelete\b').hasMatch(actionLower)) continue;

    final resolved = tokens.any((t) => _resolves(t, libDir));
    if (resolved) continue;

    violations.add(
      _Violation(
        docFile: docFile,
        primaryTarget: tokens.first,
        action: actionCell,
        candidates: tokens,
      ),
    );
  }

  return violations;
}

bool _resolves(String token, Directory libDir) {
  if (File(token).existsSync()) return true;
  final basename = token.split('/').last;
  if (basename.isEmpty) return false;
  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is! File) continue;
    if (entity.path.replaceAll(r'\', '/').split('/').last == basename) {
      return true;
    }
  }
  return false;
}

Set<String> _readBaseline() {
  final file = File(_baselinePath);
  if (!file.existsSync()) return <String>{};
  return file
      .readAsLinesSync()
      .where((l) => l.trim().isNotEmpty && !l.trimLeft().startsWith('#'))
      .toSet();
}

void _writeBaseline(List<_Violation> violations) {
  final buffer = StringBuffer()
    ..writeln('# AUD-docs-03 stale-story-file-target baseline — generated by')
    ..writeln('# tool/check_stale_story_file_targets.dart --update-baseline.')
    ..writeln(
      '# Pre-existing backlog only (stories NOT named by AUD-docs-03: 19-8',
    )
    ..writeln(
      '# and 19-9 were archived by that fix, so they never appear here). A',
    )
    ..writeln(
      '# NEW violation not listed here fails `make audit`. Burn this list',
    )
    ..writeln('# down over time — do NOT add fresh entries to paper over a');
  buffer.writeln('# new violation.');
  for (final v in violations) {
    buffer.writeln(v.key);
  }
  File(_baselinePath).writeAsStringSync(buffer.toString());
}

void main(List<String> args) {
  final report = args.contains('--report');
  final updateBaseline = args.contains('--update-baseline');

  final storiesDir = Directory('../docs/stories/implementation');
  final libDir = Directory('lib');
  if (!storiesDir.existsSync() || !libDir.existsSync()) {
    stderr.writeln(
      'ERROR: ../docs/stories/implementation or lib/ not found — run from '
      'the learning_tracker/ directory',
    );
    exit(2);
  }

  final mdFiles =
      storiesDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.md'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final allViolations = <_Violation>[];
  for (final file in mdFiles) {
    final docFile = file.path.split('/').last;
    final content = file.readAsStringSync();
    allViolations.addAll(_checkDoc(docFile, content, libDir));
  }

  if (updateBaseline) {
    _writeBaseline(allViolations);
    stdout.writeln(
      'Baseline updated: ${allViolations.length} violation(s) recorded in '
      '$_baselinePath',
    );
    return;
  }

  if (report) {
    for (final v in allViolations) {
      stdout.writeln(
        '${v.docFile}: [${v.action}] ${v.candidates.join(' / ')} — not '
        'found in lib/ (exact path or by basename)',
      );
    }
    stdout.writeln('--- ${allViolations.length} violation(s) total');
    return;
  }

  final baseline = _readBaseline();
  final newViolations = allViolations
      .where((v) => !baseline.contains(v.key))
      .toList();

  if (newViolations.isNotEmpty) {
    stderr.writeln(
      'AUD-docs-03 stale-story-file-target check FAILED — ready-for-dev/'
      'backlog/todo story references a Key Files target not found in lib/ '
      '(exact path or by basename), not in the tracked baseline '
      '($_baselinePath):',
    );
    for (final v in newViolations) {
      stderr.writeln(
        '  ${v.docFile}: [${v.action}] ${v.candidates.join(' / ')}',
      );
    }
    stderr.writeln(
      '\nEither the story is stale (archive it to docs/_archive/superseded/ '
      'or rewrite its Key Files table against the current architecture), '
      'or — if this is a reviewed, deliberate pre-existing backlog entry — '
      'regenerate the baseline with `dart run tool/'
      'check_stale_story_file_targets.dart --update-baseline`.',
    );
    exit(1);
  }

  stdout.writeln(
    'AUD-docs-03 stale-story-file-target check OK: ${allViolations.length} '
    'violation(s), all within the tracked baseline (0 new).',
  );
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

/// AUD-guardrails-10 companion checker — no basename collision with
/// diverging content between repo-root `tool/**` and `learning_tracker/tool/**`.
///
/// AUD-guardrails-10 found a root-level `tool/seed_content_db.dart` that was
/// a dead, non-compiling 242-line fragment — an orphaned fork of the real,
/// complete, actively-referenced `learning_tracker/tool/seed_content_db.dart`
/// (809 lines). Same basename, two directories, silently diverging content:
/// exactly the trap a human or agent falls into by opening the wrong file
/// from repo root and editing/trusting stale logic. That specific file has
/// been deleted (see AUD-guardrails-10 fix), but nothing previously stopped
/// a *new* same-basename fork from reappearing under either tree. This
/// checker is the acceptance_criteria[1] guard against recurrence.
///
/// Two files "collide" when they share a basename, one under repo-root
/// `tool/**` (`--dir-a`, default `../tool` relative to `learning_tracker/`)
/// and one under `learning_tracker/tool/**` (`--dir-b`, default `tool`).
/// A collision is a violation only when the two files' byte content
/// *diverges* — an intentional byte-identical copy is not itself a defect
/// this checker is scoped to flag.
///
/// Only executable/script files are compared ([_scriptExtensions]: dart,
/// py, js, mjs, sh, ps1, go) — the AUD-guardrails-10 defect shape is
/// specifically a *tool script* someone might `dart run`/execute believing
/// it is the canonical one. Generic filenames that legitimately recur by
/// convention in independent, unrelated subdirectories for non-executable
/// purposes (README.md inside three different sub-tool folders, go.mod,
/// package.json, a per-subtool main.py entry point, etc.) are not the
/// pattern this finding named and would otherwise drown the signal in
/// false positives — e.g. `tool/device_e2e/README.md` and
/// `learning_tracker/tool/curate_curricula/README.md` are two entirely
/// unrelated docs that happen to share the conventional name "README.md";
/// they are not a forked-tool defect.
///
/// This checker is a RATCHET, not a full-repo hard-fail: one pre-existing
/// diverging collision (`gen_arch_tables.dart` — the repo-root and
/// learning_tracker copies are independently-written scripts with the same
/// name and different implementations) predates AUD-guardrails-10, is not
/// named by it, and is out of this finding's scope per the audit engine's
/// scope-discipline rule. It is recorded in [_baselinePath] and tolerated,
/// tracked separately as a candidate follow-up finding. The gate only fails
/// when a NEW diverging basename collision appears that is not already in
/// the baseline — same shape as `tool/check_test_mirroring.dart` (AG-5) and
/// `tool/check_orphaned_screens.dart` (AUD-settings-08).
///
/// Usage (from `learning_tracker/`):
///   dart run tool/check_dup_tool_basename.dart                  # ratchet check
///   dart run tool/check_dup_tool_basename.dart --report          # list ALL diverging collisions, exit 0
///   dart run tool/check_dup_tool_basename.dart --dir-a <path> --dir-b <path> --baseline <path>
///     # test-only overrides so the regression test
///     # (test/tool/check_dup_tool_basename_test.dart) can exercise
///     # deliberately-broken fixtures without touching this repo's real
///     # tool/ directories.
///
/// Exit codes (ratchet mode):
///   0 — no NEW diverging basename collision outside the tracked baseline
///   1 — one or more NEW diverging collisions found (prints them)
library;

import 'dart:io';

/// Baseline of already-known diverging basename collisions (the pre-existing
/// backlog, keyed by basename). Maintainers burn this down by deleting or
/// consolidating the duplicate and removing the line, then re-running the
/// checker to confirm it drops out on its own — do NOT widen this list to
/// paper over a new violation.
const _baselinePath = 'tool/dup_tool_basename_baseline.txt';

const _defaultDirA = '../tool'; // repo-root tool/
const _defaultDirB = 'tool'; // learning_tracker/tool/

/// Extensions considered "tool scripts" for this checker — see the
/// library-level doc comment for why non-script files (README.md, go.mod,
/// package.json, ...) are deliberately excluded.
const _scriptExtensions = {'.dart', '.py', '.js', '.mjs', '.sh', '.ps1', '.go'};

class _Collision {
  _Collision(this.basename, this.pathA, this.pathB);

  final String basename;
  final String pathA;
  final String pathB;
}

/// Maps basename -> first file path found under [dirPath] (recursive).
Map<String, String> _filesByBasename(String dirPath) {
  final dir = Directory(dirPath);
  if (!dir.existsSync()) return const {};
  final map = <String, String>{};
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File) continue;
    final basename = entity.uri.pathSegments.last;
    final dotIndex = basename.lastIndexOf('.');
    if (dotIndex < 0) continue;
    final ext = basename.substring(dotIndex);
    if (!_scriptExtensions.contains(ext)) continue;
    map[basename] = entity.path;
  }
  return map;
}

bool _bytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

List<_Collision> _findDivergingCollisions(String dirA, String dirB) {
  final filesA = _filesByBasename(dirA);
  final filesB = _filesByBasename(dirB);
  final collisions = <_Collision>[];
  for (final entry in filesA.entries) {
    final pathB = filesB[entry.key];
    if (pathB == null) continue;
    final pathA = entry.value;
    final contentA = File(pathA).readAsBytesSync();
    final contentB = File(pathB).readAsBytesSync();
    if (!_bytesEqual(contentA, contentB)) {
      collisions.add(_Collision(entry.key, pathA, pathB));
    }
  }
  collisions.sort((a, b) => a.basename.compareTo(b.basename));
  return collisions;
}

Set<String> _readBaseline(String path) {
  final file = File(path);
  if (!file.existsSync()) return const {};
  return file
      .readAsLinesSync()
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.startsWith('#'))
      .toSet();
}

void main(List<String> args) {
  var dirA = _defaultDirA;
  var dirB = _defaultDirB;
  var baselinePath = _baselinePath;
  final report = args.contains('--report');
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--dir-a' && i + 1 < args.length) dirA = args[++i];
    if (args[i] == '--dir-b' && i + 1 < args.length) dirB = args[++i];
    if (args[i] == '--baseline' && i + 1 < args.length) {
      baselinePath = args[++i];
    }
  }

  final collisions = _findDivergingCollisions(dirA, dirB);

  if (report) {
    for (final c in collisions) {
      stdout.writeln('${c.basename}: ${c.pathA} <> ${c.pathB}');
    }
    stdout.writeln(
      '--- ${collisions.length} diverging basename collision(s) total',
    );
    return;
  }

  final baseline = _readBaseline(baselinePath);
  final newViolations = collisions
      .where((c) => !baseline.contains(c.basename))
      .toList();

  if (newViolations.isNotEmpty) {
    stderr.writeln(
      'AUD-guardrails-10 — NEW file basename shared between $dirA and $dirB '
      'with DIVERGING content, not in the tracked baseline ($baselinePath):',
    );
    for (final c in newViolations) {
      stderr.writeln('  ${c.basename}: ${c.pathA} <> ${c.pathB}');
    }
    stderr.writeln(
      '\nA duplicate script name across tool/** and learning_tracker/tool/** '
      'with different content is exactly how AUD-guardrails-10 happened — a '
      'human or agent opens the wrong copy and trusts stale logic. Delete or '
      'consolidate the duplicate. If this is a genuinely deliberate, '
      'reviewed, distinct-purpose pair (rare), add the basename to '
      '$baselinePath with a one-line reason instead of silencing this check.',
    );
    exit(1);
  }

  stdout.writeln(
    'check_dup_tool_basename ratchet OK: ${collisions.length} diverging '
    'collision(s), all within the tracked baseline (0 new).',
  );
}

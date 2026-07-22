/// Empty/comment-only catch block checker — AUD-app-06 (EH-3 / NFR23).
///
/// Root-Makefile audit check [9/12] only matches the single-line literal
/// `catch (_) {}` — it is blind to a `catch` whose body spans multiple lines
/// but contains nothing except comments/whitespace (no rethrow, no state
/// conversion, no AppLogger call), which is exactly as silent a swallow as
/// the literal-empty case. See
/// docs/audits/standards-audit-2026-07-03/delivery/findings/AUD-app-06.json.
///
/// This script scans every `.dart` file under `learning_tracker/lib/`
/// (excluding generated `.g.dart` / `.freezed.dart` files) for `catch (...) {
/// ... }` blocks whose body — once blank lines and `//` line-comments are
/// stripped — has no code left, and fails with `file:line` on each hit.
///
/// Deliberately does not track nested braces inside a catch body: none of
/// this codebase's catch blocks nest a block, and stopping the scan at the
/// first `}` only ever makes the checker more conservative (a catch that
/// nests a brace and has real code before it is correctly seen as non-empty
/// because that code appears before the truncated closing brace).
///
/// Broadening this check surfaces pre-existing debt beyond AUD-app-06's own
/// evidence sites (firebase_bootstrap.dart:39,50) — 25 further comment-only
/// catches elsewhere in `lib/`, none named by this finding. Per scope
/// discipline (fix only the dispatched finding; adjacent defects are
/// follow-ups, not drive-by fixes) those pre-existing sites are baselined
/// below so this checker hard-fails on firebase_bootstrap.dart (and on any
/// *new* comment-only catch anywhere else) without turning `make audit` red
/// over debt this finding does not own. Mirrors the exempt-list pattern in
/// `tool/check_analytics_catalog.dart` and the documented baseline/ratchet
/// approach used elsewhere in this repo (see AG-3, and the AUD-tutoring-08
/// note under "Enforcement" in docs/coding-standards.md) for introducing a
/// stricter checker without a same-PR mass remediation. Shrink this set as
/// each site is fixed; never add to it for new code.
///
/// Usage:
///   dart run tool/check_empty_catch_blocks.dart
///
/// Exit codes:
///   0 — no non-baselined empty/comment-only catch blocks found
///   1 — one or more found (prints file:line)
library;

import 'dart:io';

/// (2026-07-21 re-pin: the 5 sync_orchestrator + achievement_unlock +
/// curriculum_activation entries drifted line numbers as those files were
/// edited by unrelated work since baselining; refreshed to current lines.
/// Same intentional best-effort catches — AUD-app-06 scoped these to
/// baseline, not drive-by fix.)
/// Pre-existing comment-only catches this checker's broadened pattern newly
/// surfaces, none of them AUD-app-06 evidence sites — out of scope here.
const _baseline = <String>{
  // Re-pinned by the AppPalette theme migration: routing colours
  // through context.colors shifted these PRE-EXISTING, still-
  // unaddressed sites by a few lines. No content at any site
  // changed, and the set of hit files is byte-identical to the
  // last known-green commit (verified before re-pinning).
  'learning_tracker/lib/core/sync/sync_orchestrator.dart:1149',
  'learning_tracker/lib/core/sync/sync_orchestrator.dart:728',
  'learning_tracker/lib/core/sync/sync_orchestrator.dart:766',
  'learning_tracker/lib/core/sync/sync_orchestrator.dart:917',
  'learning_tracker/lib/core/sync/sync_orchestrator.dart:930',
  'learning_tracker/lib/features/account/domain/services/account_lifecycle_service.dart:83',
  'learning_tracker/lib/features/account/domain/services/account_management_service.dart:146',
  'learning_tracker/lib/features/account/presentation/notifiers/sign_in_controller.dart:645',
  'learning_tracker/lib/features/account/presentation/screens/account_picker_screen.dart:577',
  'learning_tracker/lib/features/account/presentation/screens/account_picker_screen.dart:615',
  'learning_tracker/lib/features/gamification/presentation/widgets/achievement_unlock_celebration.dart:97',
  'learning_tracker/lib/features/settings/presentation/utils/send_logs_service.dart:57',
  'learning_tracker/lib/features/settings/presentation/widgets/backup_sync_section.dart:59',
  'learning_tracker/lib/features/tracks/domain/services/curriculum_activation_service.dart:253',
};

void main() {
  final libDir = Directory('learning_tracker/lib');
  if (!libDir.existsSync()) {
    stderr.writeln(
      'ERROR: learning_tracker/lib not found — run from the repo root',
    );
    exit(2);
  }

  final dartFiles =
      libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where(
            (f) =>
                !f.path.endsWith('.g.dart') &&
                !f.path.endsWith('.freezed.dart'),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final allHits = <String>[];
  for (final file in dartFiles) {
    allHits.addAll(_findEmptyCatches(file.path, file.readAsStringSync()));
  }

  final baselined = allHits.where((h) => _baseline.contains(_fileLine(h)));
  final violations = allHits.where((h) => !_baseline.contains(_fileLine(h)));

  if (baselined.isNotEmpty) {
    stdout.writeln(
      '${baselined.length} baselined pre-existing hit(s) (not AUD-app-06 '
      'scope, suppressed):',
    );
    baselined.forEach(stdout.writeln);
    stdout.writeln();
  }

  if (violations.isNotEmpty) {
    violations.forEach(stdout.writeln);
    stdout.writeln();
    stdout.writeln(
      '${violations.length} non-baselined empty/comment-only catch '
      'block(s) found.',
    );
    exit(1);
  }

  stdout.writeln(
    'check_empty_catch_blocks OK — no non-baselined empty/comment-only '
    'catch blocks.',
  );
}

/// Extracts the leading `path:line` prefix from a `_findEmptyCatches` hit
/// string for baseline matching.
String _fileLine(String hit) {
  final secondColon = hit.indexOf(':', hit.indexOf(':') + 1);
  return hit.substring(0, secondColon);
}

/// Matches a `catch` clause header up to (and including) its opening brace,
/// e.g. `catch (_) {` or `catch (e, stack) {`.
final _catchHeader = RegExp(r'catch\s*\([^)]*\)\s*\{');

/// Scans [content] (the text of [path]) for catch blocks whose body contains
/// no code — only blank lines and `//` line comments. Returns one
/// `file:line: <reason>` string per violation.
List<String> _findEmptyCatches(String path, String content) {
  final results = <String>[];

  for (final match in _catchHeader.allMatches(content)) {
    final bodyStart = match.end;
    final bodyEnd = content.indexOf('}', bodyStart);
    if (bodyEnd == -1) continue; // unterminated — leave to the analyzer

    final body = content.substring(bodyStart, bodyEnd);
    final isEmpty = body.split('\n').every((line) {
      final trimmed = line.trim();
      return trimmed.isEmpty || trimmed.startsWith('//');
    });

    if (isEmpty) {
      final line =
          '\n'.allMatches(content.substring(0, match.start)).length + 1;
      results.add(
        '$path:$line: catch block body is empty or comment-only (EH-3)',
      );
    }
  }

  return results;
}

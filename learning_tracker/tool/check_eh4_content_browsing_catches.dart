/// EH-4 typed-catch checker for content_browsing — AUD-content_browsing-09.
///
/// `docs/coding-standards.md` EH-4 requires `catch` clauses to be typed
/// (`on <Type> catch`) rather than bare, so a programming-error `Error`
/// subtype (`TypeError`/`StateError`/`RangeError`/`NoSuchMethodError`)
/// propagates to the zone's uncaught-error handler instead of being folded
/// into an ordinary "operation failed" branch and swallowed forever.
///
/// Applies the same typed-catch rule as the retired core/sync check (AUD-core-sync-26), scoped to
/// this finding's own 4 files rather than sharing that checker's target
/// list — the project-wide `avoid_catches_without_on_clauses` /
/// `avoid_catching_errors` analyzer lints still cannot be flipped on
/// globally (~150 other bare `catch` sites remain outside both findings'
/// scope: `grep -rn '} catch (' lib/ | wc -l`).
///
/// Unlike AUD-core-sync-26 (which explicitly left wildcard `catch (_)`
/// sites out of scope), AUD-content_browsing-09 requires ALL of its 6
/// bare-catch sites — including the two `catch (_)` ones — to gain an `on`
/// clause. This checker therefore implements the finding's AC literally: a
/// bare `} catch (` (no preceding `on <Type> `) is a violation regardless
/// of whether the bound variable is named or `_`.
///
/// Usage:
///   dart run tool/check_eh4_content_browsing_catches.dart
///
/// Exit codes:
///   0 — no bare `} catch (` site remains in any target file.
///   1 — one or more bare `} catch (` sites remain (prints file:line).
library;

import 'dart:io';

/// The exact 4 files AUD-content_browsing-09 names. Deliberately NOT
/// `lib/`-wide — see the file doc comment above.
const _targetFiles = [
  'lib/features/content_browsing/presentation/screens/content_search_screen.dart',
  'lib/features/content_browsing/data/repositories/content_repository_impl.dart',
  'lib/features/content_browsing/presentation/screens/text_display_screen.dart',
  'lib/features/content_browsing/data/services/cloud_content_service.dart',
];

/// A bare (untyped) `catch` clause opens with `} catch (` — a typed one
/// reads `} on <Type> catch (` instead, so the literal substring `} catch (`
/// no longer appears once every site in a file is narrowed. This mirrors
/// the finding's own AC wording: "a grep-based Rule-0 check for '} catch ('
/// without a preceding 'on ' returns zero hits".
const _bareCatchNeedle = '} catch (';

void main() {
  final violations = <String>[];

  for (final relPath in _targetFiles) {
    final file = File(relPath);
    if (!file.existsSync()) {
      stderr.writeln(
        'ERROR: $relPath not found — run from the learning_tracker/ directory',
      );
      exit(1);
    }
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].contains(_bareCatchNeedle)) {
        violations.add('$relPath:${i + 1}: ${lines[i].trim()}');
      }
    }
  }

  if (violations.isNotEmpty) {
    stderr.writeln('EH-4 content_browsing typed-catch check FAILED:');
    for (final v in violations) {
      stderr.writeln(
        '  $v — bare catch with no `on <Type>` clause '
        '(AUD-content_browsing-09, EH-4).',
      );
    }
    exit(1);
  }

  stdout.writeln(
    'EH-4 content_browsing typed-catch check passed — no bare `} catch (` '
    'site remains in any of ${_targetFiles.length} target files '
    '(AUD-content_browsing-09).',
  );
}

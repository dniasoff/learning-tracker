/// AG-4 candidate Rule-0 checker — no duplicate public top-level class name
/// under test/features/notifications/.
///
/// AUD-t-notifications-03 found `notifications_screen_test.dart` and
/// `ws5_two_layers_test.dart` each independently declaring an identical
/// top-level `class MockNotificationGateway extends Mock implements
/// NotificationGateway {}`. Its acceptance criteria: "Only one
/// MockNotificationGateway declaration exists; both test files import it"
/// and "(Rule-0, Pending) AG-4 duplicate-symbol audit no longer lists
/// MockNotificationGateway as duplicated." Both files now import the single
/// definition in `test/features/notifications/support/
/// mock_notification_gateway.dart`.
///
/// Scope: every `*.dart` file under test/features/notifications/ — the
/// directory this finding's `normArea` (`tests/notifications`) names,
/// mirroring `tool/check_test_helpers_duplicate_functions.dart`'s
/// directory-scoped approach (AUD-t-cross-12, `test/helpers/`). A PUBLIC
/// top-level class (no leading underscore) declared in one file only
/// conflicts with another file's declaration of the SAME name when
/// imported together; a private (`_`) class is library-scoped and can
/// never collide across files, so it is excluded — this codebase has
/// several intentionally-duplicated private per-file fixture classes
/// (e.g. `_MockNotificationGateway`, `_ProfileId1`) that are not this
/// finding's concern.
///
/// This is a RATCHET, not a full-repo hard-fail — the same shape as
/// `tool/check_tq6_test_wall_clock.dart` (AUD-t-cross-84) and
/// `tool/check_notifications_sync_effect_overrides.dart`
/// (AUD-t-notifications-01): this checker's own first run surfaced the
/// SAME public `MockNotificationGateway` duplication, independently, in
/// two OTHER, unrelated pre-existing files —
/// `test/features/notifications/domain/services/streak_alert_service_test.dart`
/// and
/// `test/features/notifications/domain/services/notification_scheduler_test.dart`
/// — neither named by AUD-t-notifications-03's evidence (which cites only
/// `notifications_screen_test.dart` and `ws5_two_layers_test.dart`, both
/// fixed by the same commit as this checker). Deduplicating those two is a
/// drive-by, not this finding's job — tracked as a follow-up. Their
/// declarations are excluded from consideration via [_baseline] so the
/// gate fails only on a NEW duplicate outside that tolerated backlog, or on
/// the two files this finding just fixed regressing back to a local
/// declaration. Shrink [_baseline] as each file is burned down to import
/// the shared definition.
///
/// Usage:
///   dart run tool/check_notifications_duplicate_test_classes.dart
///
/// Exit codes (ratchet mode):
///   0 — no public top-level class name is defined in more than one
///       non-baselined file under test/features/notifications/
///   1 — one or more names collide outside [_baseline] (prints the
///       offending files:lines)
library;

import 'dart:io';

/// Pre-existing backlog this checker tolerates — discovered by this
/// checker's own first run (AUD-t-notifications-03), out of that finding's
/// named scope. Shrink this set as each file is burned down to import
/// `test/features/notifications/support/mock_notification_gateway.dart`
/// instead of redeclaring the class; never add to it to paper over a NEW
/// violation.
const _baseline = <String>{
  'test/features/notifications/domain/services/streak_alert_service_test.dart',
  'test/features/notifications/domain/services/notification_scheduler_test.dart',
};

/// Matches a top-level (column-0) `class Name` / `abstract class Name`
/// declaration. Deliberately does not match `mixin`/`enum` — this finding
/// is about a duplicated *class*.
final _topLevelClassDecl = RegExp(
  r'^(?:abstract\s+)?class\s+([A-Za-z_][A-Za-z0-9_]*)\b',
);

void main() {
  final dir = Directory('test/features/notifications');
  if (!dir.existsSync()) {
    stderr.writeln(
      'ERROR: test/features/notifications/ not found — run from '
      'learning_tracker/.',
    );
    exit(1);
  }

  final files =
      dir
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (f) =>
                f.path.endsWith('.dart') &&
                !f.path.endsWith('.g.dart') &&
                !f.path.endsWith('.freezed.dart'),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  // name -> [ "path:line", ... ] — non-baselined files only.
  final sitesByName = <String, List<String>>{};

  for (final file in files) {
    final path = file.path.replaceAll(r'\', '/');
    if (_baseline.contains(path)) continue;

    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final match = _topLevelClassDecl.firstMatch(lines[i]);
      if (match == null) continue;
      final name = match.group(1)!;
      if (name.startsWith('_')) continue; // private — no cross-file conflict
      sitesByName.putIfAbsent(name, () => []).add('$path:${i + 1}');
    }
  }

  final violations = <String>[];
  sitesByName.forEach((name, sites) {
    if (sites.length > 1) {
      violations.add('$name: ${sites.join(', ')}');
    }
  });
  violations.sort();

  if (violations.isNotEmpty) {
    stderr.writeln(
      'test/features/notifications/ duplicate top-level class check FAILED '
      '(AUD-t-notifications-03) — the same public top-level class name is '
      '(re)defined in more than one file under test/features/notifications/. '
      'Keep exactly one definition (see '
      'test/features/notifications/support/mock_notification_gateway.dart) '
      'and import it from the other file instead of redeclaring it:',
    );
    for (final v in violations) {
      stderr.writeln('  $v');
    }
    exit(1);
  }

  stdout.writeln(
    'test/features/notifications/ duplicate top-level class check passed — '
    'every public top-level class outside the ${_baseline.length} '
    'pre-existing baselined file(s) is defined in exactly one file.',
  );
}

/// TQ-6 Rule-0 checker — NotificationsScreen widget tests must override
/// the keepAlive sync-effect providers.
///
/// AUD-t-notifications-01 found `NotificationsScreen.build()`
/// unconditionally does `ref.watch(reminderSyncEffectProvider)` /
/// `ref.watch(streakAlertSyncEffectProvider)` — both `@Riverpod(keepAlive)`
/// `FutureProvider`s that chain into `notificationSchedulerProvider` ->
/// `sacredWindowRepositoryProvider` -> `userDatabaseProvider`, i.e. a real
/// `drift_flutter`-backed `UserDatabase` opened via
/// `driftDatabase(name: 'learning_tracker')`. Neither
/// `notifications_screen_test.dart` nor `ws5_two_layers_test.dart`
/// overrode these two effects, unlike
/// `notifications_screen_l1_test.dart` which does so explicitly "to
/// isolate the UI tests" (its own header comment). Running the unguarded
/// suite reproduced Drift's own runtime warning verbatim: "It looks like
/// you've created the database class UserDatabase multiple times... race
/// conditions will occur and might corrupt the database." Both files now
/// override `reminderSyncEffectProvider`/`streakAlertSyncEffectProvider`
/// with no-ops — this is the finding's own acceptance criterion: "any
/// widget test file that pumps NotificationsScreen must also override
/// both keepAlive sync-effect providers in the same overrides list."
///
/// Detection is per-file (not a precise "same ProviderScope.overrides
/// list" parse): a file "pumps NotificationsScreen" when it constructs
/// `NotificationsScreen(` outside of the widget's own definition file. It
/// "overrides both sync effects" when the file contains both
/// `reminderSyncEffectProvider.overrideWith(` and
/// `streakAlertSyncEffectProvider.overrideWith(` at least once. This
/// mirrors the file-granularity heuristic already used by
/// `tool/check_tq6_test_wall_clock.dart` and
/// `tool/check_test_stream_delay_race.dart`.
///
/// This is a RATCHET, not a full-repo hard-fail — the same shape as
/// `tool/check_test_mirroring.dart` (AG-5): AUD-t-notifications-01 names
/// only `notifications_screen_test.dart` and `ws5_two_layers_test.dart`
/// (now fixed, so they no longer trip this checker). A full-repo scan
/// surfaces the SAME missing-override shape in two other, unrelated
/// pre-existing files —
/// `test/features/notifications/presentation/screens/hot_streak_badge_visibility_test.dart`
/// and
/// `test/features/notifications/presentation/screens/notification_switch_a11y_test.dart`
/// — out of this finding's named scope (fixing them is a drive-by, not
/// this finding's job; tracked as a follow-up). Those files are captured
/// in [_baseline] below so the gate fails only on a NEW file introducing
/// the unguarded pump, or on one of the two files this finding just fixed
/// regressing, not on the pre-existing backlog. Shrink [_baseline] as each
/// is burned down to override both effects.
///
/// Usage:
///   dart run tool/check_notifications_sync_effect_overrides.dart
///
/// Exit codes (ratchet mode):
///   0 — no NEW (non-baselined) file under test/ pumps NotificationsScreen
///       without overriding both keepAlive sync-effect providers
///   1 — one or more such violations found in a file outside [_baseline]
///       (prints file:line)
library;

import 'dart:io';

/// Pre-existing backlog this checker tolerates — discovered by this
/// checker's own first run (AUD-t-notifications-01), out of that finding's
/// named scope (which is `notifications_screen_test.dart` and
/// `ws5_two_layers_test.dart`, both fixed by the same commit). Shrink this
/// set as each file is burned down to override both sync effects; never
/// add to it to paper over a NEW violation.
const _baseline = <String>{
  'test/features/notifications/presentation/screens/hot_streak_badge_visibility_test.dart',
  'test/features/notifications/presentation/screens/notification_switch_a11y_test.dart',
};

const _pumpPattern = 'NotificationsScreen(';
const _reminderOverride = 'reminderSyncEffectProvider.overrideWith(';
const _streakOverride = 'streakAlertSyncEffectProvider.overrideWith(';

/// The widget's own definition file — constructs itself via `class
/// NotificationsScreen extends ConsumerWidget`, not a pump site.
const _definitionFile =
    'lib/features/notifications/presentation/screens/notifications_screen.dart';

void main() {
  final testDir = Directory('test');
  if (!testDir.existsSync()) {
    stderr.writeln('ERROR: test/ not found — run from learning_tracker/.');
    exit(1);
  }

  final files =
      testDir
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

  final violations = <String>[];

  for (final file in files) {
    final path = file.path.replaceAll(r'\', '/');
    if (path == _definitionFile) continue;

    final lines = file.readAsLinesSync();
    final pumpLines = <int>[];
    var hasReminderOverride = false;
    var hasStreakOverride = false;

    for (var i = 0; i < lines.length; i++) {
      if (lines[i].contains(_pumpPattern)) pumpLines.add(i + 1);
      if (lines[i].contains(_reminderOverride)) hasReminderOverride = true;
      if (lines[i].contains(_streakOverride)) hasStreakOverride = true;
    }

    if (pumpLines.isEmpty) continue; // doesn't pump NotificationsScreen
    if (hasReminderOverride && hasStreakOverride) {
      continue; // both keepAlive sync effects are overridden
    }
    if (_baseline.contains(path)) continue; // tolerated pre-existing gap

    for (final line in pumpLines) {
      violations.add(
        '$path:$line: pumps NotificationsScreen() without overriding '
        'both reminderSyncEffectProvider and streakAlertSyncEffectProvider',
      );
    }
  }

  if (violations.isNotEmpty) {
    stderr.writeln(
      'NotificationsScreen sync-effect override check FAILED '
      '(AUD-t-notifications-01) — NotificationsScreen.build() '
      'unconditionally watches reminderSyncEffectProvider and '
      'streakAlertSyncEffectProvider, both @Riverpod(keepAlive) '
      'FutureProviders that chain into a real drift_flutter-backed '
      'UserDatabase. Any widget test that pumps NotificationsScreen must '
      'override BOTH with no-ops in the same ProviderScope.overrides list '
      '(see notifications_screen_l1_test.dart\'s _buildApp() for the '
      'pattern):',
    );
    for (final v in violations) {
      stderr.writeln('  $v');
    }
    exit(1);
  }

  stdout.writeln(
    'NotificationsScreen sync-effect override check passed — no NEW file '
    'under test/ pumps NotificationsScreen without overriding both '
    'keepAlive sync-effect providers (${_baseline.length} pre-existing '
    'baselined file(s) tolerated).',
  );
}

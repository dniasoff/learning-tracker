/// TQ-6 wall-clock checker — extends inner check 6 ("No DateTime.now()
/// outside core/time") from `lib/` to `test/`.
///
/// `docs/coding-standards.md`'s TQ-6 entry has read "[Enforced] inner check
/// 6 keeps `DateTime.now()` out of `lib/`. [Pending] extend to `test/`"
/// since the entry was authored (2026-07-02 rev). AUD-t-cross-84 found 29
/// wall-clock `DateTime.now()` calls stamping
/// createdAt/activatedAt/stateChangedAt across
/// `test/core/database/migration_test.dart`,
/// `test/core/database/schema_v1_smoke_test.dart`, and
/// `test/core/database/hebrew_migration_test.dart` — none of them driving a
/// date-boundary assertion today, so it was inert risk rather than an
/// active flake, but TQ-6 requires hermetic tests (fixed clock only) so a
/// later assertion added to one of those files can't silently start
/// comparing against a moving `now()` and flake near a UTC boundary under
/// CI's randomized test ordering. Those 3 files were fixed (fixed
/// `DateTime.utc(...)` constants, matching the pattern already used
/// elsewhere in `schema_v1_smoke_test.dart`) as part of the same finding —
/// this checker is the "extend to test/" half of the finding's acceptance
/// criteria.
///
/// This is a RATCHET, not a full-repo hard-fail — the same shape as
/// `tool/check_test_mirroring.dart` (AG-5) and
/// `tool/check_test_stream_delay_race.dart` (AUD-t-cross-36):
/// AUD-t-cross-84 names only the 3 files above (now fixed, so they no
/// longer trip this checker). A full-repo scan surfaces the SAME
/// wall-clock-in-test shape in 78 other, unrelated pre-existing test files
/// — out of this finding's scope (fixing them is a drive-by, not this
/// finding's job). Those files are captured in [_baseline] below so the
/// gate fails only on a NEW file introducing `DateTime.now(`, or on one of
/// the 3 files this finding just cleaned regressing, not on the
/// pre-existing backlog. Shrink [_baseline] as each is burned down to a
/// fixed clock / `clockProvider`.
///
/// Usage:
///   dart run tool/check_tq6_test_wall_clock.dart            # ratchet check
///   dart run tool/check_tq6_test_wall_clock.dart --report    # print all violations, exit 0
///
/// Exit codes (ratchet mode):
///   0 — no NEW (non-baselined) file under test/ calls `DateTime.now(`
///   1 — one or more such violations found in a file outside [_baseline]
///       (prints file:line)
library;

import 'dart:io';

/// Pre-existing backlog this checker tolerates — discovered by this
/// checker's own first run (AUD-t-cross-84), out of that finding's named
/// scope (which is the 3 `test/core/database/*.dart` files fixed by the
/// same commit). Shrink this set as each file is burned down to a fixed
/// clock / `clockProvider`; never add to it to paper over a NEW violation.
const _baseline = <String>{
  'test/core/analytics/streak_milestone_analytics_observer_test.dart',
  'test/core/database/daos/bookmark_dao_test.dart',
  'test/core/database/daos/completion_dao_test.dart',
  'test/core/database/daos/completion_event_dao_test.dart',
  'test/core/database/daos/curriculum_scope_dao_test.dart',
  'test/core/database/daos/goal_dao_test.dart',
  'test/core/database/daos/learning_ledger_dao_test.dart',
  'test/core/database/daos/point_config_dao_test.dart',
  'test/core/database/daos/profile_dao_test.dart',
  'test/core/database/daos/stage_dao_test.dart',
  'test/core/database/daos/track_dao_test.dart',
  'test/core/database/daos/track_scoped_dao_test.dart',
  'test/core/sync/merge/notification_settings_merger_test.dart',
  'test/core/sync/sync_orchestrator_test.dart',
  'test/core/utils/date_utils_test.dart',
  'test/features/account/domain/services/account_lifecycle_db_delete_test.dart',
  'test/features/account/domain/services/account_lifecycle_outbox_guard_test.dart',
  'test/features/account/presentation/providers/auth_state_init_exception_guard_test.dart',
  'test/features/dashboard/presentation/providers/dashboard_providers_test.dart',
  'test/features/dashboard/presentation/providers/dashboard_user_mode_test.dart',
  'test/features/gamification/domain/services/points_service_test.dart',
  'test/features/gamification/domain/services/streak_service_extended_test.dart',
  'test/features/gamification/domain/services/streak_service_recovery_test.dart',
  'test/features/gamification/domain/services/streak_service_test.dart',
  'test/features/gamification/presentation/providers/gamification_service_providers_test.dart',
  'test/features/learning/data/repositories/bookmark_repository_impl_test.dart',
  'test/features/learning/data/repositories/completion_repository_curriculum_dedup_test.dart',
  'test/features/learning/data/repositories/completion_repository_impl_test.dart',
  'test/features/learning/data/repositories/learning_ledger_repository_impl_test.dart',
  'test/features/learning/domain/use_cases/bulk_mark_completion_use_case_test.dart',
  'test/features/notifications/domain/services/notification_gateway_test.dart',
  'test/features/notifications/domain/services/streak_alert_service_test.dart',
  'test/features/notifications/presentation/providers/notification_providers_deep_test.dart',
  'test/features/onboarding/domain/services/bulk_prior_completion_service_test.dart',
  'test/features/onboarding/presentation/screens/onboarding_bulk_l1_test.dart',
  'test/features/parent_mode/child_mode_guard_test.dart',
  'test/features/progress/data/repositories/progress_repository_test.dart',
  'test/features/progress/recent_activity_and_hierarchy_panel_l1_test.dart',
  'test/features/settings/domain/services/account_management_service_test.dart',
  'test/features/settings/domain/services/curriculum_activation_service_test.dart',
  'test/features/settings/presentation/screens/aud_settings_02_no_latin_fragments_test.dart',
  'test/features/settings/presentation/widgets/backup_sync_section_l1_test.dart',
  'test/features/settings/settings_utils_test.dart',
  'test/features/sync/domain/models/sync_status_test.dart',
  'test/features/tracks/setup/presentation/screens/add_track_flow_screen_l1_test.dart',
  'test/features/tracks/setup/presentation/steps/step_starting_position_l1_test.dart',
  'test/features/tutoring/firestore_tutor_grant_repository_test.dart',
  'test/integration/stage_sync_test.dart',
  'test/scheduler/overdue_projection_test.dart',
  'test/story_acceptance/epic_01_foundation_test.dart',
  'test/story_acceptance/epic_02_content_test.dart',
  'test/story_acceptance/epic_03_learning_cycle_test.dart',
  'test/story_acceptance/epic_05_stages_order_test.dart',
  'test/story_acceptance/epic_06_scheduler_test.dart',
  'test/story_acceptance/epic_07_dashboard_test.dart',
  'test/story_acceptance/epic_08_gamification_test.dart',
  'test/story_acceptance/epic_09_onboarding_test.dart',
  'test/story_acceptance/epic_10_parent_mode_test.dart',
  'test/story_acceptance/epic_12_notifications_test.dart',
  'test/story_acceptance/epic_14_settings_test.dart',
  'test/story_acceptance/epic_15_multi_profile_test.dart',
  'test/story_acceptance/epic_16_pace_dashboard_test.dart',
  'test/story_acceptance/epic_25_schema_core_test.dart',
  'test/story_acceptance/regression_invariants_test.dart',
  'test/sync/tutored_listener_supervisor_test.dart',
  'test/sync/tutored_pull_isolation_test.dart',
  'test/track_setup/clear_overdue_button_test.dart',
};

const _wallClockCall = 'DateTime.now(';

void main(List<String> args) {
  final report = args.contains('--report');

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

  // path -> [ "path:line: <source line>", ... ]
  final violationsByFile = <String, List<String>>{};
  for (final file in files) {
    final path = file.path.replaceAll(r'\', '/');
    final lines = file.readAsLinesSync();
    final hits = <String>[];
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].contains(_wallClockCall)) {
        hits.add('$path:${i + 1}: ${lines[i].trim()}');
      }
    }
    if (hits.isNotEmpty) {
      violationsByFile[path] = hits;
    }
  }

  if (report) {
    for (final entry in violationsByFile.entries) {
      for (final v in entry.value) {
        stdout.writeln(v);
      }
    }
    stdout.writeln(
      '--- ${violationsByFile.length} file(s), '
      '${violationsByFile.values.fold<int>(0, (n, l) => n + l.length)} '
      'violation(s) total',
    );
    return;
  }

  final newViolationFiles =
      violationsByFile.keys.where((p) => !_baseline.contains(p)).toList()
        ..sort();

  if (newViolationFiles.isNotEmpty) {
    stderr.writeln(
      'TQ-6 test wall-clock check FAILED (AUD-t-cross-84) — a file under '
      'test/ calls DateTime.now(), a non-hermetic wall-clock read. TQ-6 '
      'requires tests use a fixed clock (a literal DateTime.utc(...) '
      'constant, or clockProvider/DateTimeFactory where the fixture is '
      'itself under test) so an assertion added later can\'t silently '
      'start comparing against a moving "now" and flake near a UTC '
      'boundary under CI\'s randomized test ordering. See '
      'test/core/database/schema_v1_smoke_test.dart for the fixed-constant '
      'pattern:',
    );
    for (final path in newViolationFiles) {
      for (final v in violationsByFile[path]!) {
        stderr.writeln('  $v');
      }
    }
    exit(1);
  }

  stdout.writeln(
    'TQ-6 test wall-clock check passed — no NEW file under test/ calls '
    'DateTime.now() (${_baseline.length} pre-existing baselined file(s) '
    'tolerated).',
  );
}

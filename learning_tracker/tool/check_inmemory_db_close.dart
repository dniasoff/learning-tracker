/// TQ-6 Rule-0 checker — every `inMemoryDb()`/`createTestUserDatabase()`
/// call site under test/ must have a matching `close()` reachable from the
/// same scope (AUD-t-gamification-04).
///
/// `test/helpers/drift_memory.dart`'s own doc comment on [inMemoryDb]
/// documents the contract: "Callers MUST `await db.close()` in `tearDown`
/// to free the native resources." Each call opens a real FFI-backed sqlite3
/// connection; skipping the close leaves it open until the test file's
/// isolate exits. AUD-t-gamification-04 found 7 call sites across the
/// gamification feature's tests that create a database via one of these two
/// factories but never close it — `ProviderContainer.dispose()` (which
/// those tests DO call in `addTearDown`) disposes Riverpod's providers, not
/// the raw `UserDatabase` object handed to `overrideWithValue`, so the
/// container teardown does not free the native resource.
///
/// A call site "has a matching close() reachable from the same scope" when,
/// within the nearest enclosing function-like body (a `test(`/
/// `testWidgets(` callback, or a named helper function/method — NOT a
/// bare `if`/`for`/`while`/`try`/`catch` control-flow block, since those
/// don't bound a callable scope on their own), there is either:
///   - `<var>.close(` on the variable the factory result was assigned to, or
///   - `addTearDown(<var>.close)` / `addTearDown(() => <var>.close())` /
///     `addTearDown(() async => ... <var>.close() ...)` referencing that
///     variable.
/// A factory call with no assigned variable at all (e.g. inlined directly
/// into `userDatabaseProvider.overrideWithValue(inMemoryDb())`) can never
/// satisfy this — there is no handle to close — so it is always a
/// violation.
///
/// This mirrors `tool/check_test_stream_delay_race.dart`'s scoped-window /
/// ratchet-baseline shape: AUD-t-gamification-04 names only 7 sites across
/// 4 gamification test files (now fixed — they no longer trip this
/// checker). Running this checker for real surfaces the SAME
/// creates-without-close shape in many other, unrelated test files —
/// pre-existing debt out of this finding's scope (fixing them is a
/// drive-by, not this finding's job). Those files are captured in
/// [_baseline] below so the gate fails only on a NEW file introducing this
/// pattern, not on the pre-existing backlog; shrink [_baseline] as each is
/// burned down.
///
/// Usage:
///   dart run tool/check_inmemory_db_close.dart            # ratchet check
///   dart run tool/check_inmemory_db_close.dart --report    # print all violations, exit 0
///
/// Exit codes (ratchet mode):
///   0 — no test file's violation count exceeds what is baselined for it in
///       [_baseline] (0 for an unbaselined file)
///   1 — one or more files exceed their baselined count (prints
///       file:line, and a per-file actual-vs-baselined summary)
library;

import 'dart:io';

/// Pre-existing backlog this checker tolerates — discovered by this
/// checker's own first run (AUD-t-gamification-04), out of that finding's
/// named scope (which is the 7 sites across 4 gamification test files
/// fixed alongside this checker, and which no longer appear here). Maps
/// file path -> the exact violation count tolerated in that file today. A
/// file's ACTUAL violation count exceeding its baselined count fails the
/// gate — this catches both a brand-new file introducing the pattern AND a
/// regression that reintroduces a violation at an already-baselined file
/// (e.g. reverting one of this finding's fixes bumps that file's count back
/// up past what's baselined). Shrink an entry (or remove it entirely) as
/// that file is burned down to close every
/// `inMemoryDb()`/`createTestUserDatabase()` it opens; never raise a count
/// to paper over a NEW violation.
const _baseline = <String, int>{
  'test/core/database/daos/active_curriculum_dao_test.dart': 1,
  'test/core/database/daos/bookmark_dao_extra_test.dart': 1,
  'test/core/database/daos/bookmark_dao_test.dart': 1,
  'test/core/database/daos/completion_dao_extended_test.dart': 1,
  'test/core/database/daos/completion_dao_extra_test.dart': 1,
  'test/core/database/daos/completion_dao_review_counts_test.dart': 1,
  'test/core/database/daos/completion_dao_test.dart': 1,
  'test/core/database/daos/completion_dao_tier_filter_test.dart': 1,
  'test/core/database/daos/completion_event_dao_test.dart': 1,
  'test/core/database/daos/curriculum_scope_dao_extra_test.dart': 1,
  'test/core/database/daos/curriculum_scope_dao_test.dart': 1,
  'test/core/database/daos/daily_plan_dao_test.dart': 1,
  'test/core/database/daos/goal_dao_extended_test.dart': 1,
  'test/core/database/daos/goal_dao_extra_test.dart': 1,
  'test/core/database/daos/goal_dao_test.dart': 1,
  'test/core/database/daos/learning_ledger_dao_extended_test.dart': 1,
  'test/core/database/daos/learning_ledger_dao_extra_test.dart': 1,
  'test/core/database/daos/learning_ledger_dao_test.dart': 1,
  'test/core/database/daos/learning_order_dao_extended_test.dart': 1,
  'test/core/database/daos/learning_order_dao_extra_test.dart': 1,
  'test/core/database/daos/learning_order_dao_test.dart': 1,
  'test/core/database/daos/outbox_dao_test.dart': 1,
  'test/core/database/daos/point_config_dao_test.dart': 1,
  'test/core/database/daos/points_balance_dao_test.dart': 1,
  'test/core/database/daos/prior_completion_import_dao_test.dart': 1,
  'test/core/database/daos/profile_dao_test.dart': 1,
  'test/core/database/daos/profile_program_dao_test.dart': 1,
  'test/core/database/daos/sacred_window_dao_test.dart': 1,
  'test/core/database/daos/stage_dao_extended_test.dart': 1,
  'test/core/database/daos/stage_dao_extra_test.dart': 1,
  'test/core/database/daos/stage_dao_test.dart': 1,
  'test/core/database/daos/streak_event_dao_test.dart': 1,
  'test/core/database/daos/study_day_config_dao_test.dart': 1,
  'test/core/database/daos/sync_kv_dao_test.dart': 1,
  'test/core/database/daos/text_download_status_dao_extended_test.dart': 1,
  'test/core/database/daos/text_download_status_dao_extra_test.dart': 1,
  'test/core/database/daos/text_download_status_dao_test.dart': 1,
  'test/core/database/daos/track_dao_deactivate_test.dart': 1,
  'test/core/database/daos/track_dao_delete_test.dart': 1,
  'test/core/database/daos/track_dao_extended_test.dart': 1,
  'test/core/database/daos/track_dao_extra_test.dart': 1,
  'test/core/database/daos/track_dao_last_curriculum_guard_test.dart': 1,
  'test/core/database/daos/track_dao_test.dart': 1,
  'test/core/database/daos/track_learning_order_dao_test.dart': 1,
  'test/core/database/daos/track_scoped_dao_test.dart': 1,
  'test/core/database/daos/user_profile_dao_extra_test.dart': 1,
  'test/core/database/daos/user_profile_dao_test.dart': 1,
  'test/core/database/user_database_companion_coverage_test.dart': 1,
  'test/core/database/user_database_dataclass_extended_test.dart': 1,
  'test/core/database/user_database_dataclass_test.dart': 1,
  'test/core/streak/streak_state_service_test.dart': 1,
  'test/core/sync/outbox/outbox_processor_test.dart': 1,
  'test/features/auth/domain/models/auth_state_test.dart': 1,
  'test/features/content_browsing/content_tile_search_providers_test.dart': 1,
  'test/features/dashboard/domain/services/dashboard_track_completion_migration_test.dart':
      1,
  'test/features/gamification/domain/services/reward_milestone_service_extended_test.dart':
      1,
  'test/features/gamification/domain/services/reward_milestone_service_test.dart':
      1,
  'test/features/gamification/domain/services/streak_service_extended_test.dart':
      1,
  'test/features/gamification/domain/services/streak_service_recovery_test.dart':
      1,
  'test/features/gamification/ga2_input_bounds_test.dart': 1,
  'test/features/gamification/ga3_duplicate_threshold_test.dart': 1,
  'test/features/gamification/presentation/providers/achievements_overview_provider_test.dart':
      2,
  'test/features/gamification/presentation/providers/reward_config_controller_test.dart':
      5,
  'test/features/gamification/presentation/screens/parent_pending_redemptions_screen_l1_test.dart':
      9,
  'test/features/gamification/presentation/screens/point_config_data_provider_purity_test.dart':
      1,
  'test/features/learning/data/repositories/completion_repository_streak_tee_test.dart':
      1,
  'test/features/notifications/data/services/sacred_window_repository_test.dart':
      1,
  'test/features/onboarding/domain/services/learning_process_wizard_service_test.dart':
      1,
  'test/features/parent_mode/domain/services/parent_dashboard_aggregator_extended_test.dart':
      1,
  'test/features/parent_mode/domain/services/parent_dashboard_aggregator_migration_test.dart':
      1,
  'test/features/progress/domain/services/chart_data_service_migration_test.dart':
      1,
  'test/features/progress/domain/services/chart_data_service_recent_activity_test.dart':
      1,
  'test/features/progress/domain/services/chart_data_service_test.dart': 1,
  'test/features/progress/domain/services/track_dual_progress_migration_test.dart':
      1,
  'test/features/progress/presentation/providers/curriculum_pace_status_provider_test.dart':
      6,
  'test/features/progress/presentation/providers/journey_providers_test.dart':
      3,
  'test/features/progress/presentation/providers/lifetime_knowledge_providers_test.dart':
      1,
  'test/features/progress/presentation/providers/pp4_lifetime_chazaros_count_test.dart':
      1,
  'test/features/progress/presentation/providers/recent_activity_reactivity_test.dart':
      1,
  'test/features/progress/presentation/providers/track_dual_progress_reactivity_test.dart':
      1,
  'test/features/progress/presentation/screens/curriculum_progress_screen_test.dart':
      1,
  'test/features/progress/presentation/screens/lifetime_knowledge_screen_test.dart':
      1,
  'test/features/progress/presentation/screens/recent_activity_screen_test.dart':
      1,
  'test/features/progress/presentation/screens/siyumim_milestones_screen_test.dart':
      1,
  'test/features/progress/recent_activity_and_hierarchy_panel_l1_test.dart': 3,
  'test/features/progress/siyumim_timeline_and_lifetime_providers_test.dart': 2,
  'test/features/scheduler/domain/study_day_chazara_gate_test.dart': 1,
  'test/features/scheduler/domain/study_day_toggle_write_test.dart': 1,
  'test/features/scheduler/domain/study_day_trackid_fallback_test.dart': 1,
  'test/features/scheduler/presentation/providers/scheduler_all_daily_tasks_test.dart':
      1,
  'test/features/scheduler/presentation/providers/scheduler_contiguous_overdue_no_gap_test.dart':
      1,
  'test/features/scheduler/presentation/providers/scheduler_providers_branches_test.dart':
      1,
  'test/features/scheduler/presentation/providers/scheduler_providers_test.dart':
      8,
  'test/features/scheduler/presentation/screens/study_day_config_screen_l1_test.dart':
      3,
  'test/features/scheduler/presentation/screens/study_day_config_screen_overflow_test.dart':
      1,
  'test/features/settings/domain/services/data_export_extended_test.dart': 1,
  'test/features/settings/domain/services/data_export_import_service_extra_test.dart':
      1,
  'test/features/settings/domain/services/data_export_import_service_import_test.dart':
      1,
  'test/features/settings/domain/services/data_export_roundtrip_test.dart': 1,
  'test/features/sync/data/local_data_upload_service_test.dart': 2,
  'test/features/sync/presentation/providers/sync_providers_test.dart': 1,
  'test/features/track_learning_order/data/repositories/track_learning_order_repository_impl_test.dart':
      1,
  'test/features/tracks/domain/services/track_progress_service_test.dart': 1,
  'test/features/tracks/setup/domain/services/track_creation_service_atomicity_test.dart':
      1,
  'test/features/tracks/setup/domain/services/track_creation_stage_seeding_test.dart':
      1,
  'test/features/tracks/setup/domain/services/track_study_days_and_scopes_dedup_test.dart':
      1,
  'test/features/tracks/setup/edit_track_screen_l1_test.dart': 1,
  'test/features/tracks/setup/presentation/screens/add_track_flow_screen_l1_test.dart':
      2,
  'test/features/tracks/setup/presentation/screens/edit_track_and_detail_l1_test.dart':
      1,
  'test/features/tracks/setup/presentation/screens/track_detail_goal_stale_test.dart':
      1,
  'test/features/tracks/setup/presentation/screens/track_detail_screen_test.dart':
      1,
  'test/features/tracks/setup/presentation/steps/goal_step_ts5_continue_overlap_test.dart':
      1,
  'test/features/tracks/setup/presentation/steps/starting_position_calendar_overflow_test.dart':
      1,
  'test/features/tracks/setup/presentation/steps/step_chazara_goal_l1_test.dart':
      1,
  'test/features/tracks/setup/presentation/steps/step_starting_position_l1_test.dart':
      6,
  'test/features/tracks/setup/track_management_hub_screen_l1_test.dart': 1,
  'test/features/tracks/track_management_body_and_order_l1_test.dart': 5,
  'test/features/tracks/track_order/presentation/track_learning_order_reset_test.dart':
      1,
  'test/features/tracks_studydays_and_content_hierarchy_l1_test.dart': 4,
  'test/features/tutoring/manage_grants_screen_l1_test.dart': 1,
  'test/integration/bypass_cleanup_offline_test.dart': 1,
  'test/overflow/overflow_guard_test.dart': 1,
  'test/story_acceptance/epic_19_offline_first_test.dart': 1,
  'test/story_acceptance/epic_25_story_22_firewall_test.dart': 2,
  'test/story_acceptance/epic_27_story_06_streak_reconciles_test.dart': 1,
  'test/story_acceptance/epic_27_story_27_8_rules_and_offline_flush_test.dart':
      1,
  'test/story_acceptance/epic_27_test_infrastructure_test.dart': 8,
  'test/story_acceptance/track_lifecycle_test.dart': 4,
  'test/sync/bookmark_outbox_entity_key_test.dart': 1,
  'test/sync/learner_profile_delete_enqueue_profile0_test.dart': 1,
  'test/sync/outbox_write_facade_live_profile_switch_test.dart': 1,
  'test/sync/study_day_config_sync_test.dart': 1,
  'test/sync/sync_orchestrator_drain_triggers_test.dart': 1,
  'test/sync/sync_orchestrator_profile0_status_test.dart': 1,
  'test/sync/sync_rework_curriculum_completion_doc_id_test.dart': 1,
  'test/sync/sync_rework_profile_programs_pull_test.dart': 1,
  'test/sync/sync_rework_push_test.dart': 2,
  'test/sync/sync_status_emission_test.dart': 1,
  'test/sync/track_delete_outbox_test.dart': 1,
  'test/sync/write_tee_status_update_test.dart': 1,
};

final _dbFactoryCall = RegExp(r'\b(inMemoryDb|createTestUserDatabase)\(\)');
// Matches `final x = inMemoryDb();` and `final x = someExpr ?? inMemoryDb();`
// alike — the factory call may be the whole RHS or the tail of a `??`
// fallback expression; either way the assignment target is what must be
// closed.
/// **Widened 2026-08-03, during the Drift→Firestore rewrite.** Previously
/// this only matched `final x = …` / `var x = …`, so the most common shape in
/// this suite — a `late UserDatabase db;` declared at `main()` scope and
/// assigned inside `setUp` — read as "no assigned variable at all" and was
/// reported as unclosable regardless of whether it was closed. That is why so
/// many files sit in [_baseline]: the checker never got as far as looking for
/// their `close()`.
///
/// Matching a bare `db = inMemoryDb();` makes the check STRICTER, not looser:
/// it can now actually evaluate those files, dropping the ones that do close
/// and still flagging the ones that don't. A factory call with genuinely no
/// assignment target (inlined straight into an argument) still matches
/// nothing here and is still an automatic violation — a test pins that.
final _assignedFactoryCall = RegExp(
  r'^\s*(?:(?:final|var)\s+)?(\w+)\s*=.*\b(?:inMemoryDb|createTestUserDatabase)\(\)',
);
final _controlFlowOpener = RegExp(
  r'^\s*(?:}?\s*(?:else\s+)?if|for|while|switch|try|catch|}?\s*else)\b',
);
final _funcLikeOpener = RegExp(r'\{\s*$');

void main(List<String> args) {
  final report = args.contains('--report');

  final testDir = Directory('test');
  if (!testDir.existsSync()) {
    stderr.writeln('ERROR: test/ not found — run from learning_tracker/.');
    exit(1);
  }

  final skipFiles = {
    'test/helpers/drift_memory.dart',
    'test/helpers/test_database.dart',
  };

  final files =
      testDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.replaceAll(r'\', '/').endsWith('.dart'))
          .where((f) => !skipFiles.contains(f.path.replaceAll(r'\', '/')))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final violationsByFile = <String, List<String>>{};
  for (final file in files) {
    final path = file.path.replaceAll(r'\', '/');
    final found = _checkFile(path, file.readAsLinesSync());
    if (found.isNotEmpty) {
      violationsByFile[path] = found;
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

  // A file fails only when its ACTUAL violation count exceeds what's
  // baselined for it (0 for a file with no baseline entry) — see the
  // [_baseline] doc comment for why this is count-based rather than a
  // simple "is this file in the set" check.
  final newViolationFiles =
      violationsByFile.keys
          .where((p) => violationsByFile[p]!.length > (_baseline[p] ?? 0))
          .toList()
        ..sort();

  if (newViolationFiles.isNotEmpty) {
    stderr.writeln(
      'In-memory DB close check FAILED (TQ-6, AUD-t-gamification-04) — a '
      'test file creates a UserDatabase via inMemoryDb()/'
      'createTestUserDatabase() without a matching close() reachable from '
      'the same scope (either "<var>.close(" or "addTearDown(<var>.close)" '
      'referencing the variable the factory result was assigned to, within '
      'the nearest enclosing test/helper function), and its violation count '
      'exceeds what is baselined (0 if unbaselined). '
      'ProviderContainer.dispose() does NOT close a raw UserDatabase handed '
      'to overrideWithValue — the native sqlite3 connection stays open '
      'until the isolate exits. Route the factory call through '
      'addTearDown(db.close) (see test/helpers/drift_memory.dart\'s doc '
      'comment on inMemoryDb):',
    );
    for (final path in newViolationFiles) {
      final baselined = _baseline[path] ?? 0;
      stderr.writeln(
        '  $path: ${violationsByFile[path]!.length} violation(s), '
        '$baselined baselined:',
      );
      for (final v in violationsByFile[path]!) {
        stderr.writeln('    $v');
      }
    }
    exit(1);
  }

  final baselineTotal = _baseline.values.fold<int>(0, (n, c) => n + c);
  stdout.writeln(
    'In-memory DB close check passed — no test file exceeds its baselined '
    'violation count (${_baseline.length} pre-existing file(s), '
    '$baselineTotal violation(s) total, tolerated).',
  );
}

/// Scans one file's lines for `inMemoryDb()`/`createTestUserDatabase()`
/// call sites lacking a matching close() in the nearest enclosing
/// function-like scope, and returns violation strings.
List<String> _checkFile(String path, List<String> lines) {
  final violations = <String>[];

  // Stack of function-like scope frames. Each frame tracks the variable
  // names created in it (with their creation line) and which of those
  // variable names have since been closed within this same frame (or a
  // nested control-flow block inside it — nested blocks are NOT separate
  // frames here, only function-like openers push a new frame).
  final frameVarsCreated = <List<MapEntry<String, int>>>[];
  final frameVarsClosed = <Set<String>>[];
  final depthStack = <int>[]; // brace depth at which each frame was opened
  var depth = 0;

  // Always have an implicit top-level frame so file-level helpers still
  // get tracked even before the first explicit function opener is seen.
  frameVarsCreated.add([]);
  frameVarsClosed.add({});
  depthStack.add(0);

  void closeVar(String varName) {
    for (var k = frameVarsClosed.length - 1; k >= 0; k--) {
      frameVarsClosed[k].add(varName);
    }
  }

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];

    // Whole-line `//` comments are excluded from factory-call/close
    // detection (but NOT from the brace-depth bookkeeping below, which
    // still runs on the raw line) — otherwise a doc comment that happens to
    // mention `inMemoryDb()`/`.close()` in prose (e.g. explaining the fix)
    // would be misread as code.
    final isCommentLine = line.trimLeft().startsWith('//');

    if (!isCommentLine) {
      // Record variable-name closes anywhere currently in scope (searched
      // top-down through the active frame stack so a close() inside a
      // nested control-flow block still credits the enclosing function
      // frame).
      final closeMatch = RegExp(r'(\w+)\s*\.\s*close\s*\(').allMatches(line);
      for (final m in closeMatch) {
        closeVar(m.group(1)!);
      }
      final tearDownMatch = RegExp(
        r'addTearDown\s*\(\s*(?:\(\)\s*(?:async\s*)?(?:=>)?\s*)?(\w+)\s*\.\s*close',
      ).allMatches(line);
      for (final m in tearDownMatch) {
        closeVar(m.group(1)!);
      }

      // Record creation sites.
      final assigned = _assignedFactoryCall.firstMatch(line);
      if (assigned != null) {
        frameVarsCreated.last.add(MapEntry(assigned.group(1)!, i));
      } else if (_dbFactoryCall.hasMatch(line)) {
        // Inlined with no variable to close — always a violation.
        violations.add(
          '$path:${i + 1}: inMemoryDb()/createTestUserDatabase() result is '
          'not assigned to a variable, so it can never be closed',
        );
      }
    }

    // Brace depth / frame bookkeeping — this must run AFTER the above scans
    // so a `close(`/creation call on the SAME line as a brace is still
    // attributed to the frame that is active for the rest of that line.
    final isFuncOpener =
        _funcLikeOpener.hasMatch(line) && !_controlFlowOpener.hasMatch(line);
    for (final ch in line.split('')) {
      if (ch == '{') {
        depth++;
      } else if (ch == '}') {
        if (depthStack.length > 1 && depth == depthStack.last) {
          // Popping a function-like frame: finalize violations for any
          // variable created in it that was never closed within it.
          final created = frameVarsCreated.removeLast();
          final closed = frameVarsClosed.removeLast();
          depthStack.removeLast();
          for (final entry in created) {
            if (!closed.contains(entry.key)) {
              violations.add(
                '$path:${entry.value + 1}: `${entry.key}` created here is '
                'never closed within its enclosing scope',
              );
            }
          }
        }
        depth--;
      }
    }
    if (isFuncOpener && depth > (depthStack.isEmpty ? -1 : depthStack.last)) {
      frameVarsCreated.add([]);
      frameVarsClosed.add({});
      depthStack.add(depth);
    }
  }

  // Any frames still open at EOF (malformed/edge case) — finalize them too
  // rather than silently dropping their violations.
  while (frameVarsCreated.length > 1) {
    final created = frameVarsCreated.removeLast();
    final closed = frameVarsClosed.removeLast();
    for (final entry in created) {
      if (!closed.contains(entry.key)) {
        violations.add(
          '$path:${entry.value + 1}: `${entry.key}` created here is never '
          'closed within its enclosing scope',
        );
      }
    }
  }
  final created = frameVarsCreated.removeLast();
  final closed = frameVarsClosed.removeLast();
  for (final entry in created) {
    if (!closed.contains(entry.key)) {
      violations.add(
        '$path:${entry.value + 1}: `${entry.key}` created here is never '
        'closed within its enclosing scope',
      );
    }
  }

  violations.sort();
  return violations;
}

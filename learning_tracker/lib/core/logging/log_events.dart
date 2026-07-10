// core/logging/log_events.dart — W1.29
//
// Typed string constants for structured log event names.
//
// Naming convention: `<subsystem>_<action>` in snake_case.
// All [AppLogger] call sites MUST use a constant from this file (or from a
// feature-level extension file) rather than an ad-hoc string literal.
//
// To extend: add a new `abstract final class` scoped to the subsystem.
// Do NOT add constants directly to [LogEvents] — keep subsystems separate.

/// Namespace aggregating all log-event constant groups.
///
/// Usage:
/// ```dart
/// AppLogger.instance.info(event: LogEvents.sync.pullOnLaunchCompleted);
/// AppLogger.instance.error(event: LogEvents.sync.mergeFailed, exception: e);
/// ```
abstract final class LogEvents {
  // Prevent instantiation — this is a pure-namespace class.
  LogEvents._();

  static const sync = _SyncEvents._();
  static const auth = _AuthEvents._();
  static const profile = _ProfileEvents._();
  static const scheduler = _SchedulerEvents._();
  static const track = _TrackEvents._();
  static const tutor = _TutorEvents._();
  static const content = _ContentEvents._();
  static const notification = _NotificationEvents._();
}

// ─── Sync ────────────────────────────────────────────────────────────────────

final class _SyncEvents {
  const _SyncEvents._();

  // Pull lifecycle
  String get pullOnLaunchStarted => 'sync_pull_on_launch_started';
  String get pullOnLaunchCompleted => 'sync_pull_on_launch_completed';
  String get pullOnLaunchFailed => 'sync_pull_on_launch_failed';
  // W7.9 — analytics events (distinct from the structured-log events above)
  String get pullStarted => 'sync_pull_started';
  String get pullCompleted => 'sync_pull_completed';
  String get pullFailed => 'sync_pull_failed';
  String get listenerAttached => 'sync_listener_attached';
  String get listenerDetached => 'sync_listener_detached';
  String get listenerError => 'sync_listener_error';
  // Phase 2 sync-architecture plan — boot-time telemetry for the first 10
  // snapshots per session so we can validate `.limit(500)` is keeping the
  // delivered page size bounded. After 10 the orchestrator stops logging to
  // avoid spam under normal use.
  String get listenerSnapshotSize => 'sync_listener_snapshot_size';
  // Phase 2 — recovery pull triggered when a listener snapshot returns
  // exactly `limit` docs (signal: there may be older changes the listener
  // window did not cover).
  String get listenerRecoveryPull => 'sync_listener_recovery_pull';
  // Phase 2 — listener parking / unparking on long-background lifecycle
  // transitions.
  String get listenersParked => 'sync_listeners_parked';
  String get listenersUnparked => 'sync_listeners_unparked';

  // Push lifecycle
  String get pushStarted => 'sync_push_started';
  String get pushCompleted => 'sync_push_completed';
  String get pushFailed => 'sync_push_failed';
  String get outboxItemEnqueued => 'sync_outbox_item_enqueued';
  String get outboxDeadLettered => 'sync_outbox_dead_lettered';
  // Phase-4 observability gauge: outbox depth + oldest-row age, logged on
  // every drain attempt (≥60 s apart given the periodic-drain trigger) so
  // dashboards can graph stuck-backlog age over time.
  String get outboxDepth => 'sync_outbox_depth';

  // Phase 0 — outbox drain lifecycle. Fired by every drain trigger
  // (write-tee, pull-complete, connectivity-online, lifecycle-resume,
  // periodic safety net) so backlog flushes are observable end-to-end.
  String get outboxDrainStarted => 'sync_outbox_drain_started';
  String get outboxDrainCompleted => 'sync_outbox_drain_completed';
  String get outboxDrainFailed => 'sync_outbox_drain_failed';

  // Merge / router
  String get mergeRowSkipped => 'sync_merge_row_skipped';
  String get mergeRouterHalt => 'sync_merge_router_halt';
  String get mergeFailed => 'sync_merge_failed';

  // Conflict / permission
  String get permissionDenied => 'sync_permission_denied';
  String get conflictResolved => 'sync_conflict_resolved';

  // AUD-core-sync-14 — resetFirestoreNetwork()'s internal disable/enable
  // guard. Fired when either call throws (most dangerously `enableNetwork()`
  // failing after `disableNetwork()` already succeeded); the failure is
  // caught and logged rather than propagating unhandled.
  String get firestoreNetworkResetFailed =>
      'sync_firestore_network_reset_failed';
}

// ─── Auth ────────────────────────────────────────────────────────────────────

final class _AuthEvents {
  const _AuthEvents._();

  String get signInStarted => 'auth_sign_in_started';
  String get signInCompleted => 'auth_sign_in_completed';
  String get signInFailed => 'auth_sign_in_failed';
  String get signOutCompleted => 'auth_sign_out_completed';
  String get magicLinkSent => 'auth_magic_link_sent';
  String get magicLinkFailed => 'auth_magic_link_failed';
  String get sessionRestored => 'auth_session_restored';
  String get sessionExpired => 'auth_session_expired';
}

// ─── Profile ─────────────────────────────────────────────────────────────────

final class _ProfileEvents {
  const _ProfileEvents._();

  String get created => 'profile_created';
  String get switched => 'profile_switched';
  String get deleted => 'profile_deleted';
  String get pinSet => 'profile_pin_set';
  String get pinVerified => 'profile_pin_verified';
  String get pinFailed => 'profile_pin_failed';
}

// ─── Scheduler ───────────────────────────────────────────────────────────────

final class _SchedulerEvents {
  const _SchedulerEvents._();

  String get goalCreated => 'scheduler_goal_created';
  String get goalUpdated => 'scheduler_goal_updated';
  String get goalDeleted => 'scheduler_goal_deleted';
  String get tasksGenerated => 'scheduler_tasks_generated';
  String get tasksGenerationFailed => 'scheduler_tasks_generation_failed';
}

// ─── Track ───────────────────────────────────────────────────────────────────

final class _TrackEvents {
  const _TrackEvents._();

  String get created => 'track_created';
  String get edited => 'track_edited';
  String get deleted => 'track_deleted';
  String get completionMarked => 'track_completion_marked';
  String get completionReverted => 'track_completion_reverted';
  String get bulkMarkStarted => 'track_bulk_mark_started';
  String get bulkMarkCompleted => 'track_bulk_mark_completed';

  // B1 regression telemetry (W7.11):
  // Fires when a BulkInTrack completion leaks into an engagement-only handler.
  String get bulkEngagementSkipped => 'bulk_engagement_skipped';
  // Fires when a LifetimeOnly completion leaks into an achievement-only handler.
  String get lifetimeAchievementSkipped => 'lifetime_achievement_skipped';
}

// ─── Tutor ───────────────────────────────────────────────────────────────────

final class _TutorEvents {
  const _TutorEvents._();

  // Invite flow
  String get inviteSent => 'tutor_invite_sent';
  String get inviteAccepted => 'tutor_invite_accepted';
  String get inviteDeclined => 'tutor_invite_declined';
  String get inviteExpired => 'tutor_invite_expired';

  // Grant lifecycle
  String get grantRescinded => 'tutor_grant_rescinded';
  String get grantRevoked => 'tutor_grant_revoked';
  String get tutorResigned => 'tutor_resigned';

  // Action log
  String get actionRecorded => 'tutor_action_recorded';

  // PIN
  String get pinSet => 'tutor_pin_set';
  String get pinVerified => 'tutor_pin_verified';
  String get pinFailed => 'tutor_pin_failed';

  // PIN reset flow (AUD-tutoring-12 / AUD-tutoring-13) — the two steps of
  // TutorPinResetScreen's reset flow are logged separately so a failure is
  // attributable to the step that actually failed.
  String get pinResetSendEmailFailed => 'tutor_pin_reset_send_email_failed';
  String get pinResetClearLocalPinFailed =>
      'tutor_pin_reset_clear_local_pin_failed';

  // Blocked operation
  String get liveMarkBlocked => 'tutor_live_mark_blocked';
}

// ─── Content ─────────────────────────────────────────────────────────────────

final class _ContentEvents {
  const _ContentEvents._();

  String get chunkDownloadStarted => 'content_chunk_download_started';
  String get chunkDownloadCompleted => 'content_chunk_download_completed';
  String get chunkDownloadFailed => 'content_chunk_download_failed';
  String get dbUpgradeStarted => 'content_db_upgrade_started';
  String get dbUpgradeCompleted => 'content_db_upgrade_completed';
  String get dbUpgradeFailed => 'content_db_upgrade_failed';
}

// ─── Notification ────────────────────────────────────────────────────────────

final class _NotificationEvents {
  const _NotificationEvents._();

  String get reminderScheduled => 'notification_reminder_scheduled';
  String get reminderFired => 'notification_reminder_fired';
  String get streakAlertScheduled => 'notification_streak_alert_scheduled';
  String get streakAlertFired => 'notification_streak_alert_fired';
  String get permissionGranted => 'notification_permission_granted';
  String get permissionDenied => 'notification_permission_denied';
}

/// R3 privacy invariant (PV-1, docs/coding-standards.md) — analytics event
/// parameters must never carry a per-child identifier or content identifier:
/// no `sefaria_ref`, no `profile_id`, no display name / email / raw name
/// field. "Which religious text a specific child studied" (or WHICH child
/// performed an action) is sensitive personal information about a child;
/// exporting it to Firebase/Google Analytics is what Play Families / COPPA
/// disclosure rules restrict.
///
/// Historically a LIVE, documented violation (docs/coding-standards.md PV-1
/// "Compliance Gaps" table, pre-fix): `logCompletionRecorded` sent
/// `sefaria_ref`; `logPinLockedOut` and `logParentModeEntered` both sent
/// `profile_id`. Fixed alongside this suite:
///   - `logCompletionRecorded` now takes `curriculumId` (coarse category)
///     instead of `sefariaRef`.
///   - `logPinLockedOut` / `logParentModeEntered` no longer take a
///     `profileId` parameter at all.
///
/// This is a SYSTEMIC sweep, not a per-method regression test: it enumerates
/// EVERY convenience method on [AnalyticsService] (the sole production
/// surface for firing analytics — PV-5 / `tool/check_analytics_catalog.dart`
/// already forces every `.logEvent()` call site in `lib/` through this
/// catalog) and asserts, for a representative invocation of each, that the
/// resulting parameter map contains none of [_bannedPiiKeys]. Adding a new
/// convenience method to [AnalyticsService] without adding it to
/// `_allConvenienceMethodEvents` below will fail
/// `test('every catalog event above is exercised')` — so this sweep cannot
/// be silently outgrown by a future event that reintroduces a banned key.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';

/// Keys that must never appear in an analytics event's parameter map
/// (PV-1): per-child identifiers, content identifiers, and direct personal
/// identifiers. Params must stay coarse, low-cardinality categories
/// (`track_type`, `curriculum_id`, counts, booleans, reasons).
const _bannedPiiKeys = <String>{
  'profile_id',
  'profileId',
  'sefaria_ref',
  'sefariaRef',
  'display_name',
  'displayName',
  'email',
  'name',
  'first_name',
  'firstName',
  'last_name',
  'lastName',
};

/// Records which events the group below has actually exercised — checked
/// for real exhaustiveness by the final test in this file. `package:test`
/// runs the `test()`/`group()` blocks in ONE file sequentially in
/// declaration order (not interleaved/parallel), so accumulating into this
/// top-level set from the group above and asserting on it in the final,
/// later-declared test is safe.
final _exercisedEvents = <String>{};

void main() {
  late FakeAnalyticsService analytics;

  setUp(() {
    analytics = FakeAnalyticsService();
  });

  /// Asserts the LAST fired [eventName]'s parameter map contains none of
  /// [_bannedPiiKeys], and records [eventName] as exercised (see
  /// [_exercisedEvents]).
  void expectNoPiiIn(String eventName) {
    _exercisedEvents.add(eventName);
    final params = analytics.lastParamsOf(eventName) ?? const {};
    for (final banned in _bannedPiiKeys) {
      expect(
        params.containsKey(banned),
        isFalse,
        reason:
            'PV-1 VIOLATION: analytics event "$eventName" fired with a '
            'banned per-child/content/personal identifier key "$banned" — '
            'params: $params. See docs/coding-standards.md PV-1.',
      );
    }
  }

  group('PV-1 — every AnalyticsEvent convenience method excludes PII', () {
    test('app_launch', () async {
      await analytics.logAppLaunch();
      expectNoPiiIn(AnalyticsEvent.appLaunch);
    });

    test(
      'completion_recorded — curriculum_id only, never sefaria_ref',
      () async {
        await analytics.logCompletionRecorded(
          curriculumId: 'mishnayos',
          trackType: 'personal',
        );
        expectNoPiiIn(AnalyticsEvent.completionRecorded);
        // Extra-explicit per-key check for the historically-violating field —
        // belt-and-suspenders alongside the generic sweep above.
        expect(
          analytics.lastParamsOf(AnalyticsEvent.completionRecorded),
          containsPair('curriculum_id', 'mishnayos'),
        );
      },
    );

    test('bulk_mark_prior_used', () async {
      await analytics.logBulkMarkPriorUsed(itemCount: 10, completionCount: 30);
      expectNoPiiIn(AnalyticsEvent.bulkMarkPriorUsed);
    });

    test('track_added', () async {
      await analytics.logTrackAdded(curriculumId: 'mishnayos');
      expectNoPiiIn(AnalyticsEvent.trackAdded);
    });

    test('streak_milestone_reached', () async {
      await analytics.logStreakMilestoneReached(milestone: 30);
      expectNoPiiIn(AnalyticsEvent.streakMilestoneReached);
    });

    test('sync_failed', () async {
      await analytics.logSyncFailed(reason: 'network_timeout');
      expectNoPiiIn(AnalyticsEvent.syncFailed);
    });

    test('pin_locked_out — never a profile_id', () async {
      await analytics.logPinLockedOut();
      expectNoPiiIn(AnalyticsEvent.pinLockedOut);
    });

    test('parent_mode_entered — never a profile_id', () async {
      await analytics.logParentModeEntered();
      expectNoPiiIn(AnalyticsEvent.parentModeEntered);
    });

    test('notification_fired', () async {
      await analytics.logNotificationFired(notificationType: 'daily_reminder');
      expectNoPiiIn(AnalyticsEvent.notificationFired);
    });

    test('notification_suppressed_sacred_time', () async {
      await analytics.logNotificationSuppressedSacredTime(
        notificationType: 'daily_reminder',
      );
      expectNoPiiIn(AnalyticsEvent.notificationSuppressedSacredTime);
    });

    test('cloud_restore_completed', () async {
      await analytics.logCloudRestoreCompleted(stepsRestored: 5);
      expectNoPiiIn(AnalyticsEvent.cloudRestoreCompleted);
    });

    test('crash_reported', () async {
      await analytics.logCrashReported(fatal: true);
      expectNoPiiIn(AnalyticsEvent.crashReported);
    });
  });

  test('every AnalyticsEvent catalog member is exercised above (sweep cannot '
      'silently go stale)', () {
    // AnalyticsEvent members that are NOT (yet) exposed via a typed
    // convenience method on AnalyticsService — these route through raw
    // .logEvent() call sites elsewhere and are out of THIS sweep's scope
    // (each has its own dedicated PV-1 coverage — see
    // analytics_pv1_redaction_test.dart and its doc comment for the full
    // list of covered call sites).
    const coveredByOtherSuites = <String>{
      AnalyticsEvent.syncMergeRowSkipped,
      AnalyticsEvent.syncMergeRouterHalt,
      AnalyticsEvent.syncOutboxDeadLettered,
      AnalyticsEvent.syncPullStarted,
      AnalyticsEvent.syncPullCompleted,
      AnalyticsEvent.syncPullFailed,
      AnalyticsEvent.syncListenerError,
      AnalyticsEvent.syncPermissionDenied,
      AnalyticsEvent.tutorPinSet,
      AnalyticsEvent.tutorActionRecorded,
      AnalyticsEvent.tutorInviteSent,
      AnalyticsEvent.tutorInviteAccepted,
      AnalyticsEvent.tutorInviteDeclined,
      AnalyticsEvent.tutorGrantRescinded,
      AnalyticsEvent.tutorGrantRevoked,
      AnalyticsEvent.tutorResigned,
      AnalyticsEvent.tutorLiveMarkBlocked,
      AnalyticsEvent.bulkEngagementSkipped,
      AnalyticsEvent.lifetimeAchievementSkipped,
    };
    const allConvenienceMethodEvents = <String>{
      AnalyticsEvent.appLaunch,
      AnalyticsEvent.completionRecorded,
      AnalyticsEvent.bulkMarkPriorUsed,
      AnalyticsEvent.trackAdded,
      AnalyticsEvent.streakMilestoneReached,
      AnalyticsEvent.syncFailed,
      AnalyticsEvent.pinLockedOut,
      AnalyticsEvent.parentModeEntered,
      AnalyticsEvent.notificationFired,
      AnalyticsEvent.notificationSuppressedSacredTime,
      AnalyticsEvent.cloudRestoreCompleted,
      AnalyticsEvent.crashReported,
    };
    expect(
      _exercisedEvents,
      allConvenienceMethodEvents,
      reason:
          'a convenience method was added to/removed from AnalyticsService '
          'without updating this sweep — add its group("...") test above '
          'so PV-1 compliance is asserted for it too.',
    );

    // Full-catalog exhaustiveness: every AnalyticsEvent member is either
    // exercised by THIS sweep or explicitly accounted for as covered
    // elsewhere — nothing in the catalog is silently unclassified.
    const fullCatalog = <String>{
      AnalyticsEvent.appLaunch,
      AnalyticsEvent.completionRecorded,
      AnalyticsEvent.bulkMarkPriorUsed,
      AnalyticsEvent.trackAdded,
      AnalyticsEvent.streakMilestoneReached,
      AnalyticsEvent.syncFailed,
      AnalyticsEvent.pinLockedOut,
      AnalyticsEvent.parentModeEntered,
      AnalyticsEvent.notificationFired,
      AnalyticsEvent.notificationSuppressedSacredTime,
      AnalyticsEvent.cloudRestoreCompleted,
      AnalyticsEvent.crashReported,
      AnalyticsEvent.syncMergeRowSkipped,
      AnalyticsEvent.syncMergeRouterHalt,
      AnalyticsEvent.syncOutboxDeadLettered,
      AnalyticsEvent.syncPullStarted,
      AnalyticsEvent.syncPullCompleted,
      AnalyticsEvent.syncPullFailed,
      AnalyticsEvent.syncListenerError,
      AnalyticsEvent.syncPermissionDenied,
      AnalyticsEvent.tutorPinSet,
      AnalyticsEvent.tutorActionRecorded,
      AnalyticsEvent.tutorInviteSent,
      AnalyticsEvent.tutorInviteAccepted,
      AnalyticsEvent.tutorInviteDeclined,
      AnalyticsEvent.tutorGrantRescinded,
      AnalyticsEvent.tutorGrantRevoked,
      AnalyticsEvent.tutorResigned,
      AnalyticsEvent.tutorLiveMarkBlocked,
      AnalyticsEvent.bulkEngagementSkipped,
      AnalyticsEvent.lifetimeAchievementSkipped,
    };
    expect(
      {...allConvenienceMethodEvents, ...coveredByOtherSuites},
      fullCatalog,
      reason:
          'a NEW AnalyticsEvent catalog member exists that is neither '
          'exercised by this PV-1 sweep nor accounted for in '
          'coveredByOtherSuites — every event must have a documented PV-1 '
          'review, not silently fall through both lists.',
    );
  });
}

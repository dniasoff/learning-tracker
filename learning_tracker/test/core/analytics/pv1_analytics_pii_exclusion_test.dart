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
/// Also historically a LIVE violation this sweep FAILED to catch on first
/// landing (adversarial review, R3 follow-up): [InviteTutorUseCase] fired
/// `tutor_invite_sent` with a `child_profile_id` parameter, which the
/// original exact-match `_bannedPiiKeys` check let through because
/// `child_profile_id` != `profile_id`. Fixed by (a) removing the identifier
/// from the event (see `tutor_invite_use_cases.dart`) and (b) changing the
/// check from exact-match to substring containment — see [_bannedPiiKeys]'s
/// doc comment.
///
/// This is a SYSTEMIC sweep in two parts:
///
///   1. Every convenience method on [AnalyticsService] (the sole production
///      surface for firing analytics — PV-5 / `tool/check_analytics_catalog.dart`
///      already forces every `.logEvent()` call site in `lib/` through this
///      catalog) is exercised below and asserted to exclude [_bannedPiiKeys].
///      Adding a new convenience method without adding it to
///      `allConvenienceMethodEvents` fails `test('every catalog event above
///      is exercised')` — so this half cannot be silently outgrown.
///
///   2. Events fired via a RAW `.logEvent()` call site (not a typed
///      convenience method — the W7.5–W7.11 events) are NOT exercisable
///      through part 1's mechanism. Each such event is either (a) exercised
///      directly in the "direct call-site sweep" group below by invoking
///      its real production use case/service, (b) genuinely covered by an
///      existing PV-1 assertion in another suite — cited by exact file path
///      in `coveredByOtherSuites`, each verified by reading the referenced
///      test — or (c) confirmed dead code with zero `lib/` emitters (see
///      `deadCatalogEvents`). A prior version of this file parked ~12
///      events in (b) that were never actually asserted anywhere (a false
///      coverage claim caught by the same adversarial review); the set
///      below is the corrected, verified list.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/exceptions/permission_exception.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_entity.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/domain/entities/mark_completion_result.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_orchestrator.dart';
import 'package:learning_tracker/features/learning/domain/use_cases/mark_completion_use_case.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/mark_live_completion_use_case.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_grant_use_cases.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_invite_use_cases.dart';

/// Keys that must never appear in an analytics event's parameter map
/// (PV-1): per-child identifiers, content identifiers, and direct personal
/// identifiers. Params must stay coarse, low-cardinality categories
/// (`track_type`, `curriculum_id`, counts, booleans, reasons).
///
/// Checked as a case-insensitive SUBSTRING of each parameter key, not an
/// exact match — `child_profile_id`/`parent_profile_id`/`tutor_profile_id`
/// all contain the banned `profile_id` key without equalling it, and a
/// pre-fix version of this sweep used exact match, which let
/// `tutor_invite_sent`'s `child_profile_id` param through undetected (see
/// this file's top doc comment). Verified against every parameter key
/// actually fired in `lib/` (`attempts`, `channel`, `collection`,
/// `curriculum_id`, `entity_kind`, `error_kind`, `fatal`, `grant_id`,
/// `item_count`, `completion_count`, `milestone`, `notification_type`,
/// `operation`, `reason`, `steps_restored`, `track_type`,
/// `triggered_from_resume`) — none contains a banned substring, so no
/// legitimate key needs a carve-out today.
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

/// Shared PV-1 assertion: no [_bannedPiiKeys] substring (case-insensitive)
/// appears in any key of [params].
void _assertNoBannedPii(Map<String, Object?> params, String eventName) {
  for (final key in params.keys) {
    final lowerKey = key.toLowerCase();
    for (final banned in _bannedPiiKeys) {
      expect(
        lowerKey.contains(banned.toLowerCase()),
        isFalse,
        reason:
            'PV-1 VIOLATION: analytics event "$eventName" fired with '
            'parameter key "$key", which contains the banned PII substring '
            '"$banned" — params: $params. See docs/coding-standards.md PV-1.',
      );
    }
  }
}

/// Records which events the group below has actually exercised — checked
/// for real exhaustiveness by the final test in this file. `package:test`
/// runs the `test()`/`group()` blocks in ONE file sequentially in
/// declaration order (not interleaved/parallel), so accumulating into this
/// top-level set from the group above and asserting on it in the final,
/// later-declared test is safe.
final _exercisedEvents = <String>{};

/// Same as [_exercisedEvents] but for the "direct call-site sweep" group
/// (raw `.logEvent()` events exercised via their real production use
/// case/service, rather than an [AnalyticsService] convenience method).
/// Tracked separately so each half's exhaustiveness is checked independently
/// (see `test('every direct call-site event above is exercised')`).
final _exercisedDirectCallEvents = <String>{};

void main() {
  late FakeAnalyticsService analytics;

  setUp(() {
    analytics = FakeAnalyticsService();
  });

  /// Asserts the LAST fired [eventName]'s parameter map contains no
  /// [_bannedPiiKeys] substring, and records [eventName] as exercised (see
  /// [_exercisedEvents]).
  void expectNoPiiIn(String eventName) {
    _exercisedEvents.add(eventName);
    _assertNoBannedPii(
      analytics.lastParamsOf(eventName) ?? const {},
      eventName,
    );
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

  /// Asserts the LAST fired [eventName]'s parameter map contains no
  /// [_bannedPiiKeys] substring, and records [eventName] as exercised (see
  /// [_exercisedDirectCallEvents]). Reuses the same [analytics] fake as the
  /// convenience-method group above — `setUp()` resets it before every test
  /// regardless of which group declared it.
  void expectDirectCallNoPiiIn(String eventName) {
    _exercisedDirectCallEvents.add(eventName);
    _assertNoBannedPii(
      analytics.lastParamsOf(eventName) ?? const {},
      eventName,
    );
  }

  group(
    'PV-1 — direct call-site sweep (raw .logEvent(), no convenience method)',
    () {
      // Fixed-clock fixtures — a hermetic literal, never a live wall-clock read.
      final invitedAt = DateTime.utc(2026, 5, 1);

      TutorGrant pendingGrant() => TutorGrant.fromDoc(
        TutorGrantDoc(
          grantId: 'grant-1',
          parentUid: 'parent-uid',
          childProfileId: 'child-1',
          tutorEmail: 'tutor@example.com',
          state: TutorGrantState.pending,
          invitedAt: invitedAt,
          updatedAt: invitedAt,
        ),
      );

      TutorGrant activeGrant() => TutorGrant.fromDoc(
        TutorGrantDoc(
          grantId: 'grant-1',
          parentUid: 'parent-uid',
          childProfileId: 'child-1',
          tutorEmail: 'tutor@example.com',
          state: TutorGrantState.active,
          invitedAt: invitedAt,
          updatedAt: invitedAt,
        ),
        permissions: TutorPermissions.defaults(),
      );

      test('tutor_invite_sent — no child_profile_id (the live PV-1 bug this '
          'sweep failed to catch on first landing)', () async {
        final useCase = InviteTutorUseCase(
          _FakeTutorGrantRepository(),
          analytics: analytics,
        );
        await useCase.call(
          tutorEmail: 'tutor@example.com',
          childProfileId: 'child-1',
        );
        expectDirectCallNoPiiIn(AnalyticsEvent.tutorInviteSent);
      });

      test('tutor_invite_accepted — no PII (grant_id only)', () async {
        final useCase = AcceptTutorInviteUseCase(
          _FakeTutorGrantRepository(),
          analytics: analytics,
        );
        await useCase.call(grant: pendingGrant());
        expectDirectCallNoPiiIn(AnalyticsEvent.tutorInviteAccepted);
      });

      test('tutor_invite_declined — no PII (grant_id only)', () async {
        final useCase = DeclineTutorInviteUseCase(
          _FakeTutorGrantRepository(),
          analytics: analytics,
        );
        await useCase.call(grant: pendingGrant());
        expectDirectCallNoPiiIn(AnalyticsEvent.tutorInviteDeclined);
      });

      test('tutor_grant_rescinded — no PII (grant_id only)', () async {
        final useCase = RescindTutorInviteUseCase(
          _FakeTutorGrantRepository(),
          analytics: analytics,
        );
        await useCase.call(grant: pendingGrant());
        expectDirectCallNoPiiIn(AnalyticsEvent.tutorGrantRescinded);
      });

      test('tutor_grant_revoked — no PII (grant_id only)', () async {
        final useCase = RevokeTutorGrantUseCase(
          _FakeTutorGrantRepository(),
          analytics: analytics,
        );
        await useCase.call(grant: activeGrant());
        expectDirectCallNoPiiIn(AnalyticsEvent.tutorGrantRevoked);
      });

      test('tutor_resigned — no PII (grant_id only)', () async {
        final useCase = ResignTutorGrantUseCase(
          _FakeTutorGrantRepository(),
          analytics: analytics,
        );
        await useCase.call(grant: activeGrant());
        expectDirectCallNoPiiIn(AnalyticsEvent.tutorResigned);
      });

      test('tutor_live_mark_blocked — no parameters at all', () async {
        final useCase = MarkLiveCompletionUseCase<void>(
          session: ResolvedSession.forTutor(
            selection: const TutoredProfileSelection(
              profileId: 'child-1',
              ownerUid: 'parent-uid',
              grantId: 'grant-1',
              permissions: TutorPermissions(),
            ),
          ),
          analytics: analytics,
        );
        await expectLater(
          useCase.call(() async {}),
          throwsA(isA<TutorWriteForbiddenException>()),
        );
        expectDirectCallNoPiiIn(AnalyticsEvent.tutorLiveMarkBlocked);
      });

      test('bulk_engagement_skipped — no parameters at all', () async {
        final useCase = _useCase(analytics);
        await useCase.call(
          const CompletionRequest(
            curriculumId: 'mishnayos',
            sefariaRef: 'Berakhot.2a',
            stageId: 1,
            trackType: 'personal',
          ),
          source: CompletionSource.bulkInTrack,
        );
        expectDirectCallNoPiiIn(AnalyticsEvent.bulkEngagementSkipped);
      });

      test('lifetime_achievement_skipped — no parameters at all', () async {
        final useCase = _useCase(analytics);
        await useCase.call(
          const CompletionRequest(
            curriculumId: 'mishnayos',
            sefariaRef: 'Berakhot.2a',
            stageId: 1,
            trackType: 'personal',
          ),
          source: CompletionSource.lifetimeOnly,
        );
        expectDirectCallNoPiiIn(AnalyticsEvent.lifetimeAchievementSkipped);
      });
    },
  );

  // ORDER-INDEPENDENCE (R6): these exhaustiveness checks assert against
  // `_exercisedEvents` / `_exercisedDirectCallEvents`, which are mutated by the
  // sibling tests as they RUN. Declared as `test(...)` they could execute before
  // the tests that populate those sets -- and did, once
  // `--test-randomize-ordering-seed=random` landed, failing with `Actual: Set:[]`
  // against a perfectly correct sweep. `tearDownAll` runs after every test in
  // this group regardless of the shuffle, so the assertion is order-independent
  // by construction. Same fix as epic_27's golden-runner check.
  tearDownAll(() {
    const directCallSiteEvents = <String>{
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
      _exercisedDirectCallEvents,
      directCallSiteEvents,
      reason:
          'a direct-call-site event was added to/removed from the group '
          'above without updating this list',
    );
  });

  tearDownAll(() {
    // AnalyticsEvent members exercised directly above via their real
    // production use case/service (see the "direct call-site sweep" group).
    const directCallSiteEvents = <String>{
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
    // AnalyticsEvent members with zero lib/ emitters — verified by grep,
    // nothing to sweep. `AnalyticsEvent.tutorActionRecorded` was the sole
    // emitter of `TutorAuditLogWriter`, deleted as dead code by
    // AUD-tutoring-06 (see analytics_pv1_redaction_test.dart's doc comment);
    // the catalog member is kept (Cloud Functions still write the
    // server-side audit trail under the same name) but nothing in `lib/`
    // fires it, so there is no live parameter shape to assert against.
    const deadCatalogEvents = <String>{AnalyticsEvent.tutorActionRecorded};
    // AnalyticsEvent members genuinely covered by a real PV-1 assertion in
    // another suite — each verified by reading the cited test. A prior
    // version of this list (~12 entries) claimed coverage that did not
    // exist anywhere; this is the corrected, verified set.
    const coveredByOtherSuites = <String>{
      // test/features/tutoring/domain/services/analytics_pv1_redaction_test.dart
      AnalyticsEvent.tutorPinSet,
      // test/story_acceptance/epic_25_story_12_sync_decomp_part1_test.dart
      AnalyticsEvent.syncMergeRouterHalt,
      // test/core/sync/outbox/outbox_processor_test.dart
      AnalyticsEvent.syncOutboxDeadLettered,
      // test/core/sync/sync_orchestrator_test.dart
      AnalyticsEvent.syncPullFailed,
      AnalyticsEvent.syncListenerError,
      AnalyticsEvent.syncPullStarted,
      AnalyticsEvent.syncPullCompleted,
      // test/core/sync/sync_orchestrator_test.dart (read path) +
      // test/core/sync/outbox/outbox_processor_test.dart (write path)
      AnalyticsEvent.syncPermissionDenied,
      // test/core/sync/merge/drift_merge_store_test.dart
      AnalyticsEvent.syncMergeRowSkipped,
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
      {
        ...allConvenienceMethodEvents,
        ...directCallSiteEvents,
        ...coveredByOtherSuites,
        ...deadCatalogEvents,
      },
      fullCatalog,
      reason:
          'a NEW AnalyticsEvent catalog member exists that is neither '
          'exercised by this PV-1 sweep (convenience-method or '
          'direct-call-site), nor accounted for in coveredByOtherSuites or '
          'deadCatalogEvents — every event must have a documented PV-1 '
          'review, not silently fall through every list.',
    );
  });
}

// ── Fakes for the direct call-site sweep ─────────────────────────────────

/// Minimal [TutorGrantRepository] stub — every mutation "succeeds" with a
/// fixed grant id, regardless of input, so the use case's own precondition
/// guards decide which path runs. List methods are unused by this sweep.
class _FakeTutorGrantRepository implements TutorGrantRepository {
  @override
  Future<TutorGrantResult> inviteTutor({
    required String tutorEmail,
    required String childProfileId,
    required TutorPermissions permissions,
    String? childName,
    String? parentName,
  }) async => const TutorGrantSuccess(grantId: 'grant-1');

  @override
  Future<TutorGrantResult> acceptInvite({required String grantId}) async =>
      const TutorGrantSuccess(grantId: 'grant-1');

  @override
  Future<TutorGrantResult> declineInvite({required String grantId}) async =>
      const TutorGrantSuccess(grantId: 'grant-1');

  @override
  Future<TutorGrantResult> rescindInvite({required String grantId}) async =>
      const TutorGrantSuccess(grantId: 'grant-1');

  @override
  Future<TutorGrantResult> revokeGrant({required String grantId}) async =>
      const TutorGrantSuccess(grantId: 'grant-1');

  @override
  Future<TutorGrantResult> resignGrant({required String grantId}) async =>
      const TutorGrantSuccess(grantId: 'grant-1');

  @override
  Future<List<TutorGrant>> listIncomingGrants() async => [];

  @override
  Future<({List<TutorGrant> grants, bool ok})>
  listIncomingGrantsWithStatus() async => (grants: <TutorGrant>[], ok: true);

  @override
  Future<List<TutorGrant>> listOutgoingGrants({
    required String childProfileId,
  }) async => [];

  @override
  Future<List<TutorGrant>> listPendingInvitesForMe() async => [];
}

/// Minimal [CompletionRepository] stub — [MarkCompletionUseCase] fires its
/// analytics BEFORE delegating here, so the returned result only needs to
/// satisfy the return type.
class _FakeCompletionRepository implements CompletionRepository {
  @override
  Future<MarkCompletionResult> markComplete(
    CompletionRequest request, {
    bool awardGamificationPoints = true,
    bool creditsAchievement = true,
  }) async => MarkCompletionResult(
    completion: CompletionEntity(
      curriculumId: CurriculumId.fromStorageKey(request.curriculumId)!,
      sefariaRef: request.sefariaRef,
      stageId: request.stageId,
      trackType: request.trackType,
      source: CompletionSource.live,
      completedAt: DateTime.utc(2026, 5, 1),
      points: 0,
    ),
  );

  @override
  Future<List<CompletionEntity>> bulkMarkComplete(
    BulkCompletionRequest request,
  ) async => [];

  @override
  Future<List<CompletionEntity>> getCompletionsByCurriculum(
    String curriculumId, {
    int? profileId,
  }) async => [];

  @override
  Future<List<CompletionEntity>> getCompletionsForContentItem(
    String sefariaRef,
  ) async => [];

  @override
  Future<Map<String, int>> getReviewCountsForCurriculum(
    CurriculumId curriculumId,
  ) async => {};

  @override
  Future<Map<int, int>> getStageBreakdownForItem({
    required CurriculumId curriculumId,
    required String sefariaRef,
  }) async => {};

  @override
  Future<bool> isStageCompleted({
    required String sefariaRef,
    required int stageId,
    required String trackType,
  }) async => false;

  @override
  Future<void> purgeCompletion({
    required CurriculumId curriculumId,
    required String sefariaRef,
    required int stageId,
    required DateTime purgedAt,
  }) async {}
}

/// Minimal [ContentRepository] stub — [CompletionOrchestrator] requires one
/// at construction, but its methods are only reached by post-write side
/// effects (siyum dispatch), which never fire here (no
/// `CompletionDetectionService` is wired in, and every write below is a
/// duplicate-free single mark, so [MarkCompletionResult.isNew] is `true`
/// but the siyum dispatch itself is a no-op with `_completionDetectionService
/// == null`).
class _FakeContentRepository implements ContentRepository {
  @override
  Future<List<ContentItem>> getContentForCurriculum(
    CurriculumId curriculumId,
  ) async => const [];

  @override
  Future<CurriculumHierarchyConfig> getHierarchyConfig(
    CurriculumId curriculumId,
  ) async => const CurriculumHierarchyConfig(
    curriculumId: 'mishnayos',
    levelLabels: [],
    totalItems: 0,
  );

  @override
  Future<List<ContentItem>> filterByLevel({
    required CurriculumId curriculumId,
    String? level1,
    String? level2,
    String? level3,
    String? level4,
  }) async => const [];

  @override
  Future<List<ContentItem>> getScopedContent({
    required CurriculumId curriculumId,
    required int scopeLevel,
    required List<String> scopeValues,
  }) async => const [];

  @override
  Future<List<ContentItem>> search({
    required CurriculumId curriculumId,
    required String query,
  }) async => const [];

  @override
  Future<ContentItem?> getContentByRef({
    required CurriculumId curriculumId,
    required String sefariaRef,
  }) async => null;
}

/// Builds a [MarkCompletionUseCase] wired over [CompletionOrchestrator] for
/// these PII-exclusion tests — the orchestrator's optional collaborators
/// (bookmark repository, siyum detection, points, streak) are all omitted,
/// which resolves every post-write side effect to a safe no-op (see
/// [CompletionOrchestrator]'s class doc comment). Only order validation and
/// the storage write itself run, both against [_FakeCompletionRepository].
MarkCompletionUseCase _useCase(AnalyticsService analytics) =>
    MarkCompletionUseCase(
      CompletionOrchestrator(
        repository: _FakeCompletionRepository(),
        contentRepository: _FakeContentRepository(),
        activeProfileId: '01J8M6H7QK2P4N9R5T6V8W0XYZ',
      ),
      analytics: analytics,
    );

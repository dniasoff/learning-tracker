import 'dart:async';

import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/logging/log_events.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/exceptions/firestore_permission_denied_exception.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

/// Signal returned by a [MergeDispatcher] after a page is merged.
///
/// `halt` causes the surrounding [PullPipeline] to stop fetching further
/// pages — used when a downstream merger detects a fatal error or a quota
/// degradation event.
enum MergeOutcome { continueNext, halt }

/// Dispatches a fetched page to the appropriate per-entity merger.
///
/// Concrete `MergeRouter` (Story 25.13 / DNI-334) implements this interface;
/// declaring it here lets [PullPipeline] land independently and keeps the
/// two stories decoupled.
abstract class MergeDispatcher {
  Future<MergeOutcome> dispatch({
    required int profileId,
    required String kind,
    required List<Map<String, dynamic>> rows,
  });
}

/// Paginates Firestore collections through a [FirestoreGateway] and hands
/// each page to a [MergeDispatcher].
///
/// Pagination loop:
///   1. Fetch a page with the current cursor (null on first iteration).
///   2. If empty, stop.
///   3. Otherwise, dispatch to the merger.
///   4. If the merger returns [MergeOutcome.halt], stop.
///   5. Otherwise, set the cursor to the last row of the page and repeat.
class PullPipeline {
  PullPipeline({
    required FirestoreGateway gateway,
    required MergeDispatcher dispatcher,
    // W7.6: optional analytics — fires merge_router_halt when the dispatcher
    // signals halt so the event is visible in analytics dashboards.
    AnalyticsService? analytics,
  }) : _gateway = gateway,
       _dispatcher = dispatcher,
       _analytics = analytics;

  final FirestoreGateway _gateway;
  final MergeDispatcher _dispatcher;
  final AnalyticsService? _analytics;

  static const int defaultPageSize = 200;

  Future<void> pullCompletions({
    required int profileId,
    int pageSize = defaultPageSize,
  }) => _pullCollection(
    profileId: profileId,
    collection: 'completions',
    kind: 'completion',
    pageSize: pageSize,
  );

  Future<void> pullBookmarks({
    required int profileId,
    int pageSize = defaultPageSize,
  }) => _pullCollection(
    profileId: profileId,
    collection: 'bookmarks',
    kind: 'bookmark',
    pageSize: pageSize,
  );

  Future<void> pullSettings({
    required int profileId,
    int pageSize = defaultPageSize,
  }) => _pullCollection(
    profileId: profileId,
    collection: 'settings',
    kind: 'settings',
    pageSize: pageSize,
  );

  Future<void> pullTracks({
    required int profileId,
    int pageSize = defaultPageSize,
  }) => _pullCollection(
    profileId: profileId,
    collection: 'curriculum_tracks',
    kind: EntityKind.trackConfig,
    pageSize: pageSize,
  );

  Future<void> pullLearnerProfiles({
    required int profileId,
    int pageSize = defaultPageSize,
  }) async {
    // learner_profiles lives at users/{uid}/learner_profiles — it is the
    // profile collection itself, not a subcollection of a profile doc. Using
    // _pullCollection here would build the wrong path
    // (users/{uid}/learner_profiles/{profileId}/learner_profiles).
    final rows = await _gateway.fetchLearnerProfiles();
    if (rows.isEmpty) return;
    await _dispatcher.dispatch(
      profileId: profileId,
      kind: EntityKind.learnerProfile,
      rows: rows,
    );
  }

  Future<void> pullLearningOrder({
    required int profileId,
    int pageSize = defaultPageSize,
  }) => _pullCollection(
    profileId: profileId,
    collection: 'learning_order',
    kind: 'learning_order',
    pageSize: pageSize,
  );

  Future<void> pullProfilePrograms({
    required int profileId,
    int pageSize = defaultPageSize,
  }) => _pullCollection(
    profileId: profileId,
    collection: 'profile_programs',
    kind: EntityKind.profileProgram,
    pageSize: pageSize,
  );

  // W2.27 — new collection + document pull methods (closes M1) ─────────────

  Future<void> pullGoals({
    required int profileId,
    int pageSize = defaultPageSize,
  }) => _pullCollection(
    profileId: profileId,
    collection: 'goals',
    kind: EntityKind.goal,
    pageSize: pageSize,
  );

  Future<void> pullLearningLedger({
    required int profileId,
    int pageSize = defaultPageSize,
  }) => _pullCollection(
    profileId: profileId,
    collection: 'learning_ledger',
    kind: EntityKind.learningLedger,
    pageSize: pageSize,
  );

  // W2.29 — stage_definitions pull (closes H4).
  Future<void> pullStageDefinitions({
    required int profileId,
    int pageSize = defaultPageSize,
  }) => _pullCollection(
    profileId: profileId,
    collection: 'stage_definitions',
    kind: EntityKind.stageDefinition,
    pageSize: pageSize,
  );

  // W2.28 — streak events pull (closes M4).
  Future<void> pullStreak({
    required int profileId,
    int pageSize = defaultPageSize,
  }) => _pullCollection(
    profileId: profileId,
    collection: 'streak_events',
    kind: EntityKind.streak,
    pageSize: pageSize,
  );

  /// Pull a single-document Firestore subcollection (notification_settings,
  /// gamification_settings, ui_preferences). Wraps the document in a
  /// single-element list so the [MergeDispatcher] receives the standard
  /// `List<Map<String, dynamic>>` contract.
  // W3.33: three preference docs unified into preferences/{scope}.
  Future<void> pullNotificationSettings({required int profileId}) =>
      _pullDocument(
        profileId: profileId,
        collection: 'preferences',
        docId: 'notification_settings',
        kind: EntityKind.notificationSettings,
      );

  Future<void> pullGamificationSettings({required int profileId}) =>
      _pullDocument(
        profileId: profileId,
        collection: 'preferences',
        docId: 'gamification_settings',
        kind: EntityKind.gamificationSettings,
      );

  Future<void> pullUiPreferences({required int profileId}) => _pullDocument(
    profileId: profileId,
    collection: 'preferences',
    docId: 'ui_preferences',
    kind: EntityKind.uiPreferences,
  );

  // Phase 1 — study_day_configs pull.
  Future<void> pullStudyDayConfigs({
    required int profileId,
    int pageSize = defaultPageSize,
  }) => _pullCollection(
    profileId: profileId,
    collection: 'study_day_configs',
    kind: EntityKind.studyDayConfig,
    pageSize: pageSize,
  );

  // WS9 Wave-B (C#2) — points spend economy pulls ──────────────────────────

  Future<void> pullPointsLedger({
    required int profileId,
    int pageSize = defaultPageSize,
  }) => _pullCollection(
    profileId: profileId,
    collection: 'points_ledger',
    kind: EntityKind.pointsLedger,
    pageSize: pageSize,
  );

  Future<void> pullRewardRedemptions({
    required int profileId,
    int pageSize = defaultPageSize,
  }) => _pullCollection(
    profileId: profileId,
    collection: 'reward_redemptions',
    kind: EntityKind.rewardRedemption,
    pageSize: pageSize,
  );

  // ── T1.pull-decouple — tutored-profile pull (read parent namespace, merge under local id) ──

  /// Pull all sub-collections for a tutored child.
  ///
  /// Reads from `users/{parentUid}/learner_profiles/{remoteProfileId}/<coll>`
  /// (the parent's Firestore namespace) but dispatches every page to the
  /// merger with [localProfileId] — the synthetic local row id created by
  /// [ProfileDao.upsertTutoredProfile]. No merger logic changes needed.
  /// Returns the number of child collections/documents that failed to merge.
  /// A non-zero count means the mirror is only partially refreshed — the caller
  /// surfaces this as a soft error WITHOUT wiping the mirror (a generic failure
  /// is not a grant revocation). A [FirestorePermissionDeniedException] still
  /// propagates (revoked grant → wipe).
  Future<int> pullForTutoredProfile({
    required String parentUid,
    required String remoteProfileId,
    required int localProfileId,
    int pageSize = defaultPageSize,
  }) async {
    var failureCount = 0;
    // Bug 3: curriculum_tracks MUST be pulled before any collection whose rows
    // are bound to a track id (settings/stage_definitions/goals/
    // study_day_configs). Those rows carry the REMOTE track id; the mergers
    // resolve the LOCAL mirror track id by (profile, curriculum), so the local
    // track row has to exist first or the resolution falls back to the stale
    // remote id (study_day_configs would then be dropped by its FK guard) and
    // the scheduler projection computes nothing for the tutor.
    final collections = <(String collection, String kind)>[
      ('completions', EntityKind.completion),
      ('bookmarks', EntityKind.bookmark),
      ('curriculum_tracks', EntityKind.trackConfig),
      ('settings', EntityKind.settings),
      ('goals', EntityKind.goal),
      ('learning_ledger', EntityKind.learningLedger),
      ('stage_definitions', EntityKind.stageDefinition),
      ('streak_events', EntityKind.streak),
      ('study_day_configs', EntityKind.studyDayConfig),
      ('profile_programs', EntityKind.profileProgram),
      ('learning_order', EntityKind.learningOrder),
      ('points_ledger', EntityKind.pointsLedger),
      ('reward_redemptions', EntityKind.rewardRedemption),
    ];

    for (final (collection, kind) in collections) {
      // Bug 3: isolate each collection. A single collection's merge/DB error
      // (e.g. gamification_settings' point_configs FK violation) must NOT abort
      // the whole tutored pull — that left the mirror with only partial data
      // and a 0-due / "No projection" scheduler view. Log + continue so the
      // remaining collections still land. PermissionDenied still propagates
      // (revoked grant → caller wipes the mirror).
      try {
        await _pullChildCollection(
          parentUid: parentUid,
          remoteProfileId: remoteProfileId,
          localProfileId: localProfileId,
          collection: collection,
          kind: kind,
          pageSize: pageSize,
        );
      } on FirestorePermissionDeniedException {
        rethrow;
      } catch (e, stackTrace) {
        failureCount++;
        AppLogger.instance.warning(
          event: 'tutored_pull_collection_failed',
          fields: {'collection': collection, 'kind': kind},
          exception: e,
          stackTrace: stackTrace,
        );
      }
    }

    // Preference documents — single-doc sub-collections.
    for (final (docId, kind) in [
      ('notification_settings', EntityKind.notificationSettings),
      ('gamification_settings', EntityKind.gamificationSettings),
      ('ui_preferences', EntityKind.uiPreferences),
    ]) {
      try {
        await _pullChildDocument(
          parentUid: parentUid,
          remoteProfileId: remoteProfileId,
          localProfileId: localProfileId,
          collection: 'preferences',
          docId: docId,
          kind: kind,
        );
      } on FirestorePermissionDeniedException {
        rethrow;
      } catch (e, stackTrace) {
        failureCount++;
        AppLogger.instance.warning(
          event: 'tutored_pull_document_failed',
          fields: {'doc': docId, 'kind': kind},
          exception: e,
          stackTrace: stackTrace,
        );
      }
    }

    return failureCount;
  }

  Future<void> _pullChildDocument({
    required String parentUid,
    required String remoteProfileId,
    required int localProfileId,
    required String collection,
    required String docId,
    required String kind,
  }) async {
    final doc = await _gateway.fetchChildDocument(
      parentUid: parentUid,
      remoteProfileId: remoteProfileId,
      collection: collection,
      docId: docId,
    );
    if (doc == null || doc.isEmpty) return;
    await _dispatcher.dispatch(
      profileId: localProfileId,
      kind: kind,
      rows: [doc],
    );
  }

  Future<void> _pullChildCollection({
    required String parentUid,
    required String remoteProfileId,
    required int localProfileId,
    required String collection,
    required String kind,
    required int pageSize,
  }) async {
    Map<String, dynamic>? cursor;
    while (true) {
      final page = await _gateway.fetchChildPage(
        parentUid: parentUid,
        remoteProfileId: remoteProfileId,
        collection: collection,
        pageSize: pageSize,
        cursor: cursor,
      );
      if (page.rows.isEmpty) return;
      final outcome = await _dispatcher.dispatch(
        profileId: localProfileId,
        kind: kind,
        rows: page.rows,
      );
      if (outcome == MergeOutcome.halt) return;
      cursor = page.rows.last;
    }
  }

  // ── Private helpers for own-account pulls ─────────────────────────────────

  Future<void> _pullDocument({
    required int profileId,
    required String collection,
    required String docId,
    required String kind,
  }) async {
    final doc = await _gateway.fetchDocument(
      profileId: profileId,
      collection: collection,
      docId: docId,
    );
    if (doc == null || doc.isEmpty) return;
    await _dispatcher.dispatch(profileId: profileId, kind: kind, rows: [doc]);
  }

  Future<void> _pullCollection({
    required int profileId,
    required String collection,
    required String kind,
    required int pageSize,
  }) async {
    Map<String, dynamic>? cursor;
    while (true) {
      final page = await _gateway.fetchPage(
        profileId: profileId,
        collection: collection,
        pageSize: pageSize,
        cursor: cursor,
      );
      if (page.rows.isEmpty) return;

      final outcome = await _dispatcher.dispatch(
        profileId: profileId,
        kind: kind,
        rows: page.rows,
      );
      if (outcome == MergeOutcome.halt) {
        // W7.6: fire telemetry so the halt is visible in analytics dashboards
        // (the structured log captures it separately via AppLogger).
        final future = _analytics?.logEvent(
          LogEvents.sync.mergeRouterHalt,
          parameters: {
            'collection': collection,
            'entity_kind': kind,
            'profile_id': profileId,
          },
        );
        if (future != null) unawaited(future);
        return;
      }

      cursor = page.rows.last;
    }
  }
}

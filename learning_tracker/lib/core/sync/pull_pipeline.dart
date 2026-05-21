import 'dart:async';

import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/logging/log_events.dart';
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

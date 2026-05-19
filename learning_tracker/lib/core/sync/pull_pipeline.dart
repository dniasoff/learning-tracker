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
  }) : _gateway = gateway,
       _dispatcher = dispatcher;

  final FirestoreGateway _gateway;
  final MergeDispatcher _dispatcher;

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
  }) => _pullCollection(
    profileId: profileId,
    collection: 'learner_profiles',
    kind: EntityKind.learnerProfile,
    pageSize: pageSize,
  );

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
      if (outcome == MergeOutcome.halt) return;

      cursor = page.rows.last;
    }
  }
}

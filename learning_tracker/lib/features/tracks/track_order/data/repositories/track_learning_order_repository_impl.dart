import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_track_learning_order_repository.dart';
import 'package:learning_tracker/features/tracks/track_order/domain/repositories/track_learning_order_repository.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';

/// AUD-tracks-15 (SM-8): this repository only talks to Firestore. It no
/// longer holds a `ContentRepository` dependency — the content-fetch
/// orchestration lives in `track_learning_order_providers.dart`, which
/// resolves the curriculum's content list and passes it in as `allItems` on
/// every call.

/// Thrown by [FirestoreTrackLearningOrderRepositoryAdapter]'s write methods
/// when `firestoreTrackLearningOrderRepositoryProvider` resolves to `null` —
/// see `BookmarkRepositoryNotReadyException`'s doc comment
/// (`lib/features/learning/data/repositories/bookmark_repository_impl.dart`)
/// for the read-vs-write split this mirrors: reads reuse a natural "nothing
/// yet" value (`[]`), writes have no such value and throw instead.
class TrackLearningOrderRepositoryNotReadyException implements Exception {
  const TrackLearningOrderRepositoryNotReadyException();

  @override
  String toString() =>
      'TrackLearningOrderRepositoryNotReadyException: '
      'firestoreTrackLearningOrderRepositoryProvider resolved to null (no '
      'active account, or no active learner profile, yet) — cannot '
      'complete a track-learning-order write until one is active.';
}

/// Firestore-backed [TrackLearningOrderRepository] adapter. Follows the
/// pattern `FirestoreBookmarkRepositoryAdapter`
/// (`lib/features/learning/data/repositories/bookmark_repository_impl.dart`)
/// establishes — read that class's doc comment first; this one only calls
/// out what is DIFFERENT here.
///
/// ## AD-25: keyed by [CurriculumId] directly, no Drift bridge needed
///
/// [TrackLearningOrderRepository] used to be keyed by the Drift-local `int
/// trackId`, requiring this adapter to hold a `UserDatabase` purely to
/// resolve `trackId -> curriculumId` (a track-table FK lookup) before every
/// call. AD-25 retired that per-device id entirely — every caller already
/// holds the [CurriculumId] directly (see `track_learning_order_providers
/// .dart`'s `_TrackCurriculumArgs`, which carried both side by side before
/// this change), so the bridge — and the Drift dependency it existed for —
/// is gone, not merely renamed.
///
/// ## Not-ready semantics
///
/// [getSedarimOrder]/[getMasechtosOrder] reuse the interface's own `[]`
/// "nothing yet" value. [saveSedarimOrder]/[saveMasechtosOrder] have no such
/// value and throw [TrackLearningOrderRepositoryNotReadyException] instead.
///
/// ## Reset and reorder-amnesty
///
/// The resolved Firestore repository handles reset with field tombstones and
/// co-writes `last_reorder_at` in the same atomic batch as every order
/// mutation. This adapter remains the provider-resolution seam and delegates
/// the complete operation unchanged.
class FirestoreTrackLearningOrderRepositoryAdapter
    implements TrackLearningOrderRepository {
  FirestoreTrackLearningOrderRepositoryAdapter({required Ref ref})
    : _ref = ref;

  final Ref _ref;

  /// Re-reads `firestoreTrackLearningOrderRepositoryProvider`, resolving to
  /// `null` exactly when it does (no active account, or no active learner
  /// profile). See `FirestoreBookmarkRepositoryAdapter._resolveOrNull`'s doc
  /// comment for why this re-reads on every call rather than caching.
  Future<FirestoreTrackLearningOrderRepository?> _resolveOrNull() {
    return _ref.read(firestoreTrackLearningOrderRepositoryProvider.future);
  }

  /// Like [_resolveOrNull], but throws
  /// [TrackLearningOrderRepositoryNotReadyException] instead of returning
  /// `null` — for the write methods and [resetToDefault]; see the class doc
  /// comment.
  Future<FirestoreTrackLearningOrderRepository> _resolve() async {
    final repo = await _resolveOrNull();
    if (repo == null) {
      throw const TrackLearningOrderRepositoryNotReadyException();
    }
    return repo;
  }

  @override
  Future<List<LearningOrderItem>> getSedarimOrder(
    CurriculumId curriculumId,
    List<ContentItem> allItems,
  ) async {
    final repo = await _resolveOrNull();
    if (repo == null) return const [];
    return repo.getSedarimOrder(curriculumId, allItems);
  }

  @override
  Future<List<LearningOrderItem>> getMasechtosOrder(
    CurriculumId curriculumId,
    List<ContentItem> allItems,
  ) async {
    final repo = await _resolveOrNull();
    if (repo == null) return const [];
    return repo.getMasechtosOrder(curriculumId, allItems);
  }

  @override
  Future<void> saveSedarimOrder(
    CurriculumId curriculumId,
    List<LearningOrderItem> items,
  ) async {
    final repo = await _resolve();
    await repo.saveSedarimOrder(curriculumId, items);
  }

  @override
  Future<void> saveMasechtosOrder(
    CurriculumId curriculumId,
    List<LearningOrderItem> items,
  ) async {
    final repo = await _resolve();
    await repo.saveMasechtosOrder(curriculumId, items);
  }

  @override
  Future<void> resetToDefault(CurriculumId curriculumId) async {
    final repo = await _resolve();
    await repo.resetToDefault(curriculumId);
  }
}

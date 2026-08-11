import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_track_learning_order_repository.dart';
import 'package:learning_tracker/features/tracks/track_order/domain/repositories/track_learning_order_repository.dart';
import 'package:learning_tracker/features/tracks/track_order/domain/services/masechta_ordering_policy.dart';
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
/// ## [resetToDefault] — propagated, not re-solved
///
/// `FirestoreTrackLearningOrderRepository.resetToDefault` itself throws
/// [UnimplementedError] unconditionally — `firestore.rules` denies `delete`
/// on `track_learning_order`, and there is no fixed doc-id universe to
/// overwrite in place instead (see that class's doc comment, "Trimmed").
/// This method still resolves the provider first (so a genuinely not-ready
/// caller sees [TrackLearningOrderRepositoryNotReadyException] rather than
/// the permanently-unimplemented one), then delegates — once ready, the
/// [UnimplementedError] propagates unchanged.
///
/// ## Reorder-amnesty (`last_reorder_at`) — NOT co-written here
///
/// The Drift impl this replaces co-stamped `curriculum_tracks.last_reorder_at`
/// inside the same transaction as every order write.
/// `last_reorder_at` IS in `firestore.rules`' `curriculum_tracks`
/// `.hasOnly()` whitelist (confirmed by reading the rules file directly),
/// but neither [FirestoreTrackLearningOrderRepository] nor
/// [FirestoreCurriculumTrackRepository] (`lib/data/repositories/
/// firestore_curriculum_track_repository.dart`) exposes a method that
/// writes it, and adding one to either means editing a file under
/// `lib/data/repositories/`, out of this task's scope. A raw
/// `cloud_firestore` write from here is not an option either —
/// `tool/check_firebase_confinement.dart` (`make audit` check 2/15, hard
/// gate) only allows `FirebaseFirestore`/`cloud_firestore` symbols inside
/// `lib/core/sync/`, `lib/core/auth/`, `lib/data/firestore/`, and
/// `lib/data/repositories/` — not `lib/features/tracks/**`. See
/// [FirestoreCurriculumTrackRepositoryAdapter]'s class doc comment
/// (`lib/features/tracks/setup/data/repositories/
/// curriculum_track_repository_impl.dart`) for the other half of this same
/// gap. [saveSedarimOrder]/[saveMasechtosOrder] below write ONLY the order
/// data — the amnesty baseline is left untouched by the Firestore path
/// until a `stampReorderAt`-shaped method is added to
/// [FirestoreCurriculumTrackRepository].
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
    // Reorder-amnesty NOT co-written — see the class doc comment.
    await repo.saveSedarimOrder(curriculumId, items);
  }

  @override
  Future<void> saveMasechtosOrder(
    CurriculumId curriculumId,
    List<LearningOrderItem> items,
  ) async {
    final repo = await _resolve();
    // Reorder-amnesty NOT co-written — see the class doc comment.
    await repo.saveMasechtosOrder(curriculumId, items);
  }

  @override
  Future<void> resetToDefault(CurriculumId curriculumId) async {
    final repo = await _resolve();
    // Always throws UnimplementedError once ready — see the class doc
    // comment's "resetToDefault" section.
    await repo.resetToDefault(curriculumId);
  }
}

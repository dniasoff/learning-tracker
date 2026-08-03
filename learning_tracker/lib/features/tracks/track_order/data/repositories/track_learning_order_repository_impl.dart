import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_track_learning_order_repository.dart';
import 'package:learning_tracker/features/tracks/track_order/domain/repositories/track_learning_order_repository.dart';
import 'package:learning_tracker/features/tracks/track_order/domain/services/masechta_ordering_policy.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';

/// AUD-tracks-15 (SM-8): this repository only talks to its own DAO
/// (`UserDatabase.trackLearningOrderDao` / `.trackDao`). It no longer holds
/// a `ContentRepository` dependency — the content-fetch orchestration lives
/// in `track_learning_order_providers.dart`, which resolves the curriculum's
/// content list and passes it in as `allItems` on every call.
class TrackLearningOrderRepositoryImpl implements TrackLearningOrderRepository {
  TrackLearningOrderRepositoryImpl({required UserDatabase database})
    : _database = database;

  final UserDatabase _database;

  /// AUD-t-cross-06: resolves the owning profileId for [trackId] from
  /// `curriculum_tracks` — the single source of truth for track ownership —
  /// so every `track_learning_order` read/write is scoped by profileId, not
  /// trackId alone.
  Future<int> _resolveProfileId(int trackId) async {
    final track = await _database.trackDao.getTrackById(trackId);
    if (track == null) {
      throw StateError('No track found for trackId=$trackId');
    }
    return track.profileId;
  }

  Map<String, ({String he, String en, int sortOrder})> _buildSedarimIndex(
    List<ContentItem> allItems,
  ) {
    final index = <String, ({String he, String en, int sortOrder})>{};
    for (final item in allItems) {
      if (item.level2 == null && !item.isLeaf) {
        index.putIfAbsent(
          item.sefariaRef,
          () => (
            he: item.displayNameHe,
            en: item.displayNameEn,
            sortOrder: item.sortOrder,
          ),
        );
      }
    }
    return index;
  }

  Future<Map<String, ({String he, String en, int sortOrder})>>
  _buildMasechtosIndex(int trackId, List<ContentItem> allItems) async {
    final sedarimIndex = _buildSedarimIndex(allItems);

    // Convert DAO rows to the savedSederOrder list expected by the policy:
    // only include rows whose sefariaRef matches a known seder, in row order.
    final profileId = await _resolveProfileId(trackId);
    final daoRows = await _database.trackLearningOrderDao.getByTrack(
      profileId,
      trackId,
    );
    final savedSederOrder = daoRows
        .where((r) => sedarimIndex.containsKey(r.sefariaRef))
        .map((r) => r.sefariaRef)
        .toList();

    return const MasechtaOrderingPolicy().buildIndex(
      allItems: allItems,
      sedarimIndex: sedarimIndex,
      savedSederOrder: savedSederOrder,
    );
  }

  Future<List<LearningOrderItem>> _getOrderedItems(
    int trackId,
    Map<String, ({String he, String en, int sortOrder})> index,
  ) async {
    final profileId = await _resolveProfileId(trackId);
    final rows = await _database.trackLearningOrderDao.getByTrack(
      profileId,
      trackId,
    );
    final matchingRows = rows
        .where((r) => index.containsKey(r.sefariaRef))
        .toList();

    if (matchingRows.isNotEmpty) {
      return matchingRows.map((r) {
        final info = index[r.sefariaRef]!;
        return LearningOrderItem(
          sefariaRef: r.sefariaRef,
          displayNameHe: info.he,
          displayNameEn: info.en,
          userSortOrder: r.sortOrder,
          isCustomOrdered: true,
        );
      }).toList();
    }

    final sorted = index.entries.toList()
      ..sort((a, b) => a.value.sortOrder.compareTo(b.value.sortOrder));
    return sorted
        .asMap()
        .entries
        .map(
          (e) => LearningOrderItem(
            sefariaRef: e.value.key,
            displayNameHe: e.value.value.he,
            displayNameEn: e.value.value.en,
            userSortOrder: e.key,
            isCustomOrdered: false,
          ),
        )
        .toList();
  }

  @override
  Future<List<LearningOrderItem>> getSedarimOrder(
    int trackId,
    List<ContentItem> allItems,
  ) async {
    final index = _buildSedarimIndex(allItems);
    return _getOrderedItems(trackId, index);
  }

  @override
  Future<List<LearningOrderItem>> getMasechtosOrder(
    int trackId,
    List<ContentItem> allItems,
  ) async {
    final index = await _buildMasechtosIndex(trackId, allItems);
    return _getOrderedItems(trackId, index);
  }

  @override
  Future<void> saveSedarimOrder(
    int trackId,
    List<LearningOrderItem> items,
  ) async {
    final refs = items.map((i) => i.sefariaRef).toList();
    // AUD-core-database-05 (DB-2): the order write and the reorder-amnesty
    // stamp must commit or roll back together — a crash/error between the
    // two would otherwise leave a stale lastReorderAt (or vice versa),
    // breaking the reorder-amnesty logic documented at architecture §10.1.
    final profileId = await _resolveProfileId(trackId);
    await _database.transaction(() async {
      await _database.trackLearningOrderDao.upsertOrder(
        profileId,
        trackId,
        refs,
      );
      // Reorder-amnesty: stamp lastReorderAt so the projection clears
      // overdue items that were scheduled before this reorder.
      await _database.trackDao.stampReorderAt(trackId);
    });
  }

  @override
  Future<void> saveMasechtosOrder(
    int trackId,
    List<LearningOrderItem> items,
  ) async {
    final refs = items.map((i) => i.sefariaRef).toList();
    // AUD-core-database-05 (DB-2): see saveSedarimOrder above.
    final profileId = await _resolveProfileId(trackId);
    await _database.transaction(() async {
      await _database.trackLearningOrderDao.upsertOrder(
        profileId,
        trackId,
        refs,
      );
      // Reorder-amnesty: stamp lastReorderAt so the projection clears
      // overdue items scheduled before this reorder.
      await _database.trackDao.stampReorderAt(trackId);
    });
  }

  @override
  Future<void> resetToDefault(int trackId) async {
    // AUD-core-database-05 (DB-2): see saveSedarimOrder above.
    final profileId = await _resolveProfileId(trackId);
    await _database.transaction(() async {
      await _database.trackLearningOrderDao.deleteByTrack(profileId, trackId);
      // Reorder-amnesty: reset-to-default is a content-order change.
      await _database.trackDao.stampReorderAt(trackId);
    });
  }
}

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
/// ## `int trackId` → `CurriculumId`: the one Drift dependency this adapter
/// keeps, and why
///
/// [TrackLearningOrderRepository] is keyed by the Drift-local `int trackId`
/// — real, live callers (`track_learning_order_providers.dart`,
/// `track_learning_order_screen.dart`) address it that way today.
/// [FirestoreTrackLearningOrderRepository] (the class this adapter wraps)
/// is keyed by [CurriculumId] instead — AD-25 retired the per-device track
/// id for this collection entirely (see that class's own class doc comment,
/// "`curriculumId` replaces the Drift `int trackId`"). Bridging the two
/// requires resolving `trackId -> curriculumId` somewhere, and — unlike
/// [FirestoreStageDefinitionRepositoryAdapter.getStagesByTrack]/
/// `.deleteStagesForTrack` (which have no such bridge available and throw
/// [UnimplementedError] instead, since that collection's own repository
/// method was dropped outright) — resolving it here is possible: this
/// adapter reads `UserDatabase.trackDao.getTrackById` for exactly that one
/// lookup, mirroring `TrackLearningOrderRepositoryImpl._resolveProfileId`'s
/// own identical pattern (same DAO call, reading `.curriculumId` here
/// instead of `.profileId`). This is a deliberate, narrow exception to "the
/// adapter never reaches into Drift": it borrows Drift ONLY for identity
/// resolution (an FK lookup), never for the order data itself, which is
/// read from and written to Firestore exclusively — the same shape
/// `FirestoreProfileRepositoryAdapter`
/// (`lib/features/profiles/data/repositories/profile_repository_impl.dart`)
/// already established for bridging two identity spaces during this
/// migration. Throws [StateError] when [trackId] does not resolve to any
/// track, mirroring `TrackLearningOrderRepositoryImpl._resolveProfileId`'s
/// own `StateError` for the same condition.
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
/// This method still resolves the trackId and the provider first (so a
/// genuinely not-ready or unknown-trackId caller sees
/// [TrackLearningOrderRepositoryNotReadyException]/[StateError] rather than
/// the permanently-unimplemented one), then delegates — once ready, the
/// [UnimplementedError] propagates unchanged.
///
/// ## Reorder-amnesty (`last_reorder_at`) — NOT co-written here
///
/// The Drift impl above co-stamps `curriculum_tracks.last_reorder_at`
/// inside the same transaction as every order write
/// (`TrackDao.stampReorderAt`). `last_reorder_at` IS now in
/// `firestore.rules`' `curriculum_tracks` `.hasOnly()` whitelist (confirmed
/// by reading the rules file directly), but neither
/// [FirestoreTrackLearningOrderRepository] nor
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
  FirestoreTrackLearningOrderRepositoryAdapter({
    required Ref ref,
    required UserDatabase database,
  }) : _ref = ref,
       _database = database;

  final Ref _ref;
  final UserDatabase _database;

  /// Resolves [trackId] to the [CurriculumId] its Firestore-side collection
  /// is actually keyed by — see the class doc comment ("`int trackId` ->
  /// `CurriculumId`"). Throws [StateError] if [trackId] does not resolve to
  /// any track, mirroring `TrackLearningOrderRepositoryImpl
  /// ._resolveProfileId`'s own guard.
  Future<CurriculumId> _resolveCurriculumId(int trackId) async {
    final track = await _database.trackDao.getTrackById(trackId);
    if (track == null) {
      throw StateError('No track found for trackId=$trackId');
    }
    final curriculumId = CurriculumId.fromStorageKey(track.curriculumId);
    if (curriculumId == null) {
      throw StateError(
        'Unknown curriculumId "${track.curriculumId}" for trackId=$trackId',
      );
    }
    return curriculumId;
  }

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
    int trackId,
    List<ContentItem> allItems,
  ) async {
    final curriculumId = await _resolveCurriculumId(trackId);
    final repo = await _resolveOrNull();
    if (repo == null) return const [];
    return repo.getSedarimOrder(curriculumId, allItems);
  }

  @override
  Future<List<LearningOrderItem>> getMasechtosOrder(
    int trackId,
    List<ContentItem> allItems,
  ) async {
    final curriculumId = await _resolveCurriculumId(trackId);
    final repo = await _resolveOrNull();
    if (repo == null) return const [];
    return repo.getMasechtosOrder(curriculumId, allItems);
  }

  @override
  Future<void> saveSedarimOrder(
    int trackId,
    List<LearningOrderItem> items,
  ) async {
    final curriculumId = await _resolveCurriculumId(trackId);
    final repo = await _resolve();
    // Reorder-amnesty NOT co-written — see the class doc comment.
    await repo.saveSedarimOrder(curriculumId, items);
  }

  @override
  Future<void> saveMasechtosOrder(
    int trackId,
    List<LearningOrderItem> items,
  ) async {
    final curriculumId = await _resolveCurriculumId(trackId);
    final repo = await _resolve();
    // Reorder-amnesty NOT co-written — see the class doc comment.
    await repo.saveMasechtosOrder(curriculumId, items);
  }

  @override
  Future<void> resetToDefault(int trackId) async {
    final curriculumId = await _resolveCurriculumId(trackId);
    final repo = await _resolve();
    // Always throws UnimplementedError once ready — see the class doc
    // comment's "resetToDefault" section.
    await repo.resetToDefault(curriculumId);
  }
}

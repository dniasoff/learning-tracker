/// Firestore adapter for the curriculum-track lifecycle (activate / retire /
/// archive / query) — part of Epic C's feature-by-feature rewire onto
/// Firestore (see `lib/data/firestore/repository_providers.dart`'s library
/// doc comment, "Reaching this file from lib/features/** — audit check
/// 102", and `lib/data/repositories/firestore_curriculum_track_repository.dart`'s
/// class doc comment for what THIS file wraps).
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_curriculum_track_repository.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';

/// Thrown by [FirestoreCurriculumTrackRepositoryAdapter]'s write methods when
/// `firestoreCurriculumTrackRepositoryProvider` resolves to `null` — see
/// `BookmarkRepositoryNotReadyException`'s doc comment
/// (`lib/features/learning/data/repositories/bookmark_repository_impl.dart`)
/// for the read-vs-write split this mirrors: reads reuse a natural "nothing
/// yet" value (`null`/`[]`/`0`/`false`), writes have no such value and throw
/// instead.
class CurriculumTrackRepositoryNotReadyException implements Exception {
  const CurriculumTrackRepositoryNotReadyException();

  @override
  String toString() =>
      'CurriculumTrackRepositoryNotReadyException: '
      'firestoreCurriculumTrackRepositoryProvider resolved to null (no '
      'active account, or no active learner profile, yet) — cannot complete '
      'a curriculum-track write until one is active.';
}

/// Firestore-backed adapter over [FirestoreCurriculumTrackRepository],
/// exposing curriculum-track lifecycle operations (activate/retire/
/// archive/query) to `lib/features/tracks/**`. Follows the pattern
/// `FirestoreBookmarkRepositoryAdapter`
/// (`lib/features/learning/data/repositories/bookmark_repository_impl.dart`)
/// establishes — read that class's doc comment first; this one only calls
/// out what is DIFFERENT here.
///
/// ## No domain interface to `implements` — genuinely new surface
///
/// Every other adapter in this rewire wave adapts an EXISTING
/// `lib/features/**/domain/repositories/*.dart` interface. No such interface
/// exists for the curriculum-track lifecycle: `CurriculumActivationService`
/// (`lib/features/tracks/domain/services/curriculum_activation_service.dart`)
/// — the sole caller of this lifecycle today — talks directly to
/// `UserDatabase.trackDao`/`.activeCurriculumDao`, two Drift DAOs, not a
/// repository interface. That service also orchestrates several OTHER
/// collections this adapter does not own (`study_day_configs` seeding,
/// Firestore push of the whole track list) in the same methods, so it is not
/// a thin pass-through this class could stand in for even if an interface
/// did exist. This class is therefore standalone and additive: it exposes
/// [FirestoreCurriculumTrackRepository]'s own method surface directly
/// (mirroring how that class itself declares "No interface" — the Drift
/// DAOs it merges are being deleted outright, not kept alongside it), ready
/// for a future task that either (a) extracts a genuine
/// `CurriculumTrackRepository` interface from `CurriculumActivationService`
/// and rewires the service to depend on it, or (b) rewrites
/// `CurriculumActivationService` itself to call this adapter directly.
/// Neither is in this task's scope (`CurriculumActivationService` lives
/// under `domain/services/`, not `data/repositories/`).
///
/// ## Not-ready semantics, per method
///
/// - [getTrack] → `null` (already the interface's own "no track" value).
/// - [isActive] → `false` (matches `FirestoreCurriculumTrackRepository
///   .isActive`'s own `track?.isActive ?? false` null-collapse).
/// - [getAllTracks] / [getActiveTracks] / [getActiveCurriculumIds] → `[]`.
/// - [countActiveTracks] → `0`.
/// - [activateTrack] / [retireTrack] / [archiveTrack] / [resetPace] — no
///   natural "nothing happened" value for a lifecycle transition or a state
///   mutation to reuse, so these throw
///   [CurriculumTrackRepositoryNotReadyException] instead, exactly the write
///   side of [BookmarkRepositoryNotReadyException]'s reasoning.
/// - [watchTrack] / [watchAllTracks] / [watchActiveTracks] /
///   [watchActiveCurriculumIds] — the underlying provider is itself a
///   `FutureProvider` (account/profile resolution is async), so each stream
///   method resolves it once via [_resolveOrNull] and then either forwards
///   to the resolved repository's own stream or falls back to a single
///   not-ready emission (`null`/`[]`) — there is no re-subscription if the
///   active account/profile changes AFTER the stream is opened. Bookmarks
///   and the other adapters in this wave have no stream methods to set a
///   precedent for; this is this wave's first, and the limitation is
///   flagged here rather than solved silently.
///
/// ## Reorder-amnesty (`last_reorder_at`) — NOT wired here, and cannot be
/// from this file
///
/// `TrackLearningOrderRepositoryImpl` (Drift) co-stamps
/// `curriculum_tracks.last_reorder_at` in the same transaction as every
/// order write (`TrackDao.stampReorderAt`) — see
/// `FirestoreTrackLearningOrderRepository`'s class doc comment
/// ("Coordination point") and
/// `lib/features/tracks/track_order/data/repositories/
/// track_learning_order_repository_impl.dart`'s adapter doc comment for the
/// other half of this. `last_reorder_at` IS now in `firestore.rules`'
/// `curriculum_tracks` `.hasOnly()` whitelist (confirmed by reading the
/// rules file directly), so the FIELD exists — but
/// [FirestoreCurriculumTrackRepository] (the class this adapter wraps) has
/// no method that writes it, and adding one is editing
/// `lib/data/repositories/firestore_curriculum_track_repository.dart`,
/// which is out of this task's scope. The alternative — writing the field
/// directly from here via a raw `cloud_firestore` call — is not available
/// either: `tool/check_firebase_confinement.dart` (`make audit` check
/// 2/15, hard gate) only allows `FirebaseFirestore`/`cloud_firestore`
/// symbols inside `lib/core/sync/`, `lib/core/auth/`, `lib/data/firestore/`,
/// and `lib/data/repositories/` — `lib/features/tracks/**` is not on that
/// list. So this adapter has no method for stamping the amnesty baseline at
/// all; a caller that reorders a track's content order through the
/// Firestore path today has no way to persist "the amnesty baseline moved"
/// through either adapter in this wave. Needs a `stampReorderAt`-shaped
/// method added to [FirestoreCurriculumTrackRepository] itself before this
/// gap can close — flagged in the task report, not solved here.
class FirestoreCurriculumTrackRepositoryAdapter {
  FirestoreCurriculumTrackRepositoryAdapter({
    required Ref ref,
    FirebaseFunctions? functions,
  }) : _ref = ref,
       _functions = functions ?? FirebaseFunctions.instance;

  final Ref _ref;
  final FirebaseFunctions _functions;

  /// Re-reads `firestoreCurriculumTrackRepositoryProvider`, resolving to
  /// `null` exactly when it does (no active account, or no active learner
  /// profile). See `FirestoreBookmarkRepositoryAdapter._resolveOrNull`'s doc
  /// comment for why this re-reads on every call rather than caching.
  Future<FirestoreCurriculumTrackRepository?> _resolveOrNull() {
    return _ref.read(firestoreCurriculumTrackRepositoryProvider.future);
  }

  /// Like [_resolveOrNull], but throws
  /// [CurriculumTrackRepositoryNotReadyException] instead of returning
  /// `null` — for the lifecycle-transition methods, which have no natural
  /// "not ready" value of their own; see the class doc comment.
  Future<FirestoreCurriculumTrackRepository> _resolve() async {
    final repo = await _resolveOrNull();
    if (repo == null) {
      throw const CurriculumTrackRepositoryNotReadyException();
    }
    return repo;
  }

  /// Returns the track for [curriculumId], or `null` if it has never been
  /// activated OR the repository is not ready yet — see the class doc
  /// comment for why reads collapse "not ready" onto the interface's own
  /// empty value.
  Future<CurriculumTrackEntity?> getTrack(CurriculumId curriculumId) async {
    final repo = await _resolveOrNull();
    if (repo == null) return null;
    return repo.getTrack(curriculumId);
  }

  /// Live updates for [curriculumId]'s track. See the class doc comment's
  /// "Not-ready semantics" section for the one-shot-resolve limitation of
  /// every `watch*` method here.
  Stream<CurriculumTrackEntity?> watchTrack(CurriculumId curriculumId) async* {
    final repo = await _resolveOrNull();
    if (repo == null) {
      yield null;
      return;
    }
    yield* repo.watchTrack(curriculumId);
  }

  /// `false` when not ready — matches
  /// `FirestoreCurriculumTrackRepository.isActive`'s own null-collapse.
  Future<bool> isActive(CurriculumId curriculumId) async {
    final repo = await _resolveOrNull();
    if (repo == null) return false;
    return repo.isActive(curriculumId);
  }

  /// Every track for this profile (any state). `[]` when not ready.
  Future<List<CurriculumTrackEntity>> getAllTracks() async {
    final repo = await _resolveOrNull();
    if (repo == null) return const [];
    return repo.getAllTracks();
  }

  /// Live updates for [getAllTracks].
  Stream<List<CurriculumTrackEntity>> watchAllTracks() async* {
    final repo = await _resolveOrNull();
    if (repo == null) {
      yield const [];
      return;
    }
    yield* repo.watchAllTracks();
  }

  /// Every ACTIVE track for this profile, sorted by `curriculumId`. `[]`
  /// when not ready.
  Future<List<CurriculumTrackEntity>> getActiveTracks() async {
    final repo = await _resolveOrNull();
    if (repo == null) return const [];
    return repo.getActiveTracks();
  }

  /// Live updates for [getActiveTracks].
  Stream<List<CurriculumTrackEntity>> watchActiveTracks() async* {
    final repo = await _resolveOrNull();
    if (repo == null) {
      yield const [];
      return;
    }
    yield* repo.watchActiveTracks();
  }

  /// Curriculum-id projection of [getActiveTracks]. `[]` when not ready.
  Future<List<String>> getActiveCurriculumIds() async {
    final repo = await _resolveOrNull();
    if (repo == null) return const [];
    return repo.getActiveCurriculumIds();
  }

  /// Live updates for [getActiveCurriculumIds].
  Stream<List<String>> watchActiveCurriculumIds() async* {
    final repo = await _resolveOrNull();
    if (repo == null) {
      yield const [];
      return;
    }
    yield* repo.watchActiveCurriculumIds();
  }

  /// `0` when not ready.
  Future<int> countActiveTracks() async {
    final repo = await _resolveOrNull();
    if (repo == null) return 0;
    return repo.countActiveTracks();
  }

  /// Activates [curriculumId]'s track — see
  /// [FirestoreCurriculumTrackRepository.activateTrack]'s doc comment for
  /// the full insert-or-reactivate semantics this collapses three Drift
  /// entry points into. Throws
  /// [CurriculumTrackRepositoryNotReadyException] when not ready.
  Future<CurriculumTrackEntity> activateTrack(CurriculumId curriculumId) async {
    final repo = await _resolve();
    return repo.activateTrack(curriculumId);
  }

  /// Retires [curriculumId]'s track. Throws
  /// [CurriculumTrackRepositoryNotReadyException] when not ready, or
  /// [StateError] if [curriculumId] is this profile's only active track —
  /// see [FirestoreCurriculumTrackRepository.retireTrack]'s doc comment.
  Future<void> retireTrack(CurriculumId curriculumId) async {
    final repo = await _resolve();
    await repo.retireTrack(curriculumId);
  }

  /// Permanently deletes a curriculum track and its dependent data.
  ///
  /// ## Why this goes through a Cloud Function
  ///
  /// `firestore.rules` sets `allow delete: if false` on `curriculum_tracks`, so
  /// a client CANNOT delete one directly — that is deliberate, not an
  /// oversight. Deletion also has to fan out across sibling collections keyed
  /// by `curriculum_id`, which is not something a client should attempt
  /// non-atomically. `functions/src/deletes.ts` owns it.
  ///
  /// This is NOT interchangeable with [retireTrack] or `archiveTrack`. Both of
  /// those are soft and PRESERVE the config; this destroys it. The distinction
  /// is deliberate — see `CurriculumActivationService`'s doc comments, which
  /// warn that `deactivate` should be used "only where hard-deleting the config
  /// on deactivation is actually intended".
  ///
  /// Throws whatever the callable throws — notably `invalid-argument` if the
  /// profile ULID or curriculum key is empty, and `permission-denied` if the
  /// caller does not own the profile. Deliberately NOT swallowed: a delete that
  /// silently does nothing is indistinguishable from one that worked.
  Future<void> deleteTrackPermanently(CurriculumId curriculumId) async {
    final profileUlid = _ref.read(activeProfileDocIdProvider);
    if (profileUlid == null || profileUlid.isEmpty) {
      throw const CurriculumTrackRepositoryNotReadyException();
    }
    await _functions
        .httpsCallable('deleteCurriculumTrack')
        .call<Map<String, dynamic>>({
          // Both are STRINGS on the function side (deletes.ts:214-219) — it
          // was migrated to ULIDs already, so this must not pass an int.
          'profileId': profileUlid,
          'curriculumId': curriculumId.storageKey,
        });
  }

  /// Archives [curriculumId]'s track. Throws
  /// [CurriculumTrackRepositoryNotReadyException] when not ready, or
  /// [StateError] if [curriculumId] is this profile's only active track —
  /// see [FirestoreCurriculumTrackRepository.archiveTrack]'s doc comment.
  Future<void> archiveTrack(CurriculumId curriculumId) async {
    final repo = await _resolve();
    await repo.archiveTrack(curriculumId);
  }

  /// Resets the pace baseline for [curriculumId]. Throws
  /// [CurriculumTrackRepositoryNotReadyException] when not ready.
  Future<void> resetPace(CurriculumId curriculumId) async {
    final repo = await _resolve();
    await repo.resetPace(curriculumId);
  }
}

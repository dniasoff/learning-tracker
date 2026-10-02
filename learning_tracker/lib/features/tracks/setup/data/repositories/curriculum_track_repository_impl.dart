/// Firestore adapter for the curriculum-track lifecycle (activate / retire /
/// archive / query) — part of Epic C's feature-by-feature rewire onto
/// Firestore (see `lib/data/firestore/repository_providers.dart`'s library
/// doc comment, "Reaching this file from lib/features/** — audit check
/// 102", and `lib/data/repositories/firestore_curriculum_track_repository.dart`'s
/// class doc comment for what THIS file wraps).
library;

import 'dart:async';

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
/// - [activateTrack] / [retireTrack] / [archiveTrack] — no
///   natural "nothing happened" value for a lifecycle transition or a state
///   mutation to reuse, so these throw
///   [CurriculumTrackRepositoryNotReadyException] instead, exactly the write
///   side of [BookmarkRepositoryNotReadyException]'s reasoning.
/// - [watchTrack] / [watchAllTracks] / [watchActiveTracks] /
///   [watchActiveCurriculumIds] — the underlying provider is itself a
///   `FutureProvider` (account/profile resolution is async), so each stream
///   remains subscribed to that provider and forwards the resolved
///   repository's stream whenever the account/profile becomes ready or
///   changes. A not-ready state produces no fabricated empty emission.
///
/// ## Reorder amnesty
///
/// No method here stamps `last_reorder_at`: since DNI-476 the AD-35
/// reorder-amnesty instant is the `mainTrackOrder` change-log entry a
/// reorder writes (`FirestoreTrackLearningOrderRepository`).
class FirestoreCurriculumTrackRepositoryAdapter {
  FirestoreCurriculumTrackRepositoryAdapter({required Ref ref}) : _ref = ref;

  final Ref _ref;

  /// Emits whether the active profile's Firestore track repository is ready.
  ///
  /// This is the feature-owned readiness seam for presentation providers.
  /// Consumers must not depend on the raw repository-resolution provider in
  /// `lib/data/firestore/`; this adapter is the boundary that owns that
  /// dependency.
  Stream<bool> watchReadiness() {
    final controller = StreamController<bool>();
    ProviderSubscription<AsyncValue<FirestoreCurriculumTrackRepository?>>?
    repositorySubscription;

    controller.onListen = () {
      repositorySubscription = _ref
          .listen<AsyncValue<FirestoreCurriculumTrackRepository?>>(
            firestoreCurriculumTrackRepositoryProvider,
            (_, next) => controller.add(next.hasValue && next.value != null),
            fireImmediately: true,
          );
    };
    controller.onCancel = () async {
      repositorySubscription?.close();
      await controller.close();
    };

    return controller.stream;
  }

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
  /// "Not-ready semantics" section for the re-subscription behavior shared
  /// by every `watch*` method here.
  Stream<CurriculumTrackEntity?> watchTrack(CurriculumId curriculumId) =>
      _watchResolved((repo) => repo.watchTrack(curriculumId));

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
  Stream<List<CurriculumTrackEntity>> watchAllTracks() =>
      _watchResolved((repo) => repo.watchAllTracks());

  /// Every ACTIVE track for this profile, sorted by `curriculumId`. `[]`
  /// when not ready.
  Future<List<CurriculumTrackEntity>> getActiveTracks() async {
    final repo = await _resolveOrNull();
    if (repo == null) return const [];
    return repo.getActiveTracks();
  }

  /// Live updates for [getActiveTracks].
  Stream<List<CurriculumTrackEntity>> watchActiveTracks() =>
      _watchResolved((repo) => repo.watchActiveTracks());

  /// Curriculum-id projection of [getActiveTracks]. `[]` when not ready.
  Future<List<String>> getActiveCurriculumIds() async {
    final repo = await _resolveOrNull();
    if (repo == null) return const [];
    return repo.getActiveCurriculumIds();
  }

  /// Live updates for [getActiveCurriculumIds].
  Stream<List<String>> watchActiveCurriculumIds() =>
      _watchResolved((repo) => repo.watchActiveCurriculumIds());

  /// Keeps a stream alive across the asynchronous account/profile resolution
  /// that supplies the Firestore repository. The old async* implementation
  /// resolved once before its first yield; a null or error at that moment
  /// completed the stream and made later readiness invisible to consumers.
  Stream<T> _watchResolved<T>(
    Stream<T> Function(FirestoreCurriculumTrackRepository repo) open,
  ) {
    final controller = StreamController<T>();
    StreamSubscription<T>? repositoryStream;
    ProviderSubscription<AsyncValue<FirestoreCurriculumTrackRepository?>>?
    repositorySubscription;
    var bindGeneration = 0;
    var isClosed = false;

    Future<void> bind(
      AsyncValue<FirestoreCurriculumTrackRepository?> state,
    ) async {
      final generation = ++bindGeneration;
      await repositoryStream?.cancel();
      repositoryStream = null;
      if (isClosed || generation != bindGeneration) return;

      if (state.hasError) {
        controller.addError(state.error!, state.stackTrace);
        return;
      }
      if (!state.hasValue || state.value == null) return;

      repositoryStream = open(
        state.value!,
      ).listen(controller.add, onError: controller.addError);
    }

    controller.onListen = () {
      repositorySubscription = _ref
          .listen<AsyncValue<FirestoreCurriculumTrackRepository?>>(
            firestoreCurriculumTrackRepositoryProvider,
            (_, next) => unawaited(bind(next)),
            fireImmediately: true,
          );
    };
    controller.onCancel = () async {
      isClosed = true;
      await repositoryStream?.cancel();
      repositorySubscription?.close();
      await controller.close();
    };

    return controller.stream;
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

  /// AD-38 "Remove track" (DNI-476): one governed action that sets
  /// `ended_at` on the track and tombstones its live sub-tracks — never a
  /// delete; learning events and points are untouched, and [reAddTrack]
  /// brings the track back with its prior config, progress and history.
  /// Throws [CurriculumTrackRepositoryNotReadyException] when not ready,
  /// [StateError] for the profile's only active track, and
  /// `GovernedWriteRejectedException` when the write is refused.
  Future<void> removeTrack(CurriculumId curriculumId) async {
    final repo = await _resolve();
    await repo.removeTrack(curriculumId);
  }

  /// AD-38 "Re-add": clears the removed track's `ended_at` through a logged
  /// change. Throws [CurriculumTrackRepositoryNotReadyException] when not
  /// ready.
  Future<void> reAddTrack(CurriculumId curriculumId) async {
    final repo = await _resolve();
    await repo.reAddTrack(curriculumId);
  }

  /// Archives [curriculumId]'s track. Throws
  /// [CurriculumTrackRepositoryNotReadyException] when not ready, or
  /// [StateError] if [curriculumId] is this profile's only active track —
  /// see [FirestoreCurriculumTrackRepository.archiveTrack]'s doc comment.
  Future<void> archiveTrack(CurriculumId curriculumId) async {
    final repo = await _resolve();
    await repo.archiveTrack(curriculumId);
  }
}

/// Feature-owned readiness signal for track presentation consumers.
final curriculumTrackRepositoryReadinessProvider = StreamProvider<bool>((ref) {
  final adapter = FirestoreCurriculumTrackRepositoryAdapter(ref: ref);
  return adapter.watchReadiness();
});

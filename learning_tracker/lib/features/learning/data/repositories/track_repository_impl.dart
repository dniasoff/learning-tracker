import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_curriculum_track_repository.dart';
import 'package:learning_tracker/features/learning/domain/repositories/track_repository.dart';

/// Thrown by [FirestoreTrackRepositoryAdapter]'s write methods when
/// `firestoreCurriculumTrackRepositoryProvider` resolves to `null` — no active
/// account, or no active learner profile yet. See
/// [BookmarkRepositoryNotReadyException] for the read-vs-write split this mirrors:
/// reads reuse a natural "nothing yet" value, writes have no such value and throw.
class TrackRepositoryNotReadyException implements Exception {
  const TrackRepositoryNotReadyException();

  @override
  String toString() =>
      'TrackRepositoryNotReadyException: firestoreCurriculumTrackRepositoryProvider '
      'resolved to null (no active account, or no active learner profile yet) — '
      'cannot complete a track write until one is active.';
}

/// Firestore-backed adapter over [FirestoreCurriculumTrackRepository],
/// implementing the [TrackRepository] interface for the learning feature.
///
/// Follows the pattern established by [FirestoreBookmarkRepositoryAdapter]
/// (`lib/features/learning/data/repositories/bookmark_repository_impl.dart`):
/// - Takes a [Ref] and re-resolves the provider on every call
/// - Construction stays synchronous; the provider is an async nullable FutureProvider
/// - Write methods throw [TrackRepositoryNotReadyException] when not ready
/// - The legacy `profileId` parameter (Drift int) is ignored — Firestore repos
///   are profile-scoped by ULID via the provider.
class FirestoreTrackRepositoryAdapter implements TrackRepository {
  FirestoreTrackRepositoryAdapter({required Ref ref}) : _ref = ref;

  final Ref _ref;

  /// Re-reads `firestoreCurriculumTrackRepositoryProvider`, resolving to `null`
  /// exactly when it does (no active account, or no active learner profile).
  /// Re-reads on every call rather than caching so profile switches mid-session
  /// are picked up automatically.
  Future<FirestoreCurriculumTrackRepository?> _resolveOrNull() {
    return _ref.read(firestoreCurriculumTrackRepositoryProvider.future);
  }

  /// Like [_resolveOrNull], but throws [TrackRepositoryNotReadyException]
  /// instead of returning `null` — for write methods with no natural
  /// "not ready" value to reuse.
  Future<FirestoreCurriculumTrackRepository> _resolve() async {
    final repo = await _resolveOrNull();
    if (repo == null) {
      throw const TrackRepositoryNotReadyException();
    }
    return repo;
  }

  @override
  Future<void> initializeDefaultTracks(
    CurriculumId curriculumId, {
    int profileId = 0,
  }) async {
    final repo = await _resolve();
    await repo.activateTrack(curriculumId);
  }
}

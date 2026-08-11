/// Firestore-backed [ProgressRepository] adapter — follows the reference
/// pattern `FirestoreBookmarkRepositoryAdapter`
/// (`lib/features/learning/data/repositories/bookmark_repository_impl.dart`).
/// Read that class's doc comment first (the numbered "pattern to copy"
/// list); this file only calls out what is DIFFERENT for progress.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_completion_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_curriculum_scope_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_curriculum_track_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_learning_ledger_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_profile_program_repository.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_entity.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_tier_filter.dart';
import 'package:learning_tracker/features/learning/domain/entities/learning_ledger_entry.dart';
import 'package:learning_tracker/features/progress/domain/repositories/progress_repository.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_scope.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/profile_program.dart';

/// Firestore-backed [ProgressRepository] adapter.
///
/// ## Delegates to the completions repository — does not own one
///
/// `docs/firestore-rewrite-map.md`'s progress note: "progress uses GROUP
/// BY/COUNT(DISTINCT) via the completions DAO... those become client-side
/// computation over a bounded query. The completions adapter is another
/// agent's — do NOT build one." This class therefore never imports
/// `cloud_firestore` and never constructs a `FirestoreCompletionRepository`
/// itself — every read goes through `firestoreCompletionRepositoryProvider`
/// (`lib/data/firestore/repository_providers.dart`), which is already wired
/// to a real, ready instance. Like every provider in that file (see
/// [_resolveOrNull]), it resolves `null` only while no account or learner
/// profile is active yet — the same "not ready yet, show a loading/empty
/// state" contract every provider there documents, not a stub — and every
/// method below falls back to its "not ready" value in exactly that case.
///
/// This class is not itself wired into `progressRepositoryProvider` yet —
/// that provider (`progress_providers.dart`) still returns the Drift-era
/// `ProgressRepositoryImpl`. Rewiring the progress feature onto this
/// adapter is a separate task that has not happened yet.
///
/// [FirestoreCompletionRepository]'s own aggregate methods
/// (`getTrackTypeBreakdownForCurriculum`, `getAggregateCountForCurriculum`)
/// already compute client-side over a bounded, paginated query — see that
/// class's doc comment, "Aggregates are computed client-side" — so
/// [getTrackBreakdown] and [getAggregateCount] below are a direct,
/// behavior-preserving delegation: same curriculum+profile scoping as the
/// Drift-era `CompletionDao.getTrackBreakdownByProfile` /
/// `getAggregateCountByProfile` (no tier/source filter in either — verified
/// by reading both DAO methods), just re-homed onto the Firestore-side
/// equivalents.
///
/// ## `getCompletionsByCurriculum` / `getAllCompletions`: resolved — owner
/// decision 3
///
/// [ProgressRepository]'s interface used to return `List<Completion>` — the
/// Drift class from `lib/core/database/daos/completion_dao.dart`, which
/// carries an autoincrement `int id`, an `int profileId`, and an `int
/// trackId` — none of which [FirestoreCompletionRepository]'s
/// `CompletionEntity` has (see that class's own doc comment: "Firestore-
/// shaped — not a port of the Drift-era `Completion` class"). Owner decision
/// 3 (`docs/firestore-rewrite-map.md`) widened [ProgressRepository] to
/// return `CompletionEntity` directly instead, after confirming the two
/// consumers of these methods (`completionHistoryForCurriculumProvider`,
/// `allCompletionHistoryProvider`) never read `.id`/`.profileId`/`.trackId`
/// — they pass the list straight through. Both methods below now delegate
/// directly, the same shape as [getTrackBreakdown]/[getAggregateCount].
/// Thrown by [FirestoreProgressRepositoryAdapter]'s reads when
/// `firestoreCompletionRepositoryProvider` resolves to `null`.
///
/// Owner ruling D-E, applied to ACHIEVEMENT-shaped reads. Every method here
/// answers "how much has this learner completed", where `0` / `[]` / `{}` is
/// indistinguishable from a truthful answer — so a not-ready backend previously
/// rendered as "you have achieved nothing", invisibly, to the learner and to
/// every gate.
///
/// This deliberately does NOT extend to configuration-shaped adapters
/// (curriculum tracks, learning order, study-day configs, goals): an empty
/// CONFIGURATION list is a legitimate state the UI already renders, whereas a
/// fabricated achievement total is not.
class ProgressRepositoryNotReadyException implements Exception {
  const ProgressRepositoryNotReadyException([
    this.providerName = 'firestoreCompletionRepositoryProvider',
  ]);

  final String providerName;

  @override
  String toString() =>
      'ProgressRepositoryNotReadyException: '
      '$providerName resolved to null (no active '
      'account, or no active learner profile, yet) — refusing to report a '
      'progress figure that would be indistinguishable from a real zero.';
}

/// Thrown when an ACHIEVEMENT-shaped read returns empty and the local
/// Firestore cache has never been populated from the server.
///
/// The cold-start-offline case that [ProgressRepositoryNotReadyException] does
/// NOT cover: there, no profile has resolved; here, one has, and the query
/// legitimately returned nothing — but from a cache that holds nothing to
/// begin with. Rendering that as `0` tells a learner with years of history
/// that they have achieved nothing.
///
/// An empty cached read is genuinely ambiguous on its own — a brand-new
/// profile looks identical — so this is raised only when the profile document
/// is ALSO absent from the cache, which is what proves the cache is cold
/// rather than the learner new.
///
/// Deliberately an exception rather than a nullable/flag return:
/// `progress_tier_counter_row.dart` already gates on `hasValue`, so an errored
/// provider keeps its placeholder. Throwing routes this into UI handling that
/// is already correct.
class ProgressDataNotHydratedException implements Exception {
  const ProgressDataNotHydratedException();

  @override
  String toString() =>
      'ProgressDataNotHydratedException: the local Firestore cache has not '
      'been populated for this profile, so an empty result cannot be '
      'distinguished from a real zero — refusing to report one.';
}

class FirestoreProgressRepositoryAdapter implements ProgressRepository {
  FirestoreProgressRepositoryAdapter({required Ref ref}) : _ref = ref;

  final Ref _ref;

  /// Re-reads `firestoreCompletionRepositoryProvider`, resolving to `null`
  /// exactly when it does (no active account, or no active learner
  /// profile). Re-resolved on every call rather than cached — see
  /// `FirestoreBookmarkRepositoryAdapter`'s class doc comment (point 3) for
  /// why.
  /// Like [_resolveOrNull], but throws — see
  /// [ProgressRepositoryNotReadyException] for why every read here throws.
  Future<FirestoreCompletionRepository> _resolve() async {
    final repo = await _resolveOrNull();
    if (repo == null) {
      throw const ProgressRepositoryNotReadyException();
    }
    return repo;
  }

  /// Raises [ProgressDataNotHydratedException] when an empty achievement read
  /// cannot be trusted, i.e. when the local cache was never populated.
  ///
  /// Called ONLY on an empty result: a non-empty one is self-evidently
  /// hydrated, so the common path adds no Firestore read at all, and the
  /// ambiguous path adds a single document read normally served from cache.
  /// Read cost is a live constraint on this project, not an afterthought.
  Future<void> _assertHydrated() async {
    // Read synchronously: `activeProfileDocIdProvider` is a
    // NotifierProvider<ActiveProfileDocId, String?>, NOT a FutureProvider —
    // it has no `.future`.
    final profileId = _ref.read(activeProfileDocIdProvider);
    if (profileId == null) {
      throw const ProgressRepositoryNotReadyException(
        'activeProfileDocIdProvider',
      );
    }
    final repo = await _ref.read(
      firestoreLearnerProfileRepositoryProvider.future,
    );
    if (repo == null) {
      throw const ProgressRepositoryNotReadyException(
        'firestoreLearnerProfileRepositoryProvider',
      );
    }
    if (!await repo.hasHydratedCache(profileId)) {
      throw const ProgressDataNotHydratedException();
    }
  }

  /// Resolves a storage key to its [CurriculumId], THROWING on an unknown key.
  ///
  /// Previously an unrecognised key silently produced `0` / `[]` / `{}` — the
  /// same fabricated-achievement defect as a not-ready backend, but caused by a
  /// programming error rather than timing. Mis-attributing a learner's progress
  /// to "nothing" must never be the quiet path.
  static CurriculumId _curriculumFor(String storageKey) {
    final id = CurriculumId.fromStorageKey(storageKey);
    if (id == null) {
      throw ArgumentError('Unknown curriculumId: $storageKey');
    }
    return id;
  }

  Future<FirestoreCompletionRepository?> _resolveOrNull() {
    return _ref.read(firestoreCompletionRepositoryProvider.future);
  }

  // ── Tracks / programs / scopes (configuration-shaped — empty is valid) ──

  /// Resolves `firestoreCurriculumTrackRepositoryProvider`, returning `null`
  /// when no profile is active yet. Configuration-shaped callers fall back to
  /// an empty list rather than throwing — see the class doc comment's D-E
  /// distinction.
  Future<FirestoreCurriculumTrackRepository?> _resolveTracksOrNull() {
    return _ref.read(firestoreCurriculumTrackRepositoryProvider.future);
  }

  /// Resolves `firestoreProfileProgramRepositoryProvider`, returning `null`
  /// when no profile is active yet.
  Future<FirestoreProfileProgramRepository?> _resolveProgramsOrNull() {
    return _ref.read(firestoreProfileProgramRepositoryProvider.future);
  }

  /// Resolves `firestoreCurriculumScopeRepositoryProvider`, returning `null`
  /// when no profile is active yet.
  Future<FirestoreCurriculumScopeRepository?> _resolveScopesOrNull() {
    return _ref.read(firestoreCurriculumScopeRepositoryProvider.future);
  }

  // ── Learning ledger (achievement-shaped — throws on not-ready) ─────────

  /// Resolves `firestoreLearningLedgerRepositoryProvider`, returning `null`
  /// when no profile is active yet. Used by [_resolveLedger] below.
  Future<FirestoreLearningLedgerRepository?> _resolveLedgerOrNull() {
    return _ref.read(firestoreLearningLedgerRepositoryProvider.future);
  }

  /// Like [_resolveLedgerOrNull], but throws — see
  /// [ProgressRepositoryNotReadyException] for why every achievement-shaped
  /// read here throws.
  Future<FirestoreLearningLedgerRepository> _resolveLedger() async {
    final repo = await _resolveLedgerOrNull();
    if (repo == null) {
      throw const ProgressRepositoryNotReadyException(
        'firestoreLearningLedgerRepositoryProvider',
      );
    }
    return repo;
  }

  @override
  Future<Map<String, int>> getTrackBreakdown(String curriculumId) async {
    final repo = await _resolve();
    final id = _curriculumFor(curriculumId);
    final result = await repo.getTrackTypeBreakdownForCurriculum(id);
    if (result.isEmpty) await _assertHydrated();
    return result;
  }

  @override
  Future<int> getAggregateCount(String curriculumId) async {
    final repo = await _resolve();
    final id = _curriculumFor(curriculumId);
    final result = await repo.getAggregateCountForCurriculum(id);
    if (result == 0) await _assertHydrated();
    return result;
  }

  @override
  Future<List<CompletionEntity>> getCompletionsByCurriculum(
    String curriculumId,
  ) async {
    final repo = await _resolve();
    final id = _curriculumFor(curriculumId);
    final result = await repo.getCompletionsForCurriculum(id);
    if (result.isEmpty) await _assertHydrated();
    return result;
  }

  @override
  Future<List<CompletionEntity>> getAllCompletions() async {
    final repo = await _resolve();
    // No curriculumId filter + CompletionTierFilter.lifetime == every
    // completion in the collection (see
    // FirestoreCompletionRepository.getCompletionsByTier's doc comment:
    // `trackAchievement`/`lifetime` return the same result set here, since
    // `completions` can only ever hold `live`/`bulkInTrack` documents) —
    // the same "no tier filter" scope the Drift-era
    // `CompletionDao.getCompletionsByProfile` this replaces had.
    final result = await repo.getCompletionsByTier(
      tier: CompletionTierFilter.lifetime,
    );
    if (result.isEmpty) await _assertHydrated();
    return result;
  }

  /// The complete lifetime learning record, across every curriculum — the
  /// "track everything I have learnt over my lifetime" feature itself.
  /// Delegates to [FirestoreLearningLedgerRepository.getLifetimeLedger].
  ///
  /// Achievement-shaped read: throws [ProgressRepositoryNotReadyException]
  /// when no profile is active yet (D-E) — a fabricated empty list here would
  /// be indistinguishable from "nothing ever learned".
  Future<List<LearningLedgerEntry>> getAllLedgerEntries() async {
    final repo = await _resolveLedger();
    final result = await repo.getLifetimeLedger();
    if (result.isEmpty) await _assertHydrated();
    return result;
  }

  /// Lifetime learning record for one curriculum. Delegates to
  /// [FirestoreLearningLedgerRepository.getLedgerForCurriculum].
  ///
  /// Achievement-shaped read — throws [ProgressRepositoryNotReadyException]
  /// when no profile is active yet (D-E).
  Future<List<LearningLedgerEntry>> getLedgerEntriesByCurriculum(
    String curriculumId,
  ) async {
    final repo = await _resolveLedger();
    final id = _curriculumFor(curriculumId);
    final result = await repo.getLedgerForCurriculum(id);
    if (result.isEmpty) await _assertHydrated();
    return result;
  }

  /// Every curriculum track for the active profile (any state). Delegates to
  /// [FirestoreCurriculumTrackRepository.getAllTracks].
  ///
  /// Configuration-shaped read — returns an empty list when no profile is
  /// active yet, rather than throwing.
  Future<List<CurriculumTrackEntity>> getAllTracks() async {
    final repo = await _resolveTracksOrNull();
    if (repo == null) return const [];
    return repo.getAllTracks();
  }

  /// Every program enrollment across this profile's curricula, keyed by
  /// `curriculumId.storageKey`. Delegates to
  /// [FirestoreProfileProgramRepository.getAllPrograms], partitioning the
  /// list into a map.
  ///
  /// Configuration-shaped read — returns an empty map when no profile is
  /// active yet.
  Future<Map<String, ProfileProgramEntity>> getProgramsByCurriculum() async {
    final repo = await _resolveProgramsOrNull();
    if (repo == null) return const <String, ProfileProgramEntity>{};
    final programs = await repo.getAllPrograms();
    return {for (final p in programs) p.curriculumId.storageKey: p};
  }

  /// Every scope selection for [curriculumId]. Delegates to
  /// [FirestoreCurriculumScopeRepository.getScopes].
  ///
  /// Configuration-shaped read — returns an empty list when no profile is
  /// active yet (a curriculum with no scope override tracks the whole
  /// curriculum, a legitimate configuration).
  Future<List<CurriculumScopeEntity>> getScopes(CurriculumId curriculumId) async {
    final repo = await _resolveScopesOrNull();
    if (repo == null) return const [];
    return repo.getScopes(curriculumId);
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/learning/completion_constants.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_learning_ledger_repository.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/domain/entities/learning_ledger_entry.dart';
import 'package:learning_tracker/features/learning/domain/repositories/learning_ledger_repository.dart';

/// Thrown by [FirestoreLearningLedgerRepositoryAdapter] when
/// `firestoreLearningLedgerRepositoryProvider` resolves to `null` — i.e. there
/// is no active account, or no active learner profile, yet.
///
/// Owner ruling D-E: a path that cannot reach its backend fails LOUDLY. It
/// deliberately does NOT return an empty ledger, because "you have learned
/// nothing" is indistinguishable from a legitimately empty ledger and would be
/// invisible to every gate — the exact silent-empty defect recorded against the
/// stage-definition adapter.
///
/// Mirrors `CompletionRepositoryNotReadyException`'s shape exactly.
class LearningLedgerRepositoryNotReadyException implements Exception {
  const LearningLedgerRepositoryNotReadyException();

  @override
  String toString() =>
      'LearningLedgerRepositoryNotReadyException: '
      'firestoreLearningLedgerRepositoryProvider resolved to null (no active '
      'account, or no active learner profile, yet) — cannot read or write the '
      'learning ledger until one is active.';
}

/// Firestore-backed [LearningLedgerRepository], replacing the Drift
/// implementation this file used to hold.
///
/// **The outbox is gone and is not replaced.** The Drift version wrote a ledger
/// row and an outbox row inside one transaction so a crash could not strand one
/// without the other. With Firestore the write IS the cloud write, so there is
/// no second row and nothing to keep in step. A failed write throws (D-E); it is
/// not queued for a later drain, because no drain exists.
///
/// **Profile scoping.** `FirestoreLearningLedgerRepository` is constructed for
/// one profile — the ledger lives at
/// `learner_profiles/{profileId}/learning_ledger` — so no method here takes a
/// `profileId`. [_activeProfileUlid] is held only to answer "is this child
/// marking their OWN completion?" in the permission gate.
///
/// **Construction.** Like [FirestoreCompletionRepositoryAdapter], this re-reads
/// its provider on every call rather than caching a resolved repository, so a
/// profile switch is picked up without rebuilding the adapter.
class FirestoreLearningLedgerRepositoryAdapter
    implements LearningLedgerRepository {
  FirestoreLearningLedgerRepositoryAdapter({
    required Ref ref,
    required ProfileMode activeProfileMode,
    this.parentPinSessionMatchesActiveProfile = false,
  }) : _ref = ref,
       _activeProfileMode = activeProfileMode;

  final Ref _ref;

  /// The ACTIVE profile's ULID (AD-24) — a `String`, not a Drift row id.
  ///
  /// Read here rather than injected, because `activeProfileDocIdProvider` lives
  /// in the data-access ring and `check_dependency_direction` (AD-23/AD-28)
  /// forbids `features/**/presentation/**` from importing that ring. This class
  /// sits under `features/learning/data/repositories/`, which the check exempts,
  /// so the dependency belongs here and not in the provider that builds it.
  ///
  /// `null` when no profile is active. A null value can never equal a real
  /// `markedBy`, so the permission gate below is inert in that state — which is
  /// correct, because [_resolve] then throws
  /// [LearningLedgerRepositoryNotReadyException] before any write happens. No
  /// write can slip through un-gated.
  String? get _activeProfileUlid => _ref.read(activeProfileDocIdProvider);

  final ProfileMode _activeProfileMode;

  /// When true, parent PIN was verified this session for [_activeProfileUlid].
  final bool parentPinSessionMatchesActiveProfile;

  Future<FirestoreLearningLedgerRepository> _resolve() async {
    final repo = await _ref.read(
      firestoreLearningLedgerRepositoryProvider.future,
    );
    if (repo == null) {
      throw const LearningLedgerRepositoryNotReadyException();
    }
    return repo;
  }

  /// AC 5: a child may not manually mark their OWN completion without an
  /// active parent PIN session for that same profile.
  ///
  /// Deliberately evaluated BEFORE [_resolve], so a permission violation throws
  /// [ChildSelfMarkException] whether or not the backend happens to be
  /// reachable. Ordering it the other way would surface a permission failure as
  /// a connectivity failure.
  void _assertManualMarkPermission({
    required String markedBy,
    required bool isManual,
  }) {
    if (isManual &&
        _activeProfileMode.isChild &&
        markedBy == _activeProfileUlid &&
        !parentPinSessionMatchesActiveProfile) {
      throw const ChildSelfMarkException();
    }
  }

  /// Rule 4 / DEC-19: only a `live` source stamps the real moment. Every other
  /// source writes [kBulkPriorSentinelDate], so a siyum earned by a bulk mark
  /// does not surface as today's recent activity or inflate streak and
  /// points-per-day reads.
  static DateTime _completedAtFor(CompletionSource source) =>
      source == CompletionSource.live
      ? DateTimeFactory.nowUtc()
      : kBulkPriorSentinelDate;

  @override
  Future<LearningLedgerEntry> recordCompletion({
    required CurriculumId curriculumId,
    required String entryScope,
    required String unitIdentifier,
    required String unitDisplayNameHe,
    required String unitDisplayNameEn,
    required String trackType,
    required String markedBy,
    required bool isManual,
    CompletionSource source = CompletionSource.live,
  }) async {
    _assertManualMarkPermission(markedBy: markedBy, isManual: isManual);
    final repo = await _resolve();
    return repo.recordCompletion(
      curriculumId: curriculumId,
      entryScope: entryScope,
      unitIdentifier: unitIdentifier,
      unitDisplayNameHe: unitDisplayNameHe,
      unitDisplayNameEn: unitDisplayNameEn,
      trackType: trackType,
      completedAt: _completedAtFor(source),
      markedBy: markedBy,
      isManual: isManual,
      source: source,
    );
  }

  @override
  Future<List<LearningLedgerEntry>> recordCompletionsBatch(
    List<LedgerEntryDraft> items, {
    CompletionSource source = CompletionSource.lifetimeOnly,
  }) async {
    // Every item is permission-checked BEFORE any write, so a batch either
    // writes in full or throws before its first chunk commits — matching
    // FirestoreLearningLedgerRepository.recordCompletionsBatch's own
    // validate-up-front discipline rather than partially committing.
    for (final item in items) {
      _assertManualMarkPermission(
        markedBy: item.markedBy,
        isManual: item.isManual,
      );
    }
    if (items.isEmpty) return const [];
    final repo = await _resolve();
    return repo.recordCompletionsBatch(
      items,
      completedAt: _completedAtFor(source),
      source: source,
    );
  }

  @override
  Future<List<LearningLedgerEntry>> getLifetimeLedger() async {
    final repo = await _resolve();
    return repo.getLifetimeLedger();
  }

  @override
  Future<List<LearningLedgerEntry>> getLedgerByCurriculum(
    CurriculumId curriculumId,
  ) async {
    final repo = await _resolve();
    return repo.getLedgerForCurriculum(curriculumId);
  }

  @override
  Future<Map<String, int>> getCompletionStats(CurriculumId curriculumId) async {
    final repo = await _resolve();
    return repo.getCompletionStats(curriculumId);
  }
}

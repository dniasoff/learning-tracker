/// Firestore-backed read facade over the lifetime learning ledger, owned by
/// `gamification/` rather than reaching across the feature boundary into
/// `learning/` directly — see the class doc comment's "Why this exists in
/// gamification, not learning" section for why a distinct file is warranted
/// even though `lib/features/learning/data/repositories/
/// learning_ledger_repository_impl.dart` already implements the same
/// underlying collection for the `learning` feature's own needs.
///
/// Follows the reference pattern `FirestoreBookmarkRepositoryAdapter`
/// (`lib/features/learning/data/repositories/bookmark_repository_impl.dart`)
/// as closely as a repository with no existing abstract interface can — see
/// `FirestoreStreakStateRepository`'s doc comment (same directory) for the
/// same "no interface to implement" situation and how this file mirrors the
/// pattern anyway.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_learning_ledger_repository.dart';
import 'package:learning_tracker/features/learning/domain/entities/learning_ledger_entry.dart';

/// Firestore-backed, gamification-owned read facade over
/// `learning_ledger/{ulid}`.
///
/// ## Why this exists in `gamification`, not `learning`
///
/// `LearningLedgerRepository`
/// (`lib/features/learning/domain/repositories/learning_ledger_repository.dart`)
/// and its Drift implementation already own the FULL read/write surface for
/// this collection, scoped to the `learning` feature. Rule 2 (no
/// cross-feature deep imports — `lib/CLAUDE.md`) means `gamification/` may
/// only reach `learning/`'s barrel file, never
/// `learning/data/repositories/learning_ledger_repository_impl.dart`
/// directly, and that barrel is not this task's to widen (the `learning`
/// feature is being rewired concurrently by a different task — see
/// `docs/firestore-rewrite-map.md`'s task-split notes). Gamification
/// features that eventually need lifetime-completion counts (e.g. an
/// achievement/badge tied to "learned X units total") therefore get their
/// own minimal read facade here, going through the SAME sanctioned seam
/// every other Firestore adapter in this rewrite uses —
/// `firestoreLearningLedgerRepositoryProvider`
/// (`lib/data/firestore/repository_providers.dart`) — rather than importing
/// `cloud_firestore` itself (forbidden outside `lib/core/sync/`,
/// `lib/core/auth/`, `lib/data/firestore/`, `lib/data/repositories/` — see
/// `tool/check_firebase_confinement.dart`) or reaching into `learning/`'s
/// internals.
///
/// ## Not wired to any current caller
///
/// Nothing under `lib/features/gamification/` reads lifetime-ledger data
/// today (verified: no reference to `LearningLedger`/`learning_ledger`
/// exists anywhere in `lib/features/gamification/` prior to this file) —
/// unlike [FirestoreStreakStateRepository], which replaces an existing
/// `StreakService`/`StreakStateService` read path. This class exists ready
/// for a future gamification consumer (a lifetime-achievement feature), not
/// because one exists yet — "an unflipped adapter is fine," per this task's
/// brief.
///
/// ## Read-only, mirroring [FirestoreStreakStateRepository]
///
/// Only the two read methods gamification would plausibly need are
/// exposed — the full write surface
/// ([FirestoreLearningLedgerRepository.recordCompletion] /
/// `recordCompletionsBatch`) belongs to whichever call site actually
/// records a completion (the `learning` feature's completion-recording
/// flow), not here.
class FirestoreGamificationLedgerRepository {
  FirestoreGamificationLedgerRepository({required Ref ref}) : _ref = ref;

  final Ref _ref;

  /// Re-reads `firestoreLearningLedgerRepositoryProvider`, resolving to
  /// `null` exactly when it does (no active account, or no active learner
  /// profile). Re-resolved on every call rather than cached — see
  /// `FirestoreBookmarkRepositoryAdapter`'s class doc comment (point 3).
  Future<FirestoreLearningLedgerRepository?> _resolveOrNull() {
    return _ref.read(firestoreLearningLedgerRepositoryProvider.future);
  }

  /// The whole lifetime ledger for this profile, across every curriculum —
  /// not-ready reduces to an empty list, the natural-empty-value convention
  /// every other adapter in this rewire uses for a non-nullable `List`
  /// return type.
  Future<List<LearningLedgerEntry>> getLifetimeLedger() async {
    final repo = await _resolveOrNull();
    if (repo == null) return const [];
    return repo.getLifetimeLedger();
  }

  /// Completion stats for [curriculumId] — `{'total', 'manual', 'auto'}`,
  /// mirroring [FirestoreLearningLedgerRepository.getCompletionStats]'s
  /// shape exactly. Not-ready reduces to all-zero counts.
  Future<Map<String, int>> getCompletionStats(CurriculumId curriculumId) async {
    final repo = await _resolveOrNull();
    if (repo == null) return const {'total': 0, 'manual': 0, 'auto': 0};
    return repo.getCompletionStats(curriculumId);
  }
}

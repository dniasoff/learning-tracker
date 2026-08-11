import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_entity.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_tier_filter.dart';
import 'package:learning_tracker/features/progress/data/repositories/firestore_progress_repository_adapter.dart'
    show ProgressRepositoryNotReadyException;
import 'package:learning_tracker/features/progress/domain/services/chart_data_service.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';

/// Firestore-backed [ChartDataRepository] — the read seam [ChartDataService]
/// uses for every chart on the Progress / Recent Activity screens. Follows
/// the `FirestoreBookmarkRepositoryAdapter` pattern
/// (`lib/features/learning/data/repositories/bookmark_repository_impl.dart`)
/// — read that class's doc comment first; this one only calls out what is
/// DIFFERENT here.
///
/// ## Achievement / configuration split (D-E) — enforced HERE, not in
/// [ChartDataService]
///
/// [ChartDataRepository]'s own class doc comment documents the split:
/// [getCompletionsByTier] / [getCompletionsByCurriculum] are
/// achievement-shaped (an empty list is indistinguishable from "learned
/// nothing", so a not-ready backend THROWS rather than returning `[]`);
/// [getGoals] is configuration-shaped (an empty list is a legitimate "no
/// goal configured" state the UI already renders). This class is where that
/// policy is actually implemented — [ChartDataService] itself never resolves
/// a Firestore repository or decides readiness; see this file's siblings for
/// why (AD-23/AD-28, `lib/features/**/domain/**` may not import the data
/// ring).
///
/// Reuses [ProgressRepositoryNotReadyException] (defined in
/// `firestore_progress_repository_adapter.dart`, the sibling adapter every
/// other progress-domain read already throws) rather than declaring a
/// second, near-identical exception type for the same "no active
/// account/profile yet" condition.
class FirestoreChartDataRepositoryAdapter implements ChartDataRepository {
  FirestoreChartDataRepositoryAdapter({required Ref ref}) : _ref = ref;

  final Ref _ref;

  @override
  Future<List<CompletionEntity>> getCompletionsByTier({
    required CompletionTierFilter tier,
    CurriculumId? curriculumId,
    DateTime? since,
    DateTime? until,
  }) async {
    final repo = await _ref.read(firestoreCompletionRepositoryProvider.future);
    if (repo == null) {
      throw const ProgressRepositoryNotReadyException();
    }
    return repo.getCompletionsByTier(
      tier: tier,
      curriculumId: curriculumId,
      since: since,
      until: until,
    );
  }

  @override
  Future<List<CompletionEntity>> getCompletionsByCurriculum(
    CurriculumId curriculumId,
  ) async {
    final repo = await _ref.read(firestoreCompletionRepositoryProvider.future);
    if (repo == null) {
      throw const ProgressRepositoryNotReadyException();
    }
    return repo.getCompletionsForCurriculum(curriculumId);
  }

  @override
  Future<List<GoalEntity>> getGoals(CurriculumId curriculumId) async {
    // Configuration-shaped: [] on not-ready, same as every other goals read.
    final repo = await _ref.read(firestoreGoalRepositoryProvider.future);
    if (repo == null) return const [];
    return repo.getGoals(curriculumId);
  }
}

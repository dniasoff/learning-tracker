import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/features/gamification/domain/services/points_service.dart';

/// Firestore-backed [CurriculumRewardEligibility].
///
/// Mirrors `FirestoreCompletionPointsAwarder.calculatePoints`'s own
/// reward-eligibility gate exactly (`completion_points_awarder.dart`,
/// `lib/features/learning/data/repositories/`): AD-25 keys eligibility by
/// curriculum, and a profile has at most one track per curriculum, so "a
/// goal exists for this curriculum" is the same eligibility test that gate
/// already uses to decide whether a live completion earns points. Deriving
/// this display-side check from a DIFFERENT rule than the one that actually
/// gated the award would let the two silently diverge (e.g. the gamification
/// screen reporting `0` for a curriculum that in fact earned points, or vice
/// versa).
///
/// **Not-ready reads throw, not `[]` (D-E).** [GoalRepository.getGoals]
/// (the feature-domain interface `daily_task_projection_service.dart` and
/// others use) treats an unresolved repository as legitimately empty — goal
/// existence is configuration-shaped on its own. But [isEligible] feeds
/// directly into [PointsService.getCurriculumTotal], which IS
/// achievement-shaped: silently treating "not ready" as "not eligible" would
/// fabricate a `0` points total for a curriculum whose true eligibility is
/// simply unknown yet. This adapter therefore resolves
/// `firestoreGoalRepositoryProvider` directly (the same raw seam the awarder
/// uses) rather than going through [GoalRepository], so it can throw on
/// not-ready instead of swallowing it into an empty list.
class FirestoreCurriculumRewardEligibilityAdapter
    implements CurriculumRewardEligibility {
  FirestoreCurriculumRewardEligibilityAdapter({required Ref ref}) : _ref = ref;

  final Ref _ref;

  @override
  Future<bool> isEligible(CurriculumId curriculumId) async {
    final goalRepository = await _ref.read(
      firestoreGoalRepositoryProvider.future,
    );
    if (goalRepository == null) {
      throw StateError(
        'FirestoreCurriculumRewardEligibilityAdapter.isEligible: '
        'firestoreGoalRepositoryProvider resolved to null (no active '
        'account, or no active learner profile, yet) — refusing to report '
        'curriculumId=${curriculumId.storageKey} as not-eligible when '
        'eligibility could not actually be evaluated.',
      );
    }
    final goals = await goalRepository.getGoals(curriculumId);
    return goals.isNotEmpty;
  }
}

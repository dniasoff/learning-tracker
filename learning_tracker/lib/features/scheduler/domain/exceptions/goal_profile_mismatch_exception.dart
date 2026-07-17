import 'package:learning_tracker/core/exceptions/app_exception.dart';

/// Thrown when a `GoalRepositoryImpl` goal operation is attempted with, or
/// against, a `profileId` that disagrees with the repository instance's own
/// `_profileId`.
///
/// `GoalRepositoryImpl` is constructed per-profile (see
/// `goalRepositoryProvider`) and this is the repository-layer backstop for
/// the multi-profile isolation invariant, on top of the DAO layer — which
/// does not itself scope `updateGoal`/`deleteGoal`/`getGoalById` by profile
/// (AUD-scheduler-03). Thrown from three sites:
///   - `createGoal`: the caller-supplied `profileId` argument disagrees with
///     the repository's own `_profileId`.
///   - `updateGoal` / `deleteGoal`: the existing goal row's `profileId`
///     disagrees with the repository's own `_profileId` — i.e. an attempt to
///     mutate or delete another profile's goal.
class GoalProfileMismatchException extends PermissionException {
  const GoalProfileMismatchException(super.message);
}

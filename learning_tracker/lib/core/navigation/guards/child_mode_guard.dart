import 'package:auto_route/auto_route.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

/// Route guard that only allows access for child-mode profiles (FR67).
///
/// Parent mode is designed for a parent to supervise a child on shared
/// device — so these routes only open when the *active learner profile*
/// is in child mode. Since Epic 15 (multi-profile) user mode is stored
/// per-profile on the `profiles` table, not on the legacy singleton
/// `user_profile` row, so this guard resolves the currently selected
/// profile via [getSelectedProfileId] and reads its `mode` column.
class ChildModeGuard extends AutoRouteGuard {
  ChildModeGuard({
    required UserDatabase Function() getDatabase,
    required int? Function() getSelectedProfileId,
  }) : _getDatabase = getDatabase,
       _getSelectedProfileId = getSelectedProfileId;

  final UserDatabase Function() _getDatabase;
  final int? Function() _getSelectedProfileId;

  @override
  Future<void> onNavigation(
    NavigationResolver resolver,
    StackRouter router,
  ) async {
    final profileId = _getSelectedProfileId();
    if (profileId == null) {
      resolver.next(false);
      return;
    }

    final profile = await _getDatabase().profileDao.getProfileById(profileId);
    resolver.next(profile?.mode == 'child');
  }
}

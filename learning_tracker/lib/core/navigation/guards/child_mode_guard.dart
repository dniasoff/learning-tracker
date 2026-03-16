import 'package:auto_route/auto_route.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';

/// Route guard that only allows access for child-mode accounts (FR67).
///
/// Adult accounts cannot access parent mode — it's designed for a parent
/// to supervise a child's device.
class ChildModeGuard extends AutoRouteGuard {
  ChildModeGuard({required this.database});

  final AppDatabase database;

  @override
  Future<void> onNavigation(
    NavigationResolver resolver,
    StackRouter router,
  ) async {
    final profiles = await database.userProfileDao.getAllUserProfiles();

    // If no profile exists, default to adult — block parent mode.
    if (profiles.isEmpty) {
      resolver.next(false);
      return;
    }

    final userMode = UserMode.values.firstWhere(
      (m) => m.name == profiles.first.userMode,
      orElse: () => UserMode.adult,
    );

    resolver.next(userMode == UserMode.child);
  }
}

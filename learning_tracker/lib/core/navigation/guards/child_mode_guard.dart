import 'package:auto_route/auto_route.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/logging/logger.dart';

final _log = AppLogger.instance;

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
    int? Function()? getActiveProfileId,
    bool Function()? isTutoredSession,
  }) : _getDatabase = getDatabase,
       _getSelectedProfileId = getSelectedProfileId,
       _getActiveProfileId = getActiveProfileId,
       _isTutoredSession = isTutoredSession;

  final UserDatabase Function() _getDatabase;
  final int? Function() _getSelectedProfileId;

  /// Resolves the *active* profile id — in a tutored session this is the
  /// synthetic talmid mirror (a child profile), which is NOT tracked by
  /// [_getSelectedProfileId] (that stays null while tutoring). Optional so
  /// tests that don't wire tutoring can omit it.
  final int? Function()? _getActiveProfileId;

  /// True when a tutor has entered a talmid's context. Optional.
  final bool Function()? _isTutoredSession;

  @override
  Future<void> onNavigation(
    NavigationResolver resolver,
    StackRouter router,
  ) async {
    // Fail-safe wrapper (no-lockout invariant): ProfileMode.fromStorageKey()
    // throws ArgumentError for any `mode` value that is not 'adult'/'child'
    // (a corrupt row, a future migration, or a sync conflict could produce
    // one), and the DB read or a disposed-provider lambda can also throw. An
    // unhandled throw would escape onNavigation and leave AutoRoute's resolver
    // completer un-completed forever — a permanent hang on every child-gated
    // route. This is a gate, so on any unexpected error we fail CLOSED.
    try {
      // Tutored session: a tutor has FULL parent-equivalent management of the
      // talmid (authoritative permission model 2026-06-02). The talmid is a
      // child profile, so the child-mode-gated parent-management routes
      // (ParentSettings/Tracks/PointConfig/RewardConfig/Lifetime) must open.
      // The active profile is the synthetic mirror — resolve it via the active
      // id, NOT selectedProfileId (which stays null while tutoring).
      final isTutored = _isTutoredSession?.call() ?? false;
      final profileId = isTutored
          ? _getActiveProfileId?.call()
          : _getSelectedProfileId();
      if (profileId == null) {
        resolver.next(false);
        return;
      }

      final profile = await _getDatabase().profileDao.getProfileById(profileId);
      resolver.next(
        profile != null &&
            ProfileMode.fromStorageKey(profile.mode) == ProfileMode.child,
      );
    } catch (error, stack) {
      _log.error(
        event: 'child_mode_guard_failed_closed',
        exception: error,
        stackTrace: stack,
      );
      if (!resolver.isResolved) resolver.next(false);
    }
  }
}

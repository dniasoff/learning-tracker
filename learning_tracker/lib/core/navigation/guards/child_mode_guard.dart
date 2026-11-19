import 'package:auto_route/auto_route.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';

final _log = AppLogger.instance;

/// Route guard that only allows access for child-mode profiles (FR67).
///
/// Parent mode is designed for a parent to supervise a child on a shared
/// device — so these routes only open when the *active learner profile* is
/// in child mode. This guard resolves the currently selected profile via
/// [getSelectedProfileId] and reads its [LearnerProfileEntity.mode].
class ChildModeGuard extends AutoRouteGuard {
  ChildModeGuard({
    required Future<LearnerProfileEntity?> Function(String profileId)
    getProfileById,
    Future<LearnerProfileEntity?> Function(String ownerUid, String profileId)?
    getTutoredProfileById,
    required String? Function() getSelectedProfileId,
    String? Function()? getActiveProfileId,
    String? Function()? getActiveOwnerUid,
    bool Function()? isTutoredSession,
  }) : _getProfileById = getProfileById,
       _getTutoredProfileById = getTutoredProfileById,
       _getSelectedProfileId = getSelectedProfileId,
       _getActiveProfileId = getActiveProfileId,
       _getActiveOwnerUid = getActiveOwnerUid,
       _isTutoredSession = isTutoredSession;

  final Future<LearnerProfileEntity?> Function(String profileId)
  _getProfileById;
  final Future<LearnerProfileEntity?> Function(
    String ownerUid,
    String profileId,
  )?
  _getTutoredProfileById;
  final String? Function() _getSelectedProfileId;

  /// Resolves the *active* profile id — in a tutored session this is the
  /// talmid's own profile id (a child profile), which is NOT tracked by
  /// [_getSelectedProfileId] (that stays null while tutoring). Optional so
  /// tests that don't wire tutoring can omit it.
  final String? Function()? _getActiveProfileId;

  /// Owner namespace for the selected talmid. In a tutor session the signed-in
  /// account is the tutor, so profile reads must use the grant's owner uid.
  final String? Function()? _getActiveOwnerUid;

  /// True when a tutor has entered a talmid's context. Optional.
  final bool Function()? _isTutoredSession;

  @override
  Future<void> onNavigation(
    NavigationResolver resolver,
    StackRouter router,
  ) async {
    // Fail-safe wrapper (no-lockout invariant): the profile read or a
    // disposed-provider lambda can throw. An unhandled throw would escape
    // onNavigation and leave AutoRoute's resolver completer un-completed
    // forever — a permanent hang on every child-gated route. This is a gate,
    // so on any unexpected error we fail CLOSED.
    try {
      // Tutored session: a tutor has FULL parent-equivalent management of the
      // talmid (authoritative permission model 2026-06-02). The talmid is a
      // child profile, so the child-mode-gated parent-management routes
      // (ParentSettings/Tracks/PointConfig/RewardConfig/Lifetime) must open.
      // The active profile is the talmid's own id, NOT selectedProfileId
      // (which stays null while tutoring).
      final isTutored = _isTutoredSession?.call() ?? false;
      final profileId = isTutored
          ? _getActiveProfileId?.call()
          : _getSelectedProfileId();
      if (profileId == null) {
        resolver.next(false);
        return;
      }

      final profile = isTutored
          ? await _readTutoredProfile(profileId)
          : await _getProfileById(profileId);
      resolver.next(profile != null && profile.mode == ProfileMode.child);
    } catch (error, stack) {
      _log.error(
        event: 'child_mode_guard_failed_closed',
        exception: error,
        stackTrace: stack,
      );
      if (!resolver.isResolved) resolver.next(false);
    }
  }

  Future<LearnerProfileEntity?> _readTutoredProfile(String profileId) async {
    final ownerUid = _getActiveOwnerUid?.call();
    final getTutoredProfileById = _getTutoredProfileById;
    if (ownerUid == null || ownerUid.isEmpty || getTutoredProfileById == null) {
      return null;
    }
    return getTutoredProfileById(ownerUid, profileId);
  }
}

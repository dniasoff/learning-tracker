import 'package:auto_route/auto_route.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';

final _log = AppLogger.instance;

/// Fails closed when a route requires an active profile.
class ProfileSelectionGuard extends AutoRouteGuard {
  ProfileSelectionGuard({
    required Future<LearnerProfileEntity?> Function(String profileId)
    getProfileById,
    required String? Function() getSelectedProfileId,
  }) : _getProfileById = getProfileById,
       _getSelectedProfileId = getSelectedProfileId;

  ProfileSelectionGuard.denyAll()
    : _getProfileById = _deny,
      _getSelectedProfileId = _noSelection;

  static Future<LearnerProfileEntity?> _deny(String _) async => null;
  static String? _noSelection() => null;

  final Future<LearnerProfileEntity?> Function(String profileId)
  _getProfileById;
  final String? Function() _getSelectedProfileId;

  @override
  Future<void> onNavigation(
    NavigationResolver resolver,
    StackRouter router,
  ) async {
    final profileId = _getSelectedProfileId();
    var allowed = false;
    if (profileId != null) {
      try {
        allowed = await _getProfileById(profileId) != null;
      } catch (error, stack) {
        _log.error(
          event: 'profile_selection_guard_failed_closed',
          exception: error,
          stackTrace: stack,
        );
      }
    }
    if (!resolver.isResolved) resolver.next(allowed);
  }
}

/// A real [AppRouter] for the Story 2.4 (DNI-495) access and offline-create
/// flows: every guard but the parent-session one lets the navigation
/// through, so the tests exercise exactly the AC-3 gate.
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/navigation/guards/child_mode_guard.dart';
import 'package:learning_tracker/core/navigation/guards/parent_session_guard.dart';
import 'package:learning_tracker/core/navigation/guards/pin_guard.dart';
import 'package:learning_tracker/core/navigation/guards/profile_guard.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_management_providers.dart';
import 'package:mocktail/mocktail.dart';

class _AllowAll extends AutoRouteGuard {
  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) =>
      resolver.next(true);
}

class _PinService extends Mock implements PinService {}

final class _AllowProfile extends ProfileGuard {
  _AllowProfile()
    : super(
        getProfiles: () async => const [],
        getSelectedProfileId: () => null,
        setSelectedProfileId: (_) {},
        isTutoredSession: () => false,
        profilePickerRoute: () => const SettingsRoute(),
      );

  @override
  Future<void> onNavigation(
    NavigationResolver resolver,
    StackRouter router,
  ) async => resolver.next(true);
}

final class _AllowChildMode extends ChildModeGuard {
  _AllowChildMode()
    : super(
        getProfileById: (_) async => null,
        getSelectedProfileId: () => null,
      );

  @override
  Future<void> onNavigation(
    NavigationResolver resolver,
    StackRouter router,
  ) async => resolver.next(true);
}

final class _AllowPin extends PinGuard {
  _AllowPin()
    : super(
        pinService: _PinService(),
        promptForPin: () async => true,
        getScope: () => null,
        pinSetupRoute: () => const SettingsRoute(),
      );

  @override
  Future<void> onNavigation(
    NavigationResolver resolver,
    StackRouter router,
  ) async => resolver.next(true);
}

/// The router, with the real [ParentSessionGuard] over [isParentSession].
AppRouter subTrackTestRouter({required bool Function() isParentSession}) =>
    AppRouter(
      sacredTimeLocationGuard: _AllowAll(),
      authGuard: _AllowAll(),
      profileGuard: _AllowProfile(),
      childModeGuard: _AllowChildMode(),
      pinGuard: _AllowPin(),
      parentSessionGuard: ParentSessionGuard(
        isParentSession: () async => isParentSession(),
      ),
    );

/// The main-track card and hub reads, faked for one Mishnayos track.
List<Override> subTrackHubCardOverrides() => [
  activeTracksProvider.overrideWith(
    (ref) => Stream.value([
      CurriculumTrackEntity(
        curriculumId: CurriculumId.mishnayos,
        state: 'active',
        activatedAt: DateTime.utc(2026),
      ),
    ]),
  ),
  dashboardActiveCurriculaProvider.overrideWith(
    (ref) async => [CurriculumId.mishnayos],
  ),
  dashboardTrackCompletionPercentageProvider(
    CurriculumId.mishnayos,
  ).overrideWith((ref) async => 0),
  trackHasChazaraProvider(
    CurriculumId.mishnayos,
  ).overrideWith((ref) async => false),
  dashboardHasProgramEnrollmentProvider(
    CurriculumId.mishnayos,
  ).overrideWith((ref) async => false),
  trackCustomNameProvider(
    CurriculumId.mishnayos,
  ).overrideWith((ref) async => null),
];

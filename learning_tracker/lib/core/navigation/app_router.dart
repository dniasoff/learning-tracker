import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/navigation/app_shell.dart';
import 'package:learning_tracker/core/navigation/guards/auth_guard.dart';
import 'package:learning_tracker/core/navigation/guards/child_mode_guard.dart';
import 'package:learning_tracker/core/navigation/guards/parent_pin_guard.dart';
import 'package:learning_tracker/core/navigation/guards/profile_guard.dart';
import 'package:learning_tracker/core/navigation/guards/restore_guard.dart';
import 'package:learning_tracker/core/navigation/guards/tutor_pin_guard.dart';
import 'package:learning_tracker/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:learning_tracker/features/content_browsing/presentation/screens/content_hierarchy_screen.dart';
import 'package:learning_tracker/features/content_browsing/presentation/screens/content_search_screen.dart';
import 'package:learning_tracker/features/content_browsing/presentation/screens/curriculum_list_screen.dart';
import 'package:learning_tracker/features/content_browsing/presentation/screens/text_display_screen.dart';
import 'package:learning_tracker/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:learning_tracker/features/gamification/presentation/screens/gamification_screen.dart';
import 'package:learning_tracker/features/learning/presentation/screens/curriculum_learning_screen.dart';
import 'package:learning_tracker/features/learning/presentation/screens/learning_screen.dart';
import 'package:learning_tracker/features/learning_order/presentation/screens/learning_order_screen.dart';
import 'package:learning_tracker/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/account_creation_screen.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/mode_selection_screen.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:learning_tracker/features/parent_mode/presentation/screens/parent_mode_screen.dart';
import 'package:learning_tracker/features/parent_mode/presentation/screens/parent_track_management_screen.dart';
import 'package:learning_tracker/features/parent_mode/presentation/screens/pin_change_screen.dart';
import 'package:learning_tracker/features/parent_mode/presentation/screens/pin_entry_screen.dart';
import 'package:learning_tracker/features/parent_mode/presentation/screens/pin_setup_screen.dart';
import 'package:learning_tracker/features/parent_mode/presentation/screens/point_config_screen.dart';
import 'package:learning_tracker/features/parent_mode/presentation/screens/reward_catalog_screen.dart';
import 'package:learning_tracker/features/profiles/presentation/screens/manage_learners_screen.dart';
import 'package:learning_tracker/features/profiles/presentation/screens/profile_picker_screen.dart';
import 'package:learning_tracker/features/progress/presentation/screens/completion_history_screen.dart';
import 'package:learning_tracker/features/progress/presentation/screens/curriculum_progress_screen.dart';
import 'package:learning_tracker/features/progress/presentation/screens/progress_charts_screen.dart';
import 'package:learning_tracker/features/progress/presentation/screens/progress_screen.dart';
import 'package:learning_tracker/features/scheduler/presentation/screens/scheduler_screen.dart';
import 'package:learning_tracker/features/settings/presentation/screens/curriculum_settings_screen.dart';
import 'package:learning_tracker/features/settings/presentation/screens/settings_screen.dart';
import 'package:learning_tracker/features/settings/presentation/screens/track_management_screen.dart';
import 'package:learning_tracker/features/sync/presentation/screens/device_restore_screen.dart';
import 'package:learning_tracker/features/sync/presentation/screens/sync_screen.dart';
import 'package:learning_tracker/features/tutor_mode/presentation/screens/tutor_dashboard_screen.dart';
import 'package:learning_tracker/features/tutor_mode/presentation/screens/tutor_mode_screen.dart';
import 'package:learning_tracker/features/tutor_mode/presentation/screens/tutor_pin_change_screen.dart';
import 'package:learning_tracker/features/tutor_mode/presentation/screens/tutor_pin_entry_screen.dart';
import 'package:learning_tracker/features/tutor_mode/presentation/screens/tutor_pin_setup_screen.dart';

part 'app_router.gr.dart';

@AutoRouterConfig(replaceInRouteName: 'Screen,Route')
class AppRouter extends RootStackRouter {
  final AuthGuard authGuard;
  final RestoreGuard restoreGuard;
  final ProfileGuard profileGuard;
  final ChildModeGuard childModeGuard;
  final ParentPinGuard parentPinGuard;
  final TutorPinGuard tutorPinGuard;

  AppRouter({
    required this.authGuard,
    required this.restoreGuard,
    required this.profileGuard,
    required this.childModeGuard,
    required this.parentPinGuard,
    required this.tutorPinGuard,
  });

  @override
  RouteType get defaultRouteType => const RouteType.material();

  @override
  List<AutoRoute> get routes => [
    // Unauthenticated routes
    AutoRoute(path: '/sign-in', page: SignInRoute.page),
    AutoRoute(path: '/welcome', page: WelcomeRoute.page),
    AutoRoute(path: '/create-account', page: AccountCreationRoute.page),
    AutoRoute(path: '/mode-selection', page: ModeSelectionRoute.page),
    AutoRoute(path: '/onboarding', page: OnboardingRoute.page),
    AutoRoute(path: '/restore', page: DeviceRestoreRoute.page),
    AutoRoute(path: '/profile-picker', page: ProfilePickerRoute.page, guards: [authGuard]),
    AutoRoute(path: '/manage-learners', page: ManageLearnersRoute.page, guards: [authGuard]),

    // App shell with bottom navigation (auth required)
    AutoRoute(
      path: '/',
      page: AppShellRoute.page,
      guards: [authGuard, restoreGuard, profileGuard],
      children: [
        AutoRoute(path: 'dashboard', page: DashboardRoute.page, initial: true),
        AutoRoute(path: 'learn', page: LearningRoute.page),
        AutoRoute(path: 'progress', page: ProgressRoute.page),
        AutoRoute(path: 'settings', page: SettingsRoute.page),
      ],
    ),

    // Progress charts
    AutoRoute(
      path: '/progress/charts',
      page: ProgressChartsRoute.page,
      guards: [authGuard],
    ),

    // Content browsing routes
    AutoRoute(
      path: '/browse',
      page: CurriculumListRoute.page,
      guards: [authGuard],
    ),
    AutoRoute(
      path: '/curriculum/:curriculumId/browse',
      page: ContentHierarchyRoute.page,
      guards: [authGuard],
    ),
    AutoRoute(
      path: '/curriculum/:curriculumId/learn',
      page: CurriculumLearningRoute.page,
      guards: [authGuard],
    ),
    AutoRoute(
      path: '/curriculum/:curriculumId/progress',
      page: CurriculumProgressRoute.page,
      guards: [authGuard],
    ),
    AutoRoute(
      path: '/curriculum/:curriculumId/settings',
      page: CurriculumSettingsRoute.page,
      guards: [authGuard],
    ),

    // Content search route
    AutoRoute(
      path: '/curriculum/:curriculumId/search',
      page: ContentSearchRoute.page,
      guards: [authGuard],
    ),

    // Text display route
    AutoRoute(
      path: '/text/:sefariaRef',
      page: TextDisplayRoute.page,
      guards: [authGuard],
    ),

    // Feature routes
    AutoRoute(
      path: '/scheduler',
      page: SchedulerRoute.page,
      guards: [authGuard],
    ),
    AutoRoute(
      path: '/gamification',
      page: GamificationRoute.page,
      guards: [authGuard],
    ),
    AutoRoute(
      path: '/notifications',
      page: NotificationsRoute.page,
      guards: [authGuard],
    ),
    AutoRoute(
      path: '/parent-mode',
      page: ParentModeRoute.page,
      guards: [authGuard, childModeGuard, parentPinGuard],
    ),
    AutoRoute(
      path: '/parent-mode/rewards',
      page: RewardCatalogRoute.page,
      guards: [authGuard, childModeGuard, parentPinGuard],
    ),
    AutoRoute(
      path: '/parent-mode/point-config',
      page: PointConfigRoute.page,
      guards: [authGuard, childModeGuard, parentPinGuard],
    ),
    AutoRoute(
      path: '/parent-mode/pin-setup',
      page: PinSetupRoute.page,
      guards: [authGuard, childModeGuard],
    ),
    AutoRoute(
      path: '/parent-mode/pin-entry',
      page: PinEntryRoute.page,
      guards: [authGuard, childModeGuard],
    ),
    AutoRoute(
      path: '/parent-mode/pin-change',
      page: PinChangeRoute.page,
      guards: [authGuard, childModeGuard, parentPinGuard],
    ),
    AutoRoute(
      path: '/parent-mode/tracks',
      page: ParentTrackManagementRoute.page,
      guards: [authGuard, childModeGuard, parentPinGuard],
    ),
    AutoRoute(
      path: '/tutor-mode',
      page: TutorModeRoute.page,
      guards: [authGuard, tutorPinGuard],
    ),
    AutoRoute(
      path: '/tutor-mode/pin-setup',
      page: TutorPinSetupRoute.page,
      guards: [authGuard],
    ),
    AutoRoute(
      path: '/tutor-mode/pin-entry',
      page: TutorPinEntryRoute.page,
      guards: [authGuard],
    ),
    AutoRoute(
      path: '/tutor-mode/pin-change',
      page: TutorPinChangeRoute.page,
      guards: [authGuard, tutorPinGuard],
    ),
    AutoRoute(
      path: '/tutor-mode/dashboard',
      page: TutorDashboardRoute.page,
      guards: [authGuard, tutorPinGuard],
    ),
    AutoRoute(path: '/sync', page: SyncRoute.page, guards: [authGuard]),
    AutoRoute(
      path: '/curriculum/:curriculumId/tracks',
      page: TrackManagementRoute.page,
      guards: [authGuard],
    ),
    AutoRoute(
      path: '/curriculum/:curriculumId/order',
      page: LearningOrderRoute.page,
      guards: [authGuard],
    ),
  ];
}

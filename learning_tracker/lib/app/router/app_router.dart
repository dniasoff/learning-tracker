import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:learning_tracker/app/restore/device_restore_screen.dart';
import 'package:learning_tracker/app/router/app_shell.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/navigation/guards/child_mode_guard.dart';
import 'package:learning_tracker/core/navigation/guards/pin_guard.dart';
import 'package:learning_tracker/core/navigation/guards/profile_guard.dart';
import 'package:learning_tracker/core/navigation/guards/restore_guard.dart';
import 'package:learning_tracker/features/account/onboarding/presentation/screens/signup_screen.dart';
import 'package:learning_tracker/features/account/presentation/screens/account_picker_screen.dart';
import 'package:learning_tracker/features/account/presentation/screens/sign_in_screen.dart';
import 'package:learning_tracker/features/content_browsing/presentation/screens/content_hierarchy_screen.dart';
import 'package:learning_tracker/features/content_browsing/presentation/screens/content_search_screen.dart';
import 'package:learning_tracker/features/content_browsing/presentation/screens/curriculum_list_screen.dart';
import 'package:learning_tracker/features/content_browsing/presentation/screens/text_display_screen.dart';
import 'package:learning_tracker/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:learning_tracker/features/gamification/presentation/screens/gamification_screen.dart';
import 'package:learning_tracker/features/gamification/presentation/screens/point_config_screen.dart';
import 'package:learning_tracker/features/gamification/presentation/screens/reward_configuration_screen.dart';
import 'package:learning_tracker/features/learning/presentation/screens/learning_screen.dart';
import 'package:learning_tracker/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/app_intro_screen.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/permission_prompt_screen.dart';
import 'package:learning_tracker/features/profiles/presentation/screens/manage_learners_screen.dart';
import 'package:learning_tracker/features/profiles/presentation/screens/parent_settings_screen.dart';
import 'package:learning_tracker/features/profiles/presentation/screens/parent_track_management_screen.dart';
import 'package:learning_tracker/features/profiles/presentation/screens/pin_flow_screen.dart';
import 'package:learning_tracker/features/profiles/presentation/screens/profile_picker_screen.dart';
import 'package:learning_tracker/features/progress/presentation/screens/completion_history_screen.dart';
import 'package:learning_tracker/features/progress/presentation/screens/curriculum_progress_screen.dart';
import 'package:learning_tracker/features/progress/presentation/screens/items_learned_screen.dart';
import 'package:learning_tracker/features/progress/presentation/screens/learning_journey_screen.dart';
import 'package:learning_tracker/features/progress/presentation/screens/lifetime_view_screen.dart';
import 'package:learning_tracker/features/progress/presentation/screens/progress_charts_screen.dart';
import 'package:learning_tracker/features/progress/presentation/screens/progress_screen.dart';
import 'package:learning_tracker/features/progress/presentation/screens/streak_history_screen.dart';
import 'package:learning_tracker/features/progress/presentation/screens/tasks_done_screen.dart';
import 'package:learning_tracker/features/sacred_time/presentation/screens/city_picker_screen.dart';
import 'package:learning_tracker/features/scheduler/presentation/screens/scheduler_screen.dart';
import 'package:learning_tracker/features/scheduler/presentation/screens/study_day_config_screen.dart';
import 'package:learning_tracker/features/settings/presentation/screens/curriculum_settings_screen.dart';
import 'package:learning_tracker/features/settings/presentation/screens/lifetime_marking_screen.dart';
import 'package:learning_tracker/features/settings/presentation/screens/settings_screen.dart';
import 'package:learning_tracker/features/settings/presentation/screens/upgrade_to_cloud_screen.dart';
import 'package:learning_tracker/features/sync/presentation/screens/sync_screen.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/screens/track_detail_screen.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/screens/track_management_hub_screen.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/presentation/screens/learning_order_screen.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart'
    show TutorGrant;
import 'package:learning_tracker/features/tutoring/presentation/screens/accept_invite_screen.dart';
import 'package:learning_tracker/features/tutoring/presentation/screens/decline_invite_screen.dart';
import 'package:learning_tracker/features/tutoring/presentation/screens/invite_tutor_screen.dart';
import 'package:learning_tracker/features/tutoring/presentation/screens/manage_grants_screen.dart';
import 'package:learning_tracker/features/tutoring/presentation/screens/manage_tutors_screen.dart';
import 'package:learning_tracker/features/tutoring/presentation/screens/tutor_audit_log_screen.dart';

part 'app_router.gr.dart';

@AutoRouterConfig(replaceInRouteName: 'Screen,Route')
class AppRouter extends RootStackRouter {
  final AutoRouteGuard authGuard;
  final RestoreGuard restoreGuard;
  final ProfileGuard profileGuard;
  final ChildModeGuard childModeGuard;
  final PinGuard pinGuard;

  AppRouter({
    required this.authGuard,
    required this.restoreGuard,
    required this.profileGuard,
    required this.childModeGuard,
    required this.pinGuard,
    super.navigatorKey,
  });

  @override
  RouteType get defaultRouteType => const RouteType.material();

  @override
  List<AutoRoute> get routes => [
    // Unauthenticated routes
    AutoRoute(path: '/intro', page: AppIntroRoute.page, initial: true),
    AutoRoute(path: '/sign-in', page: SignInRoute.page),
    // Firebase action links can deep-link to these paths. Redirect to sign-in
    // while MagicLinkService processes the incoming URI in the background.
    RedirectRoute(path: '/verify-email', redirectTo: '/sign-in'),
    RedirectRoute(path: '/__/auth/links', redirectTo: '/sign-in'),
    RedirectRoute(path: '/__/auth/action', redirectTo: '/sign-in'),
    AutoRoute(path: '/create-account', page: SignupRoute.page),
    AutoRoute(path: '/account-picker', page: AccountPickerRoute.page),
    AutoRoute(
      path: '/upgrade-to-cloud',
      page: UpgradeToCloudRoute.page,
      guards: [authGuard],
    ),
    AutoRoute(path: '/onboarding', page: OnboardingRoute.page),
    AutoRoute(
      path: '/permission-prompt',
      page: PermissionPromptRoute.page,
      guards: [authGuard],
    ),
    AutoRoute(path: '/restore', page: DeviceRestoreRoute.page),
    AutoRoute(
      path: '/profile-picker',
      page: ProfilePickerRoute.page,
      guards: [authGuard],
    ),
    AutoRoute(
      path: '/manage-learners',
      page: ManageLearnersRoute.page,
      guards: [authGuard],
    ),

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

    // Learning Journey
    AutoRoute(
      path: '/journey',
      page: LearningJourneyRoute.page,
      guards: [authGuard],
    ),

    // Progress charts
    AutoRoute(
      path: '/progress/charts',
      page: ProgressChartsRoute.page,
      guards: [authGuard],
    ),

    // Progress detail screens — tappable stat boxes on Progress.
    AutoRoute(
      path: '/progress/completions',
      page: CompletionHistoryRoute.page,
      guards: [authGuard],
    ),
    AutoRoute(
      path: '/progress/streak',
      page: StreakHistoryRoute.page,
      guards: [authGuard],
    ),
    AutoRoute(
      path: '/progress/tasks-done',
      page: TasksDoneRoute.page,
      guards: [authGuard],
    ),
    AutoRoute(
      path: '/progress/items-learned',
      page: ItemsLearnedRoute.page,
      guards: [authGuard],
    ),
    AutoRoute(
      path: '/progress/lifetime',
      page: LifetimeViewRoute.page,
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
      guards: [authGuard, childModeGuard],
    ),
    AutoRoute(
      path: '/notifications',
      page: NotificationsRoute.page,
      guards: [authGuard],
    ),
    AutoRoute(
      path: '/sacred-time/city',
      page: CityPickerRoute.page,
      guards: [authGuard],
    ),
    AutoRoute(
      path: '/parent-mode/settings',
      page: ParentSettingsRoute.page,
      guards: [authGuard, childModeGuard, pinGuard],
    ),
    AutoRoute(
      path: '/parent-mode/point-config',
      page: PointConfigRoute.page,
      guards: [authGuard, childModeGuard, pinGuard],
    ),
    AutoRoute(
      path: '/parent-mode/reward-config',
      page: RewardConfigurationRoute.page,
      guards: [authGuard, childModeGuard, pinGuard],
    ),
    AutoRoute(
      path: '/parent-mode/pin-setup',
      page: PinFlowSetupRoute.page,
      guards: [authGuard, childModeGuard],
    ),
    AutoRoute(
      path: '/parent-mode/pin-entry',
      page: PinFlowVerifyRoute.page,
      guards: [authGuard, childModeGuard],
    ),
    AutoRoute(
      path: '/parent-mode/pin-change',
      page: PinFlowChangeRoute.page,
      guards: [authGuard, childModeGuard],
    ),
    AutoRoute(
      path: '/parent-mode/tracks',
      page: ParentTrackManagementRoute.page,
      guards: [authGuard, childModeGuard, pinGuard],
    ),
    AutoRoute(
      path: '/study-days/:curriculumId',
      page: StudyDayConfigRoute.page,
      guards: [authGuard],
    ),
    AutoRoute(path: '/sync', page: SyncRoute.page, guards: [authGuard]),
    AutoRoute(
      path: '/settings/tracks',
      page: TrackManagementHubRoute.page,
      guards: [authGuard],
    ),
    AutoRoute(
      path: '/settings/tracks/detail',
      page: TrackDetailRoute.page,
      guards: [authGuard],
    ),
    AutoRoute(
      path: '/settings/lifetime',
      page: LifetimeMarkingRoute.page,
      guards: [authGuard],
    ),
    AutoRoute(
      path: '/settings/lifetime/:curriculumId',
      page: LifetimeCurriculumMarkingRoute.page,
      guards: [authGuard],
    ),
    AutoRoute(
      path: '/curriculum/:curriculumId/order',
      page: LearningOrderRoute.page,
      guards: [authGuard],
    ),

    // Tutoring routes (W6.11-W6.13)
    AutoRoute(
      path: '/tutor/manage-tutors',
      page: ManageTutorsRoute.page,
      guards: [authGuard],
    ),
    AutoRoute(
      path: '/tutor/my-grants',
      page: ManageGrantsRoute.page,
      guards: [authGuard],
    ),
    AutoRoute(
      path: '/tutor/audit-log',
      page: TutorAuditLogRoute.page,
      guards: [authGuard],
    ),

    // Tutoring invite routes (W6.7, W6.9, W6.10)
    AutoRoute(
      path: '/tutor/invite',
      page: InviteTutorRoute.page,
      guards: [authGuard],
    ),
    // Deep-link entry: /invite?token=<grantId>
    AutoRoute(path: '/invite', page: AcceptInviteRoute.page),
    AutoRoute(
      path: '/tutor/decline',
      page: DeclineInviteRoute.page,
      guards: [authGuard],
    ),
  ];
}

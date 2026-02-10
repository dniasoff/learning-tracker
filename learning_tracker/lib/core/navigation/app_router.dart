import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:learning_tracker/core/navigation/app_shell.dart';
import 'package:learning_tracker/core/navigation/guards/auth_guard.dart';
import 'package:learning_tracker/core/navigation/guards/parent_pin_guard.dart';
import 'package:learning_tracker/core/navigation/guards/tutor_pin_guard.dart';
import 'package:learning_tracker/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:learning_tracker/features/content_browsing/presentation/screens/content_browsing_screen.dart';
import 'package:learning_tracker/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:learning_tracker/features/gamification/presentation/screens/gamification_screen.dart';
import 'package:learning_tracker/features/learning/presentation/screens/curriculum_learning_screen.dart';
import 'package:learning_tracker/features/learning/presentation/screens/learning_screen.dart';
import 'package:learning_tracker/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:learning_tracker/features/parent_mode/presentation/screens/parent_mode_screen.dart';
import 'package:learning_tracker/features/progress/presentation/screens/curriculum_progress_screen.dart';
import 'package:learning_tracker/features/progress/presentation/screens/progress_screen.dart';
import 'package:learning_tracker/features/scheduler/presentation/screens/scheduler_screen.dart';
import 'package:learning_tracker/features/settings/presentation/screens/curriculum_settings_screen.dart';
import 'package:learning_tracker/features/settings/presentation/screens/settings_screen.dart';
import 'package:learning_tracker/features/settings/presentation/screens/track_management_screen.dart';
import 'package:learning_tracker/features/sync/presentation/screens/sync_screen.dart';
import 'package:learning_tracker/features/tutor_mode/presentation/screens/tutor_mode_screen.dart';

part 'app_router.gr.dart';

@AutoRouterConfig(replaceInRouteName: 'Screen,Route')
class AppRouter extends RootStackRouter {
  final AuthGuard authGuard;
  final ParentPinGuard parentPinGuard;
  final TutorPinGuard tutorPinGuard;

  AppRouter({
    required this.authGuard,
    required this.parentPinGuard,
    required this.tutorPinGuard,
  });

  @override
  RouteType get defaultRouteType => const RouteType.material();

  @override
  List<AutoRoute> get routes => [
    // Unauthenticated routes
    AutoRoute(path: '/sign-in', page: SignInRoute.page),
    AutoRoute(path: '/onboarding', page: OnboardingRoute.page),

    // App shell with bottom navigation (auth required)
    AutoRoute(
      path: '/',
      page: AppShellRoute.page,
      guards: [authGuard],
      children: [
        AutoRoute(path: 'dashboard', page: DashboardRoute.page, initial: true),
        AutoRoute(path: 'learn', page: LearningRoute.page),
        AutoRoute(path: 'progress', page: ProgressRoute.page),
        AutoRoute(path: 'settings', page: SettingsRoute.page),
      ],
    ),

    // Curriculum-scoped routes
    AutoRoute(
      path: '/curriculum/:curriculumId/browse',
      page: ContentBrowsingRoute.page,
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
      guards: [authGuard, parentPinGuard],
    ),
    AutoRoute(
      path: '/tutor-mode',
      page: TutorModeRoute.page,
      guards: [authGuard, tutorPinGuard],
    ),
    AutoRoute(path: '/sync', page: SyncRoute.page, guards: [authGuard]),
  ];
}

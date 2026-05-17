// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'app_router.dart';

/// generated route for
/// [AccountPickerScreen]
class AccountPickerRoute extends PageRouteInfo<void> {
  const AccountPickerRoute({List<PageRouteInfo>? children})
    : super(AccountPickerRoute.name, initialChildren: children);

  static const String name = 'AccountPickerRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const AccountPickerScreen();
    },
  );
}

/// generated route for
/// [AppIntroScreen]
class AppIntroRoute extends PageRouteInfo<void> {
  const AppIntroRoute({List<PageRouteInfo>? children})
    : super(AppIntroRoute.name, initialChildren: children);

  static const String name = 'AppIntroRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const AppIntroScreen();
    },
  );
}

/// generated route for
/// [AppShellScreen]
class AppShellRoute extends PageRouteInfo<void> {
  const AppShellRoute({List<PageRouteInfo>? children})
    : super(AppShellRoute.name, initialChildren: children);

  static const String name = 'AppShellRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const AppShellScreen();
    },
  );
}

/// generated route for
/// [CityPickerScreen]
class CityPickerRoute extends PageRouteInfo<void> {
  const CityPickerRoute({List<PageRouteInfo>? children})
    : super(CityPickerRoute.name, initialChildren: children);

  static const String name = 'CityPickerRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const CityPickerScreen();
    },
  );
}

/// generated route for
/// [CompletionHistoryScreen]
class CompletionHistoryRoute extends PageRouteInfo<CompletionHistoryRouteArgs> {
  CompletionHistoryRoute({
    Key? key,
    String? curriculumId,
    List<PageRouteInfo>? children,
  }) : super(
         CompletionHistoryRoute.name,
         args: CompletionHistoryRouteArgs(key: key, curriculumId: curriculumId),
         rawPathParams: {'curriculumId': curriculumId},
         initialChildren: children,
       );

  static const String name = 'CompletionHistoryRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<CompletionHistoryRouteArgs>(
        orElse: () => CompletionHistoryRouteArgs(
          curriculumId: pathParams.optString('curriculumId'),
        ),
      );
      return CompletionHistoryScreen(
        key: args.key,
        curriculumId: args.curriculumId,
      );
    },
  );
}

class CompletionHistoryRouteArgs {
  const CompletionHistoryRouteArgs({this.key, this.curriculumId});

  final Key? key;

  final String? curriculumId;

  @override
  String toString() {
    return 'CompletionHistoryRouteArgs{key: $key, curriculumId: $curriculumId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CompletionHistoryRouteArgs) return false;
    return key == other.key && curriculumId == other.curriculumId;
  }

  @override
  int get hashCode => key.hashCode ^ curriculumId.hashCode;
}

/// generated route for
/// [ContentHierarchyScreen]
class ContentHierarchyRoute extends PageRouteInfo<ContentHierarchyRouteArgs> {
  ContentHierarchyRoute({
    Key? key,
    required String curriculumId,
    String? level1,
    String? level2,
    String? level3,
    String? level4,
    List<PageRouteInfo>? children,
  }) : super(
         ContentHierarchyRoute.name,
         args: ContentHierarchyRouteArgs(
           key: key,
           curriculumId: curriculumId,
           level1: level1,
           level2: level2,
           level3: level3,
           level4: level4,
         ),
         rawPathParams: {'curriculumId': curriculumId},
         initialChildren: children,
       );

  static const String name = 'ContentHierarchyRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<ContentHierarchyRouteArgs>(
        orElse: () => ContentHierarchyRouteArgs(
          curriculumId: pathParams.getString('curriculumId'),
        ),
      );
      return ContentHierarchyScreen(
        key: args.key,
        curriculumId: args.curriculumId,
        level1: args.level1,
        level2: args.level2,
        level3: args.level3,
        level4: args.level4,
      );
    },
  );
}

class ContentHierarchyRouteArgs {
  const ContentHierarchyRouteArgs({
    this.key,
    required this.curriculumId,
    this.level1,
    this.level2,
    this.level3,
    this.level4,
  });

  final Key? key;

  final String curriculumId;

  final String? level1;

  final String? level2;

  final String? level3;

  final String? level4;

  @override
  String toString() {
    return 'ContentHierarchyRouteArgs{key: $key, curriculumId: $curriculumId, level1: $level1, level2: $level2, level3: $level3, level4: $level4}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ContentHierarchyRouteArgs) return false;
    return key == other.key &&
        curriculumId == other.curriculumId &&
        level1 == other.level1 &&
        level2 == other.level2 &&
        level3 == other.level3 &&
        level4 == other.level4;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      curriculumId.hashCode ^
      level1.hashCode ^
      level2.hashCode ^
      level3.hashCode ^
      level4.hashCode;
}

/// generated route for
/// [ContentSearchScreen]
class ContentSearchRoute extends PageRouteInfo<ContentSearchRouteArgs> {
  ContentSearchRoute({
    Key? key,
    required String curriculumId,
    List<PageRouteInfo>? children,
  }) : super(
         ContentSearchRoute.name,
         args: ContentSearchRouteArgs(key: key, curriculumId: curriculumId),
         rawPathParams: {'curriculumId': curriculumId},
         initialChildren: children,
       );

  static const String name = 'ContentSearchRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<ContentSearchRouteArgs>(
        orElse: () => ContentSearchRouteArgs(
          curriculumId: pathParams.getString('curriculumId'),
        ),
      );
      return ContentSearchScreen(
        key: args.key,
        curriculumId: args.curriculumId,
      );
    },
  );
}

class ContentSearchRouteArgs {
  const ContentSearchRouteArgs({this.key, required this.curriculumId});

  final Key? key;

  final String curriculumId;

  @override
  String toString() {
    return 'ContentSearchRouteArgs{key: $key, curriculumId: $curriculumId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ContentSearchRouteArgs) return false;
    return key == other.key && curriculumId == other.curriculumId;
  }

  @override
  int get hashCode => key.hashCode ^ curriculumId.hashCode;
}

/// generated route for
/// [CurriculumListScreen]
class CurriculumListRoute extends PageRouteInfo<void> {
  const CurriculumListRoute({List<PageRouteInfo>? children})
    : super(CurriculumListRoute.name, initialChildren: children);

  static const String name = 'CurriculumListRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const CurriculumListScreen();
    },
  );
}

/// generated route for
/// [CurriculumProgressScreen]
class CurriculumProgressRoute
    extends PageRouteInfo<CurriculumProgressRouteArgs> {
  CurriculumProgressRoute({
    Key? key,
    required String curriculumId,
    List<PageRouteInfo>? children,
  }) : super(
         CurriculumProgressRoute.name,
         args: CurriculumProgressRouteArgs(
           key: key,
           curriculumId: curriculumId,
         ),
         rawPathParams: {'curriculumId': curriculumId},
         initialChildren: children,
       );

  static const String name = 'CurriculumProgressRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<CurriculumProgressRouteArgs>(
        orElse: () => CurriculumProgressRouteArgs(
          curriculumId: pathParams.getString('curriculumId'),
        ),
      );
      return CurriculumProgressScreen(
        key: args.key,
        curriculumId: args.curriculumId,
      );
    },
  );
}

class CurriculumProgressRouteArgs {
  const CurriculumProgressRouteArgs({this.key, required this.curriculumId});

  final Key? key;

  final String curriculumId;

  @override
  String toString() {
    return 'CurriculumProgressRouteArgs{key: $key, curriculumId: $curriculumId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CurriculumProgressRouteArgs) return false;
    return key == other.key && curriculumId == other.curriculumId;
  }

  @override
  int get hashCode => key.hashCode ^ curriculumId.hashCode;
}

/// generated route for
/// [CurriculumSettingsScreen]
class CurriculumSettingsRoute
    extends PageRouteInfo<CurriculumSettingsRouteArgs> {
  CurriculumSettingsRoute({
    Key? key,
    required String curriculumId,
    List<PageRouteInfo>? children,
  }) : super(
         CurriculumSettingsRoute.name,
         args: CurriculumSettingsRouteArgs(
           key: key,
           curriculumId: curriculumId,
         ),
         rawPathParams: {'curriculumId': curriculumId},
         initialChildren: children,
       );

  static const String name = 'CurriculumSettingsRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<CurriculumSettingsRouteArgs>(
        orElse: () => CurriculumSettingsRouteArgs(
          curriculumId: pathParams.getString('curriculumId'),
        ),
      );
      return CurriculumSettingsScreen(
        key: args.key,
        curriculumId: args.curriculumId,
      );
    },
  );
}

class CurriculumSettingsRouteArgs {
  const CurriculumSettingsRouteArgs({this.key, required this.curriculumId});

  final Key? key;

  final String curriculumId;

  @override
  String toString() {
    return 'CurriculumSettingsRouteArgs{key: $key, curriculumId: $curriculumId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CurriculumSettingsRouteArgs) return false;
    return key == other.key && curriculumId == other.curriculumId;
  }

  @override
  int get hashCode => key.hashCode ^ curriculumId.hashCode;
}

/// generated route for
/// [DashboardScreen]
class DashboardRoute extends PageRouteInfo<void> {
  const DashboardRoute({List<PageRouteInfo>? children})
    : super(DashboardRoute.name, initialChildren: children);

  static const String name = 'DashboardRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const DashboardScreen();
    },
  );
}

/// generated route for
/// [DeviceRestoreScreen]
class DeviceRestoreRoute extends PageRouteInfo<void> {
  const DeviceRestoreRoute({List<PageRouteInfo>? children})
    : super(DeviceRestoreRoute.name, initialChildren: children);

  static const String name = 'DeviceRestoreRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const DeviceRestoreScreen();
    },
  );
}

/// generated route for
/// [GamificationScreen]
class GamificationRoute extends PageRouteInfo<void> {
  const GamificationRoute({List<PageRouteInfo>? children})
    : super(GamificationRoute.name, initialChildren: children);

  static const String name = 'GamificationRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const GamificationScreen();
    },
  );
}

/// generated route for
/// [LearningJourneyScreen]
class LearningJourneyRoute extends PageRouteInfo<LearningJourneyRouteArgs> {
  LearningJourneyRoute({
    Key? key,
    int? profileId,
    List<PageRouteInfo>? children,
  }) : super(
         LearningJourneyRoute.name,
         args: LearningJourneyRouteArgs(key: key, profileId: profileId),
         rawQueryParams: {'profileId': profileId},
         initialChildren: children,
       );

  static const String name = 'LearningJourneyRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final queryParams = data.queryParams;
      final args = data.argsAs<LearningJourneyRouteArgs>(
        orElse: () => LearningJourneyRouteArgs(
          profileId: queryParams.optInt('profileId'),
        ),
      );
      return LearningJourneyScreen(key: args.key, profileId: args.profileId);
    },
  );
}

class LearningJourneyRouteArgs {
  const LearningJourneyRouteArgs({this.key, this.profileId});

  final Key? key;

  final int? profileId;

  @override
  String toString() {
    return 'LearningJourneyRouteArgs{key: $key, profileId: $profileId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LearningJourneyRouteArgs) return false;
    return key == other.key && profileId == other.profileId;
  }

  @override
  int get hashCode => key.hashCode ^ profileId.hashCode;
}

/// generated route for
/// [LearningOrderScreen]
class LearningOrderRoute extends PageRouteInfo<LearningOrderRouteArgs> {
  LearningOrderRoute({
    Key? key,
    required CurriculumId curriculumId,
    List<PageRouteInfo>? children,
  }) : super(
         LearningOrderRoute.name,
         args: LearningOrderRouteArgs(key: key, curriculumId: curriculumId),
         initialChildren: children,
       );

  static const String name = 'LearningOrderRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<LearningOrderRouteArgs>();
      return LearningOrderScreen(
        key: args.key,
        curriculumId: args.curriculumId,
      );
    },
  );
}

class LearningOrderRouteArgs {
  const LearningOrderRouteArgs({this.key, required this.curriculumId});

  final Key? key;

  final CurriculumId curriculumId;

  @override
  String toString() {
    return 'LearningOrderRouteArgs{key: $key, curriculumId: $curriculumId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LearningOrderRouteArgs) return false;
    return key == other.key && curriculumId == other.curriculumId;
  }

  @override
  int get hashCode => key.hashCode ^ curriculumId.hashCode;
}

/// generated route for
/// [LearningScreen]
class LearningRoute extends PageRouteInfo<void> {
  const LearningRoute({List<PageRouteInfo>? children})
    : super(LearningRoute.name, initialChildren: children);

  static const String name = 'LearningRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const LearningScreen();
    },
  );
}

/// generated route for
/// [LifetimeCurriculumMarkingScreen]
class LifetimeCurriculumMarkingRoute
    extends PageRouteInfo<LifetimeCurriculumMarkingRouteArgs> {
  LifetimeCurriculumMarkingRoute({
    required String curriculumId,
    Key? key,
    List<PageRouteInfo>? children,
  }) : super(
         LifetimeCurriculumMarkingRoute.name,
         args: LifetimeCurriculumMarkingRouteArgs(
           curriculumId: curriculumId,
           key: key,
         ),
         initialChildren: children,
       );

  static const String name = 'LifetimeCurriculumMarkingRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<LifetimeCurriculumMarkingRouteArgs>();
      return LifetimeCurriculumMarkingScreen(
        curriculumId: args.curriculumId,
        key: args.key,
      );
    },
  );
}

class LifetimeCurriculumMarkingRouteArgs {
  const LifetimeCurriculumMarkingRouteArgs({
    required this.curriculumId,
    this.key,
  });

  final String curriculumId;

  final Key? key;

  @override
  String toString() {
    return 'LifetimeCurriculumMarkingRouteArgs{curriculumId: $curriculumId, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LifetimeCurriculumMarkingRouteArgs) return false;
    return curriculumId == other.curriculumId && key == other.key;
  }

  @override
  int get hashCode => curriculumId.hashCode ^ key.hashCode;
}

/// generated route for
/// [LifetimeMarkingScreen]
class LifetimeMarkingRoute extends PageRouteInfo<void> {
  const LifetimeMarkingRoute({List<PageRouteInfo>? children})
    : super(LifetimeMarkingRoute.name, initialChildren: children);

  static const String name = 'LifetimeMarkingRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const LifetimeMarkingScreen();
    },
  );
}

/// generated route for
/// [ManageLearnersScreen]
class ManageLearnersRoute extends PageRouteInfo<void> {
  const ManageLearnersRoute({List<PageRouteInfo>? children})
    : super(ManageLearnersRoute.name, initialChildren: children);

  static const String name = 'ManageLearnersRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const ManageLearnersScreen();
    },
  );
}

/// generated route for
/// [NotificationsScreen]
class NotificationsRoute extends PageRouteInfo<void> {
  const NotificationsRoute({List<PageRouteInfo>? children})
    : super(NotificationsRoute.name, initialChildren: children);

  static const String name = 'NotificationsRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const NotificationsScreen();
    },
  );
}

/// generated route for
/// [OnboardingScreen]
class OnboardingRoute extends PageRouteInfo<void> {
  const OnboardingRoute({List<PageRouteInfo>? children})
    : super(OnboardingRoute.name, initialChildren: children);

  static const String name = 'OnboardingRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const OnboardingScreen();
    },
  );
}

/// generated route for
/// [ParentSettingsScreen]
class ParentSettingsRoute extends PageRouteInfo<void> {
  const ParentSettingsRoute({List<PageRouteInfo>? children})
    : super(ParentSettingsRoute.name, initialChildren: children);

  static const String name = 'ParentSettingsRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const ParentSettingsScreen();
    },
  );
}

/// generated route for
/// [ParentTrackManagementScreen]
class ParentTrackManagementRoute extends PageRouteInfo<void> {
  const ParentTrackManagementRoute({List<PageRouteInfo>? children})
    : super(ParentTrackManagementRoute.name, initialChildren: children);

  static const String name = 'ParentTrackManagementRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const ParentTrackManagementScreen();
    },
  );
}

/// generated route for
/// [PermissionPromptScreen]
class PermissionPromptRoute extends PageRouteInfo<PermissionPromptRouteArgs> {
  PermissionPromptRoute({
    Key? key,
    bool isOnboarding = false,
    List<PageRouteInfo>? children,
  }) : super(
         PermissionPromptRoute.name,
         args: PermissionPromptRouteArgs(key: key, isOnboarding: isOnboarding),
         initialChildren: children,
       );

  static const String name = 'PermissionPromptRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<PermissionPromptRouteArgs>(
        orElse: () => const PermissionPromptRouteArgs(),
      );
      return PermissionPromptScreen(
        key: args.key,
        isOnboarding: args.isOnboarding,
      );
    },
  );
}

class PermissionPromptRouteArgs {
  const PermissionPromptRouteArgs({this.key, this.isOnboarding = false});

  final Key? key;

  final bool isOnboarding;

  @override
  String toString() {
    return 'PermissionPromptRouteArgs{key: $key, isOnboarding: $isOnboarding}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PermissionPromptRouteArgs) return false;
    return key == other.key && isOnboarding == other.isOnboarding;
  }

  @override
  int get hashCode => key.hashCode ^ isOnboarding.hashCode;
}

/// generated route for
/// [PinFlowChangeScreen]
class PinFlowChangeRoute extends PageRouteInfo<void> {
  const PinFlowChangeRoute({List<PageRouteInfo>? children})
    : super(PinFlowChangeRoute.name, initialChildren: children);

  static const String name = 'PinFlowChangeRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const PinFlowChangeScreen();
    },
  );
}

/// generated route for
/// [PinFlowScreen]
class PinFlowRoute extends PageRouteInfo<PinFlowRouteArgs> {
  PinFlowRoute({
    Key? key,
    required PinFlowMode mode,
    List<PageRouteInfo>? children,
  }) : super(
         PinFlowRoute.name,
         args: PinFlowRouteArgs(key: key, mode: mode),
         initialChildren: children,
       );

  static const String name = 'PinFlowRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<PinFlowRouteArgs>();
      return PinFlowScreen(key: args.key, mode: args.mode);
    },
  );
}

class PinFlowRouteArgs {
  const PinFlowRouteArgs({this.key, required this.mode});

  final Key? key;

  final PinFlowMode mode;

  @override
  String toString() {
    return 'PinFlowRouteArgs{key: $key, mode: $mode}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PinFlowRouteArgs) return false;
    return key == other.key && mode == other.mode;
  }

  @override
  int get hashCode => key.hashCode ^ mode.hashCode;
}

/// generated route for
/// [PinFlowSetupScreen]
class PinFlowSetupRoute extends PageRouteInfo<void> {
  const PinFlowSetupRoute({List<PageRouteInfo>? children})
    : super(PinFlowSetupRoute.name, initialChildren: children);

  static const String name = 'PinFlowSetupRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const PinFlowSetupScreen();
    },
  );
}

/// generated route for
/// [PinFlowVerifyScreen]
class PinFlowVerifyRoute extends PageRouteInfo<void> {
  const PinFlowVerifyRoute({List<PageRouteInfo>? children})
    : super(PinFlowVerifyRoute.name, initialChildren: children);

  static const String name = 'PinFlowVerifyRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const PinFlowVerifyScreen();
    },
  );
}

/// generated route for
/// [PointConfigScreen]
class PointConfigRoute extends PageRouteInfo<void> {
  const PointConfigRoute({List<PageRouteInfo>? children})
    : super(PointConfigRoute.name, initialChildren: children);

  static const String name = 'PointConfigRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const PointConfigScreen();
    },
  );
}

/// generated route for
/// [ProfilePickerScreen]
class ProfilePickerRoute extends PageRouteInfo<void> {
  const ProfilePickerRoute({List<PageRouteInfo>? children})
    : super(ProfilePickerRoute.name, initialChildren: children);

  static const String name = 'ProfilePickerRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const ProfilePickerScreen();
    },
  );
}

/// generated route for
/// [ProgressChartsScreen]
class ProgressChartsRoute extends PageRouteInfo<void> {
  const ProgressChartsRoute({List<PageRouteInfo>? children})
    : super(ProgressChartsRoute.name, initialChildren: children);

  static const String name = 'ProgressChartsRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const ProgressChartsScreen();
    },
  );
}

/// generated route for
/// [ProgressScreen]
class ProgressRoute extends PageRouteInfo<void> {
  const ProgressRoute({List<PageRouteInfo>? children})
    : super(ProgressRoute.name, initialChildren: children);

  static const String name = 'ProgressRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const ProgressScreen();
    },
  );
}

/// generated route for
/// [RewardConfigurationScreen]
class RewardConfigurationRoute extends PageRouteInfo<void> {
  const RewardConfigurationRoute({List<PageRouteInfo>? children})
    : super(RewardConfigurationRoute.name, initialChildren: children);

  static const String name = 'RewardConfigurationRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const RewardConfigurationScreen();
    },
  );
}

/// generated route for
/// [SchedulerScreen]
class SchedulerRoute extends PageRouteInfo<void> {
  const SchedulerRoute({List<PageRouteInfo>? children})
    : super(SchedulerRoute.name, initialChildren: children);

  static const String name = 'SchedulerRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const SchedulerScreen();
    },
  );
}

/// generated route for
/// [SettingsScreen]
class SettingsRoute extends PageRouteInfo<void> {
  const SettingsRoute({List<PageRouteInfo>? children})
    : super(SettingsRoute.name, initialChildren: children);

  static const String name = 'SettingsRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const SettingsScreen();
    },
  );
}

/// generated route for
/// [SignInScreen]
class SignInRoute extends PageRouteInfo<void> {
  const SignInRoute({List<PageRouteInfo>? children})
    : super(SignInRoute.name, initialChildren: children);

  static const String name = 'SignInRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const SignInScreen();
    },
  );
}

/// generated route for
/// [SignupScreen]
class SignupRoute extends PageRouteInfo<SignupRouteArgs> {
  SignupRoute({
    Key? key,
    String? prefilledName,
    String? prefilledEmail,
    List<PageRouteInfo>? children,
  }) : super(
         SignupRoute.name,
         args: SignupRouteArgs(
           key: key,
           prefilledName: prefilledName,
           prefilledEmail: prefilledEmail,
         ),
         initialChildren: children,
       );

  static const String name = 'SignupRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<SignupRouteArgs>(
        orElse: () => const SignupRouteArgs(),
      );
      return SignupScreen(
        key: args.key,
        prefilledName: args.prefilledName,
        prefilledEmail: args.prefilledEmail,
      );
    },
  );
}

class SignupRouteArgs {
  const SignupRouteArgs({this.key, this.prefilledName, this.prefilledEmail});

  final Key? key;

  final String? prefilledName;

  final String? prefilledEmail;

  @override
  String toString() {
    return 'SignupRouteArgs{key: $key, prefilledName: $prefilledName, prefilledEmail: $prefilledEmail}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SignupRouteArgs) return false;
    return key == other.key &&
        prefilledName == other.prefilledName &&
        prefilledEmail == other.prefilledEmail;
  }

  @override
  int get hashCode =>
      key.hashCode ^ prefilledName.hashCode ^ prefilledEmail.hashCode;
}

/// generated route for
/// [StreakHistoryScreen]
class StreakHistoryRoute extends PageRouteInfo<void> {
  const StreakHistoryRoute({List<PageRouteInfo>? children})
    : super(StreakHistoryRoute.name, initialChildren: children);

  static const String name = 'StreakHistoryRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const StreakHistoryScreen();
    },
  );
}

/// generated route for
/// [StudyDayConfigScreen]
class StudyDayConfigRoute extends PageRouteInfo<StudyDayConfigRouteArgs> {
  StudyDayConfigRoute({
    Key? key,
    required CurriculumId curriculumId,
    List<PageRouteInfo>? children,
  }) : super(
         StudyDayConfigRoute.name,
         args: StudyDayConfigRouteArgs(key: key, curriculumId: curriculumId),
         initialChildren: children,
       );

  static const String name = 'StudyDayConfigRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<StudyDayConfigRouteArgs>();
      return StudyDayConfigScreen(
        key: args.key,
        curriculumId: args.curriculumId,
      );
    },
  );
}

class StudyDayConfigRouteArgs {
  const StudyDayConfigRouteArgs({this.key, required this.curriculumId});

  final Key? key;

  final CurriculumId curriculumId;

  @override
  String toString() {
    return 'StudyDayConfigRouteArgs{key: $key, curriculumId: $curriculumId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! StudyDayConfigRouteArgs) return false;
    return key == other.key && curriculumId == other.curriculumId;
  }

  @override
  int get hashCode => key.hashCode ^ curriculumId.hashCode;
}

/// generated route for
/// [SyncScreen]
class SyncRoute extends PageRouteInfo<void> {
  const SyncRoute({List<PageRouteInfo>? children})
    : super(SyncRoute.name, initialChildren: children);

  static const String name = 'SyncRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const SyncScreen();
    },
  );
}

/// generated route for
/// [TasksDoneScreen]
class TasksDoneRoute extends PageRouteInfo<void> {
  const TasksDoneRoute({List<PageRouteInfo>? children})
    : super(TasksDoneRoute.name, initialChildren: children);

  static const String name = 'TasksDoneRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const TasksDoneScreen();
    },
  );
}

/// generated route for
/// [ItemsLearnedScreen]
class ItemsLearnedRoute extends PageRouteInfo<void> {
  const ItemsLearnedRoute({List<PageRouteInfo>? children})
    : super(ItemsLearnedRoute.name, initialChildren: children);

  static const String name = 'ItemsLearnedRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const ItemsLearnedScreen();
    },
  );
}

/// generated route for
/// [LifetimeViewScreen]
class LifetimeViewRoute extends PageRouteInfo<void> {
  const LifetimeViewRoute({List<PageRouteInfo>? children})
    : super(LifetimeViewRoute.name, initialChildren: children);

  static const String name = 'LifetimeViewRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const LifetimeViewScreen();
    },
  );
}

/// generated route for
/// [TextDisplayScreen]
class TextDisplayRoute extends PageRouteInfo<TextDisplayRouteArgs> {
  TextDisplayRoute({
    Key? key,
    required String sefariaRef,
    List<PageRouteInfo>? children,
  }) : super(
         TextDisplayRoute.name,
         args: TextDisplayRouteArgs(key: key, sefariaRef: sefariaRef),
         rawPathParams: {'sefariaRef': sefariaRef},
         initialChildren: children,
       );

  static const String name = 'TextDisplayRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<TextDisplayRouteArgs>(
        orElse: () => TextDisplayRouteArgs(
          sefariaRef: pathParams.getString('sefariaRef'),
        ),
      );
      return TextDisplayScreen(key: args.key, sefariaRef: args.sefariaRef);
    },
  );
}

class TextDisplayRouteArgs {
  const TextDisplayRouteArgs({this.key, required this.sefariaRef});

  final Key? key;

  final String sefariaRef;

  @override
  String toString() {
    return 'TextDisplayRouteArgs{key: $key, sefariaRef: $sefariaRef}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TextDisplayRouteArgs) return false;
    return key == other.key && sefariaRef == other.sefariaRef;
  }

  @override
  int get hashCode => key.hashCode ^ sefariaRef.hashCode;
}

/// generated route for
/// [TrackDetailScreen]
class TrackDetailRoute extends PageRouteInfo<TrackDetailRouteArgs> {
  TrackDetailRoute({
    Key? key,
    required CurriculumTrack track,
    List<PageRouteInfo>? children,
  }) : super(
         TrackDetailRoute.name,
         args: TrackDetailRouteArgs(key: key, track: track),
         initialChildren: children,
       );

  static const String name = 'TrackDetailRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<TrackDetailRouteArgs>();
      return TrackDetailScreen(key: args.key, track: args.track);
    },
  );
}

class TrackDetailRouteArgs {
  const TrackDetailRouteArgs({this.key, required this.track});

  final Key? key;

  final CurriculumTrack track;

  @override
  String toString() {
    return 'TrackDetailRouteArgs{key: $key, track: $track}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TrackDetailRouteArgs) return false;
    return key == other.key && track == other.track;
  }

  @override
  int get hashCode => key.hashCode ^ track.hashCode;
}

/// generated route for
/// [TrackManagementHubScreen]
class TrackManagementHubRoute
    extends PageRouteInfo<TrackManagementHubRouteArgs> {
  TrackManagementHubRoute({
    Key? key,
    bool startAdding = false,
    List<PageRouteInfo>? children,
  }) : super(
         TrackManagementHubRoute.name,
         args: TrackManagementHubRouteArgs(key: key, startAdding: startAdding),
         rawQueryParams: {'startAdding': startAdding},
         initialChildren: children,
       );

  static const String name = 'TrackManagementHubRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final queryParams = data.queryParams;
      final args = data.argsAs<TrackManagementHubRouteArgs>(
        orElse: () => TrackManagementHubRouteArgs(
          startAdding: queryParams.getBool('startAdding', false),
        ),
      );
      return TrackManagementHubScreen(
        key: args.key,
        startAdding: args.startAdding,
      );
    },
  );
}

class TrackManagementHubRouteArgs {
  const TrackManagementHubRouteArgs({this.key, this.startAdding = false});

  final Key? key;

  final bool startAdding;

  @override
  String toString() {
    return 'TrackManagementHubRouteArgs{key: $key, startAdding: $startAdding}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TrackManagementHubRouteArgs) return false;
    return key == other.key && startAdding == other.startAdding;
  }

  @override
  int get hashCode => key.hashCode ^ startAdding.hashCode;
}

/// generated route for
/// [UpgradeToCloudScreen]
class UpgradeToCloudRoute extends PageRouteInfo<void> {
  const UpgradeToCloudRoute({List<PageRouteInfo>? children})
    : super(UpgradeToCloudRoute.name, initialChildren: children);

  static const String name = 'UpgradeToCloudRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const UpgradeToCloudScreen();
    },
  );
}

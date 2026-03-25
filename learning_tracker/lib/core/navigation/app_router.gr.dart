// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'app_router.dart';

/// generated route for
/// [AccountCreationScreen]
class AccountCreationRoute extends PageRouteInfo<void> {
  const AccountCreationRoute({List<PageRouteInfo>? children})
    : super(AccountCreationRoute.name, initialChildren: children);

  static const String name = 'AccountCreationRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const AccountCreationScreen();
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
/// [CurriculumLearningScreen]
class CurriculumLearningRoute
    extends PageRouteInfo<CurriculumLearningRouteArgs> {
  CurriculumLearningRoute({
    Key? key,
    required String curriculumId,
    List<PageRouteInfo>? children,
  }) : super(
         CurriculumLearningRoute.name,
         args: CurriculumLearningRouteArgs(
           key: key,
           curriculumId: curriculumId,
         ),
         rawPathParams: {'curriculumId': curriculumId},
         initialChildren: children,
       );

  static const String name = 'CurriculumLearningRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<CurriculumLearningRouteArgs>(
        orElse: () => CurriculumLearningRouteArgs(
          curriculumId: pathParams.getString('curriculumId'),
        ),
      );
      return CurriculumLearningScreen(
        key: args.key,
        curriculumId: args.curriculumId,
      );
    },
  );
}

class CurriculumLearningRouteArgs {
  const CurriculumLearningRouteArgs({this.key, required this.curriculumId});

  final Key? key;

  final String curriculumId;

  @override
  String toString() {
    return 'CurriculumLearningRouteArgs{key: $key, curriculumId: $curriculumId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CurriculumLearningRouteArgs) return false;
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
/// [ModeSelectionScreen]
class ModeSelectionRoute extends PageRouteInfo<void> {
  const ModeSelectionRoute({List<PageRouteInfo>? children})
    : super(ModeSelectionRoute.name, initialChildren: children);

  static const String name = 'ModeSelectionRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const ModeSelectionScreen();
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
/// [ParentModeScreen]
class ParentModeRoute extends PageRouteInfo<void> {
  const ParentModeRoute({List<PageRouteInfo>? children})
    : super(ParentModeRoute.name, initialChildren: children);

  static const String name = 'ParentModeRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const ParentModeScreen();
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
/// [PinChangeScreen]
class PinChangeRoute extends PageRouteInfo<void> {
  const PinChangeRoute({List<PageRouteInfo>? children})
    : super(PinChangeRoute.name, initialChildren: children);

  static const String name = 'PinChangeRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const PinChangeScreen();
    },
  );
}

/// generated route for
/// [PinEntryScreen]
class PinEntryRoute extends PageRouteInfo<void> {
  const PinEntryRoute({List<PageRouteInfo>? children})
    : super(PinEntryRoute.name, initialChildren: children);

  static const String name = 'PinEntryRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const PinEntryScreen();
    },
  );
}

/// generated route for
/// [PinSetupScreen]
class PinSetupRoute extends PageRouteInfo<void> {
  const PinSetupRoute({List<PageRouteInfo>? children})
    : super(PinSetupRoute.name, initialChildren: children);

  static const String name = 'PinSetupRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const PinSetupScreen();
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
/// [RewardCatalogScreen]
class RewardCatalogRoute extends PageRouteInfo<void> {
  const RewardCatalogRoute({List<PageRouteInfo>? children})
    : super(RewardCatalogRoute.name, initialChildren: children);

  static const String name = 'RewardCatalogRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const RewardCatalogScreen();
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
/// [TrackManagementScreen]
class TrackManagementRoute extends PageRouteInfo<TrackManagementRouteArgs> {
  TrackManagementRoute({
    Key? key,
    required String curriculumId,
    List<PageRouteInfo>? children,
  }) : super(
         TrackManagementRoute.name,
         args: TrackManagementRouteArgs(key: key, curriculumId: curriculumId),
         rawPathParams: {'curriculumId': curriculumId},
         initialChildren: children,
       );

  static const String name = 'TrackManagementRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<TrackManagementRouteArgs>(
        orElse: () => TrackManagementRouteArgs(
          curriculumId: pathParams.getString('curriculumId'),
        ),
      );
      return TrackManagementScreen(
        key: args.key,
        curriculumId: args.curriculumId,
      );
    },
  );
}

class TrackManagementRouteArgs {
  const TrackManagementRouteArgs({this.key, required this.curriculumId});

  final Key? key;

  final String curriculumId;

  @override
  String toString() {
    return 'TrackManagementRouteArgs{key: $key, curriculumId: $curriculumId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TrackManagementRouteArgs) return false;
    return key == other.key && curriculumId == other.curriculumId;
  }

  @override
  int get hashCode => key.hashCode ^ curriculumId.hashCode;
}

/// generated route for
/// [TutorDashboardScreen]
class TutorDashboardRoute extends PageRouteInfo<void> {
  const TutorDashboardRoute({List<PageRouteInfo>? children})
    : super(TutorDashboardRoute.name, initialChildren: children);

  static const String name = 'TutorDashboardRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const TutorDashboardScreen();
    },
  );
}

/// generated route for
/// [TutorModeScreen]
class TutorModeRoute extends PageRouteInfo<void> {
  const TutorModeRoute({List<PageRouteInfo>? children})
    : super(TutorModeRoute.name, initialChildren: children);

  static const String name = 'TutorModeRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const TutorModeScreen();
    },
  );
}

/// generated route for
/// [TutorPinChangeScreen]
class TutorPinChangeRoute extends PageRouteInfo<void> {
  const TutorPinChangeRoute({List<PageRouteInfo>? children})
    : super(TutorPinChangeRoute.name, initialChildren: children);

  static const String name = 'TutorPinChangeRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const TutorPinChangeScreen();
    },
  );
}

/// generated route for
/// [TutorPinEntryScreen]
class TutorPinEntryRoute extends PageRouteInfo<void> {
  const TutorPinEntryRoute({List<PageRouteInfo>? children})
    : super(TutorPinEntryRoute.name, initialChildren: children);

  static const String name = 'TutorPinEntryRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const TutorPinEntryScreen();
    },
  );
}

/// generated route for
/// [TutorPinSetupScreen]
class TutorPinSetupRoute extends PageRouteInfo<void> {
  const TutorPinSetupRoute({List<PageRouteInfo>? children})
    : super(TutorPinSetupRoute.name, initialChildren: children);

  static const String name = 'TutorPinSetupRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const TutorPinSetupScreen();
    },
  );
}

/// generated route for
/// [WelcomeScreen]
class WelcomeRoute extends PageRouteInfo<void> {
  const WelcomeRoute({List<PageRouteInfo>? children})
    : super(WelcomeRoute.name, initialChildren: children);

  static const String name = 'WelcomeRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const WelcomeScreen();
    },
  );
}

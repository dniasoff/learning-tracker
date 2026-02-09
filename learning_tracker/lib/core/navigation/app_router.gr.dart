// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'app_router.dart';

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
/// [ContentBrowsingScreen]
class ContentBrowsingRoute extends PageRouteInfo<ContentBrowsingRouteArgs> {
  ContentBrowsingRoute({
    Key? key,
    required String curriculumId,
    List<PageRouteInfo>? children,
  }) : super(
         ContentBrowsingRoute.name,
         args: ContentBrowsingRouteArgs(key: key, curriculumId: curriculumId),
         rawPathParams: {'curriculumId': curriculumId},
         initialChildren: children,
       );

  static const String name = 'ContentBrowsingRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<ContentBrowsingRouteArgs>(
        orElse: () => ContentBrowsingRouteArgs(
          curriculumId: pathParams.getString('curriculumId'),
        ),
      );
      return ContentBrowsingScreen(
        key: args.key,
        curriculumId: args.curriculumId,
      );
    },
  );
}

class ContentBrowsingRouteArgs {
  const ContentBrowsingRouteArgs({this.key, required this.curriculumId});

  final Key? key;

  final String curriculumId;

  @override
  String toString() {
    return 'ContentBrowsingRouteArgs{key: $key, curriculumId: $curriculumId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ContentBrowsingRouteArgs) return false;
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

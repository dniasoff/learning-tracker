import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/dashboard_helpers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';

/// Typed sub-model for the header / top-of-screen section of the dashboard.
///
/// Populated by [dashboardModelProvider].
class DashboardHeaderModel {
  const DashboardHeaderModel({
    required this.userMode,
    required this.currentStreak,
    required this.maxStreak,
    required this.globalPoints,
    required this.profileName,
  });

  final UserMode userMode;
  final int currentStreak;
  final int maxStreak;
  final int globalPoints;
  final String? profileName;
}

/// Typed sub-model for the mission / daily-task section.
class DashboardTasksModel {
  const DashboardTasksModel({required this.allTasks});

  final List<DailyTask> allTasks;

  /// Computes the breakdown using the same groupTasks helper as [DashboardBody].
  DashboardTaskGroups get groups => groupTasks(allTasks);

  int get todayCount => groups.todayTasks.length;
  int get overdueCount => groups.overdueTasks.length;
  int get reviewCount => groups.reviewTasks.length;
  int get totalRemaining => todayCount + overdueCount + reviewCount;
}

/// Typed sub-model for the track carousel section.
class DashboardTracksModel {
  const DashboardTracksModel({required this.activeTracks});

  final List<CurriculumTrack> activeTracks;

  bool get isEmpty => activeTracks.isEmpty;
}

/// Typed sub-model for the lifetime learning section.
class DashboardLifetimeModel {
  const DashboardLifetimeModel({required this.lifetimeTotals});

  final LifetimeTotals? lifetimeTotals;

  double get cumulativePercentage => lifetimeTotals?.percentage ?? 0.0;
}

/// The single composed model for the entire dashboard screen.
///
/// [dashboardModelProvider] is the sole composition point that reads all
/// leaf providers and assembles them into typed sub-models. Dashboard widgets
/// watch this provider (or its sub-model properties) instead of each watching
/// multiple leaf providers individually.
class DashboardModel {
  const DashboardModel({
    required this.header,
    required this.tasks,
    required this.tracks,
    required this.lifetime,
  });

  final DashboardHeaderModel header;
  final DashboardTasksModel tasks;
  final DashboardTracksModel tracks;
  final DashboardLifetimeModel lifetime;
}

/// Single composition point for the dashboard.
///
/// Reads all leaf providers — streak, points, daily tasks, active tracks,
/// lifetime totals — and assembles them into a [DashboardModel].
///
/// Widgets that previously watched 5–10 individual providers now watch this
/// one provider and destructure the sub-models they need.
final dashboardModelProvider = Provider.autoDispose<AsyncValue<DashboardModel>>(
  (ref) {
    final profileId = ref.watch(activeProfileIdProvider);

    final userModeAsync = ref.watch(dashboardUserModeProvider);
    final streakAsync = ref.watch(dashboardStreakProvider);
    final globalPointsAsync = ref.watch(dashboardGlobalPointsProvider);
    final activeTracksAsync = ref.watch(dashboardActiveTracksStreamProvider);
    final dailyTasksAsync = ref.watch(allDailyTasksProvider);
    final lifetimeTotalsAsync = ref.watch(
      lifetimeTotalsAcrossAllCurriculaProvider(profileId),
    );

    // Propagate loading only on true initial load (no cached value yet).
    // During a reload with a cached previous value, keep the stale data visible
    // to avoid a flicker to an empty / "all caught up" state.
    if (!activeTracksAsync.hasValue || !dailyTasksAsync.hasValue) {
      return const AsyncValue.loading();
    }

    // Surface errors from critical providers.
    final tracksError = activeTracksAsync.error;
    if (tracksError != null) {
      return AsyncValue.error(
        tracksError,
        activeTracksAsync.stackTrace ?? StackTrace.current,
      );
    }

    final activeTracks = activeTracksAsync.value ?? const [];
    final userMode = userModeAsync.value ?? UserMode.adult;
    final streakData = streakAsync.value;
    final currentStreak = streakData?.currentStreak ?? 0;
    final maxStreak = streakData?.maxStreak ?? 0;
    final globalPoints = globalPointsAsync.value ?? 0;
    final allTasks = dailyTasksAsync.value ?? const [];
    final lifetimeTotals = lifetimeTotalsAsync.value;

    return AsyncValue.data(
      DashboardModel(
        header: DashboardHeaderModel(
          userMode: userMode,
          currentStreak: currentStreak,
          maxStreak: maxStreak,
          globalPoints: globalPoints,
          profileName: null, // resolved separately via selectedProfileProvider
        ),
        tasks: DashboardTasksModel(allTasks: allTasks),
        tracks: DashboardTracksModel(activeTracks: activeTracks),
        lifetime: DashboardLifetimeModel(lifetimeTotals: lifetimeTotals),
      ),
    );
  },
);

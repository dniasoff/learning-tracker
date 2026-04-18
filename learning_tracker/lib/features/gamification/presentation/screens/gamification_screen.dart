import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/gamification/domain/services/streak_service.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/points_display_widget.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/streak_widget.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/streak_calendar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'gamification_screen.g.dart';

@riverpod
Future<Set<DateTime>> streakCalendar(Ref ref) async {
  final db = ref.watch(userDatabaseProvider);
  final streakService = StreakService(db);
  final now = DateTime.now().toUtc();
  final thirtyDaysAgo = now.subtract(const Duration(days: 30));
  return streakService.getStreakCalendar(startUtc: thirtyDaysAgo, endUtc: now);
}

@RoutePage()
class GamificationScreen extends ConsumerWidget {
  const GamificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userModeAsync = ref.watch(dashboardUserModeProvider);
    final streakAsync = ref.watch(dashboardStreakProvider);
    final calendarAsync = ref.watch(streakCalendarProvider);
    final userMode = userModeAsync.asData?.value ?? UserMode.adult;
    final streakData = streakAsync.asData?.value;
    final currentStreak = streakData?.currentStreak ?? 0;
    final maxStreak = streakData?.maxStreak ?? 0;

    return Scaffold(
      appBar: AppBar(title: const AppBarTitle(text: 'Achievements')),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dashboardStreakProvider);
            ref.invalidate(streakCalendarProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Streak display
              StreakWidget(
                currentStreak: currentStreak,
                maxStreak: maxStreak,
                userMode: userMode,
              ),
              const SizedBox(height: 20),

              // Streak calendar (last 30 days)
              Text(
                'Activity Calendar',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              calendarAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (_, __) => const Text('Error loading calendar'),
                data: (activeDates) {
                  final now = DateTime.now();
                  final start = DateTime(
                    now.year,
                    now.month,
                    now.day,
                  ).subtract(const Duration(days: 29));
                  final end = DateTime(now.year, now.month, now.day);
                  return StreakCalendar(
                    activeDates: activeDates,
                    startDate: start,
                    endDate: end,
                  );
                },
              ),
              const SizedBox(height: 24),

              // Points display
              PointsDisplayWidget(userMode: userMode),
            ],
          ),
        ),
      ),
    );
  }
}

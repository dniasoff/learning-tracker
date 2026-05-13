import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/gamification/domain/services/streak_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/streak_calendar.dart';

@RoutePage()
class StreakHistoryScreen extends ConsumerWidget {
  const StreakHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(dashboardStreakProvider);
    final profileId = ref.watch(activeProfileIdProvider);
    final db = ref.watch(userDatabaseProvider);
    final current = streakAsync.asData?.value.currentStreak ?? 0;
    final longest = streakAsync.asData?.value.maxStreak ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const AppBarTitle(text: 'Streak'),
        backgroundColor: const Color(0xFFF4F6FB),
        foregroundColor: AppTheme.brandInk,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: _StreakStatTile(
                    icon: Icons.local_fire_department_rounded,
                    iconColor: const Color(0xFFFF6E76),
                    value: '$current',
                    label: 'CURRENT',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StreakStatTile(
                    icon: Icons.workspace_premium_rounded,
                    iconColor: const Color(0xFFF8C146),
                    value: '$longest',
                    label: 'LONGEST',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FutureBuilder<Set<DateTime>>(
              future: StreakService(db, profileId: profileId).getStreakCalendar(
                startUtc: DateTimeFactory.nowUtc().subtract(
                  const Duration(days: 30),
                ),
                endUtc: DateTimeFactory.nowUtc(),
              ),
              builder: (context, snapshot) {
                final activeDates = snapshot.data ?? const <DateTime>{};
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF03174C).withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Last 14 days',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.brandInk,
                        ),
                      ),
                      const SizedBox(height: 12),
                      StreakCalendar(
                        activeDates: activeDates,
                        startDate: DateTimeFactory.nowLocal().subtract(
                          const Duration(days: 13),
                        ),
                        endDate: DateTimeFactory.nowLocal(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakStatTile extends StatelessWidget {
  const _StreakStatTile({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF03174C).withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          const SizedBox(height: 24),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: const Color(0xFF11182C),
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xFF7C8595),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

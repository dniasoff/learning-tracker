import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/gamification/domain/services/streak_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/streak_calendar.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The three calendar views available on the streak history screen.
enum _StreakRange { sevenDays, twentyNineDays, allTime }

@RoutePage()
class StreakHistoryScreen extends ConsumerStatefulWidget {
  const StreakHistoryScreen({super.key});

  @override
  ConsumerState<StreakHistoryScreen> createState() =>
      _StreakHistoryScreenState();
}

class _StreakHistoryScreenState extends ConsumerState<StreakHistoryScreen> {
  _StreakRange _range = _StreakRange.sevenDays;

  ({DateTime start, DateTime end}) _dateRange(LocalDayClock clock) {
    final today = clock.today();
    return switch (_range) {
      _StreakRange.sevenDays => (
        start: today.subtract(const Duration(days: 6)),
        end: today,
      ),
      _StreakRange.twentyNineDays => (
        start: today.subtract(const Duration(days: 28)),
        end: today,
      ),
      // DateTime(2000, 1, 1) matches the bulk-prior sentinel epoch, consistent
      // with how ProgressChartsScreen handles the "All time" floor (Fix M1).
      _StreakRange.allTime => (start: DateTime(2000, 1, 1), end: today),
    };
  }

  String _rangeLabel(AppLocalizations l10n) => switch (_range) {
    _StreakRange.sevenDays => l10n.streakHistoryLast7Days,
    _StreakRange.twentyNineDays => l10n.streakHistoryLast29Days,
    _StreakRange.allTime => l10n.streakHistoryAllTime,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final streakAsync = ref.watch(dashboardStreakProvider);
    final profileId = ref.watch(activeProfileIdProvider);
    final db = ref.watch(userDatabaseProvider);
    final clock = ref.watch(localDayClockProvider);
    final current = streakAsync.asData?.value.currentStreak ?? 0;
    final longest = streakAsync.asData?.value.maxStreak ?? 0;
    final dates = _dateRange(clock);

    return Scaffold(
      backgroundColor: AppColors.surfaceF4b,
      appBar: AppBar(
        title: AppBarTitle(text: l10n.streakHistoryTitle),
        backgroundColor: AppColors.surfaceF4b,
        foregroundColor: AppTheme.brandInk,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: _StreakStatTile(
                    icon: Icons.local_fire_department_rounded,
                    iconColor: const Color(0xFFFF6E76),
                    value: '$current',
                    label: l10n.streakHistoryCurrent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StreakStatTile(
                    icon: Icons.workspace_premium_rounded,
                    iconColor: AppColors.chartAmber,
                    value: '$longest',
                    label: l10n.streakHistoryLongest,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Range selector chips.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _RangeChip(
                    label: l10n.streakHistoryLast7Days,
                    selected: _range == _StreakRange.sevenDays,
                    onTap: () =>
                        setState(() => _range = _StreakRange.sevenDays),
                  ),
                  const SizedBox(width: 8),
                  _RangeChip(
                    label: l10n.streakHistoryLast29Days,
                    selected: _range == _StreakRange.twentyNineDays,
                    onTap: () =>
                        setState(() => _range = _StreakRange.twentyNineDays),
                  ),
                  const SizedBox(width: 8),
                  _RangeChip(
                    label: l10n.streakHistoryAllTime,
                    selected: _range == _StreakRange.allTime,
                    onTap: () => setState(() => _range = _StreakRange.allTime),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<Set<DateTime>>(
              // Re-build when range changes by keying on the range enum.
              key: ValueKey(_range),
              future: StreakService(db, profileId: profileId).getStreakCalendar(
                startUtc: dates.start.toUtc(),
                endUtc: dates.end.toUtc(),
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
                        color: AppColors.blueNavy.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _rangeLabel(l10n),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.brandInk,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (!snapshot.hasData)
                        const Center(child: CircularProgressIndicator())
                      else
                        StreakCalendar(
                          activeDates: activeDates,
                          startDate: dates.start,
                          endDate: dates.end,
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

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppTheme.brandInk : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppTheme.brandInk : const Color(0xFFDDE1EA),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF5A6175),
          ),
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
            color: AppColors.blueNavy.withValues(alpha: 0.08),
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

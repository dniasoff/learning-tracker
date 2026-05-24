import 'dart:async' show unawaited;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/features/gamification/domain/services/streak_service.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/achievements_overview_provider.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/achievement_tier_card.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/achievement_unlock_celebration.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/achievements_header.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/points_display_widget.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/pro_tip_card.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/progress_summary_card.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/streak_widget.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/track_filter_row.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/streak_calendar.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'gamification_screen.g.dart';

@riverpod
Future<Set<DateTime>> streakCalendar(Ref ref) async {
  final db = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final streakService = StreakService(db, profileId: profileId);
  final now = DateTimeFactory.nowUtc();
  final thirtyDaysAgo = now.subtract(const Duration(days: 30));
  return streakService.getStreakCalendar(startUtc: thirtyDaysAgo, endUtc: now);
}

const Color _kPageBg = Color(0xFFF0F2F5);

String _curriculumLabel(
  BuildContext context,
  WidgetRef ref,
  AchievementRowVm row,
) {
  if (row.trackId == RewardMilestone.kGlobalTrackSentinel) {
    return AppLocalizations.of(context)!.achievementsGlobalRewardsLabel;
  }
  final c = row.curriculumId;
  if (c == null) return row.trackLabel;
  return curriculumLabelText(ref, curriculum: c);
}

String _filterChipLabel(
  BuildContext context,
  WidgetRef ref,
  AchievementTrackFilterVm opt,
) {
  if (opt.trackId == RewardMilestone.kGlobalTrackSentinel) {
    return AppLocalizations.of(context)!.achievementsGlobalRewardsLabel;
  }
  final c = opt.curriculumId;
  if (c == null) return opt.sortLabel;
  return curriculumLabelText(ref, curriculum: c);
}

@RoutePage()
class GamificationScreen extends ConsumerStatefulWidget {
  const GamificationScreen({super.key});

  @override
  ConsumerState<GamificationScreen> createState() => _GamificationScreenState();
}

class _GamificationScreenState extends ConsumerState<GamificationScreen> {
  /// `null` = all tracks.
  int? _trackFilterId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    ref.listen(achievementsOverviewProvider, (previous, next) {
      next.whenData((overview) {
        unawaited(
          AchievementUnlockCelebration.migrateDoneKeysIfNeeded(ref, overview),
        );
      });
    });
    final achievementsAsync = ref.watch(achievementsOverviewProvider);
    final userModeAsync = ref.watch(dashboardUserModeProvider);
    final streakAsync = ref.watch(dashboardStreakProvider);
    final calendarAsync = ref.watch(streakCalendarProvider);
    final userMode = userModeAsync.asData?.value ?? ProfileMode.adult;
    final streakData = streakAsync.asData?.value;
    final currentStreak = streakData?.currentStreak ?? 0;
    final maxStreak = streakData?.maxStreak ?? 0;

    return Scaffold(
      backgroundColor: _kPageBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AchievementsHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(achievementsOverviewProvider);
                  ref.invalidate(dashboardStreakProvider);
                  ref.invalidate(streakCalendarProvider);
                },
                child: achievementsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(
                        l10n.errorLoadingCalendar,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                  data: (overview) {
                    final filtered = _trackFilterId == null
                        ? overview.rows
                        : overview.rows
                              .where((r) => r.trackId == _trackFilterId)
                              .toList();
                    final sorted = [...filtered]
                      ..sort((a, b) {
                        final byTh = a.milestone.thresholdPoints.compareTo(
                          b.milestone.thresholdPoints,
                        );
                        if (byTh != 0) return byTh;
                        return _curriculumLabel(
                          context,
                          ref,
                          a,
                        ).compareTo(_curriculumLabel(context, ref, b));
                      });

                    return CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          sliver: SliverToBoxAdapter(
                            child: ProgressSummaryCard(
                              l10n: l10n,
                              unlocked: overview.unlockedCount,
                              total: overview.totalMilestones,
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                          sliver: SliverToBoxAdapter(
                            child: TrackFilterRow(
                              l10n: l10n,
                              options: overview.trackFilterOptions,
                              selectedTrackId: _trackFilterId,
                              onSelectAll: () =>
                                  setState(() => _trackFilterId = null),
                              onSelectTrack: (id) =>
                                  setState(() => _trackFilterId = id),
                              labelFor: (o) =>
                                  _filterChipLabel(context, ref, o),
                            ),
                          ),
                        ),
                        if (sorted.isEmpty)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                            sliver: SliverToBoxAdapter(
                              child: Text(
                                l10n.noRewardsYet,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(color: AppTheme.brandCoral),
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final row = sorted[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: AchievementTierCard(
                                    l10n: l10n,
                                    row: row,
                                    trackTag: _curriculumLabel(
                                      context,
                                      ref,
                                      row,
                                    ),
                                  ),
                                );
                              }, childCount: sorted.length),
                            ),
                          ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          sliver: SliverToBoxAdapter(
                            child: ProTipCard(l10n: l10n),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Theme(
                            data: Theme.of(
                              context,
                            ).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              title: Text(
                                l10n.achievementsActivityAndPoints,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              childrenPadding: const EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                24,
                              ),
                              children: [
                                StreakWidget(
                                  currentStreak: currentStreak,
                                  maxStreak: maxStreak,
                                  userMode: userMode,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  l10n.activityCalendar,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 8),
                                calendarAsync.when(
                                  loading: () => const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                  error: (_, __) =>
                                      Text(l10n.errorLoadingCalendar),
                                  data: (activeDates) {
                                    final now = DateTimeFactory.nowLocal();
                                    final start = DateTime(
                                      now.year,
                                      now.month,
                                      now.day,
                                    ).subtract(const Duration(days: 29));
                                    final end = DateTime(
                                      now.year,
                                      now.month,
                                      now.day,
                                    );
                                    return StreakCalendar(
                                      activeDates: activeDates,
                                      startDate: start,
                                      endDate: end,
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                                PointsDisplayWidget(userMode: userMode),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

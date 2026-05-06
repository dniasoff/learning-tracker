import 'dart:async' show unawaited;
import 'dart:ui' as ui;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/features/gamification/domain/services/streak_service.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/achievements_overview_provider.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/achievement_unlock_celebration.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/points_display_widget.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/streak_widget.dart';
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
  final now = DateTime.now().toUtc();
  final thirtyDaysAgo = now.subtract(const Duration(days: 30));
  return streakService.getStreakCalendar(startUtc: thirtyDaysAgo, endUtc: now);
}

const Color _kBrandBlue = Color(0xFF0038A8);
const Color _kPageBg = Color(0xFFF0F2F5);

String _curriculumLabel(BuildContext context, AchievementRowVm row) {
  if (row.trackId == RewardMilestone.kGlobalTrackSentinel) {
    return AppLocalizations.of(context)!.achievementsGlobalRewardsLabel;
  }
  final c = row.curriculumId;
  if (c == null) return row.trackLabel;
  final code = Localizations.localeOf(context).languageCode;
  return code == 'he' ? c.displayNameHe : c.displayNameEn;
}

String _filterChipLabel(BuildContext context, AchievementTrackFilterVm opt) {
  if (opt.trackId == RewardMilestone.kGlobalTrackSentinel) {
    return AppLocalizations.of(context)!.achievementsGlobalRewardsLabel;
  }
  final c = opt.curriculumId;
  if (c == null) return opt.sortLabel;
  final code = Localizations.localeOf(context).languageCode;
  return code == 'he' ? c.displayNameHe : c.displayNameEn;
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
    final userMode = userModeAsync.asData?.value ?? UserMode.adult;
    final streakData = streakAsync.asData?.value;
    final currentStreak = streakData?.currentStreak ?? 0;
    final maxStreak = streakData?.maxStreak ?? 0;

    return Scaffold(
      backgroundColor: _kPageBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _AchievementsHeader(),
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
                          a,
                        ).compareTo(_curriculumLabel(context, b));
                      });

                    return CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          sliver: SliverToBoxAdapter(
                            child: _ProgressSummaryCard(
                              l10n: l10n,
                              unlocked: overview.unlockedCount,
                              total: overview.totalMilestones,
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                          sliver: SliverToBoxAdapter(
                            child: _TrackFilterRow(
                              l10n: l10n,
                              options: overview.trackFilterOptions,
                              selectedTrackId: _trackFilterId,
                              onSelectAll: () =>
                                  setState(() => _trackFilterId = null),
                              onSelectTrack: (id) =>
                                  setState(() => _trackFilterId = id),
                              labelFor: (o) => _filterChipLabel(context, o),
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
                                    ?.copyWith(color: const Color(0xFF708090)),
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
                                  child: _AchievementTierCard(
                                    l10n: l10n,
                                    row: row,
                                    trackTag: _curriculumLabel(context, row),
                                  ),
                                );
                              }, childCount: sorted.length),
                            ),
                          ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          sliver: SliverToBoxAdapter(
                            child: _ProTipCard(l10n: l10n),
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
                                    final now = DateTime.now();
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

class _AchievementsHeader extends StatelessWidget {
  const _AchievementsHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Center(
        child: Text(
          l10n.myAchievementsTitle,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: const Color(0xFF1A1A1A),
          ),
        ),
      ),
    );
  }
}

class _ProgressSummaryCard extends StatelessWidget {
  const _ProgressSummaryCard({
    required this.l10n,
    required this.unlocked,
    required this.total,
  });

  final AppLocalizations l10n;
  final int unlocked;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kBrandBlue,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x330038A8),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -4,
            top: -8,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFFE53935),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.achievementsYourProgress,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Directionality(
                textDirection: ui.TextDirection.ltr,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      l10n.achievementsRewardsFraction(unlocked, total),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                    ),
                    Text(
                      ' ${l10n.achievementsRewardsLabelWord}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.achievementsEncouragement,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.92),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrackFilterRow extends StatelessWidget {
  const _TrackFilterRow({
    required this.l10n,
    required this.options,
    required this.selectedTrackId,
    required this.onSelectAll,
    required this.onSelectTrack,
    required this.labelFor,
  });

  final AppLocalizations l10n;
  final List<AchievementTrackFilterVm> options;
  final int? selectedTrackId;
  final VoidCallback onSelectAll;
  final void Function(int trackId) onSelectTrack;
  final String Function(AchievementTrackFilterVm o) labelFor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.achievementsTrackSection,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: const Color(0xFF708090),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: l10n.achievementsAllTracks,
                selected: selectedTrackId == null,
                onTap: onSelectAll,
              ),
              for (final o in options) ...[
                const SizedBox(width: 8),
                _FilterChip(
                  label: labelFor(o),
                  selected: selectedTrackId == o.trackId,
                  onTap: () => onSelectTrack(o.trackId),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? _kBrandBlue : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? _kBrandBlue : const Color(0xFFE0E4E8),
            ),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x220038A8),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF4A5568),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _AchievementTierCard extends StatelessWidget {
  const _AchievementTierCard({
    required this.l10n,
    required this.row,
    required this.trackTag,
  });

  final AppLocalizations l10n;
  final AchievementRowVm row;
  final String trackTag;

  double get _progressFraction {
    if (row.isUnlocked) return 1;
    final th = row.milestone.thresholdPoints;
    if (th <= 0) return 0;
    return (row.trackPoints / th).clamp(0.0, 1.0);
  }

  int get _percentRounded {
    if (row.isUnlocked) return 100;
    final th = row.milestone.thresholdPoints;
    if (th <= 0) return 0;
    return (row.trackPoints / th * 100).round().clamp(0, 100);
  }

  String get _statusLabel {
    if (row.isUnlocked) return l10n.achievementsStatusUnlocked;
    if (row.isNextUp) return l10n.achievementsStatusComingSoon;
    return l10n.achievementsStatusLocked;
  }

  String _milestonePointsLine(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final fmt = NumberFormat.decimalPattern(locale);
    return l10n.achievementsMilestonePoints(
      fmt.format(row.milestone.thresholdPoints),
    );
  }

  Color _statusTextColor(_TierStyle scheme) {
    if (row.isLegendTier) {
      if (row.isUnlocked) return const Color(0xFF69F0AE);
      if (row.isNextUp) return Colors.white;
      return Colors.white70;
    }
    if (row.isUnlocked) return const Color(0xFF2E7D32);
    if (row.isNextUp) return _kBrandBlue;
    return const Color(0xFF90A4AE);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = _TierStyle.forTitle(row.milestone.title, row.isLegendTier);

    final cardContent = Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TierIconBox(
            scheme: scheme,
            unlocked: row.isUnlocked,
            comingSoon: row.isNextUp,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 96),
                      child: Align(
                        alignment: AlignmentDirectional.topStart,
                        child: Text(
                          row.milestone.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: scheme.titleColor,
                                height: 1.2,
                              ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: _TrackTagChip(label: trackTag, scheme: scheme),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _statusLabel,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    color: _statusTextColor(scheme),
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _progressFraction,
                    minHeight: 7,
                    backgroundColor: scheme.barBg,
                    color: row.isLegendTier && row.isUnlocked
                        ? const Color(0xFF69F0AE)
                        : scheme.barFill,
                  ),
                ),
                const SizedBox(height: 6),
                Directionality(
                  textDirection: ui.TextDirection.ltr,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _milestonePointsLine(context),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                                color: row.isLegendTier
                                    ? Colors.white.withValues(alpha: 0.9)
                                    : const Color(0xFF4A5568),
                              ),
                        ),
                      ),
                      Text(
                        l10n.achievementsProgressPercent(_percentRounded),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: row.isLegendTier
                              ? Colors.white.withValues(alpha: 0.9)
                              : const Color(0xFF4A5568),
                        ),
                      ),
                    ],
                  ),
                ),
                if (row.isLegendTier) ...[
                  const SizedBox(height: 4),
                  Text(
                    l10n.achievementsUltimateGoal,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (row.isLegendTier) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A237E), Color(0xFF4A148C)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x441A237E),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: cardContent,
      );
    }

    return Material(
      color: scheme.cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.borderColor),
      ),
      child: cardContent,
    );
  }
}

class _TierIconBox extends StatelessWidget {
  const _TierIconBox({
    required this.scheme,
    required this.unlocked,
    required this.comingSoon,
  });

  final _TierStyle scheme;
  final bool unlocked;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    final isLocked = !unlocked;
    final borderColor = (comingSoon && isLocked)
        ? const Color(0xFFB0BEC5)
        : scheme.iconBorder;
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: scheme.iconBg,
        borderRadius: BorderRadius.circular(14),
        border: isLocked
            ? Border.all(color: borderColor, width: 1.5)
            : Border.all(color: scheme.iconBorder, width: 1.2),
      ),
      child: Center(
        child: Icon(
          isLocked ? Icons.lock_rounded : scheme.unlockedIcon,
          size: isLocked ? 28 : 30,
          color: isLocked ? scheme.lockIconColor : scheme.iconFg,
        ),
      ),
    );
  }
}

class _TrackTagChip extends StatelessWidget {
  const _TrackTagChip({required this.label, required this.scheme});

  final String label;
  final _TierStyle scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.tagBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          fontSize: 10,
          letterSpacing: 0.4,
          color: scheme.tagFg,
        ),
      ),
    );
  }
}

class _TierStyle {
  const _TierStyle({
    required this.cardBg,
    required this.borderColor,
    required this.iconBg,
    required this.iconFg,
    required this.iconBorder,
    required this.titleColor,
    required this.mutedIconColor,
    required this.barBg,
    required this.barFill,
    required this.tagBg,
    required this.tagFg,
    required this.unlockedIcon,
    required this.lockIconColor,
  });

  final Color cardBg;
  final Color borderColor;
  final Color iconBg;
  final Color iconFg;
  final Color iconBorder;
  final Color titleColor;
  final Color mutedIconColor;
  final Color barBg;
  final Color barFill;
  final Color tagBg;
  final Color tagFg;
  final IconData unlockedIcon;
  final Color lockIconColor;

  static _TierStyle forTitle(String title, bool isLegend) {
    final t = title.trim();
    if (isLegend) {
      return _TierStyle(
        cardBg: Colors.transparent,
        borderColor: Colors.transparent,
        iconBg: Colors.white.withValues(alpha: 0.12),
        iconFg: Colors.white,
        iconBorder: Colors.white30,
        titleColor: Colors.white,
        mutedIconColor: Colors.white70,
        barBg: const Color(0xFF404060),
        barFill: const Color(0xFF9E9E9E),
        tagBg: Colors.white.withValues(alpha: 0.2),
        tagFg: Colors.white,
        unlockedIcon: Icons.workspace_premium_rounded,
        lockIconColor: Colors.white70,
      );
    }
    switch (t) {
      case 'Bronze Star':
        return const _TierStyle(
          cardBg: Color(0xFFF5E6D3),
          borderColor: Color(0xFFE8D5C4),
          iconBg: Color(0xFF8D6E63),
          iconFg: Colors.white,
          iconBorder: Color(0xFF6D4C41),
          titleColor: Color(0xFF4E342E),
          mutedIconColor: Color(0xFF8D6E63),
          barBg: Color(0xFFFFE0B2),
          barFill: Color(0xFF6D4C41),
          tagBg: Color(0xFFFFE0B2),
          tagFg: Color(0xFFBF360C),
          unlockedIcon: Icons.military_tech_rounded,
          lockIconColor: Color(0xFF5D4037),
        );
      case 'Silver Star':
        return const _TierStyle(
          cardBg: Colors.white,
          borderColor: Color(0xFFECEFF1),
          iconBg: Color(0xFF90A4AE),
          iconFg: Colors.white,
          iconBorder: Color(0xFF78909C),
          titleColor: Color(0xFF37474F),
          mutedIconColor: Color(0xFF90A4AE),
          barBg: Color(0xFFE8ECEF),
          barFill: Color(0xFF546E7A),
          tagBg: Color(0xFFCFD8DC),
          tagFg: Color(0xFF455A64),
          unlockedIcon: Icons.star_rounded,
          lockIconColor: Color(0xFF607D8B),
        );
      case 'Gold Star':
        return const _TierStyle(
          cardBg: Color(0xFFFFF9E6),
          borderColor: Color(0xFFFFECB3),
          iconBg: Color(0xFFFFC400),
          iconFg: Colors.white,
          iconBorder: Color(0xFFFFA000),
          titleColor: Color(0xFFF57F17),
          mutedIconColor: Color(0xFFFFB300),
          barBg: Color(0xFFFFE082),
          barFill: Color(0xFFFF8F00),
          tagBg: Color(0xFFFFF3C4),
          tagFg: Color(0xFFE65100),
          unlockedIcon: Icons.emoji_events_rounded,
          lockIconColor: Color(0xFFF9A825),
        );
      case 'Platinum Star':
        return const _TierStyle(
          cardBg: Color(0xFFFAFCFF),
          borderColor: Color(0xFFBBDEFB),
          iconBg: Color(0xFFE3F2FD),
          iconFg: Color(0xFF42A5F5),
          iconBorder: Color(0xFF64B5F6),
          titleColor: Color(0xFF1565C0),
          mutedIconColor: Color(0xFF64B5F6),
          barBg: Color(0xFFBBDEFB),
          barFill: Color(0xFF2196F3),
          tagBg: Color(0xFFE1F5FE),
          tagFg: Color(0xFF0277BD),
          unlockedIcon: Icons.military_tech,
          lockIconColor: Color(0xFF5C6BC0),
        );
      case 'Premium Star':
        return const _TierStyle(
          cardBg: Color(0xFFF3E5F5),
          borderColor: Color(0xFFE1BEE7),
          iconBg: Color(0xFFEDE7F6),
          iconFg: Color(0xFF7E57C2),
          iconBorder: Color(0xFFB39DDB),
          titleColor: Color(0xFF4527A0),
          mutedIconColor: Color(0xFF9575CD),
          barBg: Color(0xFFCE93D8),
          barFill: Color(0xFF7B1FA2),
          tagBg: Color(0xFFE1BEE7),
          tagFg: Color(0xFF4A148C),
          unlockedIcon: Icons.diamond_outlined,
          lockIconColor: Color(0xFF6A1B9A),
        );
      case 'Diamond Star':
        return const _TierStyle(
          cardBg: Color(0xFFE0F7FF),
          borderColor: Color(0xFF80DEEA),
          iconBg: Color(0xFFE0F7FA),
          iconFg: Color(0xFF00BCD4),
          iconBorder: Color(0xFF4DD0E1),
          titleColor: Color(0xFF006064),
          mutedIconColor: Color(0xFF00ACC1),
          barBg: Color(0xFF80DEEA),
          barFill: Color(0xFF00ACC1),
          tagBg: Color(0xFFB2EBF2),
          tagFg: Color(0xFF00838F),
          unlockedIcon: Icons.diamond_outlined,
          lockIconColor: Color(0xFF0097A7),
        );
      case 'Elite Star':
        return const _TierStyle(
          cardBg: Color(0xFFFCE4EC),
          borderColor: Color(0xFFF8BBD0),
          iconBg: Color(0xFFF8BBD0),
          iconFg: Color(0xFFEC407A),
          iconBorder: Color(0xFFF48FB1),
          titleColor: Color(0xFFAD1457),
          mutedIconColor: Color(0xFFF06292),
          barBg: Color(0xFFF8BBD0),
          barFill: Color(0xFFE91E63),
          tagBg: Color(0xFFF8BBD0),
          tagFg: Color(0xFFAD1457),
          unlockedIcon: Icons.local_fire_department_outlined,
          lockIconColor: Color(0xFFC2185B),
        );
      default:
        return const _TierStyle(
          cardBg: Colors.white,
          borderColor: Color(0xFFE0E0E0),
          iconBg: Color(0xFFF5F5F5),
          iconFg: Color(0xFF78909C),
          iconBorder: Color(0xFFB0BEC5),
          titleColor: Color(0xFF37474F),
          mutedIconColor: Color(0xFF90A4AE),
          barBg: Color(0xFFECEFF1),
          barFill: _kBrandBlue,
          tagBg: Color(0xFFECEFF1),
          tagFg: Color(0xFF546E7A),
          unlockedIcon: Icons.star_rounded,
          lockIconColor: Color(0xFF78909C),
        );
    }
  }
}

class _ProTipCard extends StatelessWidget {
  const _ProTipCard({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFEFD5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFCC80)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.lightbulb_rounded,
                size: 26,
                color: Color(0xFF212121),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF4E342E),
                    height: 1.4,
                  ),
                  children: [
                    TextSpan(
                      text: '${l10n.achievementsProTipTitle} ',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFBF360C),
                      ),
                    ),
                    TextSpan(text: l10n.achievementsProTipBody),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/gamification/domain/services/streak_service.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/achievements_overview_provider.dart';
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

String _curriculumLabel(
  BuildContext context,
  AchievementRowVm row,
) {
  final c = row.curriculumId;
  if (c == null) return row.trackLabel;
  final code = Localizations.localeOf(context).languageCode;
  return code == 'he' ? c.displayNameHe : c.displayNameEn;
}

String _filterChipLabel(
  BuildContext context,
  AchievementTrackFilterVm opt,
) {
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
            _AchievementsHeader(l10n: l10n),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(achievementsOverviewProvider);
                  ref.invalidate(dashboardStreakProvider);
                  ref.invalidate(streakCalendarProvider);
                },
                child: achievementsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
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
                    final sorted = [...filtered]..sort((a, b) {
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
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final row = sorted[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _AchievementTierCard(
                                      l10n: l10n,
                                      row: row,
                                      trackTag: _curriculumLabel(context, row),
                                    ),
                                  );
                                },
                                childCount: sorted.length,
                              ),
                            ),
                          ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          sliver: SliverToBoxAdapter(child: _ProTipCard(l10n: l10n)),
                        ),
                        SliverToBoxAdapter(
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              dividerColor: Colors.transparent,
                            ),
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
  const _AchievementsHeader({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        l10n.myAchievementsTitle,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
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
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
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
              Text(
                l10n.achievementsRewardsCount(unlocked, total),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.achievementsAcrossAllTracks,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.88),
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
              color: selected
                  ? _kBrandBlue
                  : const Color(0xFFE0E4E8),
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

  String get _statusLabel {
    if (row.isUnlocked) return l10n.achievementsStatusUnlocked;
    if (row.isNextUp) return l10n.achievementsStatusComingSoon;
    return l10n.achievementsStatusLocked;
  }

  String _pointsLine(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final fmt = NumberFormat.decimalPattern(locale);
    return l10n.achievementsUnlockedAtPoints(
      fmt.format(row.milestone.thresholdPoints),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = _TierStyle.forTitle(row.milestone.title, row.isLegendTier);
    final showLockCorner = !row.isUnlocked;

    Widget cardContent = Padding(
      padding: const EdgeInsets.all(14),
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        row.milestone.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.titleColor,
                        ),
                      ),
                    ),
                    if (showLockCorner)
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 18,
                        color: scheme.mutedIconColor,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                _TrackTagChip(label: trackTag, scheme: scheme),
                const SizedBox(height: 8),
                Text(
                  _pointsLine(context),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: row.isLegendTier
                        ? Colors.white.withValues(alpha: 0.85)
                        : const Color(0xFF5C6B7A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _statusLabel,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: row.isLegendTier
                        ? (row.isUnlocked
                              ? const Color(0xFF69F0AE)
                              : row.isNextUp
                              ? Colors.white
                              : Colors.white70)
                        : row.isUnlocked
                        ? const Color(0xFF2E7D32)
                        : row.isNextUp
                        ? _kBrandBlue
                        : const Color(0xFF90A4AE),
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _progressFraction,
                    minHeight: 8,
                    backgroundColor: scheme.barBg,
                    color: row.isUnlocked
                        ? (row.isLegendTier
                              ? const Color(0xFF69F0AE)
                              : const Color(0xFF43A047))
                        : (row.isLegendTier
                              ? Colors.white.withValues(alpha: 0.9)
                              : _kBrandBlue),
                  ),
                ),
                if (row.isLegendTier) ...[
                  const SizedBox(height: 6),
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
      return Container(
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
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: scheme.iconBg,
        borderRadius: BorderRadius.circular(14),
        border: comingSoon && !unlocked
            ? Border.all(color: const Color(0xFFCFD8DC), width: 1.5)
            : Border.all(color: scheme.iconBorder, width: 1),
      ),
      child: Icon(
        scheme.icon,
        size: 30,
        color: unlocked ? scheme.iconFg : scheme.iconFg.withValues(alpha: 0.45),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.tagBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
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
    required this.tagBg,
    required this.tagFg,
    required this.icon,
  });

  final Color cardBg;
  final Color borderColor;
  final Color iconBg;
  final Color iconFg;
  final Color iconBorder;
  final Color titleColor;
  final Color mutedIconColor;
  final Color barBg;
  final Color tagBg;
  final Color tagFg;
  final IconData icon;

  static _TierStyle forTitle(String title, bool isLegend) {
    final t = title.trim();
    if (isLegend) {
      return _TierStyle(
        cardBg: Colors.transparent,
        borderColor: Colors.transparent,
        iconBg: Colors.white.withValues(alpha: 0.15),
        iconFg: Colors.white,
        iconBorder: Colors.white24,
        titleColor: Colors.white,
        mutedIconColor: Colors.white70,
        barBg: Colors.white24,
        tagBg: Colors.white24,
        tagFg: Colors.white,
        icon: Icons.workspace_premium_rounded,
      );
    }
    switch (t) {
      case 'Bronze Star':
        return _TierStyle(
          cardBg: const Color(0xFFF5E6D3),
          borderColor: const Color(0xFFE8D5C4),
          iconBg: const Color(0xFFBCAAA4),
          iconFg: const Color(0xFF5D4037),
          iconBorder: const Color(0xFF8D6E63),
          titleColor: const Color(0xFF4E342E),
          mutedIconColor: const Color(0xFF8D6E63),
          barBg: const Color(0xFFD7CCC8),
          tagBg: const Color(0xFFFFE0B2),
          tagFg: const Color(0xFFE65100),
          icon: Icons.star_rounded,
        );
      case 'Silver Star':
        return _TierStyle(
          cardBg: Colors.white,
          borderColor: const Color(0xFFECEFF1),
          iconBg: const Color(0xFFECEFF1),
          iconFg: const Color(0xFF607D8B),
          iconBorder: const Color(0xFFB0BEC5),
          titleColor: const Color(0xFF37474F),
          mutedIconColor: const Color(0xFF90A4AE),
          barBg: const Color(0xFFECEFF1),
          tagBg: const Color(0xFFCFD8DC),
          tagFg: const Color(0xFF455A64),
          icon: Icons.star_rate_rounded,
        );
      case 'Gold Star':
        return _TierStyle(
          cardBg: const Color(0xFFFFF9E6),
          borderColor: const Color(0xFFFFECB3),
          iconBg: const Color(0xFFFFD54F),
          iconFg: Colors.white,
          iconBorder: const Color(0xFFFFC107),
          titleColor: const Color(0xFFF57F17),
          mutedIconColor: const Color(0xFFFFB300),
          barBg: const Color(0xFFFFE082),
          tagBg: const Color(0xFFFFF59D),
          tagFg: const Color(0xFFF9A825),
          icon: Icons.star_rounded,
        );
      case 'Platinum Star':
        return _TierStyle(
          cardBg: Colors.white,
          borderColor: const Color(0xFFE0E0E0),
          iconBg: const Color(0xFFF5F5F5),
          iconFg: const Color(0xFF78909C),
          iconBorder: const Color(0xFFB0BEC5),
          titleColor: const Color(0xFF455A64),
          mutedIconColor: const Color(0xFF90A4AE),
          barBg: const Color(0xFFECEFF1),
          tagBg: const Color(0xFFECEFF1),
          tagFg: const Color(0xFF546E7A),
          icon: Icons.military_tech_rounded,
        );
      case 'Premium Star':
        return _TierStyle(
          cardBg: const Color(0xFFF3E5F5),
          borderColor: const Color(0xFFE1BEE7),
          iconBg: const Color(0xFFEDE7F6),
          iconFg: const Color(0xFF7E57C2),
          iconBorder: const Color(0xFFB39DDB),
          titleColor: const Color(0xFF4527A0),
          mutedIconColor: const Color(0xFF9575CD),
          barBg: const Color(0xFFD1C4E9),
          tagBg: const Color(0xFFE1BEE7),
          tagFg: const Color(0xFF6A1B9A),
          icon: Icons.emoji_events_outlined,
        );
      case 'Diamond Star':
        return _TierStyle(
          cardBg: const Color(0xFFE3F2FD),
          borderColor: const Color(0xFFBBDEFB),
          iconBg: const Color(0xFFE1F5FE),
          iconFg: const Color(0xFF0288D1),
          iconBorder: const Color(0xFF4FC3F7),
          titleColor: const Color(0xFF01579B),
          mutedIconColor: const Color(0xFF29B6F6),
          barBg: const Color(0xFFB3E5FC),
          tagBg: const Color(0xFFBBDEFB),
          tagFg: const Color(0xFF0277BD),
          icon: Icons.diamond_outlined,
        );
      case 'Elite Star':
        return _TierStyle(
          cardBg: const Color(0xFFFCE4EC),
          borderColor: const Color(0xFFF8BBD0),
          iconBg: const Color(0xFFFCE4EC),
          iconFg: const Color(0xFFEC407A),
          iconBorder: const Color(0xFFF48FB1),
          titleColor: const Color(0xFFAD1457),
          mutedIconColor: const Color(0xFFF06292),
          barBg: const Color(0xFFF8BBD0),
          tagBg: const Color(0xFFF8BBD0),
          tagFg: const Color(0xFFC2185B),
          icon: Icons.local_fire_department_outlined,
        );
      default:
        return _TierStyle(
          cardBg: Colors.white,
          borderColor: const Color(0xFFE0E0E0),
          iconBg: const Color(0xFFF5F5F5),
          iconFg: const Color(0xFF78909C),
          iconBorder: const Color(0xFFB0BEC5),
          titleColor: const Color(0xFF37474F),
          mutedIconColor: const Color(0xFF90A4AE),
          barBg: const Color(0xFFECEFF1),
          tagBg: const Color(0xFFECEFF1),
          tagFg: const Color(0xFF546E7A),
          icon: Icons.star_outline_rounded,
        );
    }
  }
}

class _ProTipCard extends StatelessWidget {
  const _ProTipCard({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE0B2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFFF8F00)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.achievementsProTipTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFE65100),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.achievementsProTipBody,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF5D4037),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

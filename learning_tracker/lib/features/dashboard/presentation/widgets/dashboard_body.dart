import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/core/utils/percentage_formatter.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/active_tracks_carousel_section.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/child_points_rewards_tab_card.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/compact_mission_card.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/dashboard_all_caught_up_card.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/dashboard_helpers.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/dashboard_level_points_card.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/empty_dashboard.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/main_focus_mission_card.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/skipped_onboarding_cta_banner.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/streak_recovery_banner.dart';
import 'package:learning_tracker/core/widgets/inline_async_error.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/gamification_route_push_guard.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
// Cross-feature import via the progress barrel (Rule 2 / DNI-386). The
// barrel re-exports `ProgressTierCounterRow`; deep importing
// `lib/features/progress/presentation/widgets/...` would violate the
// layering rule.
import 'package:learning_tracker/features/progress/progress.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

class DashboardBody extends ConsumerWidget {
  final List<CurriculumTrackEntity> activeTracks;
  final ProfileMode userMode;
  final int? currentStreak;
  final Object? streakError;
  final bool streakLoading;
  final VoidCallback? onRetryStreak;
  final String? profileName;

  const DashboardBody({
    super.key,
    required this.activeTracks,
    required this.userMode,
    required this.currentStreak,
    this.streakError,
    this.streakLoading = false,
    this.onRetryStreak,
    this.profileName,
  });

  String _greeting(AppLocalizations l10n) {
    final hour = DateTimeFactory.nowLocal().hour;
    if (hour < 12) return l10n.goodMorning;
    if (hour < 17) return l10n.goodAfternoon;
    return l10n.goodEvening;
  }

  ({IconData icon, Color fg, Color bg}) _greetingChip() {
    final hour = DateTimeFactory.nowLocal().hour;
    if (hour < 12) {
      return (
        icon: Icons.wb_sunny_rounded,
        fg: const Color(0xFFE07A00),
        bg: const Color(0xFFFFF1D6),
      );
    }
    if (hour < 17) {
      return (
        icon: Icons.brightness_high_rounded,
        fg: const Color(0xFFC25400),
        bg: const Color(0xFFFFE7C7),
      );
    }
    return (
      icon: Icons.bedtime_rounded,
      fg: const Color(0xFF4A4296),
      bg: const Color(0xFFE7E5FB),
    );
  }

  String _formatDashboardDate(BuildContext context, DateTime date) {
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.yMMMd(locale).format(date);
  }

  TextStyle _iosTextStyle(
    BuildContext context, {
    required double size,
    required FontWeight weight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return Theme.of(context).textTheme.bodyMedium!.copyWith(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final dailyTasksAsync = ref.watch(allDailyTasksProvider);
    // Use .select() so this widget only rebuilds when the integer value
    // changes — not on every completion-triggered AsyncValue re-emission
    // when points remain the same (e.g. adult users where this is always 0).
    final pointsAsync = ref.watch(dashboardGlobalPointsProvider);
    // Adults do not have a points balance by product rule. Child points stay
    // nullable until the achievement read resolves so the child UI can show
    // its loading/error state instead of a fabricated zero.
    final int? totalPoints = userMode == ProfileMode.child
        ? pointsAsync.value
        : 0;
    final lifetimeTotalsAsync = ref.watch(
      lifetimeTotalsAcrossAllCurriculaProvider,
    );
    final terms = domainTermLabels(ref);
    final reviewSectionLabel = terms.reviewSection;
    // Gate chazara labels on whether any active track has chazara (Rule 8).
    final anyTrackHasChazara =
        ref.watch(anyActiveTrackHasChazaraProvider).asData?.value ?? false;
    final chazaraReviewLabel = anyTrackHasChazara ? terms.chazara : null;
    final chazaraBubbleLabel = anyTrackHasChazara ? terms.bubbleChazara : null;
    final name = profileName ?? l10n.learner;
    final now = DateTimeFactory.nowLocal();

    // §10.2 — historical "first Firestore pull complete" gate (BUG-#35).
    //
    // Before the first full Firestore pull finishes, the local DB may be
    // empty or partially merged, so an early version of this screen gated
    // tile rendering on a first-pull-done flag from core/sync. BUG-#35 found
    // that gate strands the tiles on "…" forever for any session that never
    // runs pullOnLaunch — notably a CHILD profile / tutored session, where
    // that flag is never written. Per the offline-first rule, the local
    // Drift query is the real source of truth and sync is informational
    // only, so `tasksReady` below depends solely on `dailyTasksAsync`
    // (see the PP-15 note there) — never on sync status.

    // Provide an empty task list while not ready so the list-grouping helpers
    // below can run without null checks.  The counts derived from this list
    // are only shown when `tasksReady` is true.
    final allTasks = dailyTasksAsync.value ?? const <DailyTask>[];
    final lifetimeTotals = lifetimeTotalsAsync.hasValue
        ? lifetimeTotalsAsync.value
        : null;
    final cumulativeLifetime = lifetimeTotals?.percentage;
    final numberFormat = NumberFormat.decimalPattern();
    final lifetimePercentStr = lifetimeTotals == null
        ? null
        : formatFractionAsPercent(lifetimeTotals.percentage);
    final lifetimeSectionsStr = lifetimeTotals == null
        ? null
        : l10n.lifetimeSectionsSummary(
            numberFormat.format(lifetimeTotals.learnedSections),
            numberFormat.format(lifetimeTotals.totalSections),
            CurriculumId.values.length,
          );

    if (activeTracks.isEmpty) {
      final isChildMode =
          ref.watch(selectedProfileProvider).asData?.value?.mode ==
          ProfileMode.child;
      // T3.gating: suppress the "Add track" CTA in a tutored session.
      final isTutoredSession =
          ref.watch(activeTutoredProfileSelectionProvider) != null;
      // W6.3: if user skipped track setup during onboarding, show CTA banner
      // instead of the generic empty-dashboard prompt.
      final skipState = ref.watch(onboardingSkipStateProvider).asData?.value;
      if (skipState != null &&
          skipState.skipped &&
          !isChildMode &&
          !isTutoredSession) {
        return const SkippedOnboardingCtaBanner();
      }
      return EmptyDashboard(
        name: name,
        greeting: _greeting(l10n),
        isChildMode: isChildMode,
      );
    }

    final groupedTasks = groupTasks(allTasks);
    final todayCount = groupedTasks.todayTasks.length;
    final overdueCount = groupedTasks.overdueTasks.length;
    final reviewCount = groupedTasks.reviewTasks.length;
    final totalRemaining = todayCount + overdueCount + reviewCount;
    final level = cumulativeLifetime == null
        ? null
        : (1 + (cumulativeLifetime * 19)).clamp(1, 20).round();
    final doneDisplay = lifetimePercentStr;
    final sectionsDetail = lifetimeSectionsStr;

    // Tasks are "ready" once the local DB query has resolved.  The local Drift
    // store is the offline-first source of truth, so a resolved query is
    // authoritative regardless of whether a Firestore pull has run (see the
    // §10.2 note above — BUG-#35).
    //
    // PP-15: an earlier version of this gate also required the first-launch
    // sync flag to flip true, which made `tasksReady` true as soon as that
    // flag flipped — even before the Drift query emitted — so the
    // OVERDUE/TODAY/CHAZARA bubbles flashed real zeros for 1-2 s, which
    // looked like "all caught up". The fix uses ONLY
    // `dailyTasksAsync.hasValue` so bubbles stay on "…" until the local DB
    // query has actually returned data; the sync flag plays no further part
    // in this gate.
    final tasksReady = dailyTasksAsync.hasValue;
    final lifetimeReady = lifetimeTotalsAsync.hasValue;
    final tasksError = dailyTasksAsync.hasError;
    final lifetimeError = lifetimeTotalsAsync.hasError;
    // "All caught up" is suppressed until tasks are ready: showing it before
    // sync completes would mislead the user into thinking there's nothing to do
    // when in fact the data hasn't arrived yet.
    final showAllCaughtUp =
        tasksReady &&
        lifetimeReady &&
        reviewCount == 0 &&
        overdueCount == 0 &&
        todayCount == 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
      children: [
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Builder(
                    builder: (context) {
                      final chip = _greetingChip();
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: chip.bg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(chip.icon, size: 14, color: chip.fg),
                            const SizedBox(width: 6),
                            Text(
                              _greeting(l10n),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: chip.fg,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      // Wrap "name!" in a Unicode first-strong isolate
                      // (U+2068 … U+2069) so the trailing "!" follows the NAME's
                      // direction. Without it, a Latin name in an RTL (Hebrew)
                      // paragraph renders the neutral "!" on the wrong side
                      // ("!LoopChild" instead of "LoopChild!").
                      '\u2068$name!\u2069',
                      style: _iosTextStyle(
                        context,
                        size: 28,
                        weight: FontWeight.w800,
                        color: context.colors.brandInk,
                      ),
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDashboardDate(context, now),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.colors.brandInkMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // F-11: wrap the streak chip in a Semantics node so TalkBack/
            // VoiceOver announces a descriptive label (e.g. "3-day streak")
            // instead of the raw number "1". `excludeSemantics: true` prevents
            // the inner Icon + Text from also being announced, which would
            // produce a redundant bare "3" after the meaningful label.
            if (streakError != null)
              SizedBox(
                width: 150,
                child: InlineAsyncError(
                  error: streakError!,
                  onRetry: onRetryStreak,
                ),
              )
            else if (streakLoading)
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Semantics(
                label: l10n.tierCounterStreakDays(currentStreak ?? 0),
                excludeSemantics: true,
                child: GestureDetector(
                  // E1: register taps across the whole chip (incl. padding/gaps),
                  // not just where the icon/text render objects sit. Without
                  // `opaque`, GestureDetector defers to its children and taps on
                  // the transparent padding area are a dead no-op on-device.
                  behavior: HitTestBehavior.opaque,
                  // E1 (real root cause): GamificationRoute is gated by
                  // `childModeGuard`, which silently rejects (`resolver.next(false)`)
                  // navigation whenever the active profile is NOT in child mode. The
                  // streak chip is rendered for every mode, so in adult / tutor mode
                  // the tap fired but the guard swallowed it — "tapping does
                  // nothing". Gamification is child-only (adults have no points), so
                  // only route to it in child mode; for other modes the chip is a
                  // passive streak indicator with no dead navigation.
                  //
                  // GA-4: Also guard against double-push — if GamificationRoute is
                  // already active, a second tap would push a duplicate.
                  // Use isRouteActive (safe — no null dereference) instead of
                  // router.current.name which throws when the stack is empty or
                  // the router is a partial mock.
                  onTap: userMode == ProfileMode.child
                      ? () {
                          final alreadyActive = context.router.isRouteActive(
                            const GamificationRoute().routeName,
                          );
                          if (GamificationRoutePushGuard.canPush(
                            isGamificationRouteActive: alreadyActive,
                          )) {
                            context.router.push(const GamificationRoute());
                          }
                        }
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.statusDanger,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: context.colors.statusDanger.withValues(
                            alpha: 0.28,
                          ),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.local_fire_department_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${currentStreak ?? 0}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ), // Semantics
          ],
        ),
        const SizedBox(height: 18),
        // Tier counter row (engagement / achievement / lifetime [/ ⭐ points]).
        // Shared with Progress hub — same widget, same providers.
        // Child mode renders the fourth ⭐ points counter (see Task #14 brief).
        ProgressTierCounterRow(showPoints: userMode == ProfileMode.child),
        const SizedBox(height: 22),
        if (userMode == ProfileMode.child) ...[
          if (pointsAsync.hasError)
            InlineAsyncError(
              error: pointsAsync.error!,
              onRetry: () => ref.invalidate(dashboardGlobalPointsProvider),
            )
          else if (pointsAsync.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (!pointsAsync.hasValue)
            const Center(child: CircularProgressIndicator())
          else
            ChildPointsRewardsTabCard(
              totalPoints: totalPoints!,
              l10n: l10n,
              theme: theme,
              numberFormat: numberFormat,
              // WS7.child-ui: opens the child's prize redemption screen.
              onOpenRewards: () =>
                  context.router.push(const ChildRedemptionRoute()),
            ),
          const SizedBox(height: 18),
        ],
        if (lifetimeTotalsAsync.hasError)
          InlineAsyncError(
            error: lifetimeTotalsAsync.error!,
            onRetry: () =>
                ref.invalidate(lifetimeTotalsAcrossAllCurriculaProvider),
          )
        else if (!lifetimeTotalsAsync.hasValue)
          const Center(child: CircularProgressIndicator())
        else if (userMode == ProfileMode.child && pointsAsync.hasError)
          InlineAsyncError(
            error: pointsAsync.error!,
            onRetry: () => ref.invalidate(dashboardGlobalPointsProvider),
          )
        else if (userMode == ProfileMode.child && !pointsAsync.hasValue)
          const Center(child: CircularProgressIndicator())
        else if (showAllCaughtUp)
          DashboardAllCaughtUpCard(
            doneDisplay: doneDisplay!,
            cumulativeLifetime: cumulativeLifetime!,
          )
        else
          DashboardLevelPointsCard(
            userMode: userMode,
            level: level!,
            totalPoints: totalPoints!,
            overdueCount: overdueCount,
            todayCount: todayCount,
            reviewCount: reviewCount,
            doneDisplay: doneDisplay!,
            lifetimeSectionsDetail: sectionsDetail!,
            cumulativeLifetime: cumulativeLifetime!,
            chazaraLabel: chazaraBubbleLabel,
            tasksReady: tasksReady,
            lifetimeReady: lifetimeReady,
            tasksError: dailyTasksAsync.error,
            lifetimeError: lifetimeTotalsAsync.error,
            onRetryTasks: () => ref.invalidate(allDailyTasksProvider),
            onRetryLifetime: () =>
                ref.invalidate(lifetimeTotalsAcrossAllCurriculaProvider),
          ),
        const SizedBox(height: 30),
        // R1v2-(6): the heading previously shared a horizontal Row with the
        // pink "N remaining" pill and was capped at maxLines:1 + ellipsis, so
        // the fixed-width pill ate the row width and the heading clipped to
        // "Today's Mi…" / "…היום" at font scale 1.3. A 2-line heading needs
        // (at 28 px / w800) ~240 px at 1.0 and ~310 px at 1.3 — more than the
        // ~200 px the pill leaves on a phone-width row, so simply sharing a Row
        // cannot fit. We use a Wrap so the pill YIELDS by flowing to its own run
        // below the heading when there isn't room beside it; the heading is
        // constrained to the full available width via LayoutBuilder so it wraps
        // internally instead of clipping. Full heading shows in en + he at font
        // 1.0 and 1.3.
        LayoutBuilder(
          builder: (context, constraints) {
            return Wrap(
              spacing: 10,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                  child: Text(
                    l10n.todaysMissions,
                    style: _iosTextStyle(
                      context,
                      size: 28,
                      weight: FontWeight.w800,
                      color: context.colors.brandInk,
                    ),
                    maxLines: 2,
                    softWrap: true,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.statusDanger.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    // P3(5558): mirror the tasksReady gate the sibling
                    // OVERDUE/TODAY/CHAZARA bubbles already use (see
                    // DashboardLevelPointsCard's PP-15 "…" pattern above).
                    // Before the local Drift query has emitted, `totalRemaining`
                    // is derived from an empty placeholder task list, so it
                    // always reads 0 — showing "0 remaining" here during the
                    // load window falsely told the user there was nothing to
                    // do. Show "…" (never a number) until tasksReady flips true.
                    key: const Key('todaysMissionsRemainingPill'),
                    tasksReady ? l10n.remaining(totalRemaining) : '…',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: context.colors.statusDanger,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        MainFocusMissionCard(
          count: todayCount,
          onTap: () {
            ref
                .read(schedulerTaskSectionProvider.notifier)
                .setSection(SchedulerTaskSection.today);
            context.router.push(const SchedulerRoute());
          },
        ),
        // Only render the chazara review card when at least one active track
        // has chazara stages enabled (Rule 8).
        if (chazaraReviewLabel != null) ...[
          const SizedBox(height: 14),
          CompactMissionCard(
            label: reviewSectionLabel,
            title: chazaraReviewLabel,
            count: reviewCount,
            color: context.colors.brandGold,
            labelColor: context.colors.brandGoldDeep,
            backgroundColor: context.colors.brandCreamSoft,
            borderColor: context.colors.brandOutline,
            onTap: () {
              ref
                  .read(schedulerTaskSectionProvider.notifier)
                  .setSection(SchedulerTaskSection.review);
              context.router.push(const SchedulerRoute());
            },
          ),
        ],
        const SizedBox(height: 14),
        CompactMissionCard(
          label: l10n.urgent,
          title: l10n.missedOverdue,
          count: overdueCount,
          color: context.colors.statusError,
          labelColor: context.colors.statusError,
          titleColor: context.colors.statusError,
          borderColor: context.colors.statusError,
          dashedBorder: true,
          onTap: () {
            ref
                .read(schedulerTaskSectionProvider.notifier)
                .setSection(SchedulerTaskSection.overdue);
            context.router.push(const SchedulerRoute());
          },
        ),
        const SizedBox(height: 30),
        SizedBox(
          height: 460,
          child: ActiveTracksCarouselSection(
            title: l10n.activeTracks,
            subtitle: l10n.activeTracksSubtitle,
            activeTracks: activeTracks,
            allTasks: allTasks,
            titleStyle: _iosTextStyle(
              context,
              size: 28,
              weight: FontWeight.w800,
              color: context.colors.brandInk,
            ),
          ),
        ),
        if (userMode == ProfileMode.child) ...[
          const SizedBox(height: 14),
          if (currentStreak != null)
            StreakRecoveryBanner(currentStreak: currentStreak!),
        ],
      ],
    );
  }
}

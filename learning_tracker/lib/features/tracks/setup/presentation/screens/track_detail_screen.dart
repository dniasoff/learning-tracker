import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/learning/completion_constants.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/core/utils/hebrew_calendar_utils.dart';
import 'package:learning_tracker/core/utils/percentage_formatter.dart';
import 'package:learning_tracker/core/widgets/inline_async_error.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_tier_filter.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/bulk_mark_screen.dart';
import 'package:learning_tracker/features/progress/data/repositories/firestore_chart_data_repository_adapter.dart';
import 'package:learning_tracker/features/progress/domain/services/pace_calculator.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';
import 'package:learning_tracker/features/settings/domain/exceptions/last_active_curriculum_exception.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/tracks/setup/data/repositories/curriculum_track_repository_impl.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart'
    show ScopeEntry;
import 'package:learning_tracker/features/tracks/setup/presentation/providers/after_track_change_invalidation.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_management_providers.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/screens/edit_track_screen.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/widgets/track_info_card.dart';
import 'package:learning_tracker/features/tracks/track_order/presentation/screens/track_learning_order_screen.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Formats a [date] for display in the track-detail screen.
///
/// TS-8 fix: the old code used DateFormat.yMMMd unconditionally everywhere,
/// ignoring [useHebrewCalendar]. This function routes through the Hebrew
/// calendar formatter when the preference is active, matching the same path
/// used by [TrackInfoCard._formatDate].
String formatTrackDate({
  required DateTime date,
  required String locale,
  required bool useHebrewCalendar,
}) {
  final local = date.toLocal();
  if (useHebrewCalendar) {
    return HebrewCalendarUtils.gregorianToHebrew(local);
  }
  return DateFormat.yMMMd(locale).format(local);
}

/// Pure date-math core of [_TrackDetailScreenState._estimatedFinish].
///
/// `@visibleForTesting` (AUD-t-story-acceptance-02): extracted so the N7
/// regression test (regression_invariants_test.dart) can call the REAL
/// production formula instead of re-typing it inline. F1 was "pace-goal
/// projected finish anchors to createdAt, not now" — a test that only
/// re-types the same math never breaks when this anchor regresses back to
/// [DateTimeFactory.nowLocal] (or any other "now"-based clock).
///
/// [goal] and [remainingInPaceUnit] mirror the parameters of
/// [_TrackDetailScreenState._estimatedFinish]; formatting/localization is
/// deliberately NOT part of this function so the anchor invariant can be
/// asserted without needing an [Intl] locale or Hebrew-calendar conversion.
///
/// Returns null when [goal] is null, a deadline goal (deadline goals show
/// their target date directly — see [_estimatedFinish]), or when the pace
/// inputs required to compute a projection are missing or non-positive.
@visibleForTesting
DateTime? estimatedFinishDate({
  required GoalEntity? goal,
  required int? remainingInPaceUnit,
}) {
  if (goal == null) return null;
  // Deadline goals surface their date in the "Goal" row; skip here.
  if (goal.goalType == 'deadline') return null;
  if (goal.goalType == 'pace' &&
      goal.paceValue != null &&
      goal.pacePeriod != null &&
      remainingInPaceUnit != null &&
      remainingInPaceUnit > 0) {
    final weeklyRate = goal.pacePeriod == 'per_day'
        ? goal.paceValue! * 7
        : goal.paceValue!;
    if (weeklyRate > 0) {
      final days = (remainingInPaceUnit / weeklyRate * 7).ceil();
      return goal.createdAt.add(Duration(days: days));
    }
  }
  return null;
}

final _trackGoalProvider = FutureProvider.autoDispose
    .family<GoalEntity?, CurriculumId>((ref, curriculum) async {
      final repo = FirestoreGoalRepositoryAdapter(ref: ref);
      final goals = await repo.getGoals(curriculum);
      if (goals.isEmpty) return null;
      // Most recently created — defends against a stale row from an
      // earlier track setup outliving a re-add (same reasoning
      // dashboard_providers.dart's dashboardPaceStatus already uses).
      return goals.reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b);
    });

/// Computes a [ProgressPaceCalculator] for the given [CurriculumTrackEntity].
///
/// Live completions: `completedAt >= track.activatedAt` (excluding sentinel).
/// Bulk baseline: completions with the sentinel date (2000-01-01).
/// Total items: from [scopedItemCountProvider].
/// targetDate: deadline-goal date when available; otherwise today (so
///   requiredVelocity returns 0 — not meaningful for pace goals).
final _trackPaceCalcProvider = FutureProvider.autoDispose
    .family<ProgressPaceCalculator, CurriculumTrackEntity>((ref, track) async {
      final curriculum = track.curriculumId;
      final chartData = FirestoreChartDataRepositoryAdapter(ref: ref);
      final allCompletions = await chartData.getCompletionsByTier(
        tier: CompletionTierFilter.trackAchievement,
        curriculumId: curriculum,
      );

      final trackStart = track.activatedAt.toLocal();

      final liveCount = allCompletions
          .where(
            (c) =>
                !c.completedAt.isBefore(trackStart) &&
                !c.completedAt.isAtSameMomentAs(kBulkPriorSentinelDate),
          )
          .length;

      final bulkBaseline = allCompletions
          .where(
            (c) =>
                c.completedAt.isAtSameMomentAs(kBulkPriorSentinelDate) ||
                c.completedAt.isBefore(trackStart),
          )
          .length;

      final totalItems = await ref.watch(
        scopedItemCountProvider(curriculum).future,
      );

      final goal = await ref.watch(_trackGoalProvider(curriculum).future);
      final clock = ref.watch(localDayClockProvider);
      final targetDate =
          (goal?.goalType == 'deadline' && goal?.targetDate != null)
          ? goal!.targetDate!.toLocal()
          : clock.today();

      final today = clock.today();

      return ProgressPaceCalculator.compute(
        totalItems: totalItems,
        bulkBaseline: bulkBaseline,
        liveProgress: liveCount,
        trackStartDate: trackStart,
        targetDate: targetDate,
        today: today,
      );
    });

/// Adapter providers -- constructed here (top-level `Provider`) rather than
/// inline inside a `WidgetRef`-scoped method: `WidgetRef` does not
/// implement `Ref` the way an `@riverpod`/`Provider` callback's `Ref` does,
/// so a Firestore adapter needing a real `Ref` must be reached through a
/// provider (`ref.read(...)`), never constructed directly inside a screen
/// method (lesson from after_track_change_invalidation.dart, fixed earlier
/// this session).
final curriculumTrackDetailRepositoryProvider =
    Provider<FirestoreCurriculumTrackRepositoryAdapter>(
      (ref) => FirestoreCurriculumTrackRepositoryAdapter(ref: ref),
    );

@RoutePage()
class TrackDetailScreen extends ConsumerStatefulWidget {
  const TrackDetailScreen({super.key, required this.track});

  final CurriculumTrackEntity track;

  @override
  ConsumerState<TrackDetailScreen> createState() => _TrackDetailScreenState();
}

class _TrackDetailScreenState extends ConsumerState<TrackDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    final curriculum = track.curriculumId;
    // B-EDIT-NAME fix: the header must surface the user's custom track name
    // (stored in Goal.description) when set, falling back to the curriculum
    // label otherwise — it previously always showed the curriculum name,
    // ignoring an edited name.
    final titleText = trackDisplayTitle(ref, track);

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // The "chazara" term renders per the Hebrew-terms preference: transliterated
    // in English, Hebrew script when the toggle is on (or in Hebrew locale).
    final chazaraTerm = domainTermLabels(ref).chazara;
    final trackHasChazara =
        ref.watch(trackHasChazaraProvider(curriculum)).asData?.value ?? false;

    final completionAsync = ref.watch(
      dashboardTrackCompletionPercentageProvider(curriculum),
    );
    final cycleFraction = completionAsync.asData?.value;
    final cyclePercentDisplay = completionAsync.hasValue
        ? formatFractionAsPercent(cycleFraction!)
        : null;

    // W5-B (Task #16): dual-progress labels — Track progress (current cycle)
    // and Lifetime (all-time) — sourced from [trackDualProgressMetricsProvider]
    // so the Track Detail header matches the same numbers shown on the
    // Dashboard active-track card and the Progress hub per-track rows.
    // The provider is scoped to the active profile — no argument to pass.
    final dualMetricsAsync = ref.watch(trackDualProgressMetricsProvider);
    final dualMetricMatches = dualMetricsAsync.asData?.value
        .where((m) => m.curriculumId == curriculum)
        .toList();
    final dualMetric = (dualMetricMatches == null || dualMetricMatches.isEmpty)
        ? null
        : dualMetricMatches.first;
    final dualMetricsError =
        dualMetricsAsync.error ??
        (dualMetricsAsync.hasValue && dualMetric == null
            ? StateError('Progress metrics did not include this track')
            : null);
    final trackProgressDisplay = dualMetric == null
        ? '…'
        : formatFractionAsPercent(dualMetric.currentCyclePercentage);
    final lifetimeDisplay = dualMetric == null
        ? '…'
        : formatFractionAsPercent(dualMetric.lifetimePercentage);

    final hasProgramEnrollment =
        ref
            .watch(dashboardHasProgramEnrollmentProvider(curriculum))
            .asData
            ?.value ??
        false;

    final curriculumBarColor = context.colors.curriculumFor(curriculum);
    // W3.22: trackType column dropped — all tracks are now 'personal'.
    final accent = context.colors.blueMedium;
    const icon = Icons.menu_book_rounded;
    final locale = Localizations.localeOf(context).toString();

    final goal = ref.watch(_trackGoalProvider(curriculum)).asData?.value;

    // P1 (iter-2): the Track-Detail "Goal" config row previously read
    // "{n} · Per week" with no unit noun, while the Required-pace row in
    // TrackInfoCard already reads "{n} Dafim · Per week" (iter-1 fix). Resolve
    // the goal's unit noun through the SAME [paceGoalUnitNoun] helper so both
    // pace rows on this screen read consistently — honouring the Hebrew-terms
    // toggle, the nusach/transliteration variant, and plural/singular.
    final useHebrewTerms = domainTermLabels(ref).isHebrew;
    final paceVariant = ref.watch(currentTransliterationVariantProvider);
    final goalPaceUnitNoun = goal == null
        ? null
        : paceGoalUnitNoun(
            curriculum: curriculum,
            goalType: goal.goalType,
            paceValue: goal.paceValue,
            paceGranularity: goal.paceGranularity?.storageKey,
            useHebrew: useHebrewTerms,
            variant: paceVariant,
          );

    final totalScopeAsync = ref.watch(scopedItemCountProvider(curriculum));
    final totalScope = totalScopeAsync.asData?.value;
    final itemsRemaining = totalScope != null && cycleFraction != null
        ? (totalScope * (1 - cycleFraction)).ceil().clamp(0, totalScope)
        : null;

    // FR-fix: a pace goal whose granularity is COARSE (daf/perek/seif) measures
    // pace in those units, so the completion-date estimate must divide the
    // coarse-unit remaining count — NOT the leaf (amudim/pesukim) count. Dividing
    // leaf-by-daf-rate previously doubled the projected timeline vs the wizard.
    final paceIsCoarse = goal != null && goal.paceGranularity != null;
    final coarseTotal = paceIsCoarse
        ? ref.watch(scopedCoarseUnitCountProvider(curriculum)).asData?.value
        : null;
    final remainingInPaceUnit = (paceIsCoarse && coarseTotal != null)
        ? (cycleFraction == null
              ? null
              : (coarseTotal * (1 - cycleFraction)).ceil().clamp(
                  0,
                  coarseTotal,
                ))
        : itemsRemaining;

    final useHebrewCalendar = ref.watch(useHebrewDateProvider);
    // TS-8 fix: Est. finish must honour the SAME hebrew-date preference the rest
    // of the card uses, so a single card never mixes Hebrew + Gregorian dates.
    final estimatedFinish = _estimatedFinish(
      goal,
      remainingInPaceUnit,
      locale,
      useHebrewCalendar: useHebrewCalendar,
    );
    // TS-8 fix: use formatTrackDate so Hebrew calendar preference is respected.
    final activatedDate = formatTrackDate(
      date: track.activatedAt,
      locale: locale,
      useHebrewCalendar: useHebrewCalendar,
    );
    final paceCalc = ref.watch(_trackPaceCalcProvider(track)).asData?.value;

    return Scaffold(
      backgroundColor: context.colors.surfaceF5,
      appBar: AppBar(
        backgroundColor: context.colors.surfaceF5,
        elevation: 0,
        title: Text(
          titleText,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: context.colors.brandBlueDeep,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TrackInfoCard(
            track: track,
            goal: goal,
            paceCalc: paceCalc,
            useHebrewCalendar: useHebrewCalendar,
          ),
          const SizedBox(height: 16),
          _buildHeaderCard(
            context,
            theme,
            l10n,
            track,
            accent,
            icon,
            activatedDate,
            hasProgramEnrollment,
            cycleFraction,
            cyclePercentDisplay,
            curriculumBarColor,
            chazaraTerm,
            trackProgressLabel: l10n.trackProgress,
            trackProgressDisplay: trackProgressDisplay,
            lifetimeLabel: l10n.lifetimeLabel,
            lifetimeDisplay: lifetimeDisplay,
            completionError: completionAsync.error,
            completionLoading: completionAsync.isLoading,
            dualMetricsError: dualMetricsError,
            dualMetricsLoading: dualMetricsAsync.isLoading,
            trackHasChazara: trackHasChazara,
            locale: locale,
            goal: goal,
            goalPaceUnitNoun: goalPaceUnitNoun,
            // Pass the count in the goal's PACE unit (daf for a daf-paced track),
            // so "Items remaining" matches the Est. finish basis. Lifetime
            // aggregates stay in amudim elsewhere — this is track-scoped only.
            itemsRemaining: remainingInPaceUnit,
            estimatedFinish: estimatedFinish,
            useHebrewCalendar: useHebrewCalendar,
          ),
          const SizedBox(height: 20),
          _buildActionsCard(
            context,
            theme,
            track,
            curriculum,
            hasProgramEnrollment: hasProgramEnrollment,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    CurriculumTrackEntity track,
    Color accent,
    IconData icon,
    String activatedDate,
    bool hasProgramEnrollment,
    double? cycleFraction,
    String? cyclePercentDisplay,
    Color curriculumBarColor,
    String chazaraTerm, {
    required String trackProgressLabel,
    required String trackProgressDisplay,
    required String lifetimeLabel,
    required String lifetimeDisplay,
    Object? completionError,
    required bool completionLoading,
    Object? dualMetricsError,
    required bool dualMetricsLoading,
    required bool trackHasChazara,
    required String locale,
    required bool useHebrewCalendar,
    GoalEntity? goal,
    String? goalPaceUnitNoun,
    int? itemsRemaining,
    String? estimatedFinish,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.colors.brandCreamCard,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: context.colors.blueDeepNavy.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.trackSince(activatedDate),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.colors.brandInkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // W5-B (Task #16): dual progress labels — Track progress (current
          // cycle since activation) and Lifetime (all-time tier). These two
          // numbers must always be visible so the user can distinguish
          // "this cycle" engagement from total knowledge accumulated.
          if (dualMetricsError != null)
            InlineAsyncError(
              error: dualMetricsError,
              onRetry: () => ref.invalidate(trackDualProgressMetricsProvider),
            )
          else if (dualMetricsLoading)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                Text(
                  '$trackProgressLabel: $trackProgressDisplay',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: context.colors.brandInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '$lifetimeLabel: $lifetimeDisplay',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: context.colors.brandInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          if (!hasProgramEnrollment) ...[
            Row(
              children: [
                Text(
                  // AUD-tracks-01: this row is sourced from
                  // dashboardTrackCompletionPercentageProvider (all-time,
                  // multi-stage gate) via [cyclePercentDisplay] — a
                  // different formula from the dual-metrics row above,
                  // which is labelled with [trackProgressLabel] and driven
                  // by trackDualProgressMetricsProvider's time-gated
                  // currentCyclePercentage. Reusing trackProgressLabel here
                  // made two differently-sourced numbers appear under the
                  // identical "Track progress" label whenever the two
                  // formulas diverged. l10n.trackCompletionLabel is the
                  // bare, non-chazara counterpart of l10n.carouselCompletion
                  // ("Completion (with {chazara})") and must never be
                  // conflated with trackProgressLabel again.
                  trackHasChazara
                      ? l10n.carouselCompletion(chazaraTerm)
                      : l10n.trackCompletionLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: context.colors.brandInkMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (completionError != null)
                  InlineAsyncError(
                    error: completionError,
                    onRetry: () => ref.invalidate(
                      dashboardTrackCompletionPercentageProvider(
                        track.curriculumId,
                      ),
                    ),
                  )
                else if (completionLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Text(
                    cyclePercentDisplay!,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: context.colors.brandInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (cycleFraction != null)
              ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: cycleFraction,
                    minHeight: 10,
                    backgroundColor: context.colors.brandCreamSoft,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      curriculumBarColor,
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: 10),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFEEF0F6)),
          const SizedBox(height: 14),
          if (goal != null)
            _configRow(
              theme,
              l10n.trackDetailConfigGoal,
              _goalLabel(
                goal,
                l10n,
                locale,
                useHebrewCalendar: useHebrewCalendar,
                paceUnitNoun: goalPaceUnitNoun,
              ),
            ),
          if (itemsRemaining != null)
            _configRow(
              theme,
              l10n.trackDetailConfigItemsRemaining,
              // Caller passes the count in the track's PACE unit: dapim for a
              // daf-paced Bavli track (not amudim), aligning with Est. finish.
              '$itemsRemaining',
            ),
          if (estimatedFinish != null)
            _configRow(theme, l10n.trackDetailConfigEstFinish, estimatedFinish),
        ],
      ),
    );
  }

  Widget _configRow(ThemeData theme, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: context.colors.brandInkMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            value ?? '—',
            style: theme.textTheme.labelSmall?.copyWith(
              color: context.colors.brandInk,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String? _goalLabel(
    GoalEntity? goal,
    AppLocalizations l10n,
    String locale, {
    required bool useHebrewCalendar,
    // P1 (iter-2): unit noun for the pace goal (e.g. "Dafim"/"Daf"), resolved
    // via [paceGoalUnitNoun] in build(). When non-null the value reads
    // "7 Dafim · Per week" — matching the Required-pace row — instead of the
    // bare "7 · Per week". Null falls back to the bare number (deadline goals,
    // or curriculum/granularity that could not be resolved).
    String? paceUnitNoun,
  }) {
    if (goal == null) return null;
    if (goal.goalType == 'pace' &&
        goal.paceValue != null &&
        goal.pacePeriod != null) {
      final period = goal.pacePeriod == 'per_day'
          ? l10n.pacePerDay
          : l10n.pacePerWeek;
      final amount = paceUnitNoun != null
          ? '${goal.paceValue} $paceUnitNoun'
          : '${goal.paceValue}';
      return '$amount · $period';
    }
    if (goal.goalType == 'deadline' && goal.targetDate != null) {
      // Show the raw deadline date; the "Est. finish" row is not shown for
      // deadline goals to avoid repeating the same value twice.
      // TS-8 fix: honour the same Hebrew-date preference so this date field
      // never mixes calendars with the rest of the card.
      return formatTrackDate(
        date: goal.targetDate!,
        locale: locale,
        useHebrewCalendar: useHebrewCalendar,
      );
    }
    return null;
  }

  String? _estimatedFinish(
    GoalEntity? goal,
    // Remaining scope expressed in the SAME unit as the goal's pace
    // (coarse units for daf/perek/seif goals, leaf items otherwise) so the
    // division below matches the add-track wizard's projection.
    int? remainingInPaceUnit,
    String locale, {
    required bool useHebrewCalendar,
  }) {
    // AUD-t-story-acceptance-02: date math lives in the top-level, testable
    // estimatedFinishDate() — this method only formats its result.
    final finishDate = estimatedFinishDate(
      goal: goal,
      remainingInPaceUnit: remainingInPaceUnit,
    );
    if (finishDate == null) return null;
    // TS-8 fix: route through formatTrackDate so the projected finish date
    // is rendered in the Hebrew calendar when that preference is active,
    // matching the activated-date and the rest of the card.
    return formatTrackDate(
      date: finishDate,
      locale: locale,
      useHebrewCalendar: useHebrewCalendar,
    );
  }

  Widget _buildActionsCard(
    BuildContext context,
    ThemeData theme,
    CurriculumTrackEntity track,
    CurriculumId? curriculum, {
    required bool hasProgramEnrollment,
  }) {
    // Mark Content Done + Reorder Content are self-paced-only. When the
    // user is following a program (Daf Yomi, Mishna Yomi, etc.) the
    // pace and order are dictated by the program, so showing those
    // controls is misleading.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.brandCreamCard,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: context.colors.blueDeepNavy.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            if (!hasProgramEnrollment) ...[
              // W5-B (Task #16): Bulk-prior path — visually differentiated
              // from a "Mark complete" (live) action with outlined/secondary
              // styling so users can't confuse historical/lifetime marking
              // with live completion (which credits engagement). The icon and
              // foreground colour both use the secondary outline treatment.
              // Copy hardcoded English for now — l10n sweep follows.
              ListTile(
                key: const ValueKey('trackDetail.bulkPriorTile'),
                shape: RoundedRectangleBorder(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  // brandBlueDeep (not blueMedium): this border/tile-tint/
                  // icon/text sits directly on the card, so it needs the ink
                  // token that lightens in dark to stay visible — blueMedium
                  // is now a hero-FILL token pinned deep for white content
                  // painted over it, which would go near-invisible here
                  // (run-9 audit).
                  side: BorderSide(
                    color: context.colors.brandBlueDeep.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                tileColor: context.colors.brandBlueDeep.withValues(alpha: 0.06),
                leading: Icon(
                  Icons.history_edu_outlined,
                  color: context.colors.brandBlueDeep,
                ),
                title: Text(
                  AppLocalizations.of(context)!.trackMarkPreviouslyLearned,
                  style: TextStyle(color: context.colors.brandBlueDeep),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: context.colors.brandBlueDeep,
                ),
                onTap: curriculum != null
                    ? () => _openBulkMark(track, curriculum)
                    : null,
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: Icon(
                  Icons.swap_vert_rounded,
                  // brandBlueDeep: bare icon on the card — see the
                  // bulkPriorTile comment above for why blueMedium
                  // (hero-fill role) is wrong here.
                  color: context.colors.brandBlueDeep,
                ),
                title: Text(AppLocalizations.of(context)!.trackReorderContent),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: curriculum != null
                    ? () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => TrackLearningOrderScreen(
                            curriculumId: curriculum,
                          ),
                        ),
                      )
                    : null,
              ),
              const Divider(height: 1, indent: 56),
            ],
            if (curriculum != null) ...[
              Builder(
                builder: (context) {
                  final tutorPerms = ref.watch(activeTutorPermissionsProvider);
                  final canEditGoals =
                      tutorPerms == null || tutorPerms.canEditGoals;
                  final hasGoal =
                      ref
                          .watch(_trackGoalProvider(track.curriculumId))
                          .asData
                          ?.value !=
                      null;
                  return ListTile(
                    key: const ValueKey('trackDetail.goalTile'),
                    shape: hasProgramEnrollment
                        ? const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                          )
                        : null,
                    enabled: canEditGoals,
                    leading: Icon(
                      Icons.flag_outlined,
                      color: context.colors.brandBlueDeep,
                    ),
                    title: Text(
                      hasGoal
                          ? AppLocalizations.of(context)!.trackEditGoalLabel
                          : AppLocalizations.of(context)!.trackSetGoalLabel,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: canEditGoals
                        ? () => _openGoalEdit(track, curriculum)
                        : null,
                  );
                },
              ),
              const Divider(height: 1, indent: 56),
            ],
            if (!hasProgramEnrollment && curriculum != null) ...[
              ListTile(
                key: const ValueKey('trackDetail.studyDaysTile'),
                leading: Icon(
                  Icons.calendar_today_outlined,
                  color: context.colors.brandBlueDeep,
                ),
                title: Text(AppLocalizations.of(context)!.studyDaysTitle),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.router.push(
                  StudyDayConfigRoute(curriculumId: curriculum),
                ),
              ),
              const Divider(height: 1, indent: 56),
            ],
            ListTile(
              leading: Icon(
                Icons.edit_outlined,
                color: context.colors.brandBlueDeep,
              ),
              title: Text(AppLocalizations.of(context)!.trackEditLabel),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => EditTrackScreen(track: track),
                  ),
                );
                if (mounted) {
                  ref.invalidate(_trackGoalProvider(track.curriculumId));
                  ref.invalidate(_trackPaceCalcProvider(track));
                  // B-EDIT-NAME: refresh the resolved title so an edited name
                  // surfaces immediately in the header on return.
                  ref.invalidate(trackCustomNameProvider(track.curriculumId));
                }
              },
            ),
            const Divider(height: 1, indent: 56),
            ListTile(
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
              ),
              leading: Icon(
                Icons.delete_outline_rounded,
                color: theme.colorScheme.error,
              ),
              title: Text(
                AppLocalizations.of(context)!.trackDeleteLabel,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.error,
              ),
              onTap: () => _showDeleteDialog(track, curriculum),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the shared goal-setup form to add or edit the goal for [track],
  /// then persists via [goalRepositoryProvider] so the write reaches Drift and
  /// is queued for Firestore sync.
  Future<void> _openGoalEdit(
    CurriculumTrackEntity track,
    CurriculumId curriculum,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // The provider already returns a GoalEntity -- nothing left to convert
    // (see the module doc comment: _goalRowToEntity was deleted).
    final existingEntity = await ref.read(
      _trackGoalProvider(track.curriculumId).future,
    );
    final totalItems = await ref.read(
      scopedItemCountProvider(curriculum).future,
    );

    if (!mounted) return;

    final result = await navigator.push<GoalEntity>(
      MaterialPageRoute(
        builder: (_) => GoalSetupScreen(
          curriculumId: curriculum,
          existingGoal: existingEntity,
          totalItems: totalItems,
        ),
      ),
    );

    if (result == null || !mounted) return;

    final repo = ref.read(goalRepositoryProvider);
    final paceTarget = result.paceTarget;

    if (existingEntity == null) {
      await repo.createGoal(
        curriculumId: curriculum,
        targetPercent: result.targetPercent,
        paceTarget: paceTarget,
        description: result.description,
        dateType: result.dateType,
        paceGranularity: result.paceGranularityKey,
      );
    } else {
      await repo.updateGoal(
        goal: existingEntity,
        targetPercent: result.targetPercent,
        paceTarget: paceTarget,
        // 'none' goals clear the pace target entirely.
        clearPaceTarget: paceTarget == null,
        description: result.description,
        paceGranularity: result.paceGranularity,
        clearLearningUnit: result.paceGranularityKey == null,
      );
    }

    await onTrackChanged(ref);
    ref.invalidate(_trackGoalProvider(track.curriculumId));
    ref.invalidate(_trackPaceCalcProvider(track));

    if (mounted) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.goalSavedSnack)));
    }
  }

  Future<void> _openBulkMark(
    CurriculumTrackEntity track,
    CurriculumId curriculum,
  ) async {
    final navigator = Navigator.of(context);
    // The settings feature's adapter over FirestoreCurriculumScopeRepository
    // (curriculumScopeSettingsAdapterProvider, already imported into this
    // file for scopedItemCountProvider/scopedCoarseUnitCountProvider) is the
    // presentation-legal read seam AD-23 requires — no new adapter needed.
    final scopes = await ref
        .read(curriculumScopeSettingsAdapterProvider)
        .getScopes(curriculum);
    final scopeConstraints = scopes.isEmpty
        ? null
        : [
            for (final scope in scopes)
              ScopeEntry(level: scope.scopeLevel, value: scope.scopeValue),
          ];
    if (!mounted) return;
    await navigator.push<BulkMarkResult>(
      MaterialPageRoute(
        builder: (_) => BulkMarkScreen(
          curriculumId: curriculum,
          scopeConstraints: scopeConstraints,
        ),
      ),
    );
  }

  Future<void> _showDeleteDialog(
    CurriculumTrackEntity track,
    CurriculumId? curriculum,
  ) async {
    final l10n = AppLocalizations.of(context)!;

    // FR-fix: removing the LAST active track is blocked by the min-1 invariant
    // (TRK-HUB-04) — for BOTH Archive and Delete-and-wipe. Pre-check here and
    // surface the explanation up-front, instead of offering an Archive/Delete
    // dialog whose every option would be refused after the tap (the resweep's
    // "offered then refused" + Track-vs-curriculum-wording confusion).
    final activeCurricula = await ref.read(
      dashboardActiveCurriculaProvider.future,
    );
    if (activeCurricula.length <= 1) {
      if (!mounted) return;
      _showLastCurriculumError(l10n);
      return;
    }
    if (!mounted) return;

    // 'archive' = keep history; 'wipe' = hard-delete completions; null = cancel
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteTrackArchiveTitle),
        content: Text(l10n.deleteTrackArchiveBody),
        // Safety hierarchy: the SAFE default (Cancel) is the prominent/default
        // action so it visually dominates, while the destructive choices are
        // de-emphasized (plain text buttons, the hard-delete tinted with the
        // error colour). This prevents an accidental tap on a loud delete.
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'archive'),
            child: Text(l10n.deleteTrackArchive),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, 'wipe'),
            child: Text(l10n.deleteTrackWipe),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.actionCancel),
          ),
        ],
      ),
    );

    if (choice == null || !mounted) return;

    // TRK-HUB-04: guard — every profile must keep at least one active curriculum.
    if (choice == 'archive') {
      final curriculumToArchive = track.curriculumId;
      try {
        await ref
            .read(curriculumActivationServiceProvider)
            .deactivate(curriculumToArchive);
        await onTrackChanged(ref);
        if (mounted) context.router.pop();
      } on LastActiveCurriculumException {
        if (!mounted) return;
        _showLastCurriculumError(AppLocalizations.of(context)!);
      }
      return;
    }

    // Wipe path: check last-curriculum guard before purging.
    final activeCount = await ref.read(dashboardActiveCurriculaProvider.future);
    if (activeCount.length <= 1) {
      if (!mounted) return;
      _showLastCurriculumError(AppLocalizations.of(context)!);
      return;
    }

    // Cloud Function sweep — confirmed (functions/src/deletes.ts) to
    // delete completions/learning_ledger/streak_events/points_ledger/
    // preferences alongside the track doc itself, a superset of Drift's
    // purgeHistory, not a narrower stand-in.
    final trackRepo = ref.read(curriculumTrackDetailRepositoryProvider);
    await trackRepo.deleteTrackPermanently(track.curriculumId);
    await onTrackChanged(ref);
    if (mounted) context.router.pop();
  }

  void _showLastCurriculumError(AppLocalizations l10n) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.cannotDeactivateLastCurriculum,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              l10n.cannotDeactivateLastCurriculumDetail,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}

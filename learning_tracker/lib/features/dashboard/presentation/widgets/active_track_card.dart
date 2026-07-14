import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/curriculum_label_providers.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/utils/percentage_formatter.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/active_track_focus_pill.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/dashboard_helpers.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/track_stat_grid.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

CurriculumId _curriculumIdForTrack(CurriculumTrack track) {
  return CurriculumId.values.firstWhere(
    (c) => c.storageKey == track.curriculumId,
    orElse: () => CurriculumId.mishnayos,
  );
}

/// Active track card: program (task metrics) vs self-paced (completion) layouts.
class ActiveTrackCard extends ConsumerWidget {
  final CurriculumTrack track;
  final List<DailyTask> allTasks;

  const ActiveTrackCard({
    super.key,
    required this.track,
    required this.allTasks,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final curriculum = _curriculumIdForTrack(track);
    final terms = domainTermLabels(ref);
    final displayNamePrimary = curriculumLabelText(ref, curriculum: curriculum);
    final displayNameSecondary = terms.isHebrew
        ? null
        : curriculumHebrewName(curriculum);
    final curriculumColor = AppTheme.getCurriculumColor(curriculum);
    final bookIconBg = Color.lerp(
      kActiveTrackPrimaryBlue.withValues(alpha: 0.2),
      curriculumColor.withValues(alpha: 0.2),
      0.45,
    )!;
    final hasProgramEnrollmentAsync = ref.watch(
      dashboardHasProgramEnrollmentProvider(curriculum),
    );
    final profileId = ref.watch(activeProfileIdProvider);
    final dualMetricsAsync = ref.watch(
      trackDualProgressMetricsProvider(profileId),
    );
    final dualMetricMatches = dualMetricsAsync.asData?.value
        .where((m) => m.trackId == track.id)
        .toList();
    final dualMetric = (dualMetricMatches == null || dualMetricMatches.isEmpty)
        ? null
        : dualMetricMatches.first;
    final currentCyclePct = dualMetric?.currentCyclePercentage ?? 0.0;
    final lifetimePct = dualMetric?.lifetimePercentage ?? 0.0;
    final currentCycleDisplay = dualMetricsAsync.isLoading
        ? '…'
        : formatFractionAsPercent(currentCyclePct);
    final lifetimeDisplay = dualMetricsAsync.isLoading
        ? '…'
        : formatFractionAsPercent(lifetimePct);

    final curriculumTasks = allTasks
        .where((t) => t.trackId == track.id)
        .toList();
    final hasProgramEnrollment =
        hasProgramEnrollmentAsync.asData?.value ?? false;
    final todayTask = hasProgramEnrollment
        ? programTrackFocusTask(curriculumTasks)
        : (curriculumTasks.isNotEmpty ? curriculumTasks.first : null);
    final taskBuckets = bucketTrackTasks(curriculumTasks);
    final focusLabel = hasProgramEnrollment
        ? l10n.activeTrackNextTask
        : l10n.activeTrackCurrentFocus;
    final focusRef = todayTask?.contentItemSefariaRef;
    // UI-3 — type-aware, collapsed unit naming. Prefer the seed-sourced
    // day-level label attached to the task at generation time (a whole daf,
    // a mishnayos range), which is reliable and already collapsed. Fall back
    // to the renderer breadcrumb collapsed to the daf level (amud dropped)
    // for program tracks, or a first–last range for self-paced multi-ref
    // days. The breadcrumb's leading seder is trimmed (curriculum chip above
    // already shows it).
    final useHebrew = terms.isHebrew;
    String? unitLabelForTask(DailyTask? task) {
      if (task == null) return null;
      final seeded = programUnitDayLabel(task, useHebrew: useHebrew);
      if (seeded != null) return seeded;
      final r = task.contentItemSefariaRef;
      final rendered = trimSederFromBreadcrumb(
        ref.watch(renderedDisplayForRefProvider(r)).asData?.value ?? r,
      );
      // Program tracks collapse amud → daf; self-paced keeps its leaf.
      return hasProgramEnrollment ? collapseAmudToDaf(rendered) : rendered;
    }

    // UI-2 — "Today" is the PRIMARY element. Surface today's program unit
    // regardless of how far behind the user is. The secondary "NEXT TASK"
    // pill shows the oldest OVERDUE unit (the next thing to catch up on),
    // which is distinct from today; when caught up there is no overdue unit,
    // so only the prominent Today pill renders.
    DailyTask? todayProgramTask;
    if (hasProgramEnrollment) {
      for (final t in curriculumTasks) {
        if (t.priority == DailyTaskPriority.todayProgram) {
          todayProgramTask = t;
          break;
        }
      }
    }
    final todayUnitValue = unitLabelForTask(todayProgramTask);

    // Secondary (next/overdue) unit for the muted pill.
    final DailyTask? nextTask;
    if (hasProgramEnrollment) {
      // Oldest missed program day, if behind.
      nextTask = taskBuckets.missedProgram.isNotEmpty
          ? taskBuckets.missedProgram.first
          : null;
    } else {
      nextTask = todayTask;
    }

    // Self-paced multi-ref day: collapse the day's set of refs into a range
    // label so the focus pill shows e.g. "משנה ה׳ – ט׳" rather than a single
    // ref. Program tracks already carry a clean day-level label.
    final String selfPacedRangeValue;
    if (!hasProgramEnrollment && curriculumTasks.length > 1) {
      // Order the day's refs ascending by their canonical (numeric) Sefaria
      // ref before rendering so the collapsed range label reads low → high
      // (e.g. "Pasuk 6 – Pasuk 7"), never reversed. Sorting on the ref — not
      // the rendered display string — keeps this locale-independent.
      final orderedTasks = [...curriculumTasks]
        ..sort(
          (a, b) => compareSefariaRefs(
            a.contentItemSefariaRef,
            b.contentItemSefariaRef,
          ),
        );
      final rendered = <String>[
        for (final t in orderedTasks)
          trimSederFromBreadcrumb(
            ref
                    .watch(
                      renderedDisplayForRefProvider(t.contentItemSefariaRef),
                    )
                    .asData
                    ?.value ??
                t.contentItemSefariaRef,
          ),
      ];
      selfPacedRangeValue = collapseRefRange(rendered);
    } else {
      selfPacedRangeValue = '';
    }

    final nextUnitValue = unitLabelForTask(nextTask);
    final resolvedFocusValue = selfPacedRangeValue.isNotEmpty
        ? selfPacedRangeValue
        : (nextUnitValue ?? l10n.noProjection);
    // Show the secondary pill only when it carries a distinct unit (program:
    // only when behind; self-paced: always, as the single primary pill).
    final showFocusPill = hasProgramEnrollment
        ? (nextUnitValue != null && nextUnitValue != todayUnitValue)
        : (focusRef != null);
    return Card(
      elevation: 5,
      shadowColor: Colors.black26,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          // Card-level tap: prefer the current-focus text when there is one
          // (matches the visible 'CURRENT FOCUS' label). Browse-tree fallback
          // only when nothing is scheduled.
          final focusRef = todayTask?.contentItemSefariaRef;
          if (focusRef != null && focusRef.isNotEmpty) {
            context.router.push(TextDisplayRoute(sefariaRef: focusRef));
          } else {
            context.router.push(
              ContentHierarchyRoute(curriculumId: curriculum.storageKey),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayNamePrimary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.brandInk,
                            letterSpacing: -0.1,
                          ),
                        ),
                        if (displayNameSecondary != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            displayNameSecondary,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.brandInk,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: bookIconBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      color: kActiveTrackPrimaryBlue,
                      size: 24,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // UI-1 — the card lives in a fixed-height PageView viewport, so a
              // tall content stack (two pills + stats) used to overflow the
              // bottom (the Continue button showed the overflow stripes). Let
              // the upper content shrink/scroll inside the available space
              // while the progress labels + Continue button stay pinned below.
              Flexible(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // UI-2 — "Today" is the primary action: prominent accent
                      // pill with a calendar glyph. For program tracks it is
                      // always shown. The secondary "NEXT TASK" pill (oldest
                      // overdue) is muted and suppressed when it would merely
                      // duplicate today (caught up).
                      if (hasProgramEnrollment && todayUnitValue != null) ...[
                        ActiveTrackFocusPill(
                          label: l10n.today,
                          value: todayUnitValue,
                          prominent: true,
                          icon: Icons.today_rounded,
                        ),
                        if (showFocusPill) ...[
                          const SizedBox(height: 8),
                          ActiveTrackFocusPill(
                            label: focusLabel,
                            value: resolvedFocusValue,
                          ),
                        ],
                      ] else
                        // Self-paced (or program with no today unit): the
                        // single focus pill is the prominent primary element.
                        // No calendar glyph here — this is "current focus",
                        // not a calendar-dated "today" unit.
                        ActiveTrackFocusPill(
                          label: focusLabel,
                          value: resolvedFocusValue,
                          prominent: true,
                        ),
                      const SizedBox(height: 10),
                      // Gate the chazara stat column on per-track stage count
                      // (Rule 8). trackHasChazaraProvider returns false while
                      // loading, which conservatively hides the chazara column
                      // until we know the track has chazara stages.
                      TrackStatGrid(
                        buckets: taskBuckets,
                        l10n: l10n,
                        chazaraLabel:
                            (ref
                                    .watch(trackHasChazaraProvider(track.id))
                                    .asData
                                    ?.value ??
                                false)
                            ? terms.bubbleChazara
                            : null,
                      ),
                      if (taskBuckets.total == 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            l10n.nothingDueInQueue,
                            maxLines: 2,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppTheme.brandInkMuted,
                              height: 1.2,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dual progress labels — Track progress (current cycle)
                  // and Lifetime — share the same data source as the
                  // Progress hub per-track rows. Wrap so they fall to a
                  // second line on narrow cards instead of clipping.
                  Wrap(
                    spacing: 12,
                    runSpacing: 2,
                    children: [
                      Text(
                        '${l10n.trackProgress}: $currentCycleDisplay',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppTheme.brandInkMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${l10n.lifetimeLabel}: $lifetimeDisplay',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppTheme.brandInkMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: () {
                      // If there's a concrete next-task / current focus,
                      // jump straight to its text — that's what the
                      // 'CURRENT FOCUS' label promised. Fall back to the
                      // Learn tab when there's nothing scheduled.
                      final focusRef = todayTask?.contentItemSefariaRef;
                      if (focusRef != null && focusRef.isNotEmpty) {
                        context.router.push(
                          TextDisplayRoute(sefariaRef: focusRef),
                        );
                      } else {
                        context.router.navigate(const LearningRoute());
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: kActiveTrackPrimaryBlue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                    child: Text(l10n.continueCta),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

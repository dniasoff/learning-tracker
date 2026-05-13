import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/dashboard/domain/models/track_card_view_model.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/track_card/lifetime_learning_line.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/track_card/next_task_breadcrumb.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/track_card/track_card_header.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/track_card/track_continue_button.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/track_card/track_stat_grid.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

export 'lifetime_learning_line.dart';
export 'next_task_breadcrumb.dart';
export 'track_card_header.dart';
export 'track_continue_button.dart';
export 'track_stat_grid.dart';

/// Canonical track card that renders all 4 data shapes:
///   • programCalendar — calendar-linked program (Daf Yomi, etc.)
///   • deadlineGoal    — finish-by-date goal
///   • velocityGoal    — completions-per-day goal
///   • momentum        — no explicit goal
///
/// All shapes render through the same widget tree, driven by
/// [TrackCardViewModel]. Shape-specific data is held in optional fields
/// on the view-model; all subwidgets read only what they need.
///
/// Widget tree:
///   TrackCard
///   ├── TrackCardHeader
///   ├── NextTaskBreadcrumb
///   ├── TrackStatGrid
///   ├── (optional) empty-queue hint
///   ├── LifetimeLearningLine
///   └── TrackContinueButton
class TrackCard extends StatelessWidget {
  const TrackCard({super.key, required this.vm});

  final TrackCardViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      elevation: 5,
      shadowColor: Colors.black26,
      surfaceTintColor: Colors.transparent,
      color: AppTheme.brandCreamCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => _onCardTap(context),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────────────
              TrackCardHeader(vm: vm),
              const SizedBox(height: 10),

              // ── Next-task breadcrumb ─────────────────────────────────────
              NextTaskBreadcrumb(vm: vm),
              const SizedBox(height: 10),

              // ── Stat grid ───────────────────────────────────────────────
              TrackStatGrid(vm: vm, l10n: l10n),

              // ── Empty-queue hint ─────────────────────────────────────────
              if (vm.emptyQueueHint != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: 4),
                  child: Text(
                    vm.emptyQueueHint!,
                    maxLines: 2,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppTheme.brandInkMuted,
                      height: 1.2,
                    ),
                  ),
                ),

              // ── Lifetime + CTA ───────────────────────────────────────────
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LifetimeLearningLine(vm: vm, l10n: l10n),
                    const SizedBox(height: 8),
                    TrackContinueButton(vm: vm, l10n: l10n),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onCardTap(BuildContext context) {
    final sefariaRef = vm.nextTask.sefariaRef;
    if (sefariaRef != null && sefariaRef.isNotEmpty) {
      context.router.push(TextDisplayRoute(sefariaRef: sefariaRef));
    } else {
      context.router.push(
        ContentHierarchyRoute(curriculumId: vm.curriculumId.storageKey),
      );
    }
  }
}

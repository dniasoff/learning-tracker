/// The sub-track detail's ⋮ action registry, hub selection and the seams
/// sibling stories fill (Story 2.6 / DNI-497).
///
/// Merge-hotspot ruling: DNI-497 owns the detail screen with an overflow
/// action registry, so Story 2.4/2.5 (Edit), 2.8 (End, Delete) and others
/// add one entry each to [subTrackDetailMenuActionsProvider] (or fill a
/// seam below) without editing the screen.
library;

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_detail.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/screens/sub_track_goal_setup_flow.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

final _log = AppLogger.instance;

/// Opens a sub-track's metadata form (Story 2.4 school-year / Story 2.5
/// ongoing form).
typedef SubTrackFormLauncher =
    Future<void> Function(BuildContext context, SubTrack track);

/// Opens the goal setup of [curriculumId] from the no-deadline note.
typedef SubTrackDeadlineSetup =
    Future<void> Function(
      BuildContext context,
      WidgetRef ref,
      String curriculumId,
    );

/// The form launcher behind ⋮ → *Edit*: [openSubTrackForm]. *Edit* is
/// hidden while this is null.
final subTrackFormLauncherProvider = Provider<SubTrackFormLauncher?>(
  (ref) => openSubTrackForm,
);

/// The sub-track types whose metadata form exists; ⋮ → *Edit* shows only
/// for these. Story 2.4 (DNI-495) built the school-year form; Story 2.5
/// (DNI-496) adds [SubTrackType.ongoing] here and to [openSubTrackForm].
final subTrackFormTypesProvider = Provider<Set<SubTrackType>>(
  (ref) => const {SubTrackType.schoolYear},
);

/// Opens [track]'s metadata form (UX-DR-53: Edit moved from the hub row
/// into the detail's ⋮). Only called for a type in
/// [subTrackFormTypesProvider].
Future<void> openSubTrackForm(BuildContext context, SubTrack track) async {
  switch (track.type) {
    case SubTrackType.schoolYear:
      await context.router.push(
        SchoolYearSubTrackFormRoute(
          curriculumId: track.curriculumId,
          subTrackId: track.id,
        ),
      );
    case SubTrackType.ongoing:
      throw UnsupportedError('The ongoing sub-track form is DNI-496');
  }
}

/// The goal-setup launcher behind the no-deadline note's link:
/// [openSubTrackDeadlineSetup] over DNI-495's goal setup. Null leaves the
/// note without its link.
final subTrackDeadlineSetupProvider = Provider<SubTrackDeadlineSetup?>(
  (ref) => openSubTrackDeadlineSetup,
);

/// The detail's no-deadline link (AC-2): opens the Story 2.4 goal setup of
/// [curriculumId] through `subTrackGoalSetupLauncherProvider` (the same
/// flow as the sub-track form's link) and reports its outcome as the form
/// does. A saved deadline reaches the detail through the live learner
/// state, which then shows the capacity bar.
Future<void> openSubTrackDeadlineSetup(
  BuildContext context,
  WidgetRef ref,
  String curriculumId,
) async {
  final curriculum = CurriculumId.fromStorageKey(curriculumId);
  if (curriculum == null) return;
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final launch = ref.read(subTrackGoalSetupLauncherProvider);
  SubTrackGoalSetupOutcome outcome;
  try {
    outcome = await launch(context, ref, curriculum);
  } on Object catch (error, stack) {
    _log.error(
      event: 'sub_track_detail_goal_setup_failed',
      fields: {'curriculum_id': curriculumId},
      exception: error,
      stackTrace: stack,
    );
    outcome = SubTrackGoalSetupOutcome.failed;
  }
  if (!context.mounted) return;
  switch (outcome) {
    case SubTrackGoalSetupOutcome.saved:
      messenger.showSnackBar(SnackBar(content: Text(l10n.goalSavedSnack)));
    case SubTrackGoalSetupOutcome.failed:
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.subTrackGoalSaveFailed),
          action: SnackBarAction(
            label: l10n.actionRetry,
            onPressed: () => unawaited(
              openSubTrackDeadlineSetup(context, ref, curriculumId),
            ),
          ),
        ),
      );
    case SubTrackGoalSetupOutcome.cancelled:
      break;
  }
}

/// One ⋮ action of the detail.
final class SubTrackDetailMenuAction {
  /// Creates an action.
  const SubTrackDetailMenuAction({
    required this.id,
    required this.icon,
    required this.label,
    required this.visibleFor,
    required this.onSelected,
  });

  /// Stable id (also the menu item key, `subTrackMenu:{id}`).
  final String id;

  /// Leading icon.
  final IconData icon;

  /// Localized label.
  final String Function(AppLocalizations l10n) label;

  /// Whether the action shows for [detail] (role, ended state).
  final bool Function(SubTrackDetail detail) visibleFor;

  /// Runs the action.
  final Future<void> Function(BuildContext context, SubTrackDetail detail)
  onSelected;
}

/// The ⋮ actions of the detail, in menu order. The menu is hidden when no
/// action is visible (e.g. for the read-only child and tutor).
final subTrackDetailMenuActionsProvider =
    Provider<List<SubTrackDetailMenuAction>>((ref) {
      final edit = ref.watch(subTrackFormLauncherProvider);
      final formTypes = ref.watch(subTrackFormTypesProvider);
      return [
        // Story 2.4 / 2.5: metadata Edit moved from the hub row (UX-DR-53).
        if (edit != null)
          SubTrackDetailMenuAction(
            id: 'edit',
            icon: Icons.edit_outlined,
            label: (l10n) => l10n.subTrackDetailEdit,
            visibleFor: (detail) =>
                detail.canEdit && formTypes.contains(detail.track.type),
            onSelected: (context, detail) => edit(context, detail.track),
          ),
        // DNI-499 (Story 2.8) adds End and Delete here.
      ];
    });

/// The sub-track selected on the Manage tracks hub. Kept across rebuilds
/// and layout changes so the hub keeps its selection while a tablet's
/// detail pane updates in place (UX-DR-163, UX-DR-164).
final subTrackHubSelectionProvider =
    NotifierProvider<SubTrackHubSelection, String?>(SubTrackHubSelection.new);

/// The selected sub-track id, or null.
class SubTrackHubSelection extends Notifier<String?> {
  @override
  String? build() => null;

  /// Selects [subTrackId].
  void select(String subTrackId) => state = subTrackId;

  /// Clears the selection.
  void clear() => state = null;
}

/// Whether [context] sits inside a list-detail split whose detail pane
/// shows the selected sub-track. Provided by `SubTrackListDetailLayout`.
class SubTrackSplitScope extends InheritedWidget {
  /// Marks [child] as inside a split.
  const SubTrackSplitScope({super.key, required super.child});

  /// Whether [context] is inside a split.
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SubTrackSplitScope>() != null;

  @override
  bool updateShouldNotify(SubTrackSplitScope oldWidget) => false;
}

/// What a hub row tap does (AC-1, UX-DR-53): select the sub-track and, on
/// a phone, push its detail; inside a tablet split, the detail pane
/// updates in place and the route is not pushed.
Future<void> openSubTrackDetail(
  BuildContext context,
  WidgetRef ref,
  String subTrackId,
) async {
  ref.read(subTrackHubSelectionProvider.notifier).select(subTrackId);
  if (SubTrackSplitScope.of(context)) return;
  await context.router.push(SubTrackDetailRoute(subTrackId: subTrackId));
}

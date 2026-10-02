/// The sub-track detail's ⋮ action registry, hub selection and the seams
/// sibling stories fill (Story 2.6 / DNI-497).
///
/// Merge-hotspot ruling: DNI-497 owns the detail screen with an overflow
/// action registry, so Story 2.4/2.5 (Edit), 2.8 (End, Delete) and others
/// add one entry each to [subTrackDetailMenuActionsProvider] (or fill a
/// seam below) without editing the screen.
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_detail.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Opens a sub-track's metadata form (Story 2.4 school-year / Story 2.5
/// ongoing form).
typedef SubTrackFormLauncher =
    Future<void> Function(BuildContext context, SubTrack track);

/// Opens the goal setup of [curriculumId] from the no-deadline note.
typedef SubTrackDeadlineSetup =
    Future<void> Function(BuildContext context, String curriculumId);

/// The form launcher behind ⋮ → *Edit*. Null until the form stories
/// (DNI-495 / DNI-496) bind their routes; *Edit* is hidden while null.
final subTrackFormLauncherProvider = Provider<SubTrackFormLauncher?>(
  (ref) => null,
);

/// The goal-setup launcher behind the no-deadline note's link. Null until
/// DNI-495's `subTrackGoalSetupLauncherProvider` is bound here; the note
/// then shows without its link.
final subTrackDeadlineSetupProvider = Provider<SubTrackDeadlineSetup?>(
  (ref) => null,
);

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
      return [
        // Story 2.4 / 2.5: metadata Edit moved from the hub row (UX-DR-53).
        if (edit != null)
          SubTrackDetailMenuAction(
            id: 'edit',
            icon: Icons.edit_outlined,
            label: (l10n) => l10n.subTrackDetailEdit,
            visibleFor: (detail) => detail.canEdit,
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

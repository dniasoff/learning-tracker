/// The Manage tracks hub's tablet list-detail split (Story 2.6 / DNI-497,
/// AC-8; UX-DR-163, UX-DR-164; DESIGN.md tablet composition).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_detail_actions.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/screens/sub_track_detail_screen.dart';

/// The window width from which the hub list and the sub-track detail sit
/// side by side (AC-8).
const double subTrackSplitBreakpoint = 840;

/// Width of the hub list pane in the split.
const double subTrackSplitListWidth = 400;

/// Wraps the hub [list].
///
/// Below [subTrackSplitBreakpoint] it is just the list; a row tap pushes
/// the detail route. From the breakpoint up, row taps select in place
/// ([SubTrackSplitScope]) and, once a sub-track is selected, the list and
/// its detail sit in two panes: the list keeps its scroll position and
/// selection, and the detail pane updates in place on the next selection.
class SubTrackListDetailLayout extends ConsumerStatefulWidget {
  /// Creates the layout around [list].
  const SubTrackListDetailLayout({super.key, required this.list});

  /// The hub list (it reads [subTrackHubSelectionProvider] to mark the
  /// selected row).
  final Widget list;

  @override
  ConsumerState<SubTrackListDetailLayout> createState() =>
      _SubTrackListDetailLayoutState();
}

class _SubTrackListDetailLayoutState
    extends ConsumerState<SubTrackListDetailLayout> {
  /// Moves the list (with its scroll position) into and out of the split.
  final _listKey = GlobalKey(debugLabel: 'subTrackSplitList');

  @override
  Widget build(BuildContext context) {
    final keptList = KeyedSubtree(key: _listKey, child: widget.list);
    if (MediaQuery.sizeOf(context).width < subTrackSplitBreakpoint) {
      return keptList;
    }
    final selected = ref.watch(subTrackHubSelectionProvider);
    return SubTrackSplitScope(
      child: selected == null
          ? keptList
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: subTrackSplitListWidth, child: keptList),
                VerticalDivider(width: 1, color: context.colors.brandOutline),
                Expanded(
                  child: Material(
                    color: context.colors.surfaceF5,
                    child: SafeArea(
                      left: false,
                      right: false,
                      child: SubTrackDetailView(
                        key: const ValueKey('subTrackSplitDetail'),
                        subTrackId: selected,
                        showTitle: true,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

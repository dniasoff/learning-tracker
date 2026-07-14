import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/widgets/track_management_body.dart';

/// Central hub for viewing and managing tracks.
///
/// AUD-t-story-acceptance-04: this screen is a thin route wrapper — the
/// actual UI (list/empty/error states, add-track flow, and the TS-16
/// last-active-curriculum delete guard) is implemented once in
/// [TrackManagementBody] and shared with any other caller that needs it.
/// This class only supplies routing concerns: the `startAdding` deep-link
/// query param, and the tab-root back-navigation affordance.
@RoutePage()
class TrackManagementHubScreen extends StatelessWidget {
  const TrackManagementHubScreen({
    super.key,
    @QueryParam('startAdding') this.startAdding = false,
  });

  final bool startAdding;

  @override
  Widget build(BuildContext context) {
    return TrackManagementBody(showBackButton: true, startAdding: startAdding);
  }
}

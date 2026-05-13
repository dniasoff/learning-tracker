import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:learning_tracker/features/track_setup/presentation/widgets/track_management_body.dart';

/// Central hub for viewing and managing tracks.
///
/// Delegates all rendering to [TrackManagementBody]. The hub is a tab-root
/// destination so it does not show a back button.
@RoutePage()
class TrackManagementHubScreen extends StatelessWidget {
  const TrackManagementHubScreen({
    super.key,
    @QueryParam('startAdding') this.startAdding = false,
  });

  // ignore: unused_field
  final bool startAdding;

  @override
  Widget build(BuildContext context) {
    return const TrackManagementBody(showBackButton: false);
  }
}

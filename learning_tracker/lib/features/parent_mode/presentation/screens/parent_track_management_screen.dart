import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:learning_tracker/features/track_setup/presentation/widgets/track_management_body.dart';

/// Parent mode: track-management screen delegating to [TrackManagementBody].
///
/// This screen is pushed onto the navigation stack (has a back button) but is
/// otherwise identical to [TrackManagementHubScreen].
@RoutePage()
class ParentTrackManagementScreen extends StatelessWidget {
  const ParentTrackManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TrackManagementBody(showBackButton: true);
  }
}

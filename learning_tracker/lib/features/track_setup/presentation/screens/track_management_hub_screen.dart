import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/track_setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/track_setup/presentation/providers/after_track_change_invalidation.dart';
import 'package:learning_tracker/features/track_setup/presentation/providers/track_management_providers.dart';
import 'package:learning_tracker/features/track_setup/presentation/screens/add_track_flow_screen.dart';
import 'package:learning_tracker/features/track_setup/presentation/widgets/learning_track_card.dart';

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

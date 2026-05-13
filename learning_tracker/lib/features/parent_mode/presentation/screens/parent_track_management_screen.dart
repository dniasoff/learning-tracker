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
import 'package:learning_tracker/features/track_setup/presentation/providers/track_management_providers.dart'
    as tm;
import 'package:learning_tracker/features/track_setup/presentation/screens/add_track_flow_screen.dart';
import 'package:learning_tracker/features/track_setup/presentation/widgets/learning_track_card.dart';

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

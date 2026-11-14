import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/widgets/preference_list_tile.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Entry point to the groups the active profile can access.
///
/// The destination retains its existing profile-selection guard and only
/// exposes child approvals when the parent session is active.
class GroupsEntryTile extends ConsumerWidget {
  const GroupsEntryTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileId = ref.watch(activeProfileIdProvider);
    if (profileId == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    return PreferenceListTile.withIcon(
      icon: Icons.groups_outlined,
      iconColor: context.colors.brandBlueBright,
      iconBackground: context.colors.brandBlueSoft,
      title: l10n.groupTitle,
      subtitle: l10n.groupsEntrySubtitle,
      onTap: () => unawaited(_openGroups(context, ref, profileId)),
    );
  }

  Future<void> _openGroups(
    BuildContext context,
    WidgetRef ref,
    String profileId,
  ) async {
    final profile = await ref.read(activeProfileProvider.future);
    if (!context.mounted || profile == null) return;
    await context.router.push(
      LearningGroupsRoute(
        profileId: profileId,
        isAdult: profile.mode == ProfileMode.adult,
      ),
    );
  }
}

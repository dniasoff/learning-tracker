import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/add_profile_dialog.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/profile_edit_delete_actions.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

@RoutePage()
class ManageLearnersScreen extends ConsumerWidget {
  const ManageLearnersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(profileListStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(text: AppLocalizations.of(context)!.manageProfiles),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewPadding.bottom,
        ),
        child: FloatingActionButton(
          onPressed: () => _showAddProfileDialogCanonical(context, ref),
          tooltip: AppLocalizations.of(context)!.addProfile,
          child: const Icon(Icons.add),
        ),
      ),
      body: profilesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => AppErrorView(
          error: e,
          stackTrace: s,
          onRetry: () => ref.refresh(profileListStreamProvider),
        ),
        data: (profiles) {
          if (profiles.isEmpty) {
            return Center(
              child: Text(AppLocalizations.of(context)!.noProfilesYet),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: profiles.length,
            itemBuilder: (context, index) {
              final profile = profiles[index];
              return _ProfileListTile(profile: profile);
            },
          );
        },
      ),
    );
  }

  // WS1.consolidate: delegate to the canonical showAddProfileDialog from
  // add_profile_dialog.dart instead of duplicating the creation flow.
  Future<void> _showAddProfileDialogCanonical(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await showAddProfileDialog(context, ref);
    // showAddProfileDialog handles PIN prompt, provider invalidation, etc.
  }
}

class _ProfileListTile extends ConsumerWidget {
  final ProfileModel profile;

  const _ProfileListTile({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: _ProfileInitialsAvatar(displayName: profile.displayName),
        title: Text(profile.displayName),
        subtitle: Text(
          profile.profileMode == ProfileMode.child
              ? AppLocalizations.of(context)!.profileTypeChild
              : AppLocalizations.of(context)!.profileTypeAdult,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            switch (value) {
              case 'edit':
                await editProfileFlow(context, ref, profile);
              case 'delete':
                await deleteProfileFlow(context, ref, profile);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'edit',
              child: Text(AppLocalizations.of(context)!.profilesEditLabel),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Text(AppLocalizations.of(context)!.profilesDeleteLabel),
            ),
          ],
        ),
      ),
    );
  }
}

/// Initials circle matching the style used by [ProfileCard] in the profile
/// picker — keeps both screens visually consistent.
class _ProfileInitialsAvatar extends StatelessWidget {
  const _ProfileInitialsAvatar({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    final trimmed = displayName.trim();
    final initial = trimmed.isEmpty
        ? '?'
        : trimmed.substring(0, 1).toUpperCase();
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF2F5FC), Color(0xFFE6ECF8)],
        ),
        shape: BoxShape.circle,
        border: Border.all(
          color: context.colors.brandBlue.withValues(alpha: 0.14),
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: context.colors.brandBlueDeep,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

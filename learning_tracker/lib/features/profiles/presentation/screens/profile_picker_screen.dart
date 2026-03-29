import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/profile_avatar.dart';

@RoutePage()
class ProfilePickerScreen extends ConsumerWidget {
  const ProfilePickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(profileListProvider);

    return Scaffold(
      body: SafeArea(
        child: profilesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Error: $e')),
          data: (profiles) => _PickerBody(profiles: profiles),
        ),
      ),
    );
  }
}

class _PickerBody extends ConsumerWidget {
  final List<ProfileModel> profiles;

  const _PickerBody({required this.profiles});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 48),
          Text(
            "Who's learning today?",
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: profiles.length + 1, // +1 for add button
              itemBuilder: (context, index) {
                if (index == profiles.length) {
                  return _AddProfileCard(
                    onTap: () => _showAddProfileDialog(context, ref),
                    isDisabled: profiles.length >= 10,
                  );
                }
                final profile = profiles[index];
                return _ProfileCard(
                  profile: profile,
                  onTap: () {
                    ref
                        .read(selectedProfileIdProvider.notifier)
                        .select(profile.id);
                    context.router.replace(const AppShellRoute());
                  },
                  onLongPress: () =>
                      _showManagementSheet(context, ref, profile, profiles),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddProfileDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final nameController = TextEditingController();
    var mode = 'adult';

    final result = await showDialog<({String name, String mode})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add Profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'adult', label: Text('Adult')),
                  ButtonSegment(value: 'child', label: Text('Child')),
                ],
                selected: {mode},
                onSelectionChanged: (v) => setState(() => mode = v.first),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(ctx, (name: name, mode: mode));
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();

    if (result != null && context.mounted) {
      try {
        final repo = ref.read(profileRepositoryProvider);
        await repo.createProfile(
          accountId: 1,
          displayName: result.name,
          mode: result.mode,
        );
        ref.invalidate(profileListProvider);
      } on DuplicateProfileNameException {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('A profile named "${result.name}" already exists'),
            ),
          );
        }
      } on MaxProfilesExceededException {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Maximum 10 profiles reached')),
          );
        }
      }
    }
  }

  Future<void> _showManagementSheet(
    BuildContext context,
    WidgetRef ref,
    ProfileModel profile,
    List<ProfileModel> allProfiles,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename'),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            ListTile(
              leading: Icon(
                Icons.delete,
                color: Theme.of(ctx).colorScheme.error,
              ),
              title: Text(
                'Delete',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error),
              ),
              enabled: allProfiles.length > 1,
              subtitle: allProfiles.length <= 1
                  ? const Text('You must have at least one profile')
                  : null,
              onTap: allProfiles.length > 1
                  ? () => Navigator.pop(ctx, 'delete')
                  : null,
            ),
          ],
        ),
      ),
    );

    if (!context.mounted || action == null) return;

    if (action == 'rename') {
      await _showRenameDialog(context, ref, profile);
    } else if (action == 'delete') {
      await _showDeleteConfirmation(context, ref, profile);
    }
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    WidgetRef ref,
    ProfileModel profile,
  ) async {
    final controller = TextEditingController(text: profile.displayName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Profile'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Display Name',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (newName != null && newName.isNotEmpty && context.mounted) {
      try {
        final repo = ref.read(profileRepositoryProvider);
        await repo.updateProfile(id: profile.id, displayName: newName);
        ref.invalidate(profileListProvider);
      } on DuplicateProfileNameException {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('A profile named "$newName" already exists'),
            ),
          );
        }
      }
    }
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    ProfileModel profile,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Profile?'),
        content: Text(
          'Permanently delete "${profile.displayName}" and ALL associated '
          'learning data? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if ((confirmed ?? false) && context.mounted) {
      try {
        final repo = ref.read(profileRepositoryProvider);
        await repo.deleteProfile(profile.id);

        // Clear selection if deleted profile was selected
        final selectedId = ref.read(selectedProfileIdProvider) ?? -1;
        if (selectedId == profile.id) {
          ref.read(selectedProfileIdProvider.notifier).clear();
        }

        ref.invalidate(profileListProvider);
      } on LastProfileException {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot delete your only profile')),
          );
        }
      }
    }
  }
}

class _ProfileCard extends StatelessWidget {
  final ProfileModel profile;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ProfileCard({
    required this.profile,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ProfileAvatar(avatarIndex: profile.avatarIndex, radius: 36),
              const SizedBox(height: 12),
              Text(
                profile.displayName,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                profile.mode == 'child' ? 'Child' : 'Adult',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddProfileCard extends StatelessWidget {
  final VoidCallback onTap;
  final bool isDisabled;

  const _AddProfileCard({required this.onTap, this.isDisabled = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      color: isDisabled
          ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
          : null,
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_circle_outline,
                size: 48,
                color: isDisabled
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
                    : theme.colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                isDisabled ? 'Max 10 profiles' : 'Add Profile',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: isDisabled
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                      : theme.colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/profile_avatar.dart';

@RoutePage()
class ProfilePickerScreen extends ConsumerWidget {
  const ProfilePickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(profileListStreamProvider);

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
              itemCount: profiles.length + 1,
              itemBuilder: (context, index) {
                if (index == profiles.length) {
                  return _AddProfileCard(
                    onTap: () => _showAddDialog(context, ref),
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
                  onLongPress: () => _showManageSheet(context, ref, profile),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    var mode = 'adult';
    var avatar = 0;
    String? err;

    final result = await showDialog<({String n, String m, int a})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          Future<void> check() async {
            final n = ctrl.text.trim();
            if (n.isEmpty) {
              set(() => err = null);
              return;
            }
            final exists = await ref
                .read(appDatabaseProvider)
                .profileDao
                .profileExistsByName(1, n);
            set(
              () => err = exists
                  ? 'A profile with this name already exists'
                  : null,
            );
          }

          return AlertDialog(
            title: const Text('Add Profile'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      border: const OutlineInputBorder(),
                      errorText: err,
                    ),
                    onChanged: (_) => check(),
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'adult', label: Text('Adult')),
                      ButtonSegment(value: 'child', label: Text('Child')),
                    ],
                    selected: {mode},
                    onSelectionChanged: (v) => set(() => mode = v.first),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Choose an avatar',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 10,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: GestureDetector(
                          onTap: () => set(() => avatar = i),
                          child: Container(
                            decoration: avatar == i
                                ? BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Theme.of(ctx).colorScheme.primary,
                                      width: 3,
                                    ),
                                  )
                                : null,
                            padding: const EdgeInsets.all(2),
                            child: ProfileAvatar(avatarIndex: i, radius: 24),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: ctrl.text.trim().isNotEmpty && err == null
                    ? () => Navigator.pop(ctx, (
                        n: ctrl.text.trim(),
                        m: mode,
                        a: avatar,
                      ))
                    : null,
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
    ctrl.dispose();
    if (result == null || !context.mounted) return;
    try {
      await ref
          .read(profileRepositoryProvider)
          .createProfile(
            accountId: 1,
            displayName: result.n,
            mode: result.m,
            avatarIndex: result.a,
          );
      ref.invalidate(profileListStreamProvider);
    } on DuplicateProfileNameException {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('A profile named "${result.n}" already exists'),
          ),
        );
    } on MaxProfilesExceededException {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 10 profiles reached')),
        );
    }
  }

  Future<void> _showManageSheet(
    BuildContext context,
    WidgetRef ref,
    ProfileModel profile,
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
              enabled: profiles.length > 1,
              subtitle: profiles.length <= 1
                  ? const Text('You must have at least one profile')
                  : null,
              onTap: profiles.length > 1
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
    } else if (action == 'delete' && context.mounted) {
      await _showDeleteDialog(context, ref, profile);
    }
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    WidgetRef ref,
    ProfileModel profile,
  ) async {
    final ctrl = TextEditingController(text: profile.displayName);
    String? err;
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          Future<void> check() async {
            final n = ctrl.text.trim();
            if (n.isEmpty) {
              set(() => err = null);
              return;
            }
            final exists = await ref
                .read(appDatabaseProvider)
                .profileDao
                .profileExistsByName(1, n, excludeId: profile.id);
            set(
              () => err = exists
                  ? 'A profile with this name already exists'
                  : null,
            );
          }

          return AlertDialog(
            title: const Text('Rename Profile'),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Display Name',
                border: const OutlineInputBorder(),
                errorText: err,
              ),
              onChanged: (_) => check(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: ctrl.text.trim().isNotEmpty && err == null
                    ? () => Navigator.pop(ctx, ctrl.text.trim())
                    : null,
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
    ctrl.dispose();
    if (name == null || name.isEmpty || !context.mounted) return;
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateProfile(id: profile.id, displayName: name);
      ref.invalidate(profileListStreamProvider);
    } on DuplicateProfileNameException {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('A profile named "$name" already exists')),
        );
    }
  }

  Future<void> _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    ProfileModel profile,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Profile?'),
        content: Text(
          'Permanently delete "${profile.displayName}" and ALL associated learning data? This cannot be undone.',
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
    if (!(ok ?? false) || !context.mounted) return;
    try {
      await ref.read(profileRepositoryProvider).deleteProfile(profile.id);
      final sel = ref.read(selectedProfileIdProvider) ?? -1;
      if (sel == profile.id)
        ref.read(selectedProfileIdProvider.notifier).clear();
      ref.invalidate(profileListStreamProvider);
    } on LastProfileException {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot delete your only profile')),
        );
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

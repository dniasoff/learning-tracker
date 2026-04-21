import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/parent_mode/presentation/widgets/parent_pin_setup_dialog.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/profile_avatar.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';

@RoutePage()
class ProfilePickerScreen extends ConsumerStatefulWidget {
  const ProfilePickerScreen({super.key});

  @override
  ConsumerState<ProfilePickerScreen> createState() =>
      _ProfilePickerScreenState();
}

class _ProfilePickerScreenState extends ConsumerState<ProfilePickerScreen> {
  @override
  Widget build(BuildContext context) {
    // Use future provider instead of stream provider to avoid the
    // InheritedElement '_dependents.isEmpty' assertion that fires when
    // a stream-triggered rebuild races with dialog/overlay dismissal.
    final profilesAsync = ref.watch(profileListProvider);

    return Scaffold(
      body: SafeArea(
        child: profilesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Error: $e')),
          data: (profiles) => _buildBody(context, profiles),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<ProfileModel> profiles) {
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
              itemBuilder: (_, index) {
                if (index == profiles.length) {
                  return _AddProfileCard(
                    onTap: () => _showAddDialog(profiles.length),
                    isDisabled: profiles.length >= 10,
                  );
                }
                final profile = profiles[index];
                return _ProfileCard(
                  profile: profile,
                  onTap: () => unawaited(_selectProfile(profile.id)),
                  onLongPress: () => _showManageSheet(profile, profiles.length),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Select Profile ─────────────────────────────────────────────────────────

  Future<void> _selectProfile(int profileId) async {
    ref.read(selectedProfileIdProvider.notifier).select(profileId);
    // Recreate SyncEngine with the selected profile id and pull once so
    // profile-scoped tracks/progress are available immediately on AppShell.
    ref.invalidate(syncEngineProvider);
    final syncEngine = ref.read(syncEngineProvider);
    if (syncEngine != null) {
      await syncEngine.pullOnLaunch();
    }
    if (!mounted) return;
    await context.router.replaceAll([const AppShellRoute()]);
  }

  // ── Add Profile ───────────────────────────────────────────────────────────

  Future<void> _showAddDialog(int profileCount) async {
    final profileDao = ref.read(userDatabaseProvider).profileDao;
    final repo = ref.read(profileRepositoryProvider);

    final ctrl = TextEditingController();
    var mode = 'adult';
    String? err;

    final result = await showDialog<({String n, String m})>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          Future<void> check() async {
            final n = ctrl.text.trim();
            if (n.isEmpty) {
              set(() => err = null);
              return;
            }
            try {
              final exists = await profileDao.profileExistsByName(1, n);
              set(
                () => err = exists
                    ? 'A profile with this name already exists'
                    : null,
              );
            } catch (_) {
              set(() => err = null);
            }
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
                    ? () => Navigator.pop(ctx, (n: ctrl.text.trim(), m: mode))
                    : null,
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
    if (result == null || !mounted) {
      // Delay dispose so the dialog exit animation finishes using the controller.
      Future.delayed(const Duration(milliseconds: 300), ctrl.dispose);
      return;
    }
    try {
      final created = await repo.createProfile(
        accountId: 1,
        displayName: result.n,
        mode: result.m,
      );
      // Dispose after creation (dialog animation is done by now).
      ctrl.dispose();
      // Manually refresh the profile list after creation.
      if (mounted) ref.invalidate(profileListProvider);
      // Child profiles require a parent PIN so the parent can gate access
      // to parental controls. Prompt right after creation.
      if (created.mode == 'child' && mounted) {
        await showParentPinSetupDialog(
          context,
          ref,
          profileId: created.id,
          profileName: created.displayName,
        );
      }
    } on DuplicateProfileNameException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('A profile named "${result.n}" already exists'),
          ),
        );
      }
    } on MaxProfilesExceededException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 10 profiles reached')),
        );
      }
    }
  }

  // ── Manage (Long-press) ───────────────────────────────────────────────────

  Future<void> _showManageSheet(ProfileModel profile, int profileCount) async {
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
              enabled: profileCount > 1,
              subtitle: profileCount <= 1
                  ? const Text('You must have at least one profile')
                  : null,
              onTap: profileCount > 1
                  ? () => Navigator.pop(ctx, 'delete')
                  : null,
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'rename') {
      await _showRenameDialog(profile);
    } else if (action == 'delete' && mounted) {
      await _showDeleteDialog(profile);
    }
  }

  // ── Rename ────────────────────────────────────────────────────────────────

  Future<void> _showRenameDialog(ProfileModel profile) async {
    final profileDao = ref.read(userDatabaseProvider).profileDao;
    final repo = ref.read(profileRepositoryProvider);

    final ctrl = TextEditingController(text: profile.displayName);
    String? err;
    final name = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          Future<void> check() async {
            final n = ctrl.text.trim();
            if (n.isEmpty) {
              set(() => err = null);
              return;
            }
            try {
              final exists = await profileDao.profileExistsByName(
                1,
                n,
                excludeId: profile.id,
              );
              set(
                () => err = exists
                    ? 'A profile with this name already exists'
                    : null,
              );
            } catch (_) {
              set(() => err = null);
            }
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
    if (name == null || name.isEmpty || !mounted) {
      Future.delayed(const Duration(milliseconds: 300), ctrl.dispose);
      return;
    }
    try {
      await repo.updateProfile(id: profile.id, displayName: name);
      ctrl.dispose();
      if (mounted) ref.invalidate(profileListProvider);
    } on DuplicateProfileNameException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('A profile named "$name" already exists')),
        );
      }
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> _showDeleteDialog(ProfileModel profile) async {
    final repo = ref.read(profileRepositoryProvider);

    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
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
    if (!(ok ?? false) || !mounted) return;
    try {
      await repo.deleteProfile(profile.id);
      final sel = ref.read(selectedProfileIdProvider) ?? -1;
      if (sel == profile.id) {
        ref.read(selectedProfileIdProvider.notifier).clear();
      }
      ref.invalidate(profileListProvider);
    } on LastProfileException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot delete your only profile')),
        );
      }
    }
  }
}

// ── Stateless card widgets ──────────────────────────────────────────────────

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

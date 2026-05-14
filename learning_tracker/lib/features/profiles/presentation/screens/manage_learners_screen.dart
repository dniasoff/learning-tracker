import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/parent_mode/presentation/widgets/parent_pin_setup_dialog.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/profile_avatar.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

@RoutePage()
class ManageLearnersScreen extends ConsumerWidget {
  const ManageLearnersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(profileListStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const AppBarTitle(text: 'Manage Learners')),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewPadding.bottom,
        ),
        child: FloatingActionButton(
          onPressed: () => _showAddProfileDialog(context, ref),
          child: const Icon(Icons.add),
        ),
      ),
      body: profilesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(
          child: Text(AppLocalizations.of(context)!.errorGeneric(e.toString())),
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

  Future<void> _showAddProfileDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final result = await showDialog<({String name, String mode, int avatar})>(
      context: context,
      builder: (ctx) => _ProfileFormDialog(
        title: AppLocalizations.of(context)!.profilesAddLearner,
      ),
    );
    if (result == null) return;

    final repo = ref.read(profileRepositoryProvider);
    final accountId = ref.read(currentAccountIdProvider);
    final created = await repo.createProfile(
      accountId: accountId,
      displayName: result.name,
      mode: result.mode,
      avatarIndex: result.avatar,
    );
    ref.invalidate(profileListProvider);
    ref.invalidate(profileListStreamProvider);

    // Child profiles require a parent PIN so the parent can gate access
    // to parental controls. Prompt right after creation.
    if (created.mode == 'child' && context.mounted) {
      await showParentPinSetupDialog(
        context,
        ref,
        profileId: created.id,
        profileName: created.displayName,
      );
    }
  }
}

class _ProfileListTile extends ConsumerWidget {
  final ProfileModel profile;

  const _ProfileListTile({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: ProfileAvatar(avatarIndex: profile.avatarIndex),
        title: Text(profile.displayName),
        subtitle: Text(profile.mode == 'child' ? 'Child mode' : 'Adult mode'),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            switch (value) {
              case 'edit':
                await _editProfile(context, ref);
              case 'delete':
                await _deleteProfile(context, ref);
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

  Future<void> _editProfile(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<({String name, String mode, int avatar})>(
      context: context,
      builder: (ctx) => _ProfileFormDialog(
        title: AppLocalizations.of(context)!.profilesEditLearner,
        initialName: profile.displayName,
        initialMode: profile.mode,
        initialAvatar: profile.avatarIndex,
      ),
    );
    if (result == null) return;

    final repo = ref.read(profileRepositoryProvider);
    await repo.updateProfile(
      id: profile.id,
      displayName: result.name,
      avatarIndex: result.avatar,
    );
    ref.invalidate(profileListProvider);
    ref.invalidate(profileListStreamProvider);
    ref.invalidate(selectedProfileProvider);
  }

  Future<void> _deleteProfile(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(profileRepositoryProvider);
    final accountId = ref.read(currentAccountIdProvider);
    final remaining = await repo.countProfilesForAccount(accountId);
    final isLast = remaining <= 1;
    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isLast ? 'Delete your only profile?' : 'Delete Profile'),
        content: Text(
          isLast
              ? 'This is your only profile. Deleting "${profile.displayName}" '
                    'will erase every track, completion, and lifetime entry on '
                    'this account. You will need to create a new profile '
                    'before you can keep learning.'
              : 'Are you sure you want to delete "${profile.displayName}"? '
                    'All learning data for this profile will be permanently '
                    'lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppLocalizations.of(context)!.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.brandCoralDeep,
            ),
            child: Text(
              isLast
                  ? 'Delete anyway'
                  : AppLocalizations.of(context)!.actionDelete,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final selectedId = ref.read(selectedProfileIdProvider);
    await repo.deleteProfile(profile.id, allowLast: isLast);

    if (selectedId == profile.id) {
      ref.read(selectedProfileIdProvider.notifier).clear();
    }
    ref.invalidate(profileListProvider);
    ref.invalidate(profileListStreamProvider);
  }
}

class _ProfileFormDialog extends StatefulWidget {
  final String title;
  final String? initialName;
  final String? initialMode;
  final int? initialAvatar;

  const _ProfileFormDialog({
    required this.title,
    this.initialName,
    this.initialMode,
    this.initialAvatar,
  });

  @override
  State<_ProfileFormDialog> createState() => _ProfileFormDialogState();
}

class _ProfileFormDialogState extends State<_ProfileFormDialog> {
  late final TextEditingController _nameController;
  late String _mode;
  late int _avatarIndex;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _mode = widget.initialMode ?? 'child';
    _avatarIndex = widget.initialAvatar ?? 0;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: AppLocalizations.of(
                  context,
                )!.profilesEnterLearnerName,
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'child',
                  label: Text(AppLocalizations.of(context)!.profilesChildLabel),
                ),
                ButtonSegment(
                  value: 'adult',
                  label: Text(AppLocalizations.of(context)!.profilesAdultLabel),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (selected) {
                setState(() => _mode = selected.first);
              },
            ),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context)!.profilesChooseAvatar),
            const SizedBox(height: 8),
            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 10,
                itemBuilder: (context, index) {
                  final isSelected = index == _avatarIndex;
                  return GestureDetector(
                    onTap: () => setState(() => _avatarIndex = index),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: isSelected
                          ? BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 3,
                              ),
                            )
                          : null,
                      child: ProfileAvatar(avatarIndex: index, radius: 24),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context)!.actionCancel),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;
            Navigator.of(
              context,
            ).pop((name: name, mode: _mode, avatar: _avatarIndex));
          },
          child: Text(AppLocalizations.of(context)!.actionSave),
        ),
      ],
    );
  }
}

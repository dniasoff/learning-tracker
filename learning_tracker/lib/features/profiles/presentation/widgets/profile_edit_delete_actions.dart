import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/providers/network_providers.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/utils/text_input_formatters.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/profile_avatar.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Canonical edit-profile flow.
///
/// Opens the shared profile-form dialog (name + avatar) and persists changes
/// via [profileRepositoryProvider]. Shared between the Manage Learners screen
/// and the profile switcher/manager sheet so the two never fork.
Future<void> editProfileFlow(
  BuildContext context,
  WidgetRef ref,
  ProfileModel profile,
) async {
  final result = await showDialog<({String name, String mode, int avatar})>(
    context: context,
    builder: (ctx) => ProfileEditFormDialog(
      title: AppLocalizations.of(ctx)!.profilesEditLearner,
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

/// Canonical delete-profile flow (with last-profile guard + offline guard for
/// cloud accounts). Shared between Manage Learners and the switcher sheet.
Future<void> deleteProfileFlow(
  BuildContext context,
  WidgetRef ref,
  ProfileModel profile,
) async {
  final repo = ref.read(profileRepositoryProvider);
  final accountId = ref.read(currentAccountIdProvider);
  final remaining = await repo.countProfilesForAccount(accountId);
  final isLast = remaining <= 1;
  if (!context.mounted) return;

  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        isLast ? l10n.deleteProfileLastTitle : l10n.deleteProfileTitle,
      ),
      content: Text(
        isLast
            ? l10n.deleteProfileLastBody(profile.displayName)
            : l10n.deleteProfileBody(profile.displayName),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.actionCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppTheme.brandCoralDeep),
          child: Text(
            isLast ? l10n.deleteProfileLastConfirm : l10n.actionDelete,
          ),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  final isLocalBorn = ref.read(authStateProvider).isLocalBorn;
  if (!isLocalBorn) {
    final isOnline = await ref.read(connectivityServiceProvider).isOnline;
    if (!isOnline) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.errorDeleteProfileRequiresInternet,
            ),
          ),
        );
      }
      return;
    }
  }

  final selectedId = ref.read(selectedProfileIdProvider);
  await repo.deleteProfile(profile.id, allowLast: isLast);

  if (selectedId == profile.id) {
    ref.read(selectedProfileIdProvider.notifier).clear();
  }
  ref.invalidate(profileListProvider);
  ref.invalidate(profileListStreamProvider);
}

/// Shared profile edit form (name, mode display, avatar picker).
///
/// Mode is shown but not editable on edit (matching the existing Manage
/// Learners behaviour — only name + avatar are persisted).
class ProfileEditFormDialog extends StatefulWidget {
  final String title;
  final String? initialName;
  final String? initialMode;
  final int? initialAvatar;

  const ProfileEditFormDialog({
    super.key,
    required this.title,
    this.initialName,
    this.initialMode,
    this.initialAvatar,
  });

  @override
  State<ProfileEditFormDialog> createState() => _ProfileEditFormDialogState();
}

class _ProfileEditFormDialogState extends State<ProfileEditFormDialog> {
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
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              inputFormatters: const [TrimLeadingSpaceFormatter()],
              decoration: InputDecoration(
                labelText: l10n.profilesNameFieldLabel,
                hintText: l10n.profilesEnterLearnerName,
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'child',
                  label: Text(l10n.profilesChildLabel),
                ),
                ButtonSegment(
                  value: 'adult',
                  label: Text(l10n.profilesAdultLabel),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (selected) {
                setState(() => _mode = selected.first);
              },
            ),
            const SizedBox(height: 16),
            Text(l10n.profilesChooseAvatar),
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
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;
            Navigator.of(
              context,
            ).pop((name: name, mode: _mode, avatar: _avatarIndex));
          },
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}

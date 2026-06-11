import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/utils/text_input_formatters.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/profile_avatar.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';
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
  try {
    // PP-2 fix: pass result.mode so that the selected mode (child/adult) is
    // actually persisted. Previously mode was silently dropped, meaning a
    // parent could believe they changed a profile's mode when nothing changed.
    await repo.updateProfile(
      id: profile.id,
      displayName: result.name,
      mode: result.mode,
      avatarIndex: result.avatar,
    );
  } on TutorWriteException catch (e) {
    if (context.mounted && e.code == 'permission-denied') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.tutorPermissionDenied),
        ),
      );
    }
    return;
  }
  ref.invalidate(profileListProvider);
  ref.invalidate(profileListStreamProvider);
  ref.invalidate(selectedProfileProvider);
}

/// Canonical delete-profile flow (with last-profile guard).
/// Works offline: the repository deletes locally first and enqueues the cloud
/// delete to the outbox. Shared between Manage Learners and the switcher sheet.
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

  // Offline-first: the repository always deletes locally via Drift first,
  // then enqueues the cloud delete to the outbox (OutboxSyncWriteFacade
  // .deleteLearnerProfile). No connectivity check is needed here.
  final selectedId = ref.read(selectedProfileIdProvider);
  await repo.deleteProfile(profile.id, allowLast: isLast);

  if (selectedId == profile.id) {
    // Bug B: deleting the ACTIVE profile previously cleared the selection to
    // null. The dashboard greeting and top-bar then resolved through
    // activeProfile (id == 0 → null) and fell back to the generic "Learner"
    // label until a tile was re-tapped. Instead, auto-switch to a remaining
    // profile so the greeting/role re-derive to the now-active profile's name
    // reactively. clear() only when nothing remains (last-profile delete).
    final remainingProfiles = await repo.getProfilesByAccount(accountId);
    final next = remainingProfiles.where((p) => p.id != profile.id).firstOrNull;
    if (next != null) {
      ref.read(selectedProfileIdProvider.notifier).select(next.id);
    } else {
      ref.read(selectedProfileIdProvider.notifier).clear();
    }
  }
  ref.invalidate(profileListProvider);
  ref.invalidate(profileListStreamProvider);
  // The active profile changed identity (or was cleared): re-resolve the
  // display-name/greeting source so the dashboard greeting updates immediately.
  ref.invalidate(activeProfileProvider);
  ref.invalidate(selectedProfileProvider);
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

  // P2: inline validation for the name field. Previously a Save with an
  // empty/whitespace name silently returned with no feedback — the dialog
  // just stayed put. Mirrors EditTrackScreen's _nameError pattern: set on a
  // blocked Save, cleared as the user types a non-empty value.
  String? _nameError;

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
              onChanged: (_) {
                // Clear the inline error as soon as the user types a non-empty
                // value, so it doesn't linger once the name is resolved.
                if (_nameError != null &&
                    _nameController.text.trim().isNotEmpty) {
                  setState(() => _nameError = null);
                }
              },
              decoration: InputDecoration(
                labelText: l10n.profilesNameFieldLabel,
                hintText: l10n.profilesEnterLearnerName,
                errorText: _nameError,
              ),
              // PP-11: autofocus removed so the avatar picker and mode toggle
              // stay visible below the fold at large text scale (font 1.3).
              // The user can still tap the name field to edit it.
              autofocus: false,
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
              // Use a Row in a horizontal SingleChildScrollView, NOT a lazy
              // ListView: AlertDialog measures its content's intrinsic
              // dimensions and a lazy RenderViewport can't provide them
              // ("RenderViewport does not support returning intrinsic
              // dimensions" → the dialog crashes on open). Only 10 avatars, so
              // eager layout is cheap.
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var index = 0; index < 10; index++)
                      GestureDetector(
                        onTap: () => setState(() => _avatarIndex = index),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: index == _avatarIndex
                              ? BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    width: 3,
                                  ),
                                )
                              : null,
                          child: ProfileAvatar(avatarIndex: index, radius: 24),
                        ),
                      ),
                  ],
                ),
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
            // P2: an empty/whitespace name no longer silently no-ops; surface
            // a localized inline error so the user understands why Save did
            // nothing, then abort.
            if (name.isEmpty) {
              setState(() => _nameError = l10n.learnerNameRequired);
              return;
            }
            if (_nameError != null) {
              setState(() => _nameError = null);
            }
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

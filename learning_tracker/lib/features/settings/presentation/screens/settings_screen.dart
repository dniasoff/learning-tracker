import 'package:auto_route/auto_route.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/providers/firebase_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/track_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/account_management_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/change_password_dialog.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/delete_account_dialog.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/link_provider_dialog.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/reauthenticate_dialog.dart';

@RoutePage()
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCurriculaAsync = ref.watch(activeCurriculaStreamProvider);
    final user = ref.watch(firebaseAuthProvider).currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Change Mode Section
          ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: const Text('Change Mode'),
            subtitle: const Text('Switch between Child and Adult mode'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showChangeModeDialog(context, ref),
          ),
          const Divider(),

          // Active Curricula Section
          const ListTile(
            title: Text(
              'Active Curricula',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            subtitle: Text('Choose which curricula to display in the app'),
          ),
          const Divider(),

          // Show loading or error states
          activeCurriculaAsync.when(
            data: (activeCurricula) {
              return Column(
                children: CurriculumId.values.map((curriculum) {
                  final isActive = activeCurricula.contains(curriculum);
                  return _CurriculumToggleTile(
                    curriculum: curriculum,
                    isActive: isActive,
                    activeCurriculaCount: activeCurricula.length,
                  );
                }).toList(),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error loading curricula: $error'),
              ),
            ),
          ),

          const Divider(height: 32),

          // Account Management Section
          const ListTile(
            title: Text(
              'Account',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),

          // Change Password (only for email/password users)
          if (user != null &&
              user.providerData
                  .any((info) => info.providerId == 'password'))
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Change Password'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showChangePasswordFlow(context, ref, user),
            ),

          // Link Provider
          if (user != null)
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Link Account'),
              subtitle: const Text('Add another sign-in method'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showLinkProviderDialog(context, ref),
            ),

          const Divider(),

          // Sign Out
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign Out'),
            onTap: () => _showSignOutConfirmation(context, ref),
          ),

          // Delete Account
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              'Delete Account',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () => _showDeleteAccountFlow(context, ref, user),
          ),
        ],
      ),
    );
  }
}

Future<void> _showSignOutConfirmation(
  BuildContext context,
  WidgetRef ref,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Sign Out'),
      content: const Text(
        'Are you sure you want to sign out? Your data will be preserved '
        'for when you sign back in.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Sign Out'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final service = ref.read(accountManagementServiceProvider);
    await service.signOut();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to sign out. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

Future<void> _showDeleteAccountFlow(
  BuildContext context,
  WidgetRef ref,
  User? user,
) async {
  if (user == null) return;

  final service = ref.read(accountManagementServiceProvider);

  // Step 1: Re-authenticate
  final hasPassword =
      user.providerData.any((info) => info.providerId == 'password');
  final hasGoogle =
      user.providerData.any((info) => info.providerId == 'google.com');

  var reauthenticated = false;

  if (hasPassword) {
    reauthenticated = await showReauthenticateDialog(
          context: context,
          email: user.email ?? '',
          service: service,
        ) ??
        false;
  } else if (hasGoogle) {
    try {
      await service.reauthenticateWithGoogle();
      reauthenticated = true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Re-authentication failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  if (!reauthenticated || !context.mounted) return;

  // Step 2: Confirm deletion by typing "DELETE"
  final confirmed = await showDeleteAccountDialog(context: context);
  if (confirmed != true || !context.mounted) return;

  // Step 3: Delete account
  try {
    await service.deleteAccount(user.uid);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete account: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

Future<void> _showChangePasswordFlow(
  BuildContext context,
  WidgetRef ref,
  User user,
) async {
  final service = ref.read(accountManagementServiceProvider);

  // Step 1: Re-authenticate
  final reauthenticated = await showReauthenticateDialog(
    context: context,
    email: user.email ?? '',
    service: service,
  );
  if (reauthenticated != true || !context.mounted) return;

  // Step 2: Change password
  final changed = await showChangePasswordDialog(
    context: context,
    service: service,
  );
  if ((changed ?? false) && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password changed successfully.')),
    );
  }
}

Future<void> _showLinkProviderDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final service = ref.read(accountManagementServiceProvider);
  await showLinkProviderDialog(context: context, service: service);
}

Future<void> _showChangeModeDialog(BuildContext context, WidgetRef ref) async {
  final user = ref.read(firebaseAuthProvider).currentUser;
  if (user == null) return;

  final profileService = ref.read(userProfileServiceProvider);
  final currentMode = await profileService.getUserMode(user.uid);

  if (!context.mounted) return;

  final selected = await showDialog<UserMode>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Select Mode'),
      children: UserMode.values.map((mode) {
        return SimpleDialogOption(
          onPressed: () => Navigator.pop(context, mode),
          child: ListTile(
            leading: Icon(
              mode == UserMode.child ? Icons.child_care : Icons.person,
            ),
            title: Text(mode.name[0].toUpperCase() + mode.name.substring(1)),
            trailing: mode == currentMode
                ? const Icon(Icons.check, color: Colors.green)
                : null,
          ),
        );
      }).toList(),
    ),
  );

  if (selected == null || selected == currentMode || !context.mounted) return;

  try {
    await profileService.setUserMode(
      firebaseUid: user.uid,
      displayName: user.displayName ?? user.email?.split('@').first ?? 'User',
      mode: selected,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Mode changed to ${selected.name[0].toUpperCase()}${selected.name.substring(1)}',
          ),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to change mode. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _CurriculumToggleTile extends ConsumerWidget {
  const _CurriculumToggleTile({
    required this.curriculum,
    required this.isActive,
    required this.activeCurriculaCount,
  });

  final CurriculumId curriculum;
  final bool isActive;
  final int activeCurriculaCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(curriculumActivationServiceProvider);
    final isLastActive = isActive && activeCurriculaCount <= 1;

    return SwitchListTile(
      title: Text(curriculum.displayNameEn),
      subtitle: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(color: isActive ? Colors.green : Colors.grey),
      ),
      value: isActive,
      onChanged: isLastActive
          ? null // Disable toggle for last active curriculum
          : (newValue) async {
              try {
                await service.toggle(curriculum);
                // Invalidate family providers for the toggled curriculum (P3)
                ref.invalidate(isCurriculumActiveProvider(curriculum));
                ref.invalidate(activeTracksProvider(curriculum));
                ref.invalidate(curriculumContentProvider(curriculum));
              } on StateError catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.message),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
    );
  }
}

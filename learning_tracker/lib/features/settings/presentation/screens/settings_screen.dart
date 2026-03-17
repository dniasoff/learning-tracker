import 'package:auto_route/auto_route.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
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

/// App version constant (from pubspec.yaml).
const String _appVersion = '1.0.0';

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
          // User Profile Section
          _UserProfileSection(user: user),
          const Divider(),

          // User Mode Section
          _UserModeSection(user: user),
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

          // Settings Navigation Links
          const ListTile(
            title: Text(
              'More Settings',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notifications'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.pushRoute(const NotificationsRoute()),
          ),
          ListTile(
            leading: const Icon(Icons.sync_outlined),
            title: const Text('Data & Sync'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.pushRoute(const SyncRoute()),
          ),

          const Divider(height: 32),

          // Account Management Section
          const ListTile(
            title: Text(
              'Account',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),

          if (user != null &&
              user.providerData.any((info) => info.providerId == 'password'))
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Change Password'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showChangePasswordFlow(context, ref, user),
            ),

          if (user != null)
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Link Account'),
              subtitle: const Text('Add another sign-in method'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showLinkProviderDialog(context, ref),
            ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign Out'),
            onTap: () => _showSignOutConfirmation(context, ref),
          ),

          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              'Delete Account',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () => _showDeleteAccountFlow(context, ref, user),
          ),

          const Divider(height: 32),

          // App Version
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                'Version $_appVersion',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Displays user profile info: display name, email, and auth provider.
class _UserProfileSection extends StatelessWidget {
  const _UserProfileSection({required this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const ListTile(
        leading: Icon(Icons.person_outline),
        title: Text('Not signed in'),
      );
    }

    final providerIds = user!.providerData.map((p) => p.providerId).toList();
    final providerLabel = providerIds
        .map((id) {
          switch (id) {
            case 'google.com':
              return 'Google';
            case 'password':
              return 'Email/Password';
            default:
              return id;
          }
        })
        .join(', ');

    return ListTile(
      leading: const Icon(Icons.person),
      title: Text(user!.displayName ?? user!.email?.split('@').first ?? 'User'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (user!.email != null) Text(user!.email!),
          Text('Signed in with $providerLabel'),
        ],
      ),
      isThreeLine: user!.email != null,
    );
  }
}

/// Displays current user mode with option to change.
class _UserModeSection extends ConsumerStatefulWidget {
  const _UserModeSection({required this.user});

  final User? user;

  @override
  ConsumerState<_UserModeSection> createState() => _UserModeSectionState();
}

class _UserModeSectionState extends ConsumerState<_UserModeSection> {
  UserMode? _currentMode;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMode();
  }

  Future<void> _loadMode() async {
    if (widget.user == null) return;
    final profileService = ref.read(userProfileServiceProvider);
    final mode = await profileService.getUserMode(widget.user!.uid);
    if (mounted) {
      setState(() {
        _currentMode = mode;
        _loading = false;
      });
    }
  }

  String _modeDisplayName(UserMode mode) =>
      mode.name[0].toUpperCase() + mode.name.substring(1);

  @override
  Widget build(BuildContext context) {
    if (widget.user == null) return const SizedBox.shrink();

    final modeText = _loading
        ? 'Loading...'
        : _currentMode != null
        ? _modeDisplayName(_currentMode!)
        : 'Not set';

    return ListTile(
      leading: Icon(
        _currentMode == UserMode.child ? Icons.child_care : Icons.person,
      ),
      title: const Text('User Mode'),
      subtitle: Text(modeText),
      trailing: const Icon(Icons.chevron_right),
      onTap: _loading ? null : () => _showChangeModeConfirmation(context, ref),
    );
  }

  Future<void> _showChangeModeConfirmation(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final user = widget.user;
    if (user == null) return;

    final profileService = ref.read(userProfileServiceProvider);
    final currentMode = _currentMode ?? UserMode.adult;
    final newMode = currentMode == UserMode.adult
        ? UserMode.child
        : UserMode.adult;

    final implications = newMode == UserMode.child
        ? 'Switching to Child mode will:\n'
              '• Enable gamification features (points, rewards)\n'
              '• Make parent mode available for parental controls\n'
              '• Show celebratory animations on completions'
        : 'Switching to Adult mode will:\n'
              '• Disable gamification popups and animations\n'
              '• Remove parent mode access\n'
              '• Show streamlined completion confirmations';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Switch to ${_modeDisplayName(newMode)} Mode?'),
        content: Text(implications),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Switch to ${_modeDisplayName(newMode)}'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await profileService.setUserMode(
        firebaseUid: user.uid,
        displayName: user.displayName ?? user.email?.split('@').first ?? 'User',
        mode: newMode,
      );
      if (mounted) {
        setState(() => _currentMode = newMode);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mode changed to ${_modeDisplayName(newMode)}'),
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

  final hasPassword = user.providerData.any(
    (info) => info.providerId == 'password',
  );
  final hasGoogle = user.providerData.any(
    (info) => info.providerId == 'google.com',
  );

  var reauthenticated = false;

  if (hasPassword) {
    reauthenticated =
        await showReauthenticateDialog(
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

  final confirmed = await showDeleteAccountDialog(context: context);
  if (confirmed != true || !context.mounted) return;

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

  final reauthenticated = await showReauthenticateDialog(
    context: context,
    email: user.email ?? '',
    service: service,
  );
  if (reauthenticated != true || !context.mounted) return;

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
          ? null
          : (newValue) async {
              try {
                await service.toggle(curriculum);
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

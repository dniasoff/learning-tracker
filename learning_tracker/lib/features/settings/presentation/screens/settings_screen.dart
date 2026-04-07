import 'package:auto_route/auto_route.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart'
    show GoogleSignInException, GoogleSignInExceptionCode;
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/providers/firebase_providers.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/auth/domain/models/app_auth_state.dart';
import 'package:learning_tracker/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/account_management_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/data_export_import_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/hebrew_date_provider.dart';
import 'package:learning_tracker/features/settings/presentation/providers/theme_provider.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/change_password_dialog.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/delete_account_dialog.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/link_provider_dialog.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/reauthenticate_dialog.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';

// TODO(DNI-105): Replace with dynamic version from package_info_plus
// once the dependency is added to pubspec.yaml.
const String _appVersion = '1.0.0';

@RoutePage()
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(firebaseAuthProvider).currentUser;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const AppBarTitle(text: 'Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.router.maybePop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            // User Profile Section
            _UserProfileSection(user: user),
            const SizedBox(height: 24),

            // LEARNING section
            const _SectionHeader(title: 'LEARNING'),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.route,
                      color: theme.colorScheme.primary,
                    ),
                    title: const Text('Manage Tracks'),
                    subtitle: const Text('Add, edit, or archive tracks'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        context.pushRoute(TrackManagementHubRoute()),
                  ),
                  Divider(height: 1, indent: 56, color: theme.dividerColor),
                  _HebrewDateTile(theme: theme),
                  Divider(height: 1, indent: 56, color: theme.dividerColor),
                  ListTile(
                    leading: Icon(
                      Icons.notifications_active_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    title: const Text('Daily Reminder'),
                    subtitle: const Text('Receive daily study prompts'),
                    trailing: Switch(
                      value: true,
                      onChanged: (value) {
                        context.pushRoute(const NotificationsRoute());
                      },
                      activeTrackColor: theme.colorScheme.primary,
                    ),
                    onTap: () => context.pushRoute(const NotificationsRoute()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // APPEARANCE section
            const _SectionHeader(title: 'APPEARANCE'),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  _ThemeTile(theme: theme),
                  Divider(height: 1, indent: 56, color: theme.dividerColor),
                  _AccentColorTile(theme: theme),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // NOTIFICATIONS section
            const _SectionHeader(title: 'NOTIFICATIONS'),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.notifications_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    title: const Text('Notification Settings'),
                    subtitle: const Text('Push, email and sound'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.pushRoute(const NotificationsRoute()),
                  ),
                  Divider(height: 1, indent: 56, color: theme.dividerColor),
                  ListTile(
                    leading: Icon(
                      Icons.local_fire_department,
                      color: theme.colorScheme.primary,
                    ),
                    title: const Text('Streak Alerts'),
                    subtitle: const Text('Never lose your learning streak'),
                    trailing: Switch(
                      value: true,
                      onChanged: (value) {},
                      activeTrackColor: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // BACKUP & SYNC section (DNI-188)
            const _SectionHeader(title: 'BACKUP & SYNC'),
            const SizedBox(height: 8),
            const _BackupSyncSection(),
            const SizedBox(height: 24),

            // DATA & PRIVACY section
            const _SectionHeader(title: 'DATA & PRIVACY'),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.file_upload_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    title: const Text('Export Data'),
                    subtitle: const Text('JSON or CSV format'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _handleExportData(context, ref),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ACCOUNT section
            const _SectionHeader(title: 'ACCOUNT'),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  // User Mode
                  _UserModeSection(user: user),
                  Divider(height: 1, indent: 56, color: theme.dividerColor),
                  if (user != null &&
                      user.providerData.any(
                        (info) => info.providerId == 'password',
                      ))
                    Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.lock_outline),
                          title: const Text('Change Password'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () =>
                              _showChangePasswordFlow(context, ref, user),
                        ),
                        Divider(
                          height: 1,
                          indent: 56,
                          color: theme.dividerColor,
                        ),
                      ],
                    ),
                  if (user != null)
                    Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.link),
                          title: const Text('Link Account'),
                          subtitle: const Text('Add another sign-in method'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _showLinkProviderDialog(context, ref),
                        ),
                        Divider(
                          height: 1,
                          indent: 56,
                          color: theme.dividerColor,
                        ),
                      ],
                    ),
                  ListTile(
                    leading: Icon(
                      Icons.logout,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(
                      'Sign Out',
                      style: TextStyle(color: theme.colorScheme.primary),
                    ),
                    onTap: () => _showSignOutConfirmation(context, ref),
                  ),
                  Divider(height: 1, indent: 56, color: theme.dividerColor),
                  ListTile(
                    leading: Icon(
                      Icons.delete_forever,
                      color: theme.colorScheme.error,
                    ),
                    title: Text(
                      'Delete Account',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    onTap: () => _showDeleteAccountFlow(context, ref, user),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // App Version
            Center(
              child: Text(
                'Torah Tracker v$_appVersion',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                'Handcrafted with care',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

/// Displays sync status and account creation CTA for local-only users.
///
/// DNI-188: Optional Account Creation in Settings.
class _BackupSyncSection extends ConsumerWidget {
  const _BackupSyncSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final syncStatus = ref.watch(syncStatusProvider);
    final authState = ref.watch(authStateProvider);

    return Card(
      child: Column(
        children: [
          switch (syncStatus) {
            SyncStatusLocalOnly() => _buildLocalOnlyTile(
                context,
                theme,
                isLocalAuth: authState is LocalAuthState,
              ),
            SyncStatusSynced(:final lastSyncedAt) =>
              _buildSyncedTile(theme, lastSyncedAt),
            SyncStatusSyncing() => _buildStatusTile(
                theme,
                icon: Icons.sync,
                label: 'Syncing...',
                color: theme.colorScheme.primary,
              ),
            SyncStatusPending(:final pendingChanges) => _buildStatusTile(
                theme,
                icon: Icons.schedule,
                label: '$pendingChanges changes pending',
                color: Colors.orange,
              ),
            SyncStatusOffline(:final pendingChanges) => _buildStatusTile(
                theme,
                icon: Icons.cloud_off,
                label: pendingChanges > 0
                    ? '$pendingChanges changes queued'
                    : 'Offline',
                color: Colors.grey,
              ),
            SyncStatusError(:final message) => _buildStatusTile(
                theme,
                icon: Icons.warning_amber,
                label: 'Sync error: $message',
                color: Colors.red,
              ),
          },
        ],
      ),
    );
  }

  Widget _buildLocalOnlyTile(
    BuildContext context,
    ThemeData theme, {
    required bool isLocalAuth,
  }) {
    return ListTile(
      leading: Icon(Icons.smartphone, color: theme.colorScheme.onSurfaceVariant),
      title: const Text('Local only'),
      subtitle: const Text('Create an account to enable cloud backup'),
      trailing: isLocalAuth
          ? FilledButton.tonal(
              onPressed: () =>
                  context.pushRoute(const AccountCreationRoute()),
              child: const Text('Create Account'),
            )
          : null,
    );
  }

  Widget _buildSyncedTile(ThemeData theme, DateTime lastSyncedAt) {
    final timeAgo = _formatTimeAgo(lastSyncedAt);
    return ListTile(
      leading: const Icon(Icons.cloud_done, color: Colors.green),
      title: const Text('Sync enabled'),
      subtitle: Text('Last synced $timeAgo'),
      trailing: const Icon(Icons.chevron_right),
    );
  }

  Widget _buildStatusTile(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

/// Section header with uppercase label matching the mockup design.
class _HebrewDateTile extends ConsumerWidget {
  const _HebrewDateTile({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useHebrew = ref.watch(useHebrewDateProvider);
    return ListTile(
      leading: Icon(
        Icons.calendar_month_outlined,
        color: theme.colorScheme.primary,
      ),
      title: const Text('Hebrew Calendar'),
      subtitle: const Text('Use Hebrew dates across the app'),
      trailing: Switch(
        value: useHebrew,
        onChanged: (value) {
          ref.read(useHebrewDateProvider.notifier).setUseHebrewDate(value);
        },
        activeTrackColor: theme.colorScheme.primary,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// Displays user profile info with avatar, name, email, and badge.
class _UserProfileSection extends StatelessWidget {
  const _UserProfileSection({required this.user});

  final User? user;

  Future<void> _showEditNameDialog(BuildContext context, User user) async {
    final controller = TextEditingController(text: user.displayName ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Name'),
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
      await user.updateDisplayName(newName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (user == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Icon(Icons.person_outline, size: 48),
            SizedBox(width: 16),
            Text('Not signed in'),
          ],
        ),
      );
    }

    final displayName =
        user!.displayName ?? user!.email?.split('@').first ?? 'User';
    final initials = displayName.isNotEmpty
        ? displayName
              .split(' ')
              .take(2)
              .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
              .join()
        : '?';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
            child: Text(
              initials,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (user!.email != null)
                  Text(
                    user!.email!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'SELF-LEARNER',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.edit_outlined,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            onPressed: () => _showEditNameDialog(context, user!),
          ),
        ],
      ),
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

Future<void> _handleExportData(BuildContext context, WidgetRef ref) async {
  try {
    final service = ref.read(dataExportImportServiceProvider);
    final jsonString = await service.exportData();

    if (!context.mounted) return;

    // Show share dialog with exported data
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Complete'),
        content: Text(
          'Exported ${jsonString.length} bytes of data.\n\n'
          'Use the share button to save the file.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

/// Shows import preview and confirmation dialog.
/// Called after a JSON file is selected and read.
Future<bool> showImportConfirmation({
  required BuildContext context,
  required WidgetRef ref,
  required String jsonString,
}) async {
  final service = ref.read(dataExportImportServiceProvider);

  try {
    final preview = service.validateAndPreview(jsonString);

    if (!context.mounted) return false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Warning: Importing will overwrite all existing data.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text('Exported: ${preview.exportedAt}'),
            Text('Version: ${preview.appVersion}'),
            const Divider(),
            Text('Completions: ${preview.completionCount}'),
            Text('Goals: ${preview.goalCount}'),
            Text('Stages: ${preview.stageCount}'),
            Text('Rewards: ${preview.rewardCount}'),
            Text('Streaks: ${preview.streakCount}'),
            Text('Point Configs: ${preview.pointConfigCount}'),
            Text('Bookmarks: ${preview.bookmarkCount}'),
            Text('Learning Order: ${preview.learningOrderCount}'),
            Text('Curricula: ${preview.activeCurriculaCount}'),
            Text('Tracks: ${preview.curriculumTrackCount}'),
            Text('Profiles: ${preview.userProfileCount}'),
            const Divider(),
            Text(
              'Total records: ${preview.totalRecords}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Import & Overwrite'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return false;

    await service.importData(jsonString);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data imported successfully.')),
      );
    }
    return true;
  } on FormatException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid file: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    }
    return false;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    return false;
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
    ref.read(authStateProvider.notifier).demoteToLocal();
    if (context.mounted) {
      await context.router.replaceAll([const SignInRoute()]);
    }
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
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        // User cancelled — do nothing.
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Re-authentication failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
    if (context.mounted) {
      await context.router.replaceAll([const WelcomeRoute()]);
    }
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

class _ThemeTile extends ConsumerWidget {
  const _ThemeTile({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    String label;
    IconData icon;
    switch (themeMode) {
      case ThemeMode.dark:
        label = 'Dark';
        icon = Icons.dark_mode_outlined;
      case ThemeMode.light:
        label = 'Light';
        icon = Icons.light_mode_outlined;
      case ThemeMode.system:
        label = 'System';
        icon = Icons.brightness_auto_outlined;
    }

    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: const Text('Theme'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => _showThemePicker(context, ref, themeMode),
    );
  }

  void _showThemePicker(
    BuildContext context,
    WidgetRef ref,
    ThemeMode current,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text(
              'Choose Theme',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final option in [
              (ThemeMode.light, 'Light', Icons.light_mode_outlined),
              (ThemeMode.dark, 'Dark', Icons.dark_mode_outlined),
              (ThemeMode.system, 'System', Icons.brightness_auto_outlined),
            ])
              ListTile(
                leading: Icon(option.$3),
                title: Text(option.$2),
                trailing: current == option.$1
                    ? Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  ref.read(themeModeProvider.notifier).setThemeMode(option.$1);
                  Navigator.pop(context);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _AccentColorTile extends ConsumerWidget {
  const _AccentColorTile({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accentColor = ref.watch(accentColorProvider);

    return ListTile(
      leading: Icon(
        Icons.color_lens_outlined,
        color: theme.colorScheme.primary,
      ),
      title: const Text('Accent Color'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => _showAccentColorPicker(context, ref, accentColor),
    );
  }

  void _showAccentColorPicker(
    BuildContext context,
    WidgetRef ref,
    Color current,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text(
              'Choose Accent Color',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final option in AppTheme.accentColors)
                    GestureDetector(
                      onTap: () {
                        ref
                            .read(accentColorProvider.notifier)
                            .setAccentColor(option.color);
                        Navigator.pop(context);
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: option.color,
                              shape: BoxShape.circle,
                              border: current == option.color
                                  ? Border.all(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      width: 3,
                                    )
                                  : null,
                            ),
                            child: current == option.color
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 24,
                                  )
                                : null,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            option.name,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

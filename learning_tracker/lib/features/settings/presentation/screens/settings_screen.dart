import 'package:auto_route/auto_route.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart'
    show GoogleSignInException, GoogleSignInExceptionCode;
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/providers/firebase_providers.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/core/services/pin_service.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/auth/domain/models/auth_state.dart';
import 'package:learning_tracker/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/auth/presentation/widgets/no_backup_badge.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/account_management_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/hebrew_date_provider.dart';
import 'package:learning_tracker/features/settings/presentation/providers/language_provider.dart';
import 'package:learning_tracker/features/settings/presentation/providers/theme_provider.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/change_password_dialog.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/delete_account_dialog.dart';
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
                    onTap: () => context.pushRoute(TrackManagementHubRoute()),
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
              child: Column(children: [_ThemeTile(theme: theme)]),
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

            // LANGUAGE section
            const _SectionHeader(title: 'LANGUAGE'),
            const SizedBox(height: 8),
            Card(child: Column(children: [_LanguageTile(theme: theme)])),
            const SizedBox(height: 24),

            // ACCOUNT section
            const _SectionHeader(title: 'ACCOUNT'),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
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

            // PARENTAL CONTROLS section — only visible for child-mode accounts.
            _ParentalControlsSection(user: user),

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
              isLocalAuth: authState.isLocalBorn,
            ),
            SyncStatusSynced(:final lastSyncedAt) => _buildSyncedTile(
              theme,
              lastSyncedAt,
            ),
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
      leading: Icon(
        Icons.smartphone,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      title: const Text('Local only'),
      subtitle: const Text('Upgrade to enable cloud backup and sync'),
      trailing: isLocalAuth
          ? FilledButton.tonal(
              onPressed: () => context.pushRoute(const UpgradeToCloudRoute()),
              child: const Text('Upgrade to Cloud'),
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

/// Calendar preference tile with explicit Hebrew / Gregorian choice.
class _HebrewDateTile extends ConsumerWidget {
  const _HebrewDateTile({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useHebrew = ref.watch(useHebrewDateProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_month_outlined,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text('Calendar Preference', style: theme.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Applies to all date pickers across the app',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Gregorian'),
                  icon: Icon(Icons.calendar_today),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Hebrew'),
                  icon: Icon(Icons.calendar_month),
                ),
              ],
              selected: {useHebrew},
              onSelectionChanged: (selected) {
                ref
                    .read(useHebrewDateProvider.notifier)
                    .setUseHebrewDate(selected.first);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EditNameDialog extends StatefulWidget {
  const _EditNameDialog({required this.initialName});

  final String initialName;

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Name'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Display Name',
          border: OutlineInputBorder(),
        ),
        textCapitalization: TextCapitalization.words,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
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
class _UserProfileSection extends ConsumerStatefulWidget {
  const _UserProfileSection({required this.user});

  final User? user;

  @override
  ConsumerState<_UserProfileSection> createState() =>
      _UserProfileSectionState();
}

class _UserProfileSectionState extends ConsumerState<_UserProfileSection> {
  User? _user;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  @override
  void didUpdateWidget(covariant _UserProfileSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user != oldWidget.user) {
      _user = widget.user;
    }
  }

  Future<void> _showEditNameDialog({
    required String initialName,
    required int? profileId,
    User? user,
  }) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => _EditNameDialog(initialName: initialName),
    );

    if (newName == null || newName.isEmpty || !mounted) return;

    if (profileId != null) {
      await ref
          .read(profileRepositoryProvider)
          .updateProfile(id: profileId, displayName: newName);
    } else if (user != null) {
      await user.updateDisplayName(newName);
      await user.reload();
      if (!mounted) return;
      setState(() {
        _user = FirebaseAuth.instance.currentUser;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final user = _user;

    // Local-born fallback: when no Firebase user, render from the
    // auth-state user (populated by LocalAuthService sign-in/sign-up).
    if (user == null) {
      final authState = ref.watch(authStateProvider);
      if (!authState.isSignedIn || !authState.isLocalBorn) {
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
      return _LocalBornProfileRow(
        theme: theme,
        authUser: authState.currentUser!,
      );
    }

    final activeProfileId = ref.watch(activeProfileIdProvider);
    final profilesAsync = ref.watch(profileListStreamProvider);
    final activeProfile = profilesAsync.asData?.value
        .where((p) => p.id == activeProfileId)
        .firstOrNull;

    final displayName =
        activeProfile?.displayName ??
        user.displayName ??
        user.email?.split('@').first ??
        'User';
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
                if (user.email != null)
                  Text(
                    user.email!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.15,
                        ),
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
                    // Epic 20.8: no-backup badge for local-born users.
                    // Tier-gated inside the widget — cloud-born users
                    // don't see it.
                    const NoBackupBadge(),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.edit_outlined,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            onPressed: () => _showEditNameDialog(
              initialName: displayName,
              profileId: activeProfile?.id,
              user: user,
            ),
          ),
        ],
      ),
    );
  }
}

/// Profile row for local-born accounts. Mirrors the layout of the
/// Firebase-user row but reads from [AuthUser] (no Firebase user
/// exists for local-born accounts) and hides the edit-name button
/// since that path goes through Firebase.
class _LocalBornProfileRow extends ConsumerWidget {
  const _LocalBornProfileRow({required this.theme, required this.authUser});

  final ThemeData theme;
  final AuthUser authUser;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeProfileId = ref.watch(activeProfileIdProvider);
    final profilesAsync = ref.watch(profileListStreamProvider);
    final activeProfile = profilesAsync.asData?.value
        .where((p) => p.id == activeProfileId)
        .firstOrNull;

    final displayName =
        activeProfile?.displayName ??
        (authUser.displayName.isNotEmpty
            ? authUser.displayName
            : authUser.email.split('@').first);
    final initials = displayName
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
            child: Text(
              initials.isEmpty ? '?' : initials,
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
                Text(
                  authUser.email,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                const Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [NoBackupBadge()],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Parental controls section — only rendered when the signed-in user is in
/// child mode. Surfaces tiles to enter parent mode and manage the parent PIN.
///
/// The PIN is stored locally via [PinService] (bcrypt hash in secure storage)
/// and never synced to Firestore.
class _ParentalControlsSection extends ConsumerStatefulWidget {
  const _ParentalControlsSection({required this.user});

  final User? user;

  @override
  ConsumerState<_ParentalControlsSection> createState() =>
      _ParentalControlsSectionState();
}

class _ParentalControlsSectionState
    extends ConsumerState<_ParentalControlsSection> {
  UserMode? _mode;
  bool _hasPin = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final profileService = ref.read(userProfileServiceProvider);
    final pinService = ref.read(pinServiceProvider);
    final mode = await profileService.getUserMode(widget.user!.uid);
    final hasPin = await pinService.hasParentPin();
    if (mounted) {
      setState(() {
        _mode = mode;
        _hasPin = hasPin;
        _loading = false;
      });
    }
  }

  Future<void> _removePinConfirmed(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Parent PIN?'),
        content: const Text(
          'Parent mode will become accessible without a PIN until a new one '
          'is set. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Re-verify current PIN before removal to prevent a child from wiping it.
    if (!context.mounted) return;
    final verified = await context.router.push<bool>(const PinEntryRoute());
    if (verified != true || !context.mounted) return;

    await ref.read(pinServiceProvider).clearParentPin();
    if (!mounted) return;
    setState(() => _hasPin = false);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Parent PIN removed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _mode != UserMode.child) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(title: 'PARENTAL CONTROLS'),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  Icons.admin_panel_settings_outlined,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('Parent Mode'),
                subtitle: Text(
                  _hasPin
                      ? 'Customize tracks, rewards, and points'
                      : 'Set a PIN to unlock parent controls',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await context.pushRoute(const ParentModeRoute());
                  if (mounted) await _load();
                },
              ),
              Divider(height: 1, indent: 56, color: theme.dividerColor),
              ListTile(
                leading: Icon(
                  Icons.pin_outlined,
                  color: theme.colorScheme.primary,
                ),
                title: Text(_hasPin ? 'Change Parent PIN' : 'Set Parent PIN'),
                subtitle: const Text('4-digit PIN, stored on this device'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final route = _hasPin
                      ? const PinChangeRoute()
                      : const PinSetupRoute();
                  final result =
                      (await context.pushRoute<bool>(route)) ?? false;
                  if (result && mounted) await _load();
                },
              ),
              if (_hasPin) ...[
                Divider(height: 1, indent: 56, color: theme.dividerColor),
                ListTile(
                  leading: Icon(
                    Icons.lock_open_outlined,
                    color: theme.colorScheme.error,
                  ),
                  title: Text(
                    'Remove Parent PIN',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  subtitle: const Text('Requires current PIN to confirm'),
                  onTap: () => _removePinConfirmed(context),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
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
    ref.read(authStateProvider.notifier).signOut();

    // Epic 21.10: route to account picker when other accounts
    // remain on device, or to welcome when this was the last one.
    if (context.mounted) {
      final registry = ref.read(deviceRegistryProvider);
      final accounts = await registry.getAllAccounts();
      if (!context.mounted) return;
      if (accounts.isNotEmpty) {
        await context.router.replaceAll([const AccountPickerRoute()]);
      } else {
        await context.router.replaceAll([const WelcomeRoute()]);
      }
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

class _LanguageTile extends ConsumerWidget {
  const _LanguageTile({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(languageProvider);
    final label = supportedLanguages[current] ?? current;

    return ListTile(
      leading: Icon(Icons.language, color: theme.colorScheme.primary),
      title: const Text('Language'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => _showLanguagePicker(context, ref, current),
    );
  }

  void _showLanguagePicker(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  'Choose Language',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'Preferred language for content',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              for (final entry in supportedLanguages.entries)
                ListTile(
                  title: Text(entry.value),
                  trailing: current == entry.key
                      ? Icon(Icons.check, color: theme.colorScheme.primary)
                      : null,
                  onTap: () {
                    ref
                        .read(languageProvider.notifier)
                        .setLanguage(entry.key);
                    Navigator.pop(context);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
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

import 'package:auto_route/auto_route.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/navigation/router_provider.dart';
import 'package:learning_tracker/core/providers/firebase_providers.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/core/services/pin_service.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/auth/domain/models/auth_state.dart';
import 'package:learning_tracker/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/account_management_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/hebrew_date_provider.dart';
import 'package:learning_tracker/features/settings/presentation/providers/language_provider.dart';
import 'package:learning_tracker/features/settings/presentation/screens/lifetime_marking_screen.dart';
import 'package:learning_tracker/features/settings/presentation/utils/account_actions.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/change_password_dialog.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/reauthenticate_dialog.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';

// TODO(DNI-105): Replace with dynamic version from package_info_plus
// once the dependency is added to pubspec.yaml.
const String _appVersion = '1.2.4';

@RoutePage()
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(firebaseAuthProvider).currentUser;
    final theme = Theme.of(context);

    final activeProfileId = ref.watch(activeProfileIdProvider);
    final profilesAsync = ref.watch(profileListStreamProvider);
    final activeProfile = profilesAsync.asData?.value
        .where((p) => p.id == activeProfileId)
        .firstOrNull;
    final isChildProfile = activeProfile?.mode == 'child';
    final isAdultProfile = activeProfile?.mode == 'adult';

    return Scaffold(
      body: SafeArea(
        top: true,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.pushRoute(const ProfilePickerRoute()),
              child: _UserProfileSection(
                user: user,
                activeProfile: activeProfile,
              ),
            ),
            const SizedBox(height: 24),
            const _SectionHeader(title: 'TRACKS'),
            const SizedBox(height: 10),
            _SurfaceCard(
              child: _SettingsTile(
                icon: Icons.route_rounded,
                iconColor: AppTheme.brandBlueBright,
                iconBackground: AppTheme.brandBlueSoft,
                title: 'Manage tracks',
                subtitle: 'Create and edit your learning tracks',
                onTap: () => context.pushRoute(TrackManagementHubRoute()),
              ),
            ),
            const SizedBox(height: 12),
            const _SectionHeader(title: 'LEARNING'),
            const SizedBox(height: 10),
            _SurfaceCard(
              child: Column(
                children: [
                  _HebrewDateTile(theme: theme),
                  _tileDivider(theme),
                  _SettingsTile(
                    icon: Icons.menu_book_rounded,
                    iconColor: AppTheme.brandGoldDeep,
                    iconBackground: AppTheme.brandGoldSoft,
                    title: 'Add what you\'ve learned',
                    subtitle: 'Log custom Mitzvot or Torah studies',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LifetimeMarkingScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SurfaceCard(
              child: _SettingsTile(
                icon: Icons.notifications_active_outlined,
                iconColor: AppTheme.brandCoralDeep,
                iconBackground: theme.colorScheme.errorContainer,
                title: 'Notification Settings',
                subtitle: 'Push, email, and study sound alerts',
                onTap: () => context.pushRoute(const NotificationsRoute()),
              ),
            ),
            const SizedBox(height: 12),
            const _SurfaceCard(child: _LanguageTile()),
            const SizedBox(height: 16),
            const _BackupSyncSection(),
            const SizedBox(height: 24),
            _ParentalControlsSection(
              user: user,
              isChildProfile: isChildProfile,
            ),
            const _SectionHeader(title: 'ACCOUNT'),
            const SizedBox(height: 10),
            if (user != null &&
                user.providerData.any((info) => info.providerId == 'password'))
              Column(
                children: [
                  _SurfaceCard(
                    child: _SettingsTile(
                      icon: Icons.vpn_key_outlined,
                      iconColor: AppTheme.brandInkMuted,
                      iconBackground: theme.colorScheme.secondaryContainer,
                      title: 'Change Password',
                      onTap: () => _showChangePasswordFlow(context, ref, user),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            _SurfaceCard(
              child: _SettingsTile(
                icon: Icons.logout_rounded,
                iconColor: theme.colorScheme.error,
                iconBackground: theme.colorScheme.errorContainer,
                title: 'Sign Out',
                titleColor: theme.colorScheme.error,
                trailing: const SizedBox.shrink(),
                onTap: () => _showSignOutConfirmation(context, ref),
              ),
            ),
            if (isAdultProfile && user != null) ...[
              const SizedBox(height: 12),
              _SurfaceCard(
                child: _SettingsTile(
                  icon: Icons.delete_forever_rounded,
                  iconColor: theme.colorScheme.error,
                  iconBackground: theme.colorScheme.errorContainer,
                  title: 'Delete Account',
                  subtitle: 'Permanently remove this account and cloud data',
                  titleColor: theme.colorScheme.error,
                  trailing: const SizedBox.shrink(),
                  onTap: () => showDeleteAccountFlow(context, ref, user),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Center(
              child: Text(
                'v$_appVersion',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Center(
              child: Text(
                'Handcrafted for your Torah journey',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.change_history_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.forum_outlined,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.star_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
              ],
            ),
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
    return switch (syncStatus) {
      SyncStatusLocalOnly() => _buildLocalOnlyCard(
        context,
        theme,
        isLocalAuth: authState.isLocalBorn,
      ),
      SyncStatusSynced(:final lastSyncedAt) => _buildCloudStatusCard(
        context,
        theme,
        icon: Icons.cloud_done_rounded,
        subtitle: 'Last synced ${_formatTimeAgo(lastSyncedAt)}',
      ),
      SyncStatusSyncing() => _buildCloudStatusCard(
        context,
        theme,
        icon: Icons.sync_rounded,
        subtitle: 'Syncing...',
      ),
      SyncStatusPending(:final pendingChanges) => _buildCloudStatusCard(
        context,
        theme,
        icon: Icons.schedule_rounded,
        subtitle: '$pendingChanges changes pending',
      ),
      SyncStatusOffline(:final pendingChanges) => _buildCloudStatusCard(
        context,
        theme,
        icon: Icons.cloud_off_rounded,
        subtitle: pendingChanges > 0
            ? '$pendingChanges changes queued'
            : 'Offline',
      ),
      SyncStatusError(:final message) => _buildCloudStatusCard(
        context,
        theme,
        icon: Icons.warning_amber_rounded,
        subtitle: 'Sync error: $message',
      ),
    };
  }

  Widget _buildLocalOnlyCard(
    BuildContext context,
    ThemeData theme, {
    required bool isLocalAuth,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0B3FB4),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x30053698),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0x3A8EA4ED),
                  child: Icon(
                    Icons.cloud_upload_outlined,
                    size: 17,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'Backup & Sync',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 30,
                    height: 1.05,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Your learning progress is currently\nLOCAL ONLY. Upgrade to sync\nacross all devices.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.88),
                height: 1.35,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            if (isLocalAuth)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF3D4A5),
                    foregroundColor: const Color(0xFF2C2A26),
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    textStyle: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: const Color(0xFF2C2A26),
                    ),
                  ),
                  onPressed: () =>
                      context.pushRoute(const UpgradeToCloudRoute()),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: Color(0xFF322A23),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.arrow_upward_rounded,
                          color: Color(0xFFF3D4A5),
                          size: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Upgrade to Cloud'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCloudStatusCard(
    BuildContext context,
    ThemeData theme, {
    required IconData icon,
    required String subtitle,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0B3FB4),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x30053698),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0x3A8EA4ED),
              child: Icon(icon, size: 17, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Backup & Sync',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.88),
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => context.pushRoute(const DeviceRestoreRoute()),
              icon: const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
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
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      minLeadingWidth: 0,
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppTheme.brandBlueSoft,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.calendar_month_rounded,
          color: theme.colorScheme.primary,
          size: 16,
        ),
      ),
      title: Text(
        'Calendar Preference',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: const Color(0xFF1D2432),
        ),
      ),
      subtitle: Text(
        'Switch between Gregorian/Hebrew',
        style: theme.textTheme.bodySmall?.copyWith(
          color: const Color(0xFF929BAA),
          fontSize: 11.5,
        ),
      ),
      trailing: Transform.scale(
        scale: 0.9,
        child: Switch(
          value: useHebrew,
          activeThumbColor: Colors.white,
          activeTrackColor: AppTheme.brandBlueBright,
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: const Color(0xFFD7DEEA),
          onChanged: (value) =>
              ref.read(useHebrewDateProvider.notifier).setUseHebrewDate(value),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: theme.textTheme.labelMedium?.copyWith(
          color: const Color(0xFF8E97A6),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE9ECF2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x121D2939),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.titleColor,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      minLeadingWidth: 0,
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: iconBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: iconColor, size: 16.5),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: titleColor,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF929BAA),
                fontSize: 11.5,
              ),
            ),
      trailing:
          trailing ??
          Icon(
            Icons.chevron_right_rounded,
            size: 19,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
          ),
      onTap: onTap,
    );
  }
}

Widget _tileDivider(ThemeData theme) =>
    Divider(height: 1, indent: 62, endIndent: 14, color: theme.dividerColor);

/// Displays user profile info with avatar, name, email, and badge.
class _UserProfileSection extends ConsumerStatefulWidget {
  const _UserProfileSection({required this.user, required this.activeProfile});

  final User? user;
  final ProfileModel? activeProfile;

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
    final activeProfile =
        widget.activeProfile ??
        profilesAsync.asData?.value
            .where((p) => p.id == activeProfileId)
            .firstOrNull;

    final displayName =
        activeProfile?.displayName ??
        user.displayName ??
        user.email?.split('@').first ??
        'User';
    final profileInitial = _profileInitial(displayName);

    return _SurfaceCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFCFD8EA),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Container(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    alignment: Alignment.center,
                    child: Text(
                      profileInitial,
                      maxLines: 1,
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -2,
                  left: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'PRO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 7.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        displayName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 22,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'SELF-LEARNER',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (user.email != null)
                    Text(
                      user.email!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF8E97A6),
                        fontSize: 13,
                      ),
                    ),
                  const SizedBox(height: 4),
                  const _NoBackupInlineText(),
                ],
              ),
            ),
          ],
        ),
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
    final profileInitial = _profileInitial(displayName);

    return _SurfaceCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    profileInitial,
                    maxLines: 1,
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
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
                  const _NoBackupInlineText(),
                ],
              ),
            ),
          ],
        ),
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
  const _ParentalControlsSection({
    required this.user,
    required this.isChildProfile,
  });

  final User? user;
  final bool isChildProfile;

  @override
  ConsumerState<_ParentalControlsSection> createState() =>
      _ParentalControlsSectionState();
}

class _ParentalControlsSectionState
    extends ConsumerState<_ParentalControlsSection> {
  bool _hasPin = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pinService = ref.read(pinServiceProvider);
    final profileId = ref.read(selectedProfileIdProvider);
    final hasPin = profileId == null
        ? false
        : await pinService.hasProfilePin(profileId);
    if (mounted) {
      setState(() {
        _hasPin = hasPin;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || !widget.isChildProfile) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(title: 'PARENTAL CONTROLS'),
        const SizedBox(height: 10),
        _SurfaceCard(
          child: _SettingsTile(
            icon: Icons.admin_panel_settings_outlined,
            iconColor: AppTheme.brandCoralDeep,
            iconBackground: const Color(0xFFF8E3E7),
            title: 'Parent Mode',
            subtitle: 'Switch to admin (PIN-guarded)',
            trailing: Icon(
              _hasPin ? Icons.lock : Icons.lock_open,
              color: theme.colorScheme.onSurfaceVariant,
              size: 18,
            ),
            onTap: () async {
              ref.read(routerProvider).parentPinGuard.lock();
              await context.pushRoute(const ParentSettingsRoute());
              if (mounted) await _load();
            },
          ),
        ),
        const SizedBox(height: 12),
        _SurfaceCard(
          child: _SettingsTile(
            icon: Icons.pin_outlined,
            iconColor: AppTheme.brandInkMuted,
            iconBackground: AppTheme.brandCreamSoft,
            title: 'Parent PIN',
            subtitle: 'Change your security PIN',
            onTap: () async {
              final route = _hasPin
                  ? const PinChangeRoute()
                  : const PinSetupRoute();
              final result = (await context.pushRoute<bool>(route)) ?? false;
              if (result && mounted) await _load();
            },
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
    barrierColor: Colors.black.withValues(alpha: 0.46),
    builder: (context) {
      final theme = Theme.of(context);
      return Dialog(
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
          decoration: BoxDecoration(
            color: AppTheme.brandCreamCard,
            borderRadius: BorderRadius.circular(34),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDE7EA),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      color: Color(0xFFB43A4A),
                      size: 40,
                    ),
                  ),
                  Positioned(
                    top: -1,
                    right: -2,
                    child: Container(
                      width: 23,
                      height: 23,
                      decoration: BoxDecoration(
                        color: AppTheme.brandBlue,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.brandCreamCard,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.question_mark_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Sign Out',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: AppTheme.brandBlueDeep,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Are you sure you want to sign out?\n'
                'Your data will be preserved for when\n'
                'you sign back in.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppTheme.brandInkMuted,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.brandBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    elevation: 2,
                  ),
                  child: const Text('Sign Out'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.brandInkMuted,
                    backgroundColor: const Color(0xFFF0F1F5),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      );
    },
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
        await context.router.replaceAll([const SignInRoute()]);
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to sign out. Please try again.'),
          backgroundColor: AppTheme.brandCoralDeep,
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
  const _LanguageTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(languageProvider);
    final label = supportedLanguages[current] ?? current;

    return _SettingsTile(
      icon: Icons.language_rounded,
      iconColor: AppTheme.brandInkMuted,
      iconBackground: AppTheme.brandCreamSoft,
      title: 'Language',
      subtitle: label,
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
                    ref.read(languageProvider.notifier).setLanguage(entry.key);
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

class _NoBackupInlineText extends StatelessWidget {
  const _NoBackupInlineText();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off, size: 12, color: Color(0xFFCE8A41)),
        const SizedBox(width: 4),
        Text(
          'No Backup',
          style: theme.textTheme.labelSmall?.copyWith(
            color: const Color(0xFFCE8A41),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

String _profileInitial(String fullName) {
  final normalized = fullName.trim();
  if (normalized.isEmpty) return 'U';
  return normalized.substring(0, 1).toUpperCase();
}

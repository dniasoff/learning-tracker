import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/navigation/router_provider.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/talker_provider.dart';
import 'package:learning_tracker/core/sync/providers/outbox_providers.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/preference_list_tile.dart';
import 'package:learning_tracker/core/widgets/preference_segmented_tile.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/text_display_providers.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/parent_pin_keypad_dialog.dart';
import 'package:learning_tracker/features/sacred_time/presentation/widgets/sacred_time_settings_card.dart';
import 'package:learning_tracker/features/settings/presentation/providers/account_management_providers.dart';
import 'package:learning_tracker/features/settings/presentation/screens/lifetime_marking_screen.dart';
import 'package:learning_tracker/features/settings/presentation/utils/account_actions.dart';
import 'package:learning_tracker/features/settings/presentation/utils/send_logs_service.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/backup_sync_section.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/change_password_dialog.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/reauthenticate_dialog.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/user_profile_header_card.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

@RoutePage()
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.watch(authRepositoryProvider).currentUser;
    final authState = ref.watch(authStateProvider);
    final theme = Theme.of(context);

    final activeProfileId = ref.watch(activeProfileIdProvider);
    final profilesAsync = ref.watch(profileListStreamProvider);
    final activeProfile = profilesAsync.asData?.value
        .where((p) => p.id == activeProfileId)
        .firstOrNull;
    final isChildProfile = activeProfile?.profileMode == ProfileMode.child;
    final isAdultProfile = activeProfile?.profileMode == ProfileMode.adult;
    final hasPasswordProvider =
        user != null && user.providers.contains('password');
    final showDeleteAccountTile =
        !isChildProfile &&
        isAdultProfile &&
        (user != null || authState.isLocalBorn);

    return Scaffold(
      body: SafeArea(
        top: true,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          children: [
            if (!isChildProfile) ...[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => context.pushRoute(const ProfilePickerRoute()),
                child: UserProfileHeaderCard(
                  user: user,
                  activeProfile: activeProfile,
                  surface: UserProfileHeaderSurface.settings,
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (!isChildProfile) ...[
              _SectionHeader(title: l10n.sectionTracks),
              const SizedBox(height: 10),
              _SurfaceCard(
                child: Column(
                  children: [
                    PreferenceListTile.withIcon(
                      icon: Icons.route_rounded,
                      iconColor: AppTheme.brandBlueBright,
                      iconBackground: AppTheme.brandBlueSoft,
                      title: l10n.manageTracks,
                      subtitle: l10n.manageTracksDetail,
                      onTap: () => context.pushRoute(TrackManagementHubRoute()),
                    ),
                    _tileDivider(theme),
                    PreferenceListTile.withIcon(
                      icon: Icons.people_alt_rounded,
                      iconColor: AppTheme.brandBlueBright,
                      iconBackground: AppTheme.brandBlueSoft,
                      title: l10n.manageProfiles,
                      subtitle: l10n.manageProfilesSubtitle,
                      onTap: () =>
                          context.pushRoute(const ManageLearnersRoute()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            _SectionHeader(title: l10n.sectionLearning),
            const SizedBox(height: 10),
            _SurfaceCard(
              child: Column(
                children: [
                  const _HebrewDateTile(),
                  if (Localizations.localeOf(context).languageCode != 'he') ...[
                    _tileDivider(theme),
                    const _HebrewTermsTile(),
                  ],
                  _TransliterationVariantTileSection(theme: theme),
                  _tileDivider(theme),
                  _NikudTile(theme: theme),
                  if (!isChildProfile) ...[
                    _tileDivider(theme),
                    PreferenceListTile.withIcon(
                      icon: Icons.menu_book_rounded,
                      iconColor: AppTheme.brandGoldDeep,
                      iconBackground: AppTheme.brandGoldSoft,
                      title: l10n.addWhatYouLearned,
                      subtitle: l10n.addWhatYouLearnedSettingsSubtitle,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const LifetimeMarkingScreen(),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SurfaceCard(
              child: PreferenceListTile.withIcon(
                icon: Icons.notifications_active_outlined,
                iconColor: AppTheme.brandCoralDeep,
                iconBackground: theme.colorScheme.errorContainer,
                title: l10n.notificationSettings,
                subtitle: l10n.notificationSettingsSubtitle,
                onTap: () => context.pushRoute(const NotificationsRoute()),
              ),
            ),
            const SizedBox(height: 12),
            _SurfaceCard(
              child: PreferenceListTile.withIcon(
                icon: Icons.security_rounded,
                iconColor: const Color(0xFF1E7B5A),
                iconBackground: const Color(0xFFDDF3EB),
                title: 'App Permissions',
                subtitle: 'Notifications and location access',
                onTap: () => context.pushRoute(PermissionPromptRoute()),
              ),
            ),
            const SizedBox(height: 16),
            const SacredTimeSettingsCard(),
            if (!isChildProfile) ...[
              const SizedBox(height: 16),
              const BackupSyncSection(),
            ],
            const SizedBox(height: 24),
            _ParentalControlsSection(
              user: user,
              isChildProfile: isChildProfile,
            ),
            if (!isChildProfile || hasPasswordProvider) ...[
              _SectionHeader(title: l10n.sectionAccount),
              const SizedBox(height: 10),
              if (hasPasswordProvider)
                Column(
                  children: [
                    _SurfaceCard(
                      child: PreferenceListTile.withIcon(
                        icon: Icons.vpn_key_outlined,
                        iconColor: AppTheme.brandInkMuted,
                        iconBackground: theme.colorScheme.secondaryContainer,
                        title: l10n.changePassword,
                        onTap: () =>
                            _showChangePasswordFlow(context, ref, user),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              if (!isChildProfile)
                _SurfaceCard(
                  child: PreferenceListTile.withIcon(
                    icon: Icons.logout_rounded,
                    iconColor: theme.colorScheme.error,
                    iconBackground: theme.colorScheme.errorContainer,
                    title: l10n.signOut,
                    titleColor: theme.colorScheme.error,
                    trailing: const SizedBox.shrink(),
                    onTap: () => showSignOutConfirmation(context, ref),
                  ),
                ),
              if (showDeleteAccountTile) ...[
                const SizedBox(height: 12),
                _SurfaceCard(
                  child: PreferenceListTile.withIcon(
                    icon: Icons.delete_forever_rounded,
                    iconColor: theme.colorScheme.error,
                    iconBackground: theme.colorScheme.errorContainer,
                    title: l10n.deleteAccountTitle,
                    subtitle: authState.isLocalBorn
                        ? l10n.deleteLocalAccountSubtitle
                        : l10n.deleteAccountSubtitle,
                    titleColor: theme.colorScheme.error,
                    trailing: const SizedBox.shrink(),
                    onTap: () {
                      if (authState.isLocalBorn) {
                        showDeleteLocalAccountFlow(context, ref);
                      } else if (user != null) {
                        showDeleteAccountFlow(context, ref, user);
                      }
                    },
                  ),
                ),
              ],
            ],
            const SizedBox(height: 24),
            _SurfaceCard(
              child: PreferenceListTile.withIcon(
                icon: Icons.bug_report_outlined,
                iconColor: AppTheme.brandInkMuted,
                iconBackground: const Color(0xFFF0F1F5),
                title: 'Send Diagnostic Logs',
                subtitle: 'Stream last 10 min of activity to Firebase',
                trailing: const SizedBox.shrink(),
                onTap: () => sendLogsToFirebase(
                  context: context,
                  logger: ref.read(appLoggerProvider),
                  gateway: ref.read(firestoreGatewayProvider),
                  auth: ref.read(authRepositoryProvider),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final info = snapshot.data;
                if (info == null || info.version.isEmpty) {
                  return const SizedBox.shrink();
                }
                final buildLabel = info.buildNumber.isNotEmpty
                    ? 'v${info.version} (${info.buildNumber})'
                    : 'v${info.version}';
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Text(
                        buildLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                );
              },
            ),
            Center(
              child: Text(
                'Torah Study Tracker',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
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

// ─── Preference tiles ────────────────────────────────────────────────────────

/// Calendar preference toggle (Hebrew vs English date display).
///
/// Default: `useHebrewDate: false` (English calendar).
/// Surfaced via [PreferenceSegmentedTile] with English/Hebrew pills.
class _HebrewDateTile extends ConsumerWidget {
  const _HebrewDateTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final useHebrew = ref.watch(useHebrewDateProvider);
    return PreferenceSegmentedTile<bool>(
      icon: Icons.calendar_month_rounded,
      iconColor: AppTheme.brandBlueBright,
      iconBackground: AppTheme.brandBlueSoft,
      title: l10n.calendarPreference,
      subtitle: l10n.calendarPreferenceSubtitle,
      options: [
        (value: false, label: l10n.calendarGregorian),
        (value: true, label: l10n.calendarHebrew),
      ],
      value: useHebrew,
      onChanged: (v) => ref.read(useHebrewDateProvider.notifier).set(v),
    );
  }
}

/// Hebrew-terms toggle — renders Jewish learning terminology in Hebrew script
/// vs English transliteration.
///
/// Default: `hebrewTerms: true` (Hebrew script). See spec §9.
/// Surfaced via [PreferenceListTile] with a [Switch] trailing widget.
class _HebrewTermsTile extends ConsumerWidget {
  const _HebrewTermsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final useHebrew = ref.watch(useHebrewTermsProvider);
    return PreferenceListTile(
      title: l10n.hebrewTermsPreference,
      subtitle: l10n.hebrewTermsPreferenceSubtitle,
      leading: const PreferenceIconPill(
        icon: Icons.translate_rounded,
        iconColor: AppTheme.brandBlueBright,
        iconBackground: AppTheme.brandBlueSoft,
      ),
      trailing: Switch(
        value: useHebrew,
        onChanged: (v) => ref.read(useHebrewTermsProvider.notifier).set(v),
      ),
    );
  }
}

/// Conditionally renders the transliteration-variant tile (Sephardi vs
/// Ashkenazi) only when the Hebrew Terms toggle is **off**.
class _TransliterationVariantTileSection extends ConsumerWidget {
  const _TransliterationVariantTileSection({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useHebrew = ref.watch(useHebrewTermsProvider);
    if (useHebrew) return const SizedBox.shrink();
    return Column(
      children: [
        _tileDivider(theme),
        _TransliterationVariantTile(theme: theme),
      ],
    );
  }
}

/// Picks the Ashkenazi or Sephardi transliteration dialect for English-mode
/// named values (Bereishis vs Bereshit).
class _TransliterationVariantTile extends ConsumerWidget {
  const _TransliterationVariantTile({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final variant = ref.watch(currentTransliterationVariantProvider);
    return PreferenceSegmentedTile<TransliterationVariant>(
      icon: Icons.record_voice_over_rounded,
      title: 'Pronunciation',
      subtitle: 'Bereishis (Ashkenazi) or Bereshit (Sephardi)',
      options: const [
        (value: TransliterationVariant.ashkenazi, label: 'Ashkenazi'),
        (value: TransliterationVariant.sephardi, label: 'Sephardi'),
      ],
      value: variant,
      onChanged: (v) =>
          ref.read(currentTransliterationVariantProvider.notifier).set(v),
    );
  }
}

/// Nikud (Hebrew vowel marks) preference — show or hide nikud when learning.
class _NikudTile extends ConsumerWidget {
  const _NikudTile({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showNikud = ref.watch(showNikudProvider);
    return PreferenceSegmentedTile<bool>(
      icon: Icons.text_fields_rounded,
      title: 'Nikud',
      subtitle: 'Show or hide Hebrew vowel marks when learning.',
      options: const [
        (value: false, label: 'Without nikud'),
        (value: true, label: 'With nikud'),
      ],
      value: showNikud,
      onChanged: (v) => ref.read(showNikudProvider.notifier).set(v),
    );
  }
}

// ─── Layout helpers ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4),
      child: Text(
        title,
        style: theme.textTheme.labelMedium?.copyWith(
          color: AppColors.inkMidGrey,
          fontSize: 13,
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
        border: Border.all(color: AppColors.surfaceE9),
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

Widget _tileDivider(ThemeData theme) =>
    Divider(height: 1, indent: 62, endIndent: 14, color: theme.dividerColor);

// ─── Parental controls section ───────────────────────────────────────────────

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

  final AppUser? user;
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
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(title: l10n.sectionParentalControls),
        const SizedBox(height: 10),
        _SurfaceCard(
          child: PreferenceListTile.withIcon(
            icon: Icons.admin_panel_settings_outlined,
            iconColor: AppTheme.brandCoralDeep,
            iconBackground: const Color(0xFFF8E3E7),
            title: l10n.parentMode,
            subtitle: l10n.parentModeSubtitle,
            trailing: Icon(
              _hasPin ? Icons.lock : Icons.lock_open,
              color: theme.colorScheme.onSurfaceVariant,
              size: 18,
            ),
            onTap: () async {
              ref.read(routerProvider).pinGuard.lock();
              await context.pushRoute(const ParentSettingsRoute());
              if (mounted) await _load();
            },
          ),
        ),
        const SizedBox(height: 12),
        _SurfaceCard(
          child: PreferenceListTile.withIcon(
            icon: Icons.pin_outlined,
            iconColor: AppTheme.brandInkMuted,
            iconBackground: AppTheme.brandCreamSoft,
            title: l10n.parentPin,
            subtitle: l10n.parentPinSubtitle,
            onTap: () async {
              final profileId = ref.read(selectedProfileIdProvider);
              final pinService = ref.read(pinServiceProvider);
              if (profileId == null) return;
              final bool ok;
              if (_hasPin) {
                ok = await showParentPinChangeDialog(
                  context,
                  profileId: profileId,
                  pinService: pinService,
                );
              } else {
                ok =
                    (await context.pushRoute<bool>(
                      const PinFlowSetupRoute(),
                    )) ??
                    false;
              }
              if (ok && mounted) await _load();
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ─── Account action helpers ───────────────────────────────────────────────────

Future<void> _showChangePasswordFlow(
  BuildContext context,
  WidgetRef ref,
  AppUser user,
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
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.passwordChangedSuccessfully)));
  }
}

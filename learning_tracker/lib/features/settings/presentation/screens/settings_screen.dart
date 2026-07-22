import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/talker_provider.dart';
import 'package:learning_tracker/core/sync/providers/outbox_providers.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/widgets/preference_list_tile.dart';
import 'package:learning_tracker/core/widgets/preference_segmented_tile.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/text_display_providers.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_pin_session_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/parent_pin_keypad_dialog.dart';
import 'package:learning_tracker/features/sacred_time/presentation/widgets/sacred_time_settings_card.dart';
import 'package:learning_tracker/features/settings/presentation/screens/lifetime_marking_screen.dart';
import 'package:learning_tracker/features/settings/presentation/utils/send_logs_service.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/backup_sync_section.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/user_profile_header_card.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/manage_tutors_providers.dart'
    show incomingTutorGrantsProvider;
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_grant_providers.dart'
    show pendingTutorInvitesProvider;
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

@RoutePage()
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.watch(authRepositoryProvider).currentUser;
    final theme = Theme.of(context);

    final activeProfileId = ref.watch(activeProfileIdProvider);
    final profilesAsync = ref.watch(profileListStreamProvider);
    final activeProfile = profilesAsync.asData?.value
        .where((p) => p.id == activeProfileId)
        .firstOrNull;
    final isChildProfile = activeProfile?.profileMode == ProfileMode.child;
    final activeTutoredSelection = ref.watch(
      activeTutoredProfileSelectionProvider,
    );
    final isTutoredSession = activeTutoredSelection != null;

    // isTutorElevated: tutor in a talmid's context → parent-equivalent access
    // for the child's LEARNING management (not account-admin surfaces).
    final tutorPerms = ref.watch(activeTutorPermissionsProvider);
    final isTutorElevated = isTutoredSession;

    return Scaffold(
      body: SafeArea(
        top: true,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          children: [
            // Profile header is the canonical learner + login-account switcher
            // (avatar, name, account email; tap → account actions sheet). Daniel
            // requires children to be able to switch learner and login account
            // from here, so it is shown for every OWN profile (child, adult).
            //
            // In a TUTORED session it is HIDDEN: the header + its tap-through
            // account-actions sheet are the TUTOR's own device/account surface
            // (switch login, change password, sign out, delete account), which
            // must not leak into the talmid's student-scope context. The
            // persistent role switcher in the app shell remains the path out of
            // the tutored session.
            if (!isTutoredSession)
              UserProfileHeaderCard(
                user: user,
                activeProfile: activeProfile,
                surface: UserProfileHeaderSurface.settings,
                contextRole: UserProfileContextRole.selfLearner,
              ),
            // ── Pending tutor invitations ──────────────────────────────────────
            // Shown automatically when a parent has sent an invite addressed to
            // this account's email — no link sharing required.
            if (!isTutoredSession) const _PendingInvitesSection(),
            const SizedBox(height: 24),
            // ── DEVICE section (D2/WS4.settings) ──────────────────────────────
            // Device-scoped settings: applies to this physical device, shared by
            // every login and profile on it (OS permissions, location access).
            // WS4.login-sect: Login scope is omitted — the only Login-scoped
            // datum (debug toggle) does not yet exist, so no empty heading is shown.
            //
            // Bug 12: in a tutored (talmid) session every item here is tied to
            // the TUTOR's own device/account — App Permissions (OS prompts) and
            // Sacred Time / location ("I am in Israel", Shabbos Mode). The owner
            // ruling is to show ONLY student/profile-scope items and HIDE the
            // tutor's own account/device items, so the entire DEVICE section is
            // omitted when viewing a talmid.
            if (!isTutoredSession) ...[
              _SectionHeader(title: l10n.sectionDevice),
              const SizedBox(height: 10),
              _SurfaceCard(
                child: PreferenceListTile.withIcon(
                  icon: Icons.security_rounded,
                  iconColor: const Color(0xFF1E7B5A),
                  iconBackground: const Color(0xFFDDF3EB),
                  title: l10n.settingsAppPermissions,
                  subtitle: l10n.settingsAppPermissionsSubtitle,
                  onTap: () => context.pushRoute(PermissionPromptRoute()),
                ),
              ),
              const SizedBox(height: 16),
              // DEC-26: Sacred Time / location is DEVICE-scoped, so its card lives
              // under the DEVICE section (it was previously mis-placed under
              // PROFILE).
              //
              // AUD-sacred_time-08: SettingsRoute carries no PIN/child-mode
              // route guard (see app_router.dart), so a child on a shared
              // device could otherwise trigger the card's location actions
              // with no parent authentication. Gate the card's own
              // escalating actions (AN-2 pattern) instead of gating the
              // whole Settings screen, which children legitimately need for
              // their own profile preferences.
              SacredTimeSettingsCard(
                pinGuardRequired:
                    ref
                        .watch(sacredTimeLocationPinGuardRequiredProvider)
                        .asData
                        ?.value ??
                    false,
                activeProfileId: activeProfileId,
              ),
              const SizedBox(height: 24),
            ],
            // ── PROFILE section (D2/WS4.settings) ─────────────────────────────
            // Profile-scoped settings: per-learner preferences, tracks,
            // notifications (reminder schedules), and parental controls.
            _SectionHeader(title: l10n.sectionProfile),
            const SizedBox(height: 10),
            // TUT-06: in a tutored session the tutor has FULL parent-equivalent
            // management over the talmid (manage tracks, points, rewards, goals,
            // bulk/lifetime marking — only LIVE marking is barred). Surface the
            // single entry into the parent-management hub (ParentSettingsScreen),
            // which already renders every management tile gated by the active
            // TutorPermissions. Without this, a tutor session showed only the bare
            // learner shell with no management access at all (TUT-02/TUT-06).
            //
            // Shown whenever the tutor has ANY management permission. canEditStages
            // (track/stage config) is the broadest of the parent-equivalent edit
            // flags; the hub itself re-gates each individual tile.
            if (isTutorElevated &&
                (tutorPerms == null ||
                    tutorPerms.canEditStages ||
                    tutorPerms.canEditPoints ||
                    tutorPerms.canEditRewards ||
                    tutorPerms.canBulkPriorCompletion)) ...[
              _SurfaceCard(
                child: PreferenceListTile.withIcon(
                  icon: Icons.admin_panel_settings_outlined,
                  iconColor: context.colors.brandBlueBright,
                  iconBackground: context.colors.brandBlueSoft,
                  title: l10n.parentSettingsTitle,
                  // Bug 10: a tutor has full parent-equivalent powers — the hub
                  // surfaces tracks, points, rewards and goals (each re-gated by
                  // the tutor's permissions inside ParentSettingsScreen), so the
                  // subtitle must advertise the broader scope, not tracks only.
                  subtitle: l10n.manageChildLearningSubtitle,
                  onTap: () => context.pushRoute(const ParentSettingsRoute()),
                ),
              ),
              const SizedBox(height: 12),
            ],
            // Own adult: Manage Tracks + Manage Profiles.
            // Tutored sessions reach tracks via the parent-management hub tile
            // above, so the standalone Manage Tracks / Manage Profiles card is
            // own-profile (non-tutored) only.
            if (!isTutoredSession && !isChildProfile) ...[
              _SurfaceCard(
                child: Column(
                  children: [
                    PreferenceListTile.withIcon(
                      icon: Icons.route_rounded,
                      iconColor: context.colors.brandBlueBright,
                      iconBackground: context.colors.brandBlueSoft,
                      title: l10n.manageTracks,
                      subtitle: l10n.manageTracksDetail,
                      onTap: () => context.pushRoute(TrackManagementHubRoute()),
                    ),
                    _tileDivider(theme),
                    PreferenceListTile.withIcon(
                      icon: Icons.people_alt_rounded,
                      iconColor: context.colors.brandBlueBright,
                      iconBackground: context.colors.brandBlueSoft,
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
            _SurfaceCard(
              child: Column(
                children: [
                  const _HebrewDateTile(),
                  // R2/i18n: the Hebrew-Terms toggle is a transliteration/terms
                  // preference (Hebrew script vs English transliteration) that
                  // is meaningful in BOTH UI languages — a Hebrew-UI user still
                  // needs the control. It must render regardless of locale; do
                  // not re-gate it on `languageCode != 'he'`.
                  _tileDivider(theme),
                  const _HebrewTermsTile(),
                  _TransliterationVariantTileSection(theme: theme),
                  _tileDivider(theme),
                  _NikudTile(theme: theme),
                  // Hidden for tutors: bulk lifetime marking goes through CF (S4).
                  if (!isChildProfile && !isTutoredSession) ...[
                    _tileDivider(theme),
                    PreferenceListTile.withIcon(
                      icon: Icons.menu_book_rounded,
                      iconColor: context.colors.brandGoldDeep,
                      iconBackground: context.colors.brandGoldSoft,
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
                iconColor: context.colors.brandCoralDeep,
                iconBackground: theme.colorScheme.errorContainer,
                title: l10n.notificationSettings,
                subtitle: l10n.notificationSettingsSubtitle,
                onTap: () => context.pushRoute(const NotificationsRoute()),
              ),
            ),
            // T3.gating: backup/sync controls are write-path in tutored sessions.
            if (!isChildProfile && !isTutoredSession) ...[
              const SizedBox(height: 16),
              const BackupSyncSection(),
            ],
            const SizedBox(height: 24),
            // T3.gating: parental controls and account management are hidden in
            // tutored sessions — the tutor is viewing the child's context only.
            if (!isTutoredSession) ...[
              _ParentalControlsSection(
                user: user,
                isChildProfile: isChildProfile,
              ),
            ],
            // Account management (switch / add login, change password, sign
            // out, delete account) lives ONLY in the profile header sheet at the
            // top of this screen (tap the header card). It is intentionally NOT
            // duplicated here so there is a single home for account actions.
            const SizedBox(height: 24),
            // Bug 12: diagnostic logs are the TUTOR's own device/account logs
            // (uploaded to the tutor's Firestore under their own auth) — an
            // account/device-scope action that must be hidden when viewing a
            // talmid. Shown only in a non-tutored (own) session.
            if (!isTutoredSession)
              _SurfaceCard(
                child: PreferenceListTile.withIcon(
                  icon: Icons.bug_report_outlined,
                  iconColor: context.colors.brandInkMuted,
                  // AUD dark-mode sweep: was a hardcoded Color(0xFFF0F1F5)
                  // pale-grey chip under the already brightness-aware
                  // brandInkMuted icon (which LIGHTENS in dark) — the icon
                  // and its own background stopped matching, measured
                  // 2.28:1 in dark. brandCreamSoft is the paired recessed-
                  // surface token (equals the old literal almost exactly in
                  // light — 0xFFEFF2F7 vs 0xFFF0F1F5 — and darkens with the
                  // icon in dark), 5.97:1 in dark.
                  iconBackground: context.colors.brandCreamSoft,
                  title: l10n.settingsSendDiagnosticLogs,
                  subtitle: l10n.settingsSendDiagnosticLogsSubtitle,
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
      iconColor: context.colors.brandBlueBright,
      iconBackground: context.colors.brandBlueSoft,
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
      leading: PreferenceIconPill(
        icon: Icons.translate_rounded,
        iconColor: context.colors.brandBlueBright,
        iconBackground: context.colors.brandBlueSoft,
      ),
      // ST-3 fix: wrap Switch in Semantics so assistive tech announces
      // "Hebrew Terms, Switch, on/off" instead of an unlabeled toggle.
      trailing: Semantics(
        label: l10n.hebrewTermsPreference,
        child: Switch(
          value: useHebrew,
          onChanged: (v) => ref.read(useHebrewTermsProvider.notifier).set(v),
        ),
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
    final l10n = AppLocalizations.of(context)!;
    final variant = ref.watch(currentTransliterationVariantProvider);
    return PreferenceSegmentedTile<TransliterationVariant>(
      icon: Icons.record_voice_over_rounded,
      title: l10n.settingsPronunciation,
      subtitle: l10n.settingsPronunciationSubtitle,
      options: [
        (
          value: TransliterationVariant.ashkenazi,
          label: l10n.settingsPronunciationAshkenazi,
        ),
        (
          value: TransliterationVariant.sephardi,
          label: l10n.settingsPronunciationSephardi,
        ),
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
    final l10n = AppLocalizations.of(context)!;
    final showNikud = ref.watch(showNikudProvider);
    return PreferenceSegmentedTile<bool>(
      icon: Icons.text_fields_rounded,
      title: l10n.settingsNikud,
      subtitle: l10n.settingsNikudSubtitle,
      options: [
        (value: false, label: l10n.settingsNikudWithout),
        (value: true, label: l10n.settingsNikudWith),
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
          color: context.colors.inkMidGrey,
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.surfaceE9),
        boxShadow: [
          // AUD dark-mode sweep: was a hardcoded Color(0x121D2939) — a
          // translucent NAVY-tinted shadow that keeps a light-mode tint in
          // dark mode instead of the app's own dark-surface shadow.
          // settingsProfileCardShadow is the existing Settings card-shadow
          // token (already used by UserProfileHeaderCard for the identical
          // role) — pixel-identical to the old literal in light, plain
          // black at higher alpha in dark.
          BoxShadow(
            color: context.colors.settingsProfileCardShadow,
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
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

    // When the parent is already elevated for this profile, the tile is no
    // longer an "enter parent mode" gate — it's the entry to the admin
    // controls. Reflect that: drop the lock + "switch to admin" framing and
    // show it as an open door into tracks/rewards/tutors.
    final activeProfileId = ref.watch(activeProfileIdProvider);
    final parentAuthedProfileId = ref.watch(
      parentPinAuthenticatedProfileIdProvider,
    );
    final inParentMode =
        parentAuthedProfileId != null &&
        parentAuthedProfileId == activeProfileId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(title: l10n.sectionParentalControls),
        const SizedBox(height: 10),
        _SurfaceCard(
          child: PreferenceListTile.withIcon(
            icon: Icons.admin_panel_settings_outlined,
            iconColor: context.colors.brandCoralDeep,
            // AUD dark-mode sweep: was a hardcoded Color(0xFFF8E3E7) pale-
            // pink chip under brandCoralDeep, which LIGHTENS in dark mode
            // (it is an ink role) — icon and background stopped matching,
            // measured 1.42:1 in dark. brandCoralSoft is brandCoralDeep's
            // own paired tint container (used together everywhere else in
            // the app), 9.32:1 in dark; light stays 5.02:1 (was 4.79:1).
            iconBackground: context.colors.brandCoralSoft,
            title: l10n.parentMode,
            subtitle: inParentMode
                ? l10n.parentModeActiveSubtitle
                : l10n.parentModeSubtitle,
            trailing: Icon(
              inParentMode
                  ? Icons.chevron_right_rounded
                  : (_hasPin ? Icons.lock : Icons.lock_open),
              color: theme.colorScheme.onSurfaceVariant,
              size: 18,
            ),
            onTap: () async {
              // Opens the admin controls. The PIN guard on ParentSettingsRoute
              // prompts for the PIN only if not already elevated this session
              // (no forced re-lock — once in parent mode you stay in it until
              // you explicitly Exit parent mode).
              await context.pushRoute(const ParentSettingsRoute());
              if (mounted) await _load();
            },
          ),
        ),
        // PIN management is only exposed when the parent is already
        // authenticated for this profile (inParentMode). Without this gate
        // a child could see the tile in their own Settings and attempt to
        // brute-force the parent PIN (R5-2).
        if (inParentMode) ...[
          const SizedBox(height: 12),
          _SurfaceCard(
            child: PreferenceListTile.withIcon(
              icon: Icons.pin_outlined,
              iconColor: context.colors.brandInkMuted,
              iconBackground: context.colors.brandCreamSoft,
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
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Tutor access section ───────────────────────────────────────────────────────

/// Shows all tutor grants (active + pending) in Settings so the user can see
/// who they are tutoring and accept/view pending invitations without needing
/// a link.  Pending invites are discovered automatically from Firestore by
/// the signed-in user's email address.
class _PendingInvitesSection extends ConsumerWidget {
  const _PendingInvitesSection();

  /// AUD-tutoring-08 (PF-2): this section is embedded (non-scrolling) inside
  /// the outer Settings ListView, so it cannot become a lazy builder itself.
  /// Cap the inline preview instead of rendering a dedicated tutor's entire
  /// (unbounded, no-archiving-path) roster on every Settings open; a "View
  /// all" row routes to the dedicated, independently-scrolling ManageGrants
  /// hub for the rest.
  static const _maxInlinePreview = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAsync = ref.watch(incomingTutorGrantsProvider);
    final pendingAsync = ref.watch(pendingTutorInvitesProvider);

    final activeGrants =
        activeAsync.asData?.value
            .where((g) => g.grantState is ActiveGrant)
            .toList() ??
        const [];
    final pendingGrants =
        pendingAsync.asData?.value
            .where((g) => g.grantState is PendingGrant)
            .toList() ??
        const [];

    if (activeGrants.isEmpty && pendingGrants.isEmpty) {
      return const SizedBox.shrink();
    }

    // Pending invites are the more actionable item (need a tap to accept),
    // so they get preview priority; active grants fill any remaining budget.
    final visiblePending = pendingGrants.take(_maxInlinePreview).toList();
    final activeBudget = _maxInlinePreview - visiblePending.length;
    final visibleActive = activeBudget > 0
        ? activeGrants.take(activeBudget).toList()
        : const <TutorGrant>[];
    final hiddenCount =
        (pendingGrants.length - visiblePending.length) +
        (activeGrants.length - visibleActive.length);

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            l10n.profilePickerTalmidProfiles,
            style: theme.textTheme.labelSmall?.copyWith(
              color: context.colors.brandInkMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ),
        for (final grant in visiblePending) ...[
          _TutorGrantTile(grant: grant, isPending: true),
          const SizedBox(height: 8),
        ],
        for (final grant in visibleActive) ...[
          _TutorGrantTile(grant: grant, isPending: false),
          const SizedBox(height: 8),
        ],
        if (hiddenCount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              onPressed: () => context.pushRoute(const ManageGrantsRoute()),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.colors.brandBlue,
                side: BorderSide(
                  color: context.colors.brandBlue.withValues(alpha: 0.5),
                ),
                minimumSize: const Size(double.infinity, 40),
              ),
              child: Text(l10n.settingsTutoringViewAll(hiddenCount)),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _TutorGrantTile extends StatelessWidget {
  const _TutorGrantTile({required this.grant, required this.isPending});

  final TutorGrant grant;
  final bool isPending;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final childLabel = grant.childDisplayLabel;

    // AUD dark-mode sweep: bg/border/icon/text here were four hardcoded,
    // brightness-fixed literals (pale-yellow/pale-green pastel card), so the
    // card stayed exactly as bright in dark mode as in light — inconsistent
    // with every sibling status-badge in the app, which already uses
    // statusActiveBadge/statusPendingBadge for this exact "tutor grant"
    // concept (manage_grants_screen.dart, manage_tutors_screen.dart).
    // statusSuccessSoftBg/statusSuccessSoftText and
    // statusWarningSoft/statusWarningSoftText are the app's existing
    // solid-card pairs for this same active/pending shape (accept/decline
    // confirmation cards) — reusing them here darkens the card in dark mode
    // while very slightly IMPROVING the light-mode pair (old pending
    // icon/text-on-bg measured 2.49:1 in light, a pre-existing amber-on-
    // near-white contrast gap; new pairing clears 4.55–4.68:1 in both
    // modes, 7.67–8.64:1 in dark).
    final cardBg = isPending
        ? context.colors.statusWarningSoft
        : context.colors.statusSuccessSoftBg;
    final accentColor = isPending
        ? context.colors.statusWarningSoftText
        : context.colors.statusSuccessSoftText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.school_rounded, color: accentColor, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  childLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  isPending
                      ? l10n.statusPendingTapToAccept
                      : l10n.tutoredChildrenStatusTutoring,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (isPending)
            FilledButton(
              style: FilledButton.styleFrom(
                // statusPendingBadge (not the old hardcoded 0xFFF57F17):
                // same hue family, but brightness-aware so it stays
                // consistent with the icon/text above; the button's
                // foreground already comes from the theme's own
                // contrast-computed default (unaffected by this change).
                backgroundColor: context.colors.statusPendingBadge,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
              ),
              onPressed: () =>
                  context.pushRoute(AcceptInviteRoute(token: grant.grantId)),
              child: Text(l10n.acceptInviteAccept),
            ),
        ],
      ),
    );
  }
}

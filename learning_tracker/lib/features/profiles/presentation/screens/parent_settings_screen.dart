import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/gamification/data/repositories/firestore_points_balance_reader_adapter.dart';
import 'package:learning_tracker/features/gamification/data/repositories/firestore_points_ledger_write_adapter.dart';
import 'package:learning_tracker/features/gamification/data/repositories/reward_redemption_repository_impl.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/points_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/settings/presentation/utils/account_actions.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/backup_sync_section.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/user_profile_header_card.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

final _rewardRedemptionRepositoryProvider =
    Provider<FirestoreRewardRedemptionRepositoryAdapter>(
      (ref) => FirestoreRewardRedemptionRepositoryAdapter(ref: ref),
    );

/// Reactive count of pending reward-redemption requests for the active profile.
///
/// Backed by [FirestoreRewardRedemptionRepositoryAdapter.watchPendingRedemptions]
/// so the "Pending Prizes" row subtitle updates live as requests arrive or are
/// fulfilled/declined — rather than reflecting only the count at screen-build
/// time (#33). Same underlying stream `parent_pending_redemptions_screen.dart`'s
/// `pendingRedemptionsProvider` uses.
final pendingRedemptionsCountProvider = StreamProvider.autoDispose<int>((ref) {
  final repo = ref.watch(_rewardRedemptionRepositoryProvider);
  return repo.watchPendingRedemptions().map((list) => list.length);
});

final _pointsLedgerWriteAdapterProvider =
    Provider<FirestorePointsLedgerWriteAdapter>(
      (ref) => FirestorePointsLedgerWriteAdapter(ref: ref),
    );

/// Debitable points balance for the active (child / talmid) profile.
///
/// **Not a live stream** — `points_ledger` has no Firestore watch
/// equivalent (SR-4 caps queries at 500, see [globalPointsProvider]'s doc
/// comment for the full reasoning). Re-reads on
/// [pendingRedemptionsCountProvider]'s changes (a redemption fulfil/decline
/// moves the balance) and is explicitly `ref.invalidate`d after a parent
/// points adjustment below.
final activeProfilePointsBalanceProvider = FutureProvider.autoDispose<int>((
  ref,
) {
  ref.watch(pendingRedemptionsCountProvider);
  final reader = FirestorePointsBalanceReaderAdapter(ref: ref);
  return reader.getBalance();
});

/// Configuration hub shown to a parent when their child profile is active.
///
/// Includes the same profile header as Settings (avatar, name, account email;
/// tap opens profile picker). Surfaces parent-only controls: managing tracks,
/// point configuration, backup/sync, and lifetime learning entries.
@RoutePage()
class ParentSettingsScreen extends ConsumerWidget {
  const ParentSettingsScreen({super.key});

  static Color _pageBg(BuildContext context) => context.colors.surfaceF3;
  static const Color _managePurple = Color(0xFF7B5FD9);
  static Color _iconCircleMuted(BuildContext context) =>
      context.colors.surfaceE9;
  static Color _iconMutedFg(BuildContext context) =>
      context.colors.brandInkMuted;
  static const Color _chevronMuted = Color(0xFFC2C9D3);
  static Color _dangerIconBg(BuildContext context) =>
      context.colors.statusErrorSoft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final user = ref.watch(authRepositoryProvider).currentUser;
    final activeProfileId = ref.watch(activeProfileIdProvider);
    final profilesAsync = ref.watch(profileListStreamProvider);
    final activeProfile = profilesAsync.asData?.value
        .where((p) => p.profileId == activeProfileId)
        .firstOrNull;
    final showDeleteAccountTile = user != null;

    // WS3.3d: when a tutor has entered a talmid's context, gate edit tiles
    // behind the corresponding TutorPermissions field.
    // null  → owner mode: all tiles visible.
    // non-null → tutored mode: only tiles with true permissions shown.
    final tutorPerms = ref.watch(activeTutorPermissionsProvider);
    final isTutoredContext = tutorPerms != null;

    // #33: reactive pending-redemption count → live subtitle on the
    // "Pending Prizes" row (0 → empty copy, N → "N prize requests waiting").
    final pendingAsync = ref.watch(pendingRedemptionsCountProvider);
    final pendingSubtitle = pendingAsync.when(
      loading: () => const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (error, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            color: context.colors.brandWarning,
            size: 18,
          ),
          const SizedBox(width: 6),
          Flexible(child: Text(l10n.errorGeneric(error.toString()))),
          IconButton(
            onPressed: () => ref.invalidate(pendingRedemptionsCountProvider),
            icon: const Icon(Icons.refresh, size: 18),
            tooltip: l10n.actionRetry,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
      data: (pendingCount) => Text(
        pendingCount > 0
            ? l10n.pendingRedemptionsCountSubtitle(pendingCount)
            : l10n.pendingRedemptionsEmpty,
      ),
    );

    // Ownership gate helpers — whether each category tile should be shown.
    // Owners always see every tile; tutors see only what they're permitted.
    final canEditTracks = !isTutoredContext || tutorPerms.canEditStages;
    // H5: point configuration + parent_points_adjust gate on the dedicated
    // canEditPoints permission, NOT canEditGoals (a different concept).
    final canEditPoints = !isTutoredContext || tutorPerms.canEditPoints;
    final canEditRewards = !isTutoredContext || tutorPerms.canEditRewards;
    // Goals are per-track (set/edited from each track's "Set/Edit Goal" tile),
    // so the hub's "Manage Goals" row routes into the track list. Gated on the
    // dedicated canEditGoals permission (default true for tutors), distinct
    // from canEditStages which gates track add/edit/archive.
    final canEditGoals = !isTutoredContext || tutorPerms.canEditGoals;
    // WS3.3h: canBulkPriorCompletion = true by default (G3/DEC-33) — tutors
    // always see the bulk-mark tile unless the parent explicitly disabled it.
    final canBulkMark = !isTutoredContext || tutorPerms.canBulkPriorCompletion;

    // Owner-only tiles are completely hidden in tutored mode.
    final showOwnerOnlyTiles = !isTutoredContext;

    // Build the main edit tiles, hiding those locked by tutor permissions.
    // If all three tiles are hidden the panel is omitted entirely to avoid
    // an empty card.
    final showEditPanel =
        canEditTracks || canEditGoals || canEditPoints || canEditRewards;

    return Scaffold(
      backgroundColor: _pageBg(context),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _pageBg(context),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: context.colors.brandBlueDeep,
          onPressed: () => context.router.maybePop(),
        ),
        title: Text(
          l10n.parentSettingsTitle,
          style: theme.textTheme.titleLarge?.copyWith(
            color: context.colors.brandBlueDeep,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          UserProfileHeaderCard(
            user: user,
            activeProfile: activeProfile,
            surface: UserProfileHeaderSurface.parent,
            contextRole: isTutoredContext
                ? UserProfileContextRole.tutor
                : UserProfileContextRole.parent,
          ),
          const SizedBox(height: 16),
          // WS3.3d: edit panel — only shown when at least one tile is visible.
          if (showEditPanel) ...[
            _WhitePanel(
              // WS1.consolidate: "Switch Profile" row removed — the always-on
              // avatar switcher in the bottom nav is the canonical path (DEC-11).
              child: Column(
                children: [
                  // WS3.3d: canEditStages gates "Manage Tracks" for tutors.
                  if (canEditTracks) ...[
                    _ManageRow(
                      iconBackground: _managePurple,
                      icon: Icons.route_rounded,
                      iconColor: Colors.white,
                      title: l10n.manageTracks,
                      subtitle: l10n.manageTracksForChildSubtitle,
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: _chevronMuted,
                        size: 26,
                      ),
                      onTap: () =>
                          context.pushRoute(const ParentTrackManagementRoute()),
                    ),
                  ],
                  // Goals: per-track pace/deadline goals are set from each
                  // track's "Set/Edit Goal" tile, so this row routes into the
                  // track list. Gated on canEditGoals (default true for tutors),
                  // distinct from canEditStages above.
                  if (canEditGoals) ...[
                    if (canEditTracks) _rowDivider(context),
                    _ManageRow(
                      iconBackground: const Color(0xFFE7F0FF),
                      icon: Icons.flag_rounded,
                      iconColor: const Color(0xFF1E52D4),
                      title: l10n.manageGoals,
                      subtitle: l10n.manageGoalsSubtitle,
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: _chevronMuted,
                        size: 26,
                      ),
                      onTap: () =>
                          context.pushRoute(const ParentTrackManagementRoute()),
                    ),
                  ],
                  // WS3.3d: canEditPoints gates "Point Configuration" for tutors.
                  if (canEditPoints) ...[
                    if (canEditTracks || canEditGoals) _rowDivider(context),
                    _ManageRow(
                      iconBackground: _iconCircleMuted(context),
                      icon: Icons.tune_rounded,
                      iconColor: _iconMutedFg(context),
                      title: l10n.pointSettingsTitle,
                      subtitle: l10n.pointConfigurationSubtitle,
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: _chevronMuted,
                        size: 26,
                      ),
                      onTap: () => context.pushRoute(const PointConfigRoute()),
                    ),
                    // WS7.adjust: parent manual add/deduct (DEC-17).
                    _rowDivider(context),
                    _ManageRow(
                      iconBackground: const Color(0xFFE0EAFF),
                      icon: Icons.add_circle_outline_rounded,
                      iconColor: const Color(0xFF1E52D4),
                      title: l10n.parentPointsAdjustTitle,
                      subtitle: l10n.parentPointsAdjustSubtitle,
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: _chevronMuted,
                        size: 26,
                      ),
                      onTap: () => unawaited(
                        _showAdjustPointsDialog(context, ref, l10n),
                      ),
                    ),
                  ],
                  // WS3.3d: canEditRewards gates "Reward Configuration" for tutors.
                  if (canEditRewards) ...[
                    if (canEditTracks || canEditGoals || canEditPoints)
                      _rowDivider(context),
                    _ManageRow(
                      iconBackground: context.colors.peachTint,
                      icon: Icons.card_giftcard_rounded,
                      // AUD-profiles dark-mode sweep: was a hardcoded
                      // Color(0xFFB45309) — fine in light (~4.06:1) but
                      // peachTint darkens sharply in dark, dropping this
                      // fixed rust-brown to 2.95:1. peachTintIconAccent
                      // lightens like peachDark in dark: 9.96:1.
                      iconColor: context.colors.peachTintIconAccent,
                      title: l10n.rewardConfigurationTitle,
                      subtitle: l10n.rewardConfigurationSubtitle,
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: _chevronMuted,
                        size: 26,
                      ),
                      onTap: () =>
                          context.pushRoute(const RewardConfigurationRoute()),
                    ),
                    // WS7.redeem: pending prize requests from child.
                    _rowDivider(context),
                    _ManageRow(
                      iconBackground: const Color(0xFFE8F5E9),
                      icon: Icons.redeem_rounded,
                      iconColor: const Color(0xFF388E3C),
                      title: l10n.pendingRedemptionsTitle,
                      subtitleWidget: pendingSubtitle,
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: _chevronMuted,
                        size: 26,
                      ),
                      onTap: () => context.pushRoute(
                        const ParentPendingRedemptionsRoute(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          // WS3.3h: bulk-mark tile — shown when canBulkPriorCompletion.
          // Default = true (G3/DEC-33); tutors always see it unless
          // the parent explicitly disabled canBulkPriorCompletion.
          if (canBulkMark)
            _WhitePanel(
              child: _ManageRow(
                iconBackground: const Color(0xFFE8D4B8),
                icon: Icons.menu_book_rounded,
                iconColor: const Color(0xFF6B4E2E),
                leadingSquare: true,
                title: l10n.addWhatYouLearned,
                subtitle: l10n.addWhatYouLearnedSettingsSubtitle,
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: _chevronMuted,
                  size: 26,
                ),
                onTap: () => context.pushRoute(const LifetimeMarkingRoute()),
              ),
            ),
          // WS3.3a: "Manage tutors" tile — owner-only (hidden in tutored context).
          // WS3.3d: tutors cannot manage other tutors.
          if (showOwnerOnlyTiles) ...[
            const SizedBox(height: 16),
            _WhitePanel(
              child: _ManageRow(
                // AUD-profiles dark-mode sweep: was a hardcoded
                // Color(0xFFE8F4FD) that stayed light in dark while its icon
                // reads brandBlue (LIGHTENS in dark) — measured 2.26:1 in
                // dark. Reusing settingsProfileBadgeParentBg: identical
                // 0xFFE8F4FD in light, darkens to 6.22:1 against brandBlue
                // dark.
                iconBackground: context.colors.settingsProfileBadgeParentBg,
                icon: Icons.school_rounded,
                iconColor: context.colors.brandBlue,
                leadingSquare: false,
                title: l10n.manageTutors,
                subtitle: l10n.manageTutorsSubtitle,
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: _chevronMuted,
                  size: 26,
                ),
                onTap: () => context.pushRoute(const ManageTutorsRoute()),
              ),
            ),
            const SizedBox(height: 16),
            const BackupSyncSection(parentSettingsHeroLayout: true),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
              child: Text(
                l10n.sectionAccountSafety,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: context.colors.inkMidGrey,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  fontSize: 11,
                ),
              ),
            ),
            _WhitePanel(
              child: _ManageRow(
                iconBackground: _dangerIconBg(context),
                icon: Icons.logout_rounded,
                iconColor: context.colors.chartRed,
                title: l10n.signOut,
                titleColor: context.colors.chartRed,
                subtitle: null,
                leadingSquare: true,
                trailing: const SizedBox.shrink(),
                onTap: () => showSignOutConfirmation(context, ref),
              ),
            ),
            if (showDeleteAccountTile) ...[
              const SizedBox(height: 12),
              _WhitePanel(
                child: _ManageRow(
                  iconBackground: _dangerIconBg(context),
                  icon: Icons.delete_forever_rounded,
                  // AUD-profiles dark-mode sweep: was a hardcoded Material
                  // Color(0xFFB00020) against surfaces that BOTH darken in
                  // dark (statusErrorSoft icon chip, brandCreamCard row
                  // text) — measured 2.30:1 (icon) / 2.37:1 (text).
                  // deleteAccountDangerRed lightens like brandError in dark:
                  // ~6.7-6.9:1 against both.
                  iconColor: context.colors.deleteAccountDangerRed,
                  title: l10n.deleteAccountTitle,
                  titleColor: context.colors.deleteAccountDangerRed,
                  subtitle: l10n.deleteAccountSubtitle,
                  subtitleColor: context.colors.deleteAccountDangerRed,
                  leadingSquare: true,
                  trailing: const SizedBox.shrink(),
                  onTap: () {
                    showDeleteAccountFlow(context, ref, user);
                  },
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _rowDivider(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 72,
      endIndent: 16,
      color: context.colors.surfaceE9,
    );
  }
}

/// WS7.adjust — show the parent points adjustment dialog (DEC-17).
///
/// Already PIN-gated at route level; this dialog is reached only from inside
/// [ParentSettingsScreen] which is behind [authGuard, childModeGuard, pinGuard].
Future<void> _showAdjustPointsDialog(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l10n,
) async {
  var addMode = true;
  final amountController = TextEditingController();
  final noteController = TextEditingController();

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(l10n.parentPointsAdjustTitle),
        // The dialog shrinks when the numeric keyboard opens; without a
        // scroll view the fixed-height column overflowed (~66px). Scrolling
        // lets the content fit and resize with the keyboard.
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Consumer(
                builder: (context, ref, _) {
                  final balance =
                      ref
                          .watch(activeProfilePointsBalanceProvider)
                          .asData
                          ?.value ??
                      0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      l10n.parentPointsAdjustCurrentBalance(balance),
                      style: Theme.of(ctx).textTheme.bodyMedium,
                    ),
                  );
                },
              ),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: true,
                    label: Text(l10n.parentPointsAdjustAddLabel),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text(l10n.parentPointsAdjustDeductLabel),
                  ),
                ],
                selected: {addMode},
                onSelectionChanged: (v) => setState(() => addMode = v.first),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: l10n.parentPointsAdjustAmountHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: InputDecoration(
                  hintText: l10n.parentPointsAdjustNoteHint,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: amountController,
            builder: (ctx, value, _) {
              final amount = int.tryParse(value.text.trim()) ?? 0;
              final isValid = amount > 0;
              return FilledButton(
                onPressed: isValid ? () => Navigator.pop(ctx, true) : null,
                child: Text(l10n.parentPointsAdjustConfirm),
              );
            },
          ),
        ],
      ),
    ),
  );

  if (result != true || !context.mounted) return;

  final amount = int.tryParse(amountController.text.trim()) ?? 0;
  if (amount <= 0) return;

  final writer = ref.read(_pointsLedgerWriteAdapterProvider);
  final delta = addMode ? amount : -amount;
  final note = noteController.text.trim().isEmpty
      ? null
      : noteController.text.trim();

  await writer.appendParentAdjustment(delta: delta, note: note);
  ref.invalidate(activeProfilePointsBalanceProvider);
  ref.invalidate(globalPointsProvider);
  ref.invalidate(dashboardGlobalPointsProvider);

  amountController.dispose();
  noteController.dispose();

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.parentPointsAdjustAppliedSnackbar)),
    );
  }
}

class _WhitePanel extends StatelessWidget {
  const _WhitePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.brandCreamCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140038A8),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(20), child: child),
    );
  }
}

class _ManageRow extends StatelessWidget {
  const _ManageRow({
    required this.iconBackground,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    required this.trailing,
    this.titleColor,
    this.subtitleColor,
    this.onTap,
    this.leadingSquare = false,
  });

  final Color iconBackground;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final Widget trailing;
  final Color? titleColor;
  final Color? subtitleColor;
  final VoidCallback? onTap;
  final bool leadingSquare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: leadingSquare
                      ? BorderRadius.circular(12)
                      : null,
                  shape: leadingSquare ? BoxShape.rectangle : BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: titleColor ?? context.colors.brandInk,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    if (subtitle != null || subtitleWidget != null) ...[
                      const SizedBox(height: 4),
                      subtitleWidget ??
                          Text(
                            subtitle!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: subtitleColor ?? context.colors.inkMidGrey,
                              fontSize: 14,
                              height: 1.25,
                            ),
                          ),
                    ],
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// WS7.redeem — parent-facing screen to approve (fulfil) or decline
/// pending prize redemption requests from a child.
///
/// When a child redeems a reward in [ChildRedemptionScreen], a
/// [RewardRedemption] row is created with status `pending_fulfilment`.
/// The parent opens this screen (accessible via [ParentSettingsScreen] →
/// "Pending Prizes") and can:
///  - **Fulfil**: marks the physical prize as handed over; status → fulfilled.
///  - **Decline**: refunds the points to the child's balance; status → declined.
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/features/gamification/domain/reward_milestone_icons.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

// ─── Provider ─────────────────────────────────────────────────────────────────

/// Pending reward-redemption requests for the active (child) profile.
///
/// DG-PND-05: previously a one-shot [FutureProvider.autoDispose] calling
/// [PointsBalanceDao.getPendingRedemptions]. This left the
/// [ParentPendingRedemptionsScreen] list STALE after any mutation — e.g., when
/// the child submits a new redemption on another device (cloud sync push) or
/// when a pending row transitions to fulfilled/declined — until
/// `ref.invalidate()` was called manually.
///
/// Fix: converted to a [StreamProvider.autoDispose] backed by
/// [PointsBalanceDao.watchPendingRedemptions]. The stream emits the updated
/// list on every `reward_redemptions` row change, so the parent sees new
/// requests and fulfilled/declined removals instantly without requiring manual
/// invalidation or pull-to-refresh.
///
/// The `ref.invalidate(pendingRedemptionsProvider)` calls after fulfil/decline
/// are retained for backwards compatibility (they restart the stream
/// subscription, which is benign for a [StreamProvider]).
///
/// Declared as a manual provider (not @riverpod code-gen) to avoid
/// riverpod_generator choking on the Drift-generated [RewardRedemption] type.
final pendingRedemptionsProvider =
    StreamProvider.autoDispose<List<RewardRedemption>>((ref) {
      final db = ref.watch(userDatabaseProvider);
      final profileId = ref.watch(activeProfileIdProvider);
      return db.pointsBalanceDao.watchPendingRedemptions(profileId);
    });

// ─── Screen ───────────────────────────────────────────────────────────────────

@RoutePage()
class ParentPendingRedemptionsScreen extends ConsumerWidget {
  const ParentPendingRedemptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final redemptionsAsync = ref.watch(pendingRedemptionsProvider);

    return Scaffold(
      backgroundColor: context.colors.surfaceF4b,
      appBar: AppBar(
        // #32: explicit back button wired to the router pop (the SAME nav the
        // hardware back uses). Without an explicit leading the auto-generated
        // back affordance was mis-handled and the tap fell through to the
        // persistent profile-switcher bar instead of popping to ParentSettings.
        leading: IconButton(
          key: const Key('parentPendingRedemptionsBackButton'),
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.router.maybePop(),
        ),
        title: Text(l10n.pendingRedemptionsTitle),
        backgroundColor: context.colors.surfaceF4b,
        elevation: 0,
      ),
      body: redemptionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.errorGeneric(e.toString()))),
        data: (redemptions) {
          if (redemptions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.card_giftcard,
                      size: 80,
                      color: theme.colorScheme.primary.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.pendingRedemptionsEmptyTitle,
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.pendingRedemptionsEmpty,
                      style: TextStyle(
                        fontSize: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: redemptions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) => _RedemptionCard(
              redemption: redemptions[i],
              l10n: l10n,
              theme: theme,
              onFulfil: () => _fulfil(context, ref, redemptions[i], l10n),
              onDecline: () => _decline(context, ref, redemptions[i], l10n),
            ),
          );
        },
      ),
    );
  }

  Future<void> _fulfil(
    BuildContext context,
    WidgetRef ref,
    RewardRedemption redemption,
    AppLocalizations l10n,
  ) async {
    final db = ref.read(userDatabaseProvider);
    // WS9 Wave-B (C#2): ensure the points-sync sink is registered so the
    // status change is pushed to the child's device.
    ref.read(outboxSyncWriteFacadeProvider);
    await db.pointsBalanceDao.fulfilRedemption(redemption.id);
    // SM-4 (AUD-gamification-01): the screen can be popped while the DB
    // write above is in flight -- check context.mounted before touching
    // `ref`/`context` again, not after.
    if (context.mounted) {
      ref.invalidate(pendingRedemptionsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pendingRedemptionsFulfilledSnackbar)),
      );
    }
  }

  Future<void> _decline(
    BuildContext context,
    WidgetRef ref,
    RewardRedemption redemption,
    AppLocalizations l10n,
  ) async {
    final db = ref.read(userDatabaseProvider);
    // WS9 Wave-B (C#2): ensure the points-sync sink is registered so the
    // decline + refund ledger entry are pushed to the child's device.
    ref.read(outboxSyncWriteFacadeProvider);
    await db.pointsBalanceDao.declineRedemption(redemption.id);
    // SM-4 (AUD-gamification-01): the screen can be popped while the DB
    // write above is in flight -- check context.mounted before touching
    // `ref`/`context` again, not after.
    if (context.mounted) {
      ref.invalidate(pendingRedemptionsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pendingRedemptionsDeclinedSnackbar)),
      );
    }
  }
}

// ─── Card widget ──────────────────────────────────────────────────────────────

class _RedemptionCard extends StatefulWidget {
  const _RedemptionCard({
    required this.redemption,
    required this.l10n,
    required this.theme,
    required this.onFulfil,
    required this.onDecline,
  });

  final RewardRedemption redemption;
  final AppLocalizations l10n;
  final ThemeData theme;
  final Future<void> Function() onFulfil;
  final Future<void> Function() onDecline;

  @override
  State<_RedemptionCard> createState() => _RedemptionCardState();
}

class _RedemptionCardState extends State<_RedemptionCard> {
  // Double-tap guard: while a fulfil/decline is in flight, BOTH actions are
  // disabled so the same redemption can't be fulfilled/declined twice (or
  // fulfilled-then-declined) by rapid taps before the list refreshes.
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final redemption = widget.redemption;
    final l10n = widget.l10n;
    final theme = widget.theme;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: context.colors.gamifSoftBlueCardBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                RewardMilestoneIcons.iconForIndex(redemption.iconIndex),
                color: context.colors.brandBlueDeep,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    redemption.rewardTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.pendingRedemptionsCost(redemption.pointsCost),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.colors.brandBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FilledButton(
                  onPressed: _busy ? null : () => _run(widget.onFulfil),
                  style: FilledButton.styleFrom(
                    // AUD-darkmode: brandBlueDeep is an ink-on-CARD role
                    // that LIGHTENS in dark mode (correct for the icon above,
                    // painted on the themed gamifSoftBlueCardBg circle), but
                    // here it was misused as a button FILL with hardcoded
                    // white text -- measured 1.63:1 in dark.
                    // chazaraSelectedGradientStart is pinned to this exact
                    // brandBlueDeep light literal (0xFF0E3392) in both
                    // themes, restoring ~11:1 in dark.
                    backgroundColor:
                        context.colors.chazaraSelectedGradientStart,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    l10n.pendingRedemptionsApprove,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: _busy ? null : () => _run(widget.onDecline),
                  style: TextButton.styleFrom(
                    foregroundColor: context.colors.brandInkMuted,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                  ),
                  child: Text(
                    l10n.pendingRedemptionsDecline,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
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

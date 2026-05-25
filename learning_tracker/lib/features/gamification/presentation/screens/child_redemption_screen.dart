/// WS7.redeem / WS7.child-ui — the child-facing prize redemption screen.
///
/// Displays the child's current balance and all enabled rewards configured
/// by the parent (via [RewardMilestoneService]). Each reward shows its cost
/// in points. If the child can afford it (balance ≥ cost) they tap Redeem →
/// confirm dialog → balance debited, redemption record created with status
/// `pending_fulfilment`. The parent approves (fulfils) or declines (refunds)
/// via [ParentPendingRedemptionsScreen].
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/features/gamification/domain/reward_milestone_icons.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'child_redemption_screen.g.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

@riverpod
Future<int> childRedemptionBalance(Ref ref) async {
  final db = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  return db.pointsBalanceDao.getBalance(profileId);
}

@riverpod
Future<List<RewardMilestone>> childRedemptionRewards(Ref ref) async {
  final db = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final svc = RewardMilestoneService(db, profileId: profileId);
  // Gather all enabled milestones (global + per-track).
  final global = await svc.getGlobalMilestones();
  final tracks = await db.trackDao.getActiveTracksForProfile(profileId);
  final perTrack = <RewardMilestone>[];
  for (final t in tracks) {
    perTrack.addAll(await svc.getMilestonesForTrack(t.id));
  }
  return [
    ...global.where((m) => m.isEnabled),
    ...perTrack.where((m) => m.isEnabled),
  ];
}

// ─── Screen ───────────────────────────────────────────────────────────────────

@RoutePage()
class ChildRedemptionScreen extends ConsumerWidget {
  const ChildRedemptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final balanceAsync = ref.watch(childRedemptionBalanceProvider);
    final rewardsAsync = ref.watch(childRedemptionRewardsProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceF4b,
      appBar: AppBar(
        title: Text(l10n.redeemScreenTitle),
        backgroundColor: AppColors.surfaceF4b,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Balance card
          _BalanceCard(balanceAsync: balanceAsync, l10n: l10n, theme: theme),
          // Reward list
          Expanded(
            child: rewardsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(e.toString())),
              data: (rewards) {
                if (rewards.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        l10n.redeemScreenNoRewards,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  );
                }
                final balance = balanceAsync.asData?.value ?? 0;
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: rewards.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) => _RewardCard(
                    reward: rewards[i],
                    balance: balance,
                    l10n: l10n,
                    theme: theme,
                    onRedeem: () =>
                        _confirmRedeem(context, ref, rewards[i], l10n),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRedeem(
    BuildContext context,
    WidgetRef ref,
    RewardMilestone reward,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.redeemScreenConfirmTitle(reward.title)),
        content: Text(l10n.redeemScreenConfirmBody(reward.pointsCost)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.redeemScreenConfirmButton),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final db = ref.read(userDatabaseProvider);
    final profileId = ref.read(activeProfileIdProvider);
    // WS9 Wave-B (C#2): touch the outbox facade provider so the points-sync
    // sink is registered on the DAO before the redemption is written, ensuring
    // the redemption + debit ledger entry are pushed to Firestore.
    ref.read(outboxSyncWriteFacadeProvider);

    final redemption = await db.pointsBalanceDao.createRedemption(
      profileId: profileId,
      rewardTitle: reward.title,
      iconIndex: reward.iconIndex,
      pointsCost: reward.pointsCost,
    );

    if (!context.mounted) return;
    if (redemption == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.redeemScreenInsufficientSnackbar)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.redeemScreenRequestedSnackbar(reward.title)),
        ),
      );
      // Invalidate so balance refreshes.
      ref.invalidate(childRedemptionBalanceProvider);
    }
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.balanceAsync,
    required this.l10n,
    required this.theme,
  });

  final AsyncValue<int> balanceAsync;
  final AppLocalizations l10n;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E52D4), // kChildRewardsCardBlueTop
            AppColors.blueLight,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E52D4).withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.redeemScreenBalance,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          balanceAsync.when(
            loading: () => const SizedBox(
              height: 32,
              width: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (balance) => Text(
              l10n.dashboardPointsValue(balance.toString()),
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({
    required this.reward,
    required this.balance,
    required this.l10n,
    required this.theme,
    required this.onRedeem,
  });

  final RewardMilestone reward;
  final int balance;
  final AppLocalizations l10n;
  final ThemeData theme;
  final VoidCallback onRedeem;

  @override
  Widget build(BuildContext context) {
    final canAfford = balance >= reward.pointsCost;
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
              decoration: const BoxDecoration(
                color: Color(0xFFEEF3FA),
                shape: BoxShape.circle,
              ),
              child: Icon(
                RewardMilestoneIcons.iconForIndex(reward.iconIndex),
                color: const Color(0xFF00218D),
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reward.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.redeemScreenCostLabel(reward.pointsCost),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: canAfford
                          ? const Color(0xFF1E52D4)
                          : const Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: canAfford ? onRedeem : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00218D),
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                canAfford
                    ? l10n.redeemScreenAffordableLabel
                    : l10n.redeemScreenCannotAfford,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: canAfford ? Colors.white : const Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

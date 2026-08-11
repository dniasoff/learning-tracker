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
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/features/gamification/data/repositories/firestore_points_balance_reader_adapter.dart';
import 'package:learning_tracker/features/gamification/data/repositories/reward_redemption_repository_impl.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/features/gamification/domain/reward_milestone_icons.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/achievements_overview_provider.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/gamification_service_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'child_redemption_screen.g.dart';

final _redemptionRepositoryProvider =
    Provider<FirestoreRewardRedemptionRepositoryAdapter>(
      (ref) => FirestoreRewardRedemptionRepositoryAdapter(ref: ref),
    );

// ─── Providers ────────────────────────────────────────────────────────────────

/// Child's debitable points balance — reactive stream backed by watchBalance.
///
/// DG-RDMP-01: previously a one-shot [FutureProvider] calling
/// [PointsBalanceDao.getBalance] (reads the balance once). This left the
/// ChildRedemptionScreen's balance card STALE after any balance mutation
/// (parent adjustment, redemption debit) until a manual `ref.invalidate()`.
///
/// Fix: converted to a [StreamProvider] backed by
/// [PointsBalanceDao.watchBalance] — the same reactive read path used by
/// [dashboardGlobalPointsProvider] and [globalPointsProvider]. Any write to
/// the PointsBalance row causes the stream to emit the new value immediately.
// Not a live watch: firestore.rules caps every points_ledger query at
// limit<=500, so there is no single-listener way to watch an
// arbitrarily-long ledger's derived balance live -- same constraint
// dashboard_providers.dart's dashboardGlobalPoints already accepted
// this session. Re-reads on completionCommittedProvider plus explicit
// invalidation after this screen's own redemption write.
@riverpod
Future<int> childRedemptionBalance(Ref ref) async {
  ref.watch<int>(completionCommittedProvider);
  final reader = FirestorePointsBalanceReaderAdapter(ref: ref);
  return reader.getBalance();
}

@riverpod
Future<List<RewardMilestone>> childRedemptionRewards(Ref ref) async {
  // DEC-32/GA-3: per-track rewards were removed from the spend economy --
  // every reward is a single global priced spend-item now (same fix
  // already applied to dashboard_providers.dart/
  // achievements_overview_provider.dart earlier this session).
  final svc = ref.watch(rewardMilestoneServiceProvider);
  final global = await svc.getMilestones();
  return global.where((m) => m.isEnabled).toList();
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
    // R3-7: detect active tutored session — redemption is VIEW-ONLY for tutors.
    final isTutoredSession =
        ref.watch(activeTutoredProfileSelectionProvider) != null;

    return Scaffold(
      backgroundColor: context.colors.surfaceF4b,
      appBar: AppBar(
        // #31: explicit back button wired to the router pop (the SAME nav the
        // hardware back uses). Without an explicit leading the auto-generated
        // back affordance was mis-handled and the tap fell through to the
        // persistent profile-switcher bar instead of popping to the Dashboard.
        leading: IconButton(
          key: const Key('childRedemptionBackButton'),
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.router.maybePop(),
        ),
        title: Text(l10n.redeemScreenTitle),
        backgroundColor: context.colors.surfaceF4b,
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
              error: (e, _) =>
                  Center(child: Text(l10n.errorGeneric(e.toString()))),
              data: (rewards) {
                if (rewards.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        l10n.redeemScreenNoRewards,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: context.colors.brandInkMuted,
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
                    isTutoredSession: isTutoredSession,
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
    // R3-7 defense-in-depth: hard-guard against redemption in a tutored session.
    // The UI already disables the button when isTutoredSession is true; this
    // guard ensures createRedemption is NEVER called even if the button were
    // somehow reached (e.g. programmatic invocation, future refactor).
    if (ref.read(activeTutoredProfileSelectionProvider) != null) return;

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

    final redemptionRepo = ref.read(_redemptionRepositoryProvider);
    final redemption = await redemptionRepo.createRedemption(
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
      // childRedemptionBalanceProvider is a one-shot Future now (not a
      // live watch -- see its own doc comment), so it needs an explicit
      // invalidate here to reflect the debit immediately.
      ref.invalidate(childRedemptionBalanceProvider);
      // DG-ACHV-01: invalidate achievementsOverviewProvider so the gamification
      // screen's unlock classification reflects the post-debit balance without
      // requiring a pull-to-refresh. Without this, a milestone that was
      // "unlocked" (affordable) at the time of redemption would remain classified
      // as unlocked on the achievements screen even though the child's balance
      // has since dropped below the threshold.
      ref.invalidate(achievementsOverviewProvider);
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context
                .colors
                .gamifChildRewardsCardBlueTop, // kChildRewardsCardBlueTop(context)
            context.colors.blueLight,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: context.colors.gamifChildRewardsCardBlueTop.withValues(
              alpha: 0.22,
            ),
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
    required this.isTutoredSession,
    required this.l10n,
    required this.theme,
    required this.onRedeem,
  });

  final RewardMilestone reward;
  final int balance;
  // R3-7: when true the redeem button is disabled and shows the tutor-mode
  // label, mirroring how the mark-complete button is barred in tutor sessions.
  final bool isTutoredSession;
  final AppLocalizations l10n;
  final ThemeData theme;
  final VoidCallback onRedeem;

  @override
  Widget build(BuildContext context) {
    final canAfford = balance >= reward.pointsCost;
    // R3-7: tutors see the button as disabled regardless of balance.
    final buttonEnabled = canAfford && !isTutoredSession;
    final buttonLabel = isTutoredSession
        ? l10n.redeemScreenTutorUnavailable
        : canAfford
        ? l10n.redeemScreenAffordableLabel
        : l10n.redeemScreenCannotAfford;
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
                RewardMilestoneIcons.iconForIndex(reward.iconIndex),
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
                    reward.title,
                    // #39: wrap at word boundaries (max 2 lines) and ellipsize
                    // on overflow so a long single-token title like "BronzeStar"
                    // never breaks mid-character ("BronzeS\ntar").
                    softWrap: true,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.redeemScreenCostLabel(reward.pointsCost),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: canAfford
                          ? context.colors.brandBlue
                          : context.colors.brandInkSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // #39 (R1): cap the action button's width so a long label
            // ("Not enough points" / "Not available (tutor mode)") cannot grow
            // wide enough — especially at large text scales (e.g. 1.3) — to
            // squeeze the Expanded title column into a mid-word break. The label
            // wraps to at most two centred lines and ellipsizes beyond that,
            // leaving the title column adequate room.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 132),
              child: FilledButton(
                onPressed: buttonEnabled ? onRedeem : null,
                style: FilledButton.styleFrom(
                  // AUD-darkmode: brandBlueDeep is an ink-on-CARD role that
                  // LIGHTENS in dark mode (correct for the icon above, painted
                  // on the themed gamifSoftBlueCardBg circle), but here it was
                  // misused as a button FILL with hardcoded white text --
                  // measured 1.63:1 in dark. chazaraSelectedGradientStart is
                  // pinned to this exact brandBlueDeep light literal
                  // (0xFF0E3392) in both themes, restoring ~11:1 in dark.
                  backgroundColor: context.colors.chazaraSelectedGradientStart,
                  disabledBackgroundColor: context.colors.brandCreamSoft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  buttonLabel,
                  textAlign: TextAlign.center,
                  softWrap: true,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: buttonEnabled
                        ? Colors.white
                        : context.colors.brandInkMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

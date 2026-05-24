import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/manage_tutors_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/screens/tutor_pin_entry_gate.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

// ── WS3.3b / W6.14: Tutored children section ─────────────────────────────────
//
// DEC-8 visibility rule: show this section iff the current user has
// ≥1 active talmid OR ≥1 pending invitation. Previously gated on active-only.
//
// When pending invitations exist, a "View invitations" row is rendered at the
// top of the section so the tutor can accept or decline.

/// Renders a "Talmid Profiles" header with:
///   • A "View invitations" entry (when pending invitations exist)
///   • A row per active tutored-child grant
///
/// Hidden entirely while grants are loading or when no grants exist at all.
class TutoredChildrenSection extends ConsumerWidget {
  const TutoredChildrenSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grantsAsync = ref.watch(incomingTutorGrantsProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return grantsAsync.when(
      // Don't block the render on the grants load — the own-children grid
      // is already visible. Show nothing while grants are loading.
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (grants) {
        // DEC-8: section visible iff ≥1 active talmid OR ≥1 pending invitation.
        final activeGrants = grants
            .where((g) => g.grantState is ActiveGrant)
            .toList();
        final pendingGrants = grants
            .where((g) => g.grantState is PendingGrant)
            .toList();

        if (activeGrants.isEmpty && pendingGrants.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                l10n.profilePickerTalmidProfiles,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppTheme.brandInkMuted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // WS3.3b: "View invitations" row — shown when pending invites exist.
            if (pendingGrants.isNotEmpty) ...[
              _ViewInvitationsRow(pendingCount: pendingGrants.length),
              const SizedBox(height: 8),
            ],

            // Active tutored-child rows.
            for (final grant in activeGrants) ...[
              _TutoredChildRow(grant: grant),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

// ── "View invitations" row ────────────────────────────────────────────────────

/// Tappable row that navigates to the tutor's incoming grants screen so they
/// can accept or decline pending invitations.
class _ViewInvitationsRow extends StatelessWidget {
  const _ViewInvitationsRow({required this.pendingCount});

  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3CD),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              const Center(
                child: Icon(
                  Icons.mail_outline_rounded,
                  color: Color(0xFFB07A00),
                  size: 24,
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade700,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$pendingCount',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        title: Text(
          'View invitations',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '$pendingCount pending tutor invitation${pendingCount > 1 ? 's' : ''}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.orange.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Color(0xFFC2C9D3),
        ),
        onTap: () => unawaited(context.pushRoute(const ManageGrantsRoute())),
      ),
    );
  }
}

// ── Tutored child row ─────────────────────────────────────────────────────────

/// A tappable row for an active tutored-child grant.
///
/// Tapping presents the [TutorPinEntryGate]. On PIN success the row:
///   1. Sets [ActiveTutoredProfileSelection] so the router resolves
///      [PinScope.tutor()] correctly for any subsequent guarded routes.
///   2. Navigates to [ManageGrantsRoute] — the tutor's combined-surface
///      entry point until 3d wires the full child-profile view.
class _TutoredChildRow extends ConsumerWidget {
  const _TutoredChildRow({required this.grant});

  final TutorGrant grant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // WS3.3c: child display name — the grant doc carries a childProfileId
    // (Firestore string). Until the Cloud Function denormalises a childName
    // field onto the grant doc, show the profile ID as a compact fallback.
    // This is better than the previous "Child:{id}" placeholder.
    final childLabel = grant.childProfileId;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F4FD),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.school_rounded,
            color: AppTheme.brandBlue,
            size: 24,
          ),
        ),
        title: Text(
          childLabel,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          'Tutoring',
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.green.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.school_rounded,
                size: 14,
                color: Colors.green.shade700,
              ),
              const SizedBox(width: 4),
              Text(
                'Tutor',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        // WS3.3c: Present the TutorPinEntryGate on tap.
        onTap: () => _enterTalmidView(context, ref),
      ),
    );
  }

  /// Push the [TutorPinEntryGate] modally. On PIN success, set the active
  /// tutored-profile context and navigate to the talmid's view.
  void _enterTalmidView(BuildContext context, WidgetRef ref) {
    // The tutor's own local profile ID is required to key the PIN hash.
    // If the tutor has no own profile (profile-less tutor per DEC-6/DEC-21),
    // fall back to a sentinel profile ID of 0 — TutorPinEntryGate handles
    // the setup path for an unset PIN.
    final tutorOwnProfileId = ref.read(selectedProfileIdProvider) ?? 0;

    // Build the TutoredProfileSelection from the active grant.
    final activeState = grant.grantState as ActiveGrant;
    final selection = TutoredProfileSelection(
      profileId: grant.childProfileId,
      ownerUid: grant.parentUid,
      grantId: grant.grantId,
      permissions: activeState.permissions,
    );

    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => TutorPinEntryGate(
            profileId: tutorOwnProfileId,
            onPinVerified: () {
              // Set active tutored-profile context so the router resolves
              // PinScope.tutor() for any subsequent guarded routes.
              ref
                  .read(activeTutoredProfileSelectionProvider.notifier)
                  .enter(selection);
              // Pop the gate and navigate to the talmid's view.
              Navigator.of(context).pop();
              unawaited(context.pushRoute(const ManageGrantsRoute()));
            },
            onCancel: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }
}

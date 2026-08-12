import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/app/router/router_provider.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/navigation/pin_scope.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
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
      error: (error, stackTrace) {
        // AUD-profiles-15: hiding the section on a load failure is a
        // defensible UX call, but the failure must still leave a trace so a
        // persistently failing grants query (e.g. a Firestore rule
        // regression on the tutoring collection) can be diagnosed.
        AppLogger.instance.warning(
          event: 'tutored_children_grants_load_error',
          exception: error,
          stackTrace: stackTrace,
        );
        return const SizedBox.shrink();
      },
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
                  color: context.colors.brandInkMuted,
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

            // INFO/MED: when the tutor has ONLY active grants (no pending
            // invitations) the "View invitations" row above is absent, leaving
            // no UI path to ManageGrants (resign / review). Surface a dedicated
            // "Manage tutoring grants" entry whenever there is ≥1 active grant
            // so an active tutor can always reach ManageGrants. (When pending
            // invites exist the View-invitations row already routes there, but
            // this row remains useful as the explicit management entry point.)
            if (activeGrants.isNotEmpty) ...[
              const _ManageGrantsRow(),
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
class _ViewInvitationsRow extends ConsumerWidget {
  const _ViewInvitationsRow({required this.pendingCount});

  final int pendingCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
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
              // AX-1/AUD-profiles-23: PositionedDirectional so the
              // pending-invite count badge sits on the TRAILING corner of
              // the mail icon in both LTR and RTL. A plain Positioned(right:)
              // pinned it to the physical right, which is the LEADING edge
              // in Hebrew RTL.
              PositionedDirectional(
                top: 6,
                end: 6,
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
          l10n.tutoredChildrenViewInvitations,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          l10n.tutoredChildrenPendingInvitations(pendingCount),
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.orange.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Color(0xFFC2C9D3),
        ),
        // H3: enforce the Tutor PIN gate before showing the grants screen,
        // regardless of entry path (this row, deep links, etc). The gate keys
        // the PIN on the tutor's OWN profile id (C1).
        onTap: () => _openInvitations(context, ref),
      ),
    );
  }

  /// H3: present the [TutorPinEntryGate] before navigating to the grants
  /// screen so pending-invitation data is never shown without the Tutor PIN.
  void _openInvitations(BuildContext context, WidgetRef ref) {
    final tutorOwnProfileId = ref.read(selectedProfileIdProvider);
    if (tutorOwnProfileId == null) {
      // This section only renders for a signed-in tutor viewing their own
      // profile picker, so a null active profile id here is a not-ready
      // inconsistency, not a legitimate "profile-less tutor" state — there
      // is no honest ULID fallback to fabricate (AD-24). Bail rather than
      // open a PIN gate keyed on a made-up id.
      AppLogger.instance.warning(
        event: 'tutored_children_open_invitations_no_active_profile',
      );
      return;
    }
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => TutorPinEntryGate(
            profileId: tutorOwnProfileId,
            onPinVerified: () {
              // Capture the stable AppRouter before popping: popping the
              // switcher sheet unmounts this row, so `context.pushRoute` would
              // fail — but the router singleton survives.
              final router = ref.read(routerProvider);
              // Prime the tutor scope so the route guard does not re-prompt.
              router.pinGuard.markScopeAuthenticated(
                PinScope.tutor(tutorOwnProfileId),
              );
              // Pop the PIN gate AND the profile-switcher sheet beneath it
              // before pushing the grants screen. Both were pushed onto the
              // same (root) navigator; popping only the gate would leave the
              // modal sheet lingering on top once the grants screen is later
              // dismissed. Pop both so we land cleanly on the grants screen.
              final navigator = Navigator.of(context);
              navigator.pop(); // PIN gate
              if (navigator.canPop()) {
                navigator.pop(); // switcher sheet
              }
              unawaited(router.push(const ManageGrantsRoute()));
            },
            onCancel: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }
}

// ── "Manage tutoring grants" row ──────────────────────────────────────────────

/// Tappable row that navigates to [ManageGrantsRoute] so a tutor with active
/// grants can resign or review them. Reuses the same Tutor-PIN-gated path as
/// [_ViewInvitationsRow]; surfaced for active grants because the
/// invitations row only renders when PENDING invites exist.
class _ManageGrantsRow extends ConsumerWidget {
  const _ManageGrantsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
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
            color: const Color(0xFFEDEAF7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Icon(
              Icons.manage_accounts_rounded,
              color: Color(0xFF6B3FA0),
              size: 24,
            ),
          ),
        ),
        title: Text(
          l10n.tutoredChildrenManageGrants,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          l10n.tutoredChildrenManageGrantsSubtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: context.colors.brandInkMuted,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Color(0xFFC2C9D3),
        ),
        // H3: same Tutor-PIN gate as the invitations entry — never show grant
        // data without the Tutor PIN, regardless of entry path.
        onTap: () => _openManageGrants(context, ref),
      ),
    );
  }

  /// Present the [TutorPinEntryGate] before navigating to ManageGrants. Mirrors
  /// [_ViewInvitationsRow._openInvitations].
  void _openManageGrants(BuildContext context, WidgetRef ref) {
    final tutorOwnProfileId = ref.read(selectedProfileIdProvider);
    if (tutorOwnProfileId == null) {
      // See _ViewInvitationsRow._openInvitations' identical guard.
      AppLogger.instance.warning(
        event: 'tutored_children_open_manage_grants_no_active_profile',
      );
      return;
    }
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => TutorPinEntryGate(
            profileId: tutorOwnProfileId,
            onPinVerified: () {
              final router = ref.read(routerProvider);
              router.pinGuard.markScopeAuthenticated(
                PinScope.tutor(tutorOwnProfileId),
              );
              final navigator = Navigator.of(context);
              navigator.pop(); // PIN gate
              if (navigator.canPop()) {
                navigator.pop(); // switcher sheet
              }
              unawaited(router.push(const ManageGrantsRoute()));
            },
            onCancel: () => Navigator.of(context).pop(),
          ),
        ),
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
    final l10n = AppLocalizations.of(context)!;

    // M3: show the denormalised child name when the server provides it,
    // otherwise a friendly generic label — never the raw Firestore profile id.
    final childLabel = grant.childDisplayLabel;

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
            // AUD-profiles dark-mode sweep: was a hardcoded
            // Color(0xFFE8F4FD) that stayed light in dark while the icon
            // reads brandBlue (LIGHTENS in dark) — measured 2.26:1 in dark
            // (same bug as parent_settings_screen.dart's Manage Tutors
            // tile). Reusing settingsProfileBadgeParentBg: identical
            // 0xFFE8F4FD in light, darkens to 6.22:1 against brandBlue dark.
            color: context.colors.settingsProfileBadgeParentBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.school_rounded,
            color: context.colors.brandBlue,
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
          l10n.tutoredChildrenStatusTutoring,
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
                l10n.tutoredChildrenRoleBadge,
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

  /// Push the [TutorPinEntryGate] modally. On PIN success, enter the selected
  /// tutored profile context and land in the regular AppShell dashboard.
  void _enterTalmidView(BuildContext context, WidgetRef ref) {
    // The tutor's own profile ULID is required to key the PIN hash. See
    // _ViewInvitationsRow._openInvitations' identical guard for why there
    // is no honest fallback for a null id (AD-24) — bail rather than
    // fabricate one.
    final tutorOwnProfileId = ref.read(selectedProfileIdProvider);
    if (tutorOwnProfileId == null) {
      AppLogger.instance.warning(
        event: 'tutored_children_enter_talmid_view_no_active_profile',
      );
      return;
    }

    // Build the TutoredProfileSelection from the active grant.
    // C1: carry the tutor's OWN profile id so the route guard resolves
    // PinScope.tutor(tutorOwnProfileId) — the SAME namespace this gate keys
    // the PIN on — for any subsequent guarded routes.
    final activeState = grant.grantState as ActiveGrant;
    final selection = TutoredProfileSelection(
      profileId: grant.childProfileId,
      ownerUid: grant.parentUid,
      grantId: grant.grantId,
      permissions: activeState.permissions,
      tutorOwnProfileId: tutorOwnProfileId,
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
              // C2: prime the tutor scope as authenticated so the first
              // tutor-scoped edit route after the gate does not re-prompt.
              final router = ref.read(routerProvider);
              router.pinGuard.markScopeAuthenticated(
                PinScope.tutor(tutorOwnProfileId),
              );
              // Pop the PIN gate, dismiss the switcher sheet, then land on the
              // same dashboard route used by a regular signed-in user.
              Navigator.of(context).pop();
              final navigator = navigatorKey.currentState;
              if (navigator != null && navigator.canPop()) {
                navigator.pop();
              }
              unawaited(router.replaceAll([const AppShellRoute()]));
            },
            onCancel: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }
}

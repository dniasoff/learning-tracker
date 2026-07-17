import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/app/router/router_provider.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/navigation/pin_scope.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/sync/providers/tutored_pull_providers.dart';
import 'package:learning_tracker/core/sync/tutored_pull_service.dart';
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
    final tutorOwnProfileId = ref.read(selectedProfileIdProvider) ?? 0;
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
            color: AppTheme.brandInkMuted,
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
    final tutorOwnProfileId = ref.read(selectedProfileIdProvider) ?? 0;
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

  /// Push the [TutorPinEntryGate] modally. On PIN success, run the tutored
  /// pull, install the resolved local profile id, then land in the talmid
  /// dashboard (T2.entry-pull + T2.nav).
  void _enterTalmidView(BuildContext context, WidgetRef ref) {
    // The tutor's own local profile ID is required to key the PIN hash.
    // If the tutor has no own profile (profile-less tutor per DEC-6/DEC-21),
    // fall back to a sentinel profile ID of 0 — TutorPinEntryGate handles
    // the setup path for an unset PIN.
    final tutorOwnProfileId = ref.read(selectedProfileIdProvider) ?? 0;

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
              ref
                  .read(routerProvider)
                  .pinGuard
                  .markScopeAuthenticated(PinScope.tutor(tutorOwnProfileId));
              // Pop the PIN gate, then fire the pull + navigate
              // (T2.entry-pull). The profile-switcher sheet is intentionally
              // left mounted for now: `_fireEntryPullAndNavigate` runs async
              // work keyed off this widget's `context`/`ref`, and popping the
              // sheet here would unmount the row (disposing them) before the
              // pull completes. The sheet is dismissed at navigation time
              // inside `_fireEntryPullAndNavigate` (via the root navigator),
              // immediately before the shell is rebuilt.
              Navigator.of(context).pop();
              unawaited(_fireEntryPullAndNavigate(context, ref, selection));
            },
            onCancel: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }

  /// T2.entry-pull — run the tutored pull after the PIN gate passes, install
  /// the resolved synthetic local profile id, then replace the stack with the
  /// talmid's AppShell (T2.nav).  On failure, clears the selection and shows
  /// an error snackbar so the user lands back at the picker, never crashes.
  ///
  /// Offline-first: if a cached mirror exists from a previous session, navigate
  /// immediately without waiting for the network.  A fresh pull is only required
  /// on first access when no local data exists; that pull is capped at 15 s so
  /// the spinner never hangs indefinitely.
  Future<void> _fireEntryPullAndNavigate(
    BuildContext context,
    WidgetRef ref,
    TutoredProfileSelection selection,
  ) async {
    final accountId = ref.read(currentAccountIdProvider);
    // Capture the stable AppRouter up front: once the switcher sheet is popped
    // (see dismissSwitcherSheet) this widget unmounts, so `context.router` is
    // no longer usable — but the router singleton survives.
    final router = ref.read(routerProvider);

    // Dismiss the profile-switcher sheet that was left mounted beneath the PIN
    // gate. `router.replaceAll` only rebuilds auto_route's managed page stack;
    // the imperatively-pushed modal sheet is NOT cleared by it, so without this
    // explicit pop the sheet lingers on top of the talmid dashboard. Popping it
    // via the global root navigator key (not the dying widget context) makes
    // the dismissal robust against the widget unmounting.
    void dismissSwitcherSheet() {
      final navigator = navigatorKey.currentState;
      if (navigator != null && navigator.canPop()) {
        navigator.pop();
      }
    }

    // Offline-first: check for a cached mirror before touching the network.
    final cachedProfile = await ref
        .read(userDatabaseProvider)
        .profileDao
        .getTutoredProfile(
          parentUid: selection.ownerUid,
          remoteChildProfileId: selection.profileId,
          grantId: selection.grantId,
        );

    if (cachedProfile != null) {
      // Mirror from a previous session — enter immediately with local data.
      // Delta listeners will stream any changes once connectivity is restored.
      ref
          .read(resolvedTutoredLocalProfileIdProvider.notifier)
          .resolve(cachedProfile.id);
      final gateway = buildTutoredGateway(
        ref: ref,
        parentUid: selection.ownerUid,
      );
      try {
        unawaited(
          ref
              .read(tutoredListenerSupervisorProvider)
              .attach(
                localProfileId: cachedProfile.id,
                gateway: gateway,
                parentUid: selection.ownerUid,
                remoteProfileId: selection.profileId,
              ),
        );
      } catch (e, st) {
        AppLogger.instance.warning(
          event: 'tutored_listener_attach_error',
          exception: e,
          stackTrace: st,
        );
      }
      dismissSwitcherSheet();
      unawaited(router.replaceAll([const AppShellRoute()]));
      return;
    }

    // No cached mirror — first-time access requires a network pull.
    // Show a blocking progress indicator; cap at 15 s so offline doesn't spin
    // forever.
    var loadingShown = false;
    if (context.mounted) {
      loadingShown = true;
      unawaited(
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        ),
      );
    }
    void dismissLoading() {
      if (loadingShown && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingShown = false;
      }
    }

    try {
      // R4-M2: pass wipeService so permissionDenied clears the stale mirror
      // row rather than leaving it until the next pull entry.
      final svc = buildTutoredPullServiceFromWidget(
        ref: ref,
        parentUid: selection.ownerUid,
        wipeService: buildTutoredMirrorWipeServiceFromWidget(
          ref: ref,
          onWipe: (_) =>
              ref.read(activeTutoredProfileSelectionProvider.notifier).exit(),
        ),
      );
      final result = await svc
          .pull(
            accountId: accountId,
            parentUid: selection.ownerUid,
            remoteProfileId: selection.profileId,
            grantId: selection.grantId,
            childDisplayName: grant.childDisplayLabel,
            childMode: 'child',
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () =>
                (localProfileId: 0, result: TutoredPullResult.error),
          );

      switch (result.result) {
        case TutoredPullResult.success:
          ref
              .read(resolvedTutoredLocalProfileIdProvider.notifier)
              .resolve(result.localProfileId);
          // D3/D5 — attach delta listeners after the initial pull so the
          // talmid view stays live without full re-pulls.
          final gateway = buildTutoredGateway(
            ref: ref,
            parentUid: selection.ownerUid,
          );
          // R4-L4: wrap unawaited attach so synchronous throws are logged
          // rather than silently swallowed.
          try {
            unawaited(
              ref
                  .read(tutoredListenerSupervisorProvider)
                  .attach(
                    localProfileId: result.localProfileId,
                    gateway: gateway,
                    parentUid: selection.ownerUid,
                    remoteProfileId: selection.profileId,
                  ),
            );
          } catch (e, st) {
            AppLogger.instance.warning(
              event: 'tutored_listener_attach_error',
              exception: e,
              stackTrace: st,
            );
          }
          dismissLoading();
          dismissSwitcherSheet();
          unawaited(router.replaceAll([const AppShellRoute()]));
        case TutoredPullResult.permissionDenied:
          AppLogger.instance.warning(
            event: 'tutored_pull_permission_denied',
            fields: {'grantId': selection.grantId},
          );
          ref.read(activeTutoredProfileSelectionProvider.notifier).exit();
          dismissLoading();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context)!.tutoredEntryPermissionDenied,
                ),
              ),
            );
          }
        case TutoredPullResult.error:
          AppLogger.instance.warning(
            event: 'tutored_pull_error',
            fields: {'grantId': selection.grantId},
          );
          ref.read(activeTutoredProfileSelectionProvider.notifier).exit();
          dismissLoading();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.tutoredEntryError),
              ),
            );
          }
      }
    } on StateError catch (e) {
      // buildTutoredPullServiceFromWidget throws StateError for non-cloud accounts.
      AppLogger.instance.warning(
        event: 'tutored_pull_aborted',
        fields: {'error': e.toString()},
      );
      ref.read(activeTutoredProfileSelectionProvider.notifier).exit();
      dismissLoading();
      // AUD-profiles-10 (EH-2/UX completeness): give feedback consistent with
      // the permissionDenied/error branches above — without this the user
      // taps the row, watches the spinner, and it disappears with zero
      // explanation, indistinguishable from a silent hang.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.tutoredEntryAborted),
          ),
        );
      }
    }
  }
}

// ManageTutorsScreen — W6.11
//
// Parent perspective: shows per-child sections of active tutors + pending
// invites. Each row has a Revoke (active) or Rescind (pending) action button.
// Tapping a tutor row opens the audit log viewer (W6.13) for that grant.
//
// Wired to:
//   ListOutgoingTutorGrantsUseCase  — list grants per child
//   RevokeTutorGrantUseCase         — revoke active grant
//   RescindTutorInviteUseCase       — rescind pending invite

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/providers/tutored_pull_providers.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_invite_use_cases.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/manage_tutors_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

@RoutePage()
class ManageTutorsScreen extends ConsumerWidget {
  const ManageTutorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(profileListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: context.colors.brandCream,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.manageTutors),
        backgroundColor: context.colors.brandCream,
        elevation: 0,
      ),
      body: profilesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => AppErrorView(
          error: e,
          stackTrace: st,
          onRetry: () => ref.refresh(profileListProvider),
        ),
        data: (allProfiles) {
          // Tutors are granted access to a specific CHILD only — an adult
          // profile is never tutored, so it must not appear here.
          final children = allProfiles
              .where((p) => p.profileMode == ProfileMode.child)
              .toList();
          if (children.isEmpty) {
            return _EmptyProfilesView(theme: theme);
          }
          return _PerChildGrantsList(profiles: children);
        },
      ),
    );
  }
}

class _EmptyProfilesView extends StatelessWidget {
  const _EmptyProfilesView({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.school_outlined,
              size: 56,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.manageTutorsEmptyHeading,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.manageTutorsEmptyBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// DG-TUT-STALE-01 (P0): the owner's outgoing-grants list must reliably reflect
/// a REMOTE acceptance by the tutor. `outgoingTutorGrantsProvider` is a one-shot
/// autoDispose FutureProvider over the `listTutorGrants` Cloud Function; the CF
/// returns the correct (Active) state on a fresh fetch, but the view did not
/// reliably re-query on re-entry (eventual consistency / autoDispose not always
/// evicting). This widget forces a fresh query so the parent is never stuck
/// seeing an accepted grant as "Pending":
///   (a) PULL-TO-REFRESH (RefreshIndicator) invalidates every child's provider.
///   (b) re-fetch whenever the screen is (re)shown — on initState and on
///       app-resume — so a fresh entry always re-queries.
class _PerChildGrantsList extends ConsumerStatefulWidget {
  const _PerChildGrantsList({required this.profiles});

  final List<ProfileModel> profiles;

  @override
  ConsumerState<_PerChildGrantsList> createState() =>
      _PerChildGrantsListState();
}

class _PerChildGrantsListState extends ConsumerState<_PerChildGrantsList>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // (b) Re-query on first (re)show so re-entering the screen always fetches
    // the current grant state rather than serving a stale autoDispose cache.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshAll());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // (b) Re-query on app-resume — a tutor may have accepted while the owner
    // was backgrounded; refresh so the grant flips to Active on return.
    if (state == AppLifecycleState.resumed) {
      _refreshAll();
    }
  }

  /// Invalidate every child's outgoing-grants provider so each re-runs the
  /// `listTutorGrants` CF and reflects the latest server state.
  void _refreshAll() {
    if (!mounted) return;
    for (final profile in widget.profiles) {
      ref.invalidate(outgoingTutorGrantsProvider(profile.id.toString()));
    }
  }

  Future<void> _onRefresh() async {
    _refreshAll();
    // Await the re-fetch of every child's provider so the RefreshIndicator
    // spinner stays until fresh data is in (or an error surfaces).
    await Future.wait([
      for (final profile in widget.profiles)
        ref.read(outgoingTutorGrantsProvider(profile.id.toString()).future),
    ]).catchError((_) => const <List<TutorGrant>>[]);
  }

  @override
  Widget build(BuildContext context) {
    // (a) Pull-to-refresh. AlwaysScrollableScrollPhysics so the gesture works
    // even when the list is short and would not otherwise scroll.
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: widget.profiles.length,
        itemBuilder: (context, index) {
          final profile = widget.profiles[index];
          return _ChildGrantsSection(profile: profile);
        },
      ),
    );
  }
}

class _ChildGrantsSection extends ConsumerWidget {
  const _ChildGrantsSection({required this.profile});

  final ProfileModel profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final grantsAsync = ref.watch(
      outgoingTutorGrantsProvider(profile.id.toString()),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            profile.displayName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.colors.brandBlue,
            ),
          ),
        ),
        grantsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: LinearProgressIndicator(),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            // AUD-tutoring-11: never interpolate the raw exception text into
            // UI copy (EH-5) — a fixed localized string still distinguishes
            // this from "No tutors invited." (R-TU2: a load failure must
            // never be masked as an empty roster).
            child: Text(
              l10n.manageTutorsLoadErrorGeneric,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
          data: (grants) {
            if (grants.isEmpty) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  l10n.manageTutorsNoTutors,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }

            final active = grants
                .where((g) => g.grantState is ActiveGrant)
                .toList();
            final pending = grants
                .where((g) => g.grantState is PendingGrant)
                .toList();

            // AUD-tutoring-08 (PF-2, verify-correction site): flatten
            // headers + rows and build via ListView.builder rather than
            // eagerly expanding every tutor row with a `for` loop inside a
            // plain Column, matching the fix applied to ManageGrantsScreen.
            final items = <_TutorGrantListItem>[
              if (active.isNotEmpty) ...[
                _TutorGrantHeaderItem(
                  l10n.manageTutorsActiveSection(active.length),
                ),
                for (final grant in active)
                  _TutorGrantRowItem(grant: grant, isActive: true),
              ],
              if (pending.isNotEmpty) ...[
                _TutorGrantHeaderItem(
                  l10n.manageTutorsPendingSection(pending.length),
                ),
                for (final grant in pending)
                  _TutorGrantRowItem(grant: grant, isActive: false),
              ],
            ];

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return switch (item) {
                  _TutorGrantHeaderItem(:final label) => _SectionDivider(
                    label: label,
                  ),
                  _TutorGrantRowItem(:final grant, :final isActive) =>
                    isActive
                        ? _TutorGrantRow.active(
                            grant: grant,
                            childProfileId: profile.id.toString(),
                            childName: profile.displayName,
                          )
                        : _TutorGrantRow.pending(
                            grant: grant,
                            childProfileId: profile.id.toString(),
                            childName: profile.displayName,
                          ),
                };
              },
            );
          },
        ),
        // WS3.3f: "Invite a tutor" button — always visible per child section
        // so the parent can add a tutor even when one is already active.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: OutlinedButton.icon(
            onPressed: () => context.pushRoute(
              InviteTutorRoute(childProfileId: profile.id.toString()),
            ),
            icon: const Icon(Icons.person_add_rounded, size: 18),
            label: Text(l10n.manageTutorsInviteButton),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.brandBlue,
              side: BorderSide(
                color: context.colors.brandBlue.withValues(alpha: 0.5),
              ),
              minimumSize: const Size(double.infinity, 40),
            ),
          ),
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }
}

/// AUD-tutoring-08 (PF-2): a flattened row model so a child's tutor list can
/// be fed to a single [ListView.builder] instead of eagerly expanding a
/// `for` loop of widgets per section.
sealed class _TutorGrantListItem {
  const _TutorGrantListItem();
}

class _TutorGrantHeaderItem extends _TutorGrantListItem {
  const _TutorGrantHeaderItem(this.label);
  final String label;
}

class _TutorGrantRowItem extends _TutorGrantListItem {
  const _TutorGrantRowItem({required this.grant, required this.isActive});
  final TutorGrant grant;
  final bool isActive;
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.outline,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TutorGrantRow extends ConsumerStatefulWidget {
  const _TutorGrantRow.active({
    required this.grant,
    required this.childProfileId,
    required this.childName,
  }) : isActive = true;

  const _TutorGrantRow.pending({
    required this.grant,
    required this.childProfileId,
    required this.childName,
  }) : isActive = false;

  final TutorGrant grant;
  final String childProfileId;
  final String childName;
  final bool isActive;

  @override
  ConsumerState<_TutorGrantRow> createState() => _TutorGrantRowState();
}

class _TutorGrantRowState extends ConsumerState<_TutorGrantRow> {
  bool _acting = false;

  Future<void> _revoke() async {
    if (_acting) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await _showConfirmation(
      context,
      title: l10n.manageTutorsRevokeTitle,
      message: l10n.manageTutorsRevokeBody(widget.grant.tutorEmail),
      confirmLabel: l10n.manageTutorsRevoke,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _acting = true);
    try {
      final result = await ref
          .read(revokeTutorGrantUseCaseProvider)
          .call(grant: widget.grant);
      if (!mounted) return;
      // AUD-tutoring-01: the CF result must be checked before treating the
      // action as successful — a genuine server rejection (permission-denied,
      // already-revoked race, offline) must not wipe the local mirror or tell
      // the tutor their access was cut off while it is still active
      // server-side.
      switch (result) {
        case TutorGrantSuccess():
          // R4-M3: wipe the mirror and exit the tutored session so listeners
          // detach immediately rather than waiting for the next entry attempt.
          final grantId = widget.grant.grantId;
          unawaited(
            buildTutoredMirrorWipeServiceFromWidget(
              ref: ref,
              onWipe: (_) => ref
                  .read(activeTutoredProfileSelectionProvider.notifier)
                  .exit(),
            ).wipeMirrorForGrant(grantId),
          );
          ref.invalidate(outgoingTutorGrantsProvider(widget.childProfileId));
          // WS3.3g: fire-and-forget notification — tutor is notified of
          // revocation. Parent name from current auth user; falls back to
          // 'Parent' if unavailable.
          final parentName =
              ref.read(authRepositoryProvider).currentUser?.displayName ??
              l10n.tutorFallbackParent;
          unawaited(
            ref
                .read(tutorNotificationGatewayProvider)
                .notifyTutorOfRevocation(
                  tutorEmail: widget.grant.tutorEmail,
                  parentName: parentName,
                  childName: widget.childName,
                ),
          );
        case TutorGrantFailure(:final code):
          AppLogger.instance.error(
            event: 'Tutor grant revoke rejected by server',
            fields: {'code': code ?? 'unknown'},
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.manageTutorsRevokeErrorGeneric)),
          );
        case TutorGrantPreconditionError():
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.manageTutorsRevokeErrorGeneric)),
          );
      }
    } catch (e, st) {
      // AUD-tutoring-11: log the real exception for diagnostics, but never
      // interpolate its raw text into UI copy (EH-5).
      AppLogger.instance.error(
        event: 'Failed to revoke tutor grant',
        exception: e,
        stackTrace: st,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.manageTutorsRevokeErrorGeneric)),
        );
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _rescind() async {
    if (_acting) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await _showConfirmation(
      context,
      title: l10n.manageTutorsRescindTitle,
      message: l10n.manageTutorsRescindBody(widget.grant.tutorEmail),
      confirmLabel: l10n.manageTutorsRescind,
      isDestructive: false,
    );
    if (!confirmed || !mounted) return;

    setState(() => _acting = true);
    try {
      final result = await ref
          .read(rescindTutorInviteUseCaseProvider)
          .call(grant: widget.grant);
      if (!mounted) return;
      // AUD-tutoring-01: check the CF result before invalidating the grants
      // list as if the rescind succeeded.
      switch (result) {
        case TutorGrantSuccess():
          ref.invalidate(outgoingTutorGrantsProvider(widget.childProfileId));
        case TutorGrantFailure(:final code):
          AppLogger.instance.error(
            event: 'Tutor invite rescind rejected by server',
            fields: {'code': code ?? 'unknown'},
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.manageTutorsRescindErrorGeneric)),
          );
        case TutorGrantPreconditionError():
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.manageTutorsRescindErrorGeneric)),
          );
      }
    } catch (e, st) {
      // AUD-tutoring-11: log the real exception for diagnostics, but never
      // interpolate its raw text into UI copy (EH-5).
      AppLogger.instance.error(
        event: 'Failed to rescind tutor invite',
        exception: e,
        stackTrace: st,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.manageTutorsRescindErrorGeneric)),
        );
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  void _openAuditLog() {
    context.router.push(
      TutorAuditLogRoute(
        grantId: widget.grant.grantId,
        tutorEmail: widget.grant.tutorEmail,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final grantState = widget.grant.grantState;

    final statusColor = grantState is ActiveGrant
        ? context.colors.statusActiveBadge
        : context.colors.statusPendingBadge;
    final statusLabel = grantState is ActiveGrant
        ? l10n.statusActive
        : l10n.statusPending;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: statusColor.withValues(alpha: 0.15),
        child: Icon(
          grantState is ActiveGrant
              ? Icons.school_rounded
              : Icons.hourglass_top_rounded,
          color: statusColor,
          size: 20,
        ),
      ),
      title: Text(
        widget.grant.tutorEmail,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        statusLabel,
        style: theme.textTheme.bodySmall?.copyWith(color: statusColor),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.isActive)
            IconButton(
              icon: const Icon(Icons.history_rounded),
              tooltip: l10n.manageTutorsViewAuditLog,
              onPressed: _openAuditLog,
              color: context.colors.brandBlue,
              iconSize: 20,
            ),
          if (_acting)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            TextButton(
              onPressed: widget.isActive ? _revoke : _rescind,
              style: TextButton.styleFrom(
                foregroundColor: widget.isActive
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(
                widget.isActive
                    ? l10n.manageTutorsRevoke
                    : l10n.manageTutorsRescind,
              ),
            ),
        ],
      ),
    );
  }

  Future<bool> _showConfirmation(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    required bool isDestructive,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppLocalizations.of(ctx)!.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: isDestructive
                ? TextButton.styleFrom(
                    foregroundColor: Theme.of(ctx).colorScheme.error,
                  )
                : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

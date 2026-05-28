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
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/sync/providers/tutored_pull_providers.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    hide authStateProvider;
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
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
      backgroundColor: AppTheme.brandCream,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.manageTutors),
        backgroundColor: AppTheme.brandCream,
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

class _PerChildGrantsList extends ConsumerWidget {
  const _PerChildGrantsList({required this.profiles});

  final List<ProfileModel> profiles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: profiles.length,
      itemBuilder: (context, index) {
        final profile = profiles[index];
        return _ChildGrantsSection(profile: profile);
      },
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
              color: AppTheme.brandBlue,
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
            child: Text(
              l10n.manageTutorsLoadError(e.toString()),
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
                    color: theme.colorScheme.outline,
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

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (active.isNotEmpty) ...[
                  _SectionDivider(
                    label: l10n.manageTutorsActiveSection(active.length),
                  ),
                  for (final grant in active)
                    _TutorGrantRow.active(
                      grant: grant,
                      childProfileId: profile.id.toString(),
                      childName: profile.displayName,
                    ),
                ],
                if (pending.isNotEmpty) ...[
                  _SectionDivider(
                    label: l10n.manageTutorsPendingSection(pending.length),
                  ),
                  for (final grant in pending)
                    _TutorGrantRow.pending(
                      grant: grant,
                      childProfileId: profile.id.toString(),
                      childName: profile.displayName,
                    ),
                ],
              ],
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
              foregroundColor: AppTheme.brandBlue,
              side: BorderSide(
                color: AppTheme.brandBlue.withValues(alpha: 0.5),
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
      await ref.read(revokeTutorGrantUseCaseProvider).call(grant: widget.grant);
      if (mounted) {
        // R4-M3: wipe the mirror and exit the tutored session so listeners
        // detach immediately rather than waiting for the next entry attempt.
        final grantId = widget.grant.grantId;
        unawaited(
          buildTutoredMirrorWipeServiceFromWidget(
            ref: ref,
            onWipe: (_) =>
                ref.read(activeTutoredProfileSelectionProvider.notifier).exit(),
          ).wipeMirrorForGrant(grantId),
        );
        ref.invalidate(outgoingTutorGrantsProvider(widget.childProfileId));
        // WS3.3g: fire-and-forget notification — tutor is notified of revocation.
        // Parent name from current auth user; falls back to 'Parent' if unavailable.
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
      }
    } catch (e, st) {
      AppLogger.instance.error(
        event: 'Failed to revoke tutor grant',
        exception: e,
        stackTrace: st,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.manageTutorsRevokeError(e.toString()))),
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
      await ref
          .read(rescindTutorInviteUseCaseProvider)
          .call(grant: widget.grant);
      if (mounted) {
        ref.invalidate(outgoingTutorGrantsProvider(widget.childProfileId));
      }
    } catch (e, st) {
      AppLogger.instance.error(
        event: 'Failed to rescind tutor invite',
        exception: e,
        stackTrace: st,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.manageTutorsRescindError(e.toString()))),
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
        ? Colors.green.shade600
        : Colors.orange.shade700;
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
              color: AppTheme.brandBlue,
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

// ManageGrantsScreen — W6.12
//
// Tutor perspective: shows all children this user tutors (active grants)
// with parent context. Each row has a Resign button.
//
// Wired to:
//   ListIncomingTutorAccessUseCase — list grants where caller is tutor
//   ResignTutorGrantUseCase        — resign from an active grant

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    hide authStateProvider;
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/manage_tutors_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

@RoutePage()
class ManageGrantsScreen extends ConsumerStatefulWidget {
  const ManageGrantsScreen({super.key});

  @override
  ConsumerState<ManageGrantsScreen> createState() => _ManageGrantsScreenState();
}

class _ManageGrantsScreenState extends ConsumerState<ManageGrantsScreen> {
  // H1: When the tutor backs out of the talmid view, clear the active tutored
  // selection so the keepAlive provider does not leave _isTutorSession true on
  // the tutor's OWN profile (re-creates the DEC-21 dual-role bug). onSessionLocked
  // never fires for the talmid view (no PIN lock there), so we clear it here on
  // pop of this route — the entry point for the talmid view.
  void _clearTutoredSelection() {
    if (ref.read(activeTutoredProfileSelectionProvider) != null) {
      ref.read(activeTutoredProfileSelectionProvider.notifier).exit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final grantsAsync = ref.watch(incomingTutorGrantsProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _clearTutoredSelection();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.manageGrantsAppBarTitle),
          backgroundColor: AppTheme.brandBlue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: grantsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => AppErrorView(
            error: e,
            stackTrace: st,
            onRetry: () => ref.refresh(incomingTutorGrantsProvider),
          ),
          data: (grants) {
            final activeGrants = grants
                .where((g) => g.grantState is ActiveGrant)
                .toList();
            final pendingGrants = grants
                .where((g) => g.grantState is PendingGrant)
                .toList();

            if (grants.isEmpty) {
              return _EmptyGrantsView(theme: theme);
            }

            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                if (activeGrants.isNotEmpty) ...[
                  _SectionHeader(
                    label: l10n.manageGrantsActiveSection(activeGrants.length),
                    theme: theme,
                  ),
                  for (final grant in activeGrants)
                    _GrantRow(grant: grant, canResign: true),
                  const SizedBox(height: 8),
                ],
                if (pendingGrants.isNotEmpty) ...[
                  _SectionHeader(
                    label: l10n.manageGrantsPendingSection(
                      pendingGrants.length,
                    ),
                    theme: theme,
                  ),
                  for (final grant in pendingGrants)
                    _GrantRow(grant: grant, canResign: false),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EmptyGrantsView extends StatelessWidget {
  const _EmptyGrantsView({required this.theme});
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
              l10n.manageGrantsEmptyHeading,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.manageGrantsEmptyBody,
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.theme});
  final String label;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
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

class _GrantRow extends ConsumerStatefulWidget {
  const _GrantRow({required this.grant, required this.canResign});

  final TutorGrant grant;
  final bool canResign;

  @override
  ConsumerState<_GrantRow> createState() => _GrantRowState();
}

class _GrantRowState extends ConsumerState<_GrantRow> {
  bool _acting = false;

  Future<void> _resign() async {
    if (_acting) return;

    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.manageGrantsResignTitle),
        content: Text(
          l10n.manageGrantsResignBody(
            widget.grant.childDisplayLabel,
            widget.grant.parentDisplayLabel,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l10n.manageGrantsResign),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _acting = true);
    try {
      await ref.read(resignTutorGrantUseCaseProvider).call(grant: widget.grant);
      if (mounted) {
        ref.invalidate(incomingTutorGrantsProvider);
        // WS3.3g / M1: fire-and-forget notification — parent is notified of the
        // resignation. The parent email is not readable from the grant doc (UID
        // only), so we route by parentUid; the gateway falls back to a
        // uid-addressed recipient so the notification is not dropped.
        final currentUser = ref.read(authRepositoryProvider).currentUser;
        final tutorName =
            currentUser?.displayName ??
            currentUser?.email ??
            l10n.tutorFallbackName;
        unawaited(
          ref
              .read(tutorNotificationGatewayProvider)
              .notifyParentOfResignation(
                parentEmail: '',
                parentUid: widget.grant.parentUid,
                tutorName: tutorName,
                childName: widget.grant.childProfileId,
              ),
        );
      }
    } catch (e, st) {
      AppLogger.instance.error(
        event: 'Failed to resign tutor grant',
        exception: e,
        stackTrace: st,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.manageGrantsResignError(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isActive = widget.grant.grantState is ActiveGrant;
    final statusColor = isActive
        ? Colors.green.shade600
        : Colors.orange.shade700;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppTheme.brandBlue.withValues(alpha: 0.12),
        child: const Icon(
          Icons.child_care_rounded,
          color: AppTheme.brandBlue,
          size: 20,
        ),
      ),
      title: Text(
        // M3: show the denormalised child name when available, otherwise a
        // friendly generic label — never the raw Firestore profile id.
        widget.grant.childDisplayLabel,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            // M3: human parent label instead of the raw UID.
            widget.grant.parentDisplayLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isActive ? l10n.statusActive : l10n.statusPending,
              style: theme.textTheme.labelSmall?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      isThreeLine: true,
      trailing: widget.canResign
          ? (_acting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton(
                    onPressed: _resign,
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: Text(l10n.manageGrantsResign),
                  ))
          : null,
    );
  }
}

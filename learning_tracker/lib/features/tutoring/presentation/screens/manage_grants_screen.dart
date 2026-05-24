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
import 'package:learning_tracker/features/tutoring/presentation/providers/manage_tutors_providers.dart';

@RoutePage()
class ManageGrantsScreen extends ConsumerWidget {
  const ManageGrantsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grantsAsync = ref.watch(incomingTutorGrantsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tutoring Grants'),
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
                  label: 'Active (${activeGrants.length})',
                  theme: theme,
                ),
                for (final grant in activeGrants)
                  _GrantRow(grant: grant, canResign: true),
                const SizedBox(height: 8),
              ],
              if (pendingGrants.isNotEmpty) ...[
                _SectionHeader(
                  label: 'Pending invites (${pendingGrants.length})',
                  theme: theme,
                ),
                for (final grant in pendingGrants)
                  _GrantRow(grant: grant, canResign: false),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _EmptyGrantsView extends StatelessWidget {
  const _EmptyGrantsView({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
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
              'No tutoring relationships',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When a parent invites you to tutor their child, '
              'the grant will appear here.',
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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resign from tutoring?'),
        content: Text(
          'You will immediately lose access to this child\'s profile. '
          'The parent will be notified.\n\n'
          'Child profile: ${widget.grant.childProfileId}\n'
          'Parent: ${widget.grant.parentUid}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Resign'),
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
        // WS3.3g: fire-and-forget notification — parent is notified of resignation.
        // Tutor name from current auth user; parent email not available on grant
        // (no email field on TutorGrant — parent UID only), so we pass empty string;
        // the logging implementation absorbs silently.
        final currentUser = ref.read(authRepositoryProvider).currentUser;
        final tutorName =
            currentUser?.displayName ?? currentUser?.email ?? 'Your tutor';
        unawaited(
          ref
              .read(tutorNotificationGatewayProvider)
              .notifyParentOfResignation(
                parentEmail: '', // Parent email not available from grant doc
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not resign: $e')));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
        // TODO(data-layer): replace with child display name resolved from
        // profile (requires cross-uid read; will be resolved by parent's
        // Firestore data or passed via the grant document in v2).
        'Child profile: ${widget.grant.childProfileId}',
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
            'Parent UID: ${widget.grant.parentUid}',
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
              isActive ? 'Active' : 'Pending',
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
                    child: const Text('Resign'),
                  ))
          : null,
    );
  }
}

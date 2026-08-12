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
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_invite_use_cases.dart';
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
        backgroundColor: context.colors.brandCream,
        appBar: AppBar(
          title: Text(l10n.manageGrantsAppBarTitle),
          backgroundColor: context.colors.brandCream,
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

            // AUD-tutoring-08 (PF-2): flatten headers + rows into a single
            // lazily-built item list instead of eagerly expanding every row
            // via a `for` loop inside a non-lazy ListView. A dedicated
            // tutor (e.g. a rebbi/melamed tracking many talmidim across
            // seasons — the tutoring feature's own stated use case)
            // accumulates one grant per student relationship over time with
            // no archiving path, so this roster is not bounded small.
            final items = <_GrantListItem>[
              if (activeGrants.isNotEmpty) ...[
                _GrantHeaderItem(
                  l10n.manageGrantsActiveSection(activeGrants.length),
                ),
                for (final grant in activeGrants)
                  _GrantRowItem(grant: grant, canResign: true),
                const _GrantSpacerItem(),
              ],
              if (pendingGrants.isNotEmpty) ...[
                _GrantHeaderItem(
                  l10n.manageGrantsPendingSection(pendingGrants.length),
                ),
                for (final grant in pendingGrants)
                  _GrantRowItem(grant: grant, canResign: false),
              ],
            ];

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return switch (item) {
                  _GrantHeaderItem(:final label) => _SectionHeader(
                    label: label,
                    theme: theme,
                  ),
                  _GrantRowItem(:final grant, :final canResign) => _GrantRow(
                    grant: grant,
                    canResign: canResign,
                  ),
                  _GrantSpacerItem() => const SizedBox(height: 8),
                };
              },
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

/// AUD-tutoring-08 (PF-2): a flattened row model so the grants list can be
/// fed to a single lazy [ListView.builder] instead of eagerly expanding a
/// `for` loop of widgets per section.
sealed class _GrantListItem {
  const _GrantListItem();
}

class _GrantHeaderItem extends _GrantListItem {
  const _GrantHeaderItem(this.label);
  final String label;
}

class _GrantRowItem extends _GrantListItem {
  const _GrantRowItem({required this.grant, required this.canResign});
  final TutorGrant grant;
  final bool canResign;
}

class _GrantSpacerItem extends _GrantListItem {
  const _GrantSpacerItem();
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

  /// P2 (M3): the grant OWNER's display name for UI — the denormalised
  /// [TutorGrant.parentName] when it is a genuine human name, otherwise a
  /// localized relationship fallback. Never the raw UID and never a server
  /// placeholder token like "CloudUser".
  String _ownerLabel(AppLocalizations l10n) =>
      widget.grant.parentName ?? l10n.tutorFallbackParent;

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
            _ownerLabel(l10n),
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
      final result = await ref
          .read(resignTutorGrantUseCaseProvider)
          .call(grant: widget.grant);
      if (!mounted) return;
      // AUD-tutoring-01: the CF result must be checked before treating the
      // action as successful — the sibling invite/accept/decline screens
      // already switch exhaustively on TutorGrantResult; this row previously
      // discarded the result and ran the success side effects unconditionally,
      // so a genuine server rejection (permission-denied, already-resigned
      // race, offline) still wiped the local mirror and told the parent the
      // resignation succeeded.
      switch (result) {
        case TutorGrantSuccess():
          // Exit an active tutored session if this is the grant being resigned.
          if (widget.grant.grantId ==
              ref.read(activeTutoredProfileSelectionProvider)?.grantId) {
            ref.read(activeTutoredProfileSelectionProvider.notifier).exit();
          }
          ref.invalidate(incomingTutorGrantsProvider);
          // WS3.3g / M1: fire-and-forget notification — parent is notified of
          // the resignation. The parent email is not readable from the grant
          // doc (UID only), so we route by parentUid; the gateway falls back
          // to a uid-addressed recipient so the notification is not dropped.
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
                  // GA-5: use the human-readable display label, not the raw
                  // Firestore profile id (childProfileId was a string like
                  // "raw_firestore_profile_id_123" — not a child name).
                  childName: widget.grant.childDisplayLabel,
                ),
          );
        case TutorGrantFailure(:final code):
          AppLogger.instance.error(
            event: 'Tutor grant resign rejected by server',
            fields: {'code': code ?? 'unknown'},
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.manageGrantsResignErrorGeneric)),
          );
        case TutorGrantPreconditionError():
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.manageGrantsResignErrorGeneric)),
          );
      }
    } catch (e, st) {
      // AUD-tutoring-11: log the real exception for diagnostics, but never
      // interpolate its raw text into UI copy — a Hebrew sentence must not
      // end in an untranslated English/gRPC fragment (EH-5).
      AppLogger.instance.error(
        event: 'Failed to resign tutor grant',
        exception: e,
        stackTrace: st,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.manageGrantsResignErrorGeneric)),
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
        ? context.colors.statusActiveBadge
        : context.colors.statusPendingBadge;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: context.colors.brandBlue.withValues(alpha: 0.12),
        child: Icon(
          Icons.child_care_rounded,
          color: context.colors.brandBlue,
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
            // M3: human parent label instead of the raw UID. Falls back to a
            // localized relationship label when the owner name is unavailable
            // or a server placeholder (never the literal "CloudUser").
            _ownerLabel(l10n),
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

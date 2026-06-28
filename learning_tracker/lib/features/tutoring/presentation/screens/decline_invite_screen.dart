// W6.10 — Decline pending invite flow (FR-2.5)
//
// Shown when a tutor user receives a tutor invite and wants to decline it.
//
// Can be triggered:
//   (a) From the AcceptInviteScreen "Decline" button (token known, no TutorGrant
//       aggregate available locally — build a stub grant from the token).
//   (b) From the ManageGrantsScreen (TutorGrant already loaded locally).
//
// Flow:
//   1. Confirmation step — asks the user if they are sure.
//   2. Calls DeclineTutorInviteUseCase.
//   3. On success: shows a brief success message and calls [onDeclined].
//   4. On error: shows inline error with retry option.

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    hide authStateProvider;
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_invite_use_cases.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/manage_tutors_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_grant_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// A full-page screen for declining a pending tutor invite.
///
/// Accepts either:
///   • [token] — raw invite token string when navigating from a deep-link;
///     the screen builds a minimal stub grant internally.
///   • [grant] — a locally loaded [TutorGrant] when navigating from the
///     grant management UI.
///
/// Exactly one of [token] or [grant] must be non-null.
///
/// [onDeclined] is called after a successful decline so the caller can
/// navigate away (e.g. pop, or go to dashboard).
@RoutePage()
class DeclineInviteScreen extends ConsumerStatefulWidget {
  const DeclineInviteScreen({
    this.token,
    this.grant,
    required this.onDeclined,
    super.key,
  }) : assert(
         (token != null) != (grant != null),
         'Exactly one of token or grant must be provided.',
       );

  /// Raw invite token (from deep-link). Used when no [TutorGrant] is available.
  final String? token;

  /// Pre-loaded [TutorGrant] aggregate. Used when navigating from the
  /// grant-management screen.
  final TutorGrant? grant;

  /// Called after the invite is successfully declined.
  final VoidCallback onDeclined;

  @override
  ConsumerState<DeclineInviteScreen> createState() =>
      _DeclineInviteScreenState();
}

enum _DeclineStep { confirm, declining, success, error }

class _DeclineInviteScreenState extends ConsumerState<DeclineInviteScreen> {
  _DeclineStep _step = _DeclineStep.confirm;
  String? _errorMessage;

  /// Resolve the grant to pass to the use case.
  ///
  /// If [widget.grant] is provided, use it directly. Otherwise build a
  /// minimal stub from [widget.token] — the Cloud Function validates
  /// ownership and expiry server-side.
  TutorGrant _resolveGrant() {
    if (widget.grant != null) return widget.grant!;
    final token = widget.token!;
    final now = DateTimeFactory.nowUtc();
    final doc = TutorGrantDoc(
      grantId: token,
      parentUid: '',
      childProfileId: '',
      tutorEmail: '',
      state: TutorGrantState.pending,
      invitedAt: now,
      updatedAt: now,
      expiresAt: now.add(const Duration(days: 7)),
    );
    return TutorGrant.fromDoc(doc);
  }

  Future<void> _declineInvite() async {
    setState(() {
      _step = _DeclineStep.declining;
      _errorMessage = null;
    });
    try {
      final useCase = ref.read(declineTutorInviteUseCaseProvider);
      final grant = _resolveGrant();
      final result = await useCase(grant: grant);
      if (!mounted) return;
      switch (result) {
        case TutorGrantSuccess():
          setState(() => _step = _DeclineStep.success);
          // WS3.3g / M1: fire-and-forget DEC-23 notification — parent is
          // notified of the decline. The parent email is not readable from the
          // grant doc (UID only), so we route by parentUid; the gateway falls
          // back to a uid-addressed recipient so the notification is not dropped.
          final tutorEmail =
              ref.read(authRepositoryProvider).currentUser?.email ??
              grant.tutorEmail;
          unawaited(
            ref
                .read(tutorNotificationGatewayProvider)
                .notifyParentOfDecline(
                  parentEmail: '',
                  parentUid: grant.parentUid,
                  tutorEmail: tutorEmail,
                  // GA-5: use the human-readable display label, not the raw
                  // Firestore profile id (childProfileId was a raw string id,
                  // not a child name).
                  childName: grant.childDisplayLabel,
                ),
          );
        case TutorGrantFailure():
          // Never surface raw Firebase/gRPC codes (e.g. "UNAVAILABLE") to
          // the user — always map to a friendly, localized message.
          setState(() {
            _step = _DeclineStep.error;
            _errorMessage = AppLocalizations.of(
              context,
            )!.declineInviteGenericError;
          });
        case TutorGrantPreconditionError(:final message):
          setState(() {
            _step = _DeclineStep.error;
            _errorMessage = message;
          });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _step = _DeclineStep.error;
          _errorMessage = AppLocalizations.of(
            context,
          )!.declineInviteGenericError;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.brandCream,
      appBar: AppBar(
        backgroundColor: AppTheme.brandCream,
        elevation: 0,
        title: Text(AppLocalizations.of(context)!.declineInviteAppBarTitle),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _buildBody(theme),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    return switch (_step) {
      _DeclineStep.confirm => _buildConfirm(theme),
      _DeclineStep.declining => _buildDeclining(),
      _DeclineStep.success => _buildSuccess(theme),
      _DeclineStep.error => _buildError(theme),
    };
  }

  Widget _buildConfirm(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    // Wrap in LayoutBuilder + SingleChildScrollView + ConstrainedBox +
    // IntrinsicHeight so the layout scrolls (instead of overflowing with a
    // RenderFlex error) on short / keyboard-visible viewports and at large
    // text scales. IntrinsicHeight gives the Column a finite height inside the
    // unbounded scroll view so the flexible Spacer can push the actions to the
    // bottom when there is spare room (ConstrainedBox(minHeight: maxHeight)
    // stretches the column to fill a tall viewport); when the content is
    // taller than the viewport the column takes its natural height and the
    // scroll view scrolls.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : 0,
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),
                  const CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.statusWarningSoft,
                    child: Icon(
                      Icons.do_not_disturb_on_rounded,
                      size: 36,
                      color: Color(0xFFB07A00),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.declineInviteConfirmHeading,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.brandInk,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.declineInviteConfirmBody,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppTheme.brandInkMuted,
                      height: 1.4,
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _declineInvite,
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(l10n.declineInviteConfirm),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => context.router.pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.brandInk,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(l10n.actionCancel),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeclining() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(l10n.declineInviteInProgress),
        ],
      ),
    );
  }

  Widget _buildSuccess(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    // Centred fixed pile — wrap in a height-clamped scroll view so it stays
    // vertically centred on normal screens but scrolls (rather than
    // overflowing) on short viewports / large text.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : 0,
            ),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: Color(0xFFEAF5EA),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 48,
                      color: Color(0xFF3A7C3A),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.declineInviteSuccessHeading,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.brandInk,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.declineInviteSuccessBody,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppTheme.brandInkMuted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: () => unawaited(
                      context.router.replaceAll([const AppShellRoute()]),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(l10n.actionGoToDashboard),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildError(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    // Centred fixed pile — wrap in a height-clamped scroll view so it stays
    // vertically centred on normal screens but scrolls (rather than
    // overflowing) on short viewports / large text.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : 0,
            ),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.red.shade50,
                    child: Icon(
                      Icons.error_rounded,
                      size: 48,
                      color: Colors.red.shade600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.declineInviteErrorHeading,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.brandInk,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage ?? l10n.unexpectedError,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppTheme.brandInkMuted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),
                  OutlinedButton(
                    onPressed: () =>
                        setState(() => _step = _DeclineStep.confirm),
                    child: Text(l10n.actionTryAgain),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

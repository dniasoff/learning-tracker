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
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_invite_use_cases.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_grant_providers.dart';

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
    final now = DateTime.now().toUtc();
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
        case TutorGrantFailure(:final message):
          setState(() {
            _step = _DeclineStep.error;
            _errorMessage = message;
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
          _errorMessage = 'Unable to decline invite. Please try again.';
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
        title: const Text('Decline Invite'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        const CircleAvatar(
          radius: 36,
          backgroundColor: Color(0xFFFFF3CD),
          child: Icon(
            Icons.do_not_disturb_on_rounded,
            size: 36,
            color: Color(0xFFB07A00),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Decline tutor invite?',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppTheme.brandInk,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'You are about to decline this tutor invite. '
          'The parent will be notified that you declined. '
          'You will not have access to this child\'s learning profile.',
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
          child: const Text('Decline invite'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => context.router.pop(),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.brandInk,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: const StadiumBorder(),
          ),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildDeclining() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Declining invite…'),
        ],
      ),
    );
  }

  Widget _buildSuccess(ThemeData theme) {
    return Column(
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
          'Invite declined',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppTheme.brandInk,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'You have declined this tutor invite. '
          'The parent has been notified.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: AppTheme.brandInkMuted,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () =>
              unawaited(context.router.replaceAll([const AppShellRoute()])),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: const StadiumBorder(),
          ),
          child: const Text('Go to dashboard'),
        ),
      ],
    );
  }

  Widget _buildError(ThemeData theme) {
    return Column(
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
          'Could not decline invite',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppTheme.brandInk,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _errorMessage ?? 'An unexpected error occurred.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: AppTheme.brandInkMuted,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),
        OutlinedButton(
          onPressed: () => setState(() => _step = _DeclineStep.confirm),
          child: const Text('Try again'),
        ),
      ],
    );
  }
}

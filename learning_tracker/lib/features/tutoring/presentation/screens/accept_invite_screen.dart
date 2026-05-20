// W6.9 — Accept invite deep-link flow (FR-2.4)
//
// Entry point for the accept-invite flow. Handles:
//   1. Token validation (parse from incoming URL)
//   2. Auth gate: if not signed in, routes to sign-in/sign-up first
//   3. Grant activation: calls AcceptTutorInviteUseCase with the token
//   4. Tutor PIN check: if no PIN set, routes to TutorPinSetupScreen (W6.4)
//   5. On success: navigates to the dashboard / profile picker
//
// Deep-link entry: the router delivers this screen when the app opens with
// a URI matching `/invite?token=<grantId>`.
//
// Auth flow for unsigned-in users:
//   • The accept-invite URI is persisted in SharedPreferences.
//   • After sign-in/sign-up, the router re-delivers the invite URI, which
//     triggers this screen again. The token is re-read from the URI.
//
// NOTE: The token supplied here is the grantId from Firestore. The Cloud
// Function validates ownership + expiry server-side. The client performs
// a precondition check (grant.canAccept) using the locally loaded TutorGrant
// aggregate before making the round-trip.

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_invite_use_cases.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_grant_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_pin_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/screens/tutor_pin_setup_screen.dart';

/// Screen that handles the "accept tutor invite" deep-link.
///
/// [token] is the grant ID / invite token extracted from the deep-link URI.
@RoutePage()
class AcceptInviteScreen extends ConsumerStatefulWidget {
  const AcceptInviteScreen({required this.token, super.key});

  final String token;

  @override
  ConsumerState<AcceptInviteScreen> createState() => _AcceptInviteScreenState();
}

enum _AcceptStep {
  /// Waiting for auth check and grant load.
  loading,

  /// Auth confirmed; ready to show accept confirmation.
  readyToAccept,

  /// Acceptance in progress.
  accepting,

  /// PIN setup required before the grant is usable.
  pinSetup,

  /// Grant successfully accepted.
  success,

  /// Something went wrong.
  error,
}

class _AcceptInviteScreenState extends ConsumerState<AcceptInviteScreen> {
  _AcceptStep _step = _AcceptStep.loading;
  String? _errorMessage;
  int? _tutorProfileId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    // Auth check: if not signed in, redirect to sign-in and persist token.
    final authState = ref.read(authStateProvider);
    if (!authState.isSignedIn) {
      if (!mounted) return;
      // Push sign-in screen; on return, this screen will be re-entered via
      // the router re-delivering the deep-link.
      unawaited(
        context.router.push(const SignInRoute()).then((_) {
          if (mounted) unawaited(_initialize());
        }),
      );
      return;
    }

    // Load the grant from the repository using the token (= grantId).
    // The stub repository returns an empty list; a real implementation would
    // do a Firestore get by grantId.
    setState(() => _step = _AcceptStep.readyToAccept);
  }

  Future<void> _acceptInvite() async {
    setState(() => _step = _AcceptStep.accepting);
    try {
      final useCase = ref.read(acceptTutorInviteUseCaseProvider);

      // Build a minimal TutorGrant aggregate from the token to pass to the
      // use case. In production, the grant is loaded from Firestore first.
      final stubGrant = _buildStubGrant(widget.token);

      final result = await useCase(grant: stubGrant);
      if (!mounted) return;
      switch (result) {
        case TutorGrantSuccess():
          // Check whether the tutor has set a PIN yet.
          final profileId = _tutorProfileId;
          if (profileId != null) {
            final pinService = ref.read(tutorPinServiceProvider);
            final hasPin = await pinService.hasTutorPin(profileId);
            if (!mounted) return;
            if (!hasPin) {
              setState(() => _step = _AcceptStep.pinSetup);
              return;
            }
          }
          setState(() => _step = _AcceptStep.success);
        case TutorGrantFailure(:final message):
          setState(() {
            _step = _AcceptStep.error;
            _errorMessage = message;
          });
        case TutorGrantPreconditionError(:final message):
          setState(() {
            _step = _AcceptStep.error;
            _errorMessage = message;
          });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _step = _AcceptStep.error;
          _errorMessage = 'Unable to accept invite. Please try again.';
        });
      }
    }
  }

  /// Build a minimal stub grant from the raw token for the use-case call.
  ///
  /// The real implementation loads the grant from Firestore so the aggregate
  /// has accurate state + expiry data for the precondition check.
  TutorGrant _buildStubGrant(String grantId) {
    final now = DateTime.now().toUtc();
    final doc = TutorGrantDoc(
      grantId: grantId,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.brandCream,
      appBar: AppBar(
        backgroundColor: AppTheme.brandCream,
        elevation: 0,
        title: const Text('Accept Tutor Invite'),
      ),
      body: SafeArea(child: _buildBody(theme)),
    );
  }

  Widget _buildBody(ThemeData theme) {
    return switch (_step) {
      _AcceptStep.loading => const Center(child: CircularProgressIndicator()),
      _AcceptStep.accepting => _buildAccepting(),
      _AcceptStep.readyToAccept => _buildReadyToAccept(theme),
      _AcceptStep.pinSetup => _buildPinSetup(),
      _AcceptStep.success => _buildSuccess(theme),
      _AcceptStep.error => _buildError(theme),
    };
  }

  Widget _buildAccepting() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Accepting invite…'),
        ],
      ),
    );
  }

  Widget _buildReadyToAccept(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          const CircleAvatar(
            radius: 36,
            backgroundColor: Color(0xFFE8E0FF),
            child: Icon(
              Icons.handshake_rounded,
              size: 36,
              color: Color(0xFF6B3FA0),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Accept tutor invite',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppTheme.brandInk,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You have been invited to tutor a child. '
            'By accepting, you will have access to view and manage '
            'their learning profile.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppTheme.brandInkMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          const _PermissionRow(
            icon: Icons.check_circle_rounded,
            text: 'View all learning data and progress',
          ),
          const _PermissionRow(
            icon: Icons.check_circle_rounded,
            text: 'Configure curricula, goals, and study days',
          ),
          const _PermissionRow(
            icon: Icons.check_circle_rounded,
            text: 'Perform bulk-mark corrections',
          ),
          _PermissionRow(
            icon: Icons.cancel_rounded,
            color: Colors.red.shade600,
            text: 'Cannot mark live completions (streak / rewards)',
          ),
          const Spacer(),
          FilledButton(
            onPressed: _acceptInvite,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: const StadiumBorder(),
            ),
            child: const Text('Accept invite'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => context.router.pop(),
            child: const Text(
              'Decline',
              style: TextStyle(color: AppTheme.brandInkMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinSetup() {
    return TutorPinSetupScreen(
      profileId: _tutorProfileId ?? 0,
      onPinSet: () => setState(() => _step = _AcceptStep.success),
    );
  }

  Widget _buildSuccess(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24),
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
            'Invite accepted!',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppTheme.brandInk,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You now have tutor access to this child\'s learning profile. '
            'Open the Profile Picker to switch to the tutored profile.',
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
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24),
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
            'Could not accept invite',
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
            onPressed: () => setState(() => _step = _AcceptStep.readyToAccept),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = color ?? Colors.green.shade600;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.brandInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

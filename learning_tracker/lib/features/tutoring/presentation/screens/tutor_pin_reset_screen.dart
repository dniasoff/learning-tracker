// W6.6 — Tutor PIN reset flow via email verification (FR-5.5)
//
// Shown when the tutor taps "Forgot your Tutor PIN?" from the PIN entry gate.
//
// Flow:
//   1. User confirms their email address (pre-filled from Firebase Auth)
//   2. Firebase Auth sends a password-reset / custom-action email
//   3. User confirms email was sent
//   4. After email link is followed, the user is prompted to set a new PIN
//      (delegates back to TutorPinSetupScreen).
//
// The Firebase Auth `sendPasswordResetEmail` email is reused here as the
// reset mechanism — it is the standard Firebase pattern and does not require
// a custom email template. The Tutor PIN is device-local; clearing it here
// allows the user to create a new one on next sign-in.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_pin_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

enum _ResetStep { confirm, emailSent }

/// Screen that guides a tutor through resetting their Tutor PIN.
///
/// [profileId] is the tutor's own learner-profile ID (used to clear the stored
/// PIN after the reset flow completes).
///
/// [onResetComplete] is called after the user acknowledges the email was sent.
/// The caller should navigate to [TutorPinSetupScreen] to let the tutor create
/// a new PIN.
class TutorPinResetScreen extends ConsumerStatefulWidget {
  const TutorPinResetScreen({
    required this.profileId,
    required this.onResetComplete,
    super.key,
  });

  final int profileId;
  final VoidCallback onResetComplete;

  @override
  ConsumerState<TutorPinResetScreen> createState() =>
      _TutorPinResetScreenState();
}

class _TutorPinResetScreenState extends ConsumerState<TutorPinResetScreen> {
  _ResetStep _step = _ResetStep.confirm;
  bool _isSending = false;
  String? _errorMessage;

  String? get _currentEmail {
    final authRepo = ref.read(authRepositoryProvider);
    return authRepo.currentUser?.email;
  }

  Future<void> _sendResetEmail() async {
    final email = _currentEmail;
    if (email == null || email.isEmpty) {
      setState(
        () =>
            _errorMessage = AppLocalizations.of(context)!.tutorPinResetNoEmail,
      );
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });
    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.sendPasswordResetEmail(email);

      // Clear the local PIN so the user can re-create it after reset.
      final pinService = ref.read(tutorPinServiceProvider);
      await pinService.clearTutorPin(widget.profileId);

      if (!mounted) return;
      // Invalidate so TutorPinEntryGate sees pinIsSet = false.
      ref.invalidate(tutorPinIsSetProvider(widget.profileId));
      setState(() => _step = _ResetStep.emailSent);
    } catch (e) {
      if (mounted) {
        setState(
          () => _errorMessage = AppLocalizations.of(
            context,
          )!.tutorPinResetSendFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final email = _currentEmail ?? l10n.tutorPinResetFallbackEmail;

    return Scaffold(
      backgroundColor: AppTheme.brandCream,
      appBar: AppBar(
        backgroundColor: AppTheme.brandCream,
        elevation: 0,
        title: Text(l10n.tutorPinResetAppBarTitle),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: switch (_step) {
            _ResetStep.confirm => _buildConfirmStep(theme, email),
            _ResetStep.emailSent => _buildEmailSentStep(theme, email),
          },
        ),
      ),
    );
  }

  Widget _buildConfirmStep(ThemeData theme, String email) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        const CircleAvatar(
          radius: 36,
          backgroundColor: Color(0xFFFFF3CD),
          child: Icon(
            Icons.lock_reset_rounded,
            size: 36,
            color: Color(0xFFB07A00),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          l10n.tutorPinResetHeading,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppTheme.brandInk,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.tutorPinResetSendingTo,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: AppTheme.brandInkMuted,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          email,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: AppTheme.brandInk,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.tutorPinResetReturnHint,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppTheme.brandInkMuted,
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const Spacer(),
        FilledButton(
          onPressed: _isSending ? null : _sendResetEmail,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: const StadiumBorder(),
          ),
          child: _isSending
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(l10n.tutorPinResetSendButton),
        ),
      ],
    );
  }

  Widget _buildEmailSentStep(ThemeData theme, String email) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        const CircleAvatar(
          radius: 36,
          backgroundColor: Color(0xFFEAF5EA),
          child: Icon(
            Icons.mark_email_read_rounded,
            size: 36,
            color: Color(0xFF3A7C3A),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          l10n.tutorPinResetCheckEmailHeading,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppTheme.brandInk,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.tutorPinResetCheckEmailBody(email),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: AppTheme.brandInkMuted,
            height: 1.4,
          ),
        ),
        const Spacer(),
        FilledButton(
          onPressed: widget.onResetComplete,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: const StadiumBorder(),
          ),
          child: Text(l10n.tutorPinResetSetNew),
        ),
      ],
    );
  }
}

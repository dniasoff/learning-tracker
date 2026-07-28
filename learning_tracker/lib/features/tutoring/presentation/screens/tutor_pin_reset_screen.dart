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
import 'package:learning_tracker/core/logging/log_events.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
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

    // AUD-tutoring-12 / AUD-tutoring-13: send and local-PIN-clear are two
    // independent operations, each in its own typed try/catch, so a failure
    // is attributed to the step that actually failed and is always logged.
    // Previously both awaits shared one bare `catch (e)`, which (a) reported
    // a clearTutorPin failure as "failed to send" even though the email had
    // already sent — a real risk of the user retrying and triggering a
    // second reset email — and (b) trapped Error subtypes (masking real
    // programming bugs) with zero AppLogger call, making a genuine defect
    // indistinguishable from a normal network failure.
    try {
      try {
        final authRepo = ref.read(authRepositoryProvider);
        await authRepo.sendPasswordResetEmail(email);
      } on Exception catch (e, stackTrace) {
        AppLogger.instance.error(
          event: LogEvents.tutor.pinResetSendEmailFailed,
          exception: e,
          stackTrace: stackTrace,
        );
        if (mounted) {
          setState(
            () => _errorMessage = AppLocalizations.of(
              context,
            )!.tutorPinResetSendFailed,
          );
        }
        return;
      }

      // The reset email has been sent successfully at this point. Clearing
      // the local Tutor PIN is best-effort bookkeeping — TutorPinSetupScreen
      // unconditionally overwrites the stored PIN hash when the tutor sets
      // their new PIN, so a failure here does not block the reset flow. It
      // must never be reported as a send failure, but it must still be
      // recorded rather than silently dropped.
      try {
        final pinService = ref.read(tutorPinServiceProvider);
        await pinService.clearTutorPin(widget.profileId);
      } on Exception catch (e, stackTrace) {
        AppLogger.instance.error(
          event: LogEvents.tutor.pinResetClearLocalPinFailed,
          fields: {'profileId': widget.profileId},
          exception: e,
          stackTrace: stackTrace,
        );
      }

      if (!mounted) return;
      // Invalidate so TutorPinEntryGate sees pinIsSet = false.
      ref.invalidate(tutorPinIsSetProvider(widget.profileId));
      setState(() => _step = _ResetStep.emailSent);
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
      backgroundColor: context.colors.brandCream,
      appBar: AppBar(
        backgroundColor: context.colors.brandCream,
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
        CircleAvatar(
          radius: 36,
          backgroundColor: context.colors.statusWarningSoft,
          child: Icon(
            Icons.lock_reset_rounded,
            size: 36,
            color: context.colors.statusWarningSoftText,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          l10n.tutorPinResetHeading,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: context.colors.brandInk,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.tutorPinResetSendingTo,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: context.colors.brandInkMuted,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          email,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: context.colors.brandInk,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.tutorPinResetReturnHint,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: context.colors.brandInkMuted,
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
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    // AUD-darkmode: this FilledButton uses the default theme
                    // style (brandBlue bg + dynamically-computed onPrimary
                    // text), but the spinner hardcoded white instead, going
                    // invisible in dark mode against the lightened brandBlue
                    // fill (~2.52:1) while the label stayed correctly legible.
                    color: theme.colorScheme.onPrimary,
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
        CircleAvatar(
          radius: 36,
          backgroundColor: context.colors.statusSuccessSoftBg,
          child: Icon(
            Icons.mark_email_read_rounded,
            size: 36,
            color: context.colors.statusSuccessSoftText,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          l10n.tutorPinResetCheckEmailHeading,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: context.colors.brandInk,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.tutorPinResetCheckEmailBody(email),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: context.colors.brandInkMuted,
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

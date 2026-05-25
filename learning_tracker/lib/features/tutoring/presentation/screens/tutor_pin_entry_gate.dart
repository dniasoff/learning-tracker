// W6.5 — Tutor PIN entry gate (FR-5.4)
//
// Displayed every time a tutor switches into a tutored child profile.
// Guards the child data behind the tutor's own PIN.
//
// Flow:
//   • If no PIN is set → redirect to [TutorPinSetupScreen] (W6.4)
//   • If locked out → show lockout countdown
//   • Otherwise → show [PinEntryWidget]; on success call [onPinVerified]
//
// The gate is a full-screen widget (Scaffold) intended to be pushed modally
// or embedded as the first screen in the tutored-profile route stack.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/pin_entry_widget.dart';
import 'package:learning_tracker/features/tutoring/domain/services/tutor_pin_service.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_pin_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/screens/tutor_pin_reset_screen.dart';
import 'package:learning_tracker/features/tutoring/presentation/screens/tutor_pin_setup_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Full-screen PIN gate that a tutor must pass before accessing a tutored
/// child's profile.
///
/// [profileId] is the tutor's own learner-profile ID (the PIN namespace).
/// [onPinVerified] is called when the PIN is accepted; navigate from here.
/// [onCancel] is called when the user taps the back/cancel affordance.
class TutorPinEntryGate extends ConsumerStatefulWidget {
  const TutorPinEntryGate({
    required this.profileId,
    required this.onPinVerified,
    required this.onCancel,
    super.key,
  });

  final int profileId;
  final VoidCallback onPinVerified;
  final VoidCallback onCancel;

  @override
  ConsumerState<TutorPinEntryGate> createState() => _TutorPinEntryGateState();
}

class _TutorPinEntryGateState extends ConsumerState<TutorPinEntryGate> {
  String? _errorMessage;
  bool _isVerifying = false;
  bool _showSetupScreen = false;

  Future<void> _onPinComplete(String pin) async {
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });
    try {
      final service = ref.read(tutorPinServiceProvider);
      final result = await service.verifyTutorPin(
        profileId: widget.profileId,
        rawPin: pin,
      );
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      switch (result) {
        case TutorPinSuccess():
          widget.onPinVerified();
        case TutorPinIncorrect():
          setState(() => _errorMessage = l10n.tutorPinIncorrect);
        case TutorPinLockedOut(:final remainingMinutes):
          setState(
            () => _errorMessage = l10n.tutorPinLockedOut(remainingMinutes),
          );
        case TutorPinValidationError(:final message):
          setState(() => _errorMessage = message);
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check whether a PIN is set yet; if not, show the setup screen inline.
    final pinIsSetAsync = ref.watch(tutorPinIsSetProvider(widget.profileId));

    return pinIsSetAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: Center(
          child: Text(AppLocalizations.of(context)!.tutorPinErrorPrefix('$e')),
        ),
      ),
      data: (pinIsSet) {
        if (!pinIsSet || _showSetupScreen) {
          return TutorPinSetupScreen(
            profileId: widget.profileId,
            onPinSet: () {
              setState(() => _showSetupScreen = false);
              // After PIN is set, re-enter the gate (now shows PIN entry).
              ref.invalidate(tutorPinIsSetProvider(widget.profileId));
            },
          );
        }
        return _buildPinEntry(context);
      },
    );
  }

  Widget _buildPinEntry(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppTheme.brandCream,
      appBar: AppBar(
        backgroundColor: AppTheme.brandCream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: widget.onCancel,
        ),
        title: Text(l10n.tutorPinAppBarTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const CircleAvatar(
                radius: 36,
                backgroundColor: Color(0xFFE8E0FF),
                child: Icon(
                  Icons.lock_person_rounded,
                  size: 36,
                  color: Color(0xFF6B3FA0),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.tutorPinEntryHeading,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.brandInk,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.tutorPinEntryBody,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppTheme.brandInkMuted,
                ),
              ),
              const SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _isVerifying
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : PinEntryWidget(
                          title: l10n.tutorPinAppBarTitle,
                          errorMessage: _errorMessage,
                          onPinComplete: _onPinComplete,
                        ),
                ),
              ),
              const SizedBox(height: 16),
              // Reset PIN affordance (W6.6). L1: routes to the real
              // TutorPinResetScreen (sends a Firebase reset email + clears the
              // local PIN) instead of a fake "email sent" snackbar.
              TextButton(
                onPressed: _openResetFlow,
                child: Text(
                  l10n.tutorPinForgot,
                  style: const TextStyle(color: AppTheme.brandInkMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// L1: open the real Tutor PIN reset flow. On completion, the PIN has been
  /// cleared and tutorPinIsSetProvider invalidated, so re-entering the gate
  /// shows the setup screen for a new PIN.
  void _openResetFlow() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TutorPinResetScreen(
          profileId: widget.profileId,
          onResetComplete: () {
            // Pop the reset screen and re-evaluate the gate: the PIN is now
            // cleared, so the gate routes to setup for a fresh PIN.
            Navigator.of(context).pop();
            if (mounted) {
              setState(() => _showSetupScreen = true);
            }
          },
        ),
      ),
    );
  }
}

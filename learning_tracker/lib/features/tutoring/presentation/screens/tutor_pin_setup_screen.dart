// W6.4 — Tutor PIN setup screen (FR-5.3)
//
// Shown when a tutor user first sets up a Tutor PIN. Triggered at:
//   • Tutor onboarding (via OnboardingScreen intent → joiningToTutor branch)
//   • First tutor invite acceptance (AcceptInviteScreen triggers it before
//     routing to the profile picker)
//
// Reuses the existing [PinEntryWidget] from core/widgets/.
// Delegates to [TutorPinService] (W4.30).
//
// Flow:
//   1. Enter new PIN (4 digits)
//   2. Confirm PIN (re-enter)
//   → on match: saves PIN, calls [onPinSet]
//   → on mismatch: shows error, resets to step 1

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/pin_entry_widget.dart';
import 'package:learning_tracker/features/tutoring/domain/services/tutor_pin_service.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_pin_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

enum _TutorPinSetupStep { enterPin, confirmPin }

/// Screen that sets up the Tutor PIN for a first-time tutor user.
///
/// [profileId] is the tutor's own learner-profile ID (used as the PIN
/// namespace key in [TutorPinService]).
///
/// [onPinSet] is called after the PIN is successfully saved; the caller
/// navigates to the next destination (profile picker or dashboard).
///
/// [onSkip] is optional — if provided, a "Set up later" text button is shown.
/// Skipping is NOT recommended (PIN is mandatory per FR-5.3) but callers may
/// offer it in development/testing contexts.
class TutorPinSetupScreen extends ConsumerStatefulWidget {
  const TutorPinSetupScreen({
    required this.profileId,
    required this.onPinSet,
    this.onSkip,
    super.key,
  });

  final int profileId;
  final VoidCallback onPinSet;
  final VoidCallback? onSkip;

  @override
  ConsumerState<TutorPinSetupScreen> createState() =>
      _TutorPinSetupScreenState();
}

class _TutorPinSetupScreenState extends ConsumerState<TutorPinSetupScreen> {
  _TutorPinSetupStep _step = _TutorPinSetupStep.enterPin;
  String? _firstPin;
  String? _errorMessage;
  bool _isSaving = false;

  void _onFirstPinEntered(String pin) {
    setState(() {
      _firstPin = pin;
      _step = _TutorPinSetupStep.confirmPin;
      _errorMessage = null;
    });
  }

  Future<void> _onConfirmPinEntered(String pin) async {
    if (pin != _firstPin) {
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.tutorPinSetupMismatch;
        _step = _TutorPinSetupStep.enterPin;
        _firstPin = null;
      });
      return;
    }

    setState(() => _isSaving = true);
    try {
      final service = ref.read(tutorPinServiceProvider);
      final result = await service.setTutorPin(
        profileId: widget.profileId,
        rawPin: pin,
      );
      if (!mounted) return;
      switch (result) {
        case TutorPinSuccess():
          widget.onPinSet();
        case TutorPinValidationError(:final message):
          setState(() {
            _errorMessage = message;
            _step = _TutorPinSetupStep.enterPin;
            _firstPin = null;
          });
        case TutorPinIncorrect():
        case TutorPinLockedOut():
          // Not expected during setup — treat as generic error.
          setState(() {
            _errorMessage = AppLocalizations.of(
              context,
            )!.tutorPinSetupSaveError;
            _step = _TutorPinSetupStep.enterPin;
            _firstPin = null;
          });
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isConfirmStep = _step == _TutorPinSetupStep.confirmPin;

    return Scaffold(
      backgroundColor: AppTheme.brandCream,
      appBar: AppBar(
        backgroundColor: AppTheme.brandCream,
        elevation: 0,
        title: Text(l10n.tutorPinSetupAppBarTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              // Header icon
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
                isConfirmStep
                    ? l10n.tutorPinSetupConfirmHeading
                    : l10n.tutorPinSetupCreateHeading,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.brandInk,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isConfirmStep
                    ? l10n.tutorPinSetupConfirmBody
                    : l10n.tutorPinSetupCreateBody,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppTheme.brandInkMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      if (_isSaving)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: CircularProgressIndicator(),
                        )
                      else
                        PinEntryWidget(
                          title: isConfirmStep
                              ? l10n.tutorPinSetupConfirmLabel
                              : l10n.tutorPinSetupEnterNewLabel,
                          errorMessage: _errorMessage,
                          onPinComplete: isConfirmStep
                              ? _onConfirmPinEntered
                              : _onFirstPinEntered,
                        ),
                    ],
                  ),
                ),
              ),
              if (widget.onSkip != null) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: widget.onSkip,
                  child: Text(
                    l10n.tutorPinSetupLater,
                    style: const TextStyle(color: AppTheme.brandInkMuted),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

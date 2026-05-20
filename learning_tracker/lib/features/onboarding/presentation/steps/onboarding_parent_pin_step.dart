import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/widgets/pin_entry_widget.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';

/// Sub-steps within the parent PIN setup phase.
///
/// Replaces the `_isPinConfirmStep` boolean so the two sub-states are named
/// and exhaustively handled.
enum PinStep {
  /// User is entering the PIN for the first time.
  enterPin,

  /// User is re-entering the PIN to confirm it matches.
  confirmPin,
}

/// Onboarding phase: set the parent PIN for child-mode profiles.
///
/// Only shown when `isChildMode == true`.
class OnboardingParentPinStep extends ConsumerStatefulWidget {
  const OnboardingParentPinStep({
    super.key,
    required this.profileId,
    required this.childName,
    required this.onComplete,
  });

  final int profileId;
  final String childName;
  final VoidCallback onComplete;

  @override
  ConsumerState<OnboardingParentPinStep> createState() =>
      _OnboardingParentPinStepState();
}

class _OnboardingParentPinStepState
    extends ConsumerState<OnboardingParentPinStep> {
  String? _firstPin;
  String? _pinError;
  PinStep _pinStep = PinStep.enterPin;

  void _onFirstPinEntered(String pin) {
    setState(() {
      _firstPin = pin;
      _pinStep = PinStep.confirmPin;
      _pinError = null;
    });
  }

  Future<void> _onConfirmPinEntered(String pin) async {
    if (pin != _firstPin) {
      setState(() {
        _pinError = 'PINs do not match';
        _pinStep = PinStep.enterPin;
        _firstPin = null;
      });
      return;
    }

    try {
      await ref.read(pinServiceProvider).setProfilePin(widget.profileId, pin);
    } on ArgumentError catch (e) {
      if (mounted) {
        setState(() {
          _pinError = e.message as String?;
          _pinStep = PinStep.enterPin;
          _firstPin = null;
        });
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _firstPin = null;
      _pinStep = PinStep.enterPin;
      _pinError = null;
    });
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final childName = widget.childName.isNotEmpty
        ? widget.childName
        : 'your child';
    final subtitle = switch (_pinStep) {
      PinStep.confirmPin => 'Re-enter the PIN to confirm',
      PinStep.enterPin =>
        'Set a 4-digit PIN to access parent controls for $childName. '
            'The PIN is stored only on this device.',
    };

    return SafeArea(
      top: false,
      // Scrollable so the soft keyboard squeezing the viewport scrolls the
      // card instead of overflowing it.
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                PinEntryWidget(
                  title: switch (_pinStep) {
                    PinStep.confirmPin => 'Confirm PIN',
                    PinStep.enterPin => 'Enter New PIN',
                  },
                  errorMessage: _pinError,
                  onPinComplete: switch (_pinStep) {
                    PinStep.confirmPin => _onConfirmPinEntered,
                    PinStep.enterPin => _onFirstPinEntered,
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

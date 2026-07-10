// W6.4 — Tutor PIN setup screen (FR-5.3)
//
// Shown when a tutor user first sets up a Tutor PIN. Triggered at:
//   • Tutor onboarding (via OnboardingScreen intent → joiningToTutor branch)
//   • First tutor invite acceptance (AcceptInviteScreen triggers it before
//     routing to the profile picker)
//
// Uses an always-visible custom on-screen numpad (TUT-07) — matching the
// TutorPinEntryGate (W6.5) — instead of the soft-keyboard-based PinEntryWidget,
// which required a tap to summon the IME and appeared dead on device.
// Delegates to [TutorPinService] (W4.30).
//
// Flow:
//   1. Enter new PIN (4 digits)
//   2. Confirm PIN (re-enter)
//   → on match: saves PIN, calls [onPinSet]
//   → on mismatch: shows error, resets to step 1

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
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

  // TUT-07: digits entered so far on the always-visible custom numpad for the
  // current step. Cleared on step transitions and on error.
  String _digits = '';

  void _appendDigit(String d) {
    if (_isSaving) return;
    if (_digits.length >= 4) return;
    setState(() {
      _digits += d;
      _errorMessage = null;
    });
    if (_digits.length == 4) {
      final pin = _digits;
      // Clear the on-screen digits before advancing so the next step (confirm)
      // starts empty and no digits linger across the step transition.
      _digits = '';
      if (_step == _TutorPinSetupStep.confirmPin) {
        unawaited(_onConfirmPinEntered(pin));
      } else {
        _onFirstPinEntered(pin);
      }
    }
  }

  void _backspace() {
    if (_isSaving) return;
    if (_digits.isEmpty) return;
    setState(() {
      _digits = _digits.substring(0, _digits.length - 1);
      _errorMessage = null;
    });
  }

  void _onFirstPinEntered(String pin) {
    setState(() {
      _firstPin = pin;
      _step = _TutorPinSetupStep.confirmPin;
      _errorMessage = null;
      _digits = '';
    });
  }

  Future<void> _onConfirmPinEntered(String pin) async {
    if (pin != _firstPin) {
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.tutorPinSetupMismatch;
        _step = _TutorPinSetupStep.enterPin;
        _firstPin = null;
        _digits = '';
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
      final errorMessage = switch (result) {
        TutorPinSuccess() => null,
        TutorPinValidationError(:final message) => message,
        // Not expected during setup — treat as generic error.
        TutorPinIncorrect() || TutorPinLockedOut() => AppLocalizations.of(
          context,
        )!.tutorPinSetupSaveError,
      };
      if (errorMessage == null) {
        widget.onPinSet();
      } else {
        setState(() {
          _errorMessage = errorMessage;
          _step = _TutorPinSetupStep.enterPin;
          _firstPin = null;
          _digits = '';
        });
      }
    } catch (e, st) {
      // EH-2/EH-3: setTutorPin has no exception handling at all, so an
      // underlying storage failure (e.g. secure-storage/keystore error)
      // propagates raw. Without this catch the user was left staring at a
      // stalled confirm step: _isSaving still resets via `finally`, but no
      // error ever appears and the entered digits are never cleared.
      AppLogger.instance.error(
        event: 'tutor_pin_set_failed',
        exception: e,
        stackTrace: st,
      );
      if (mounted) {
        setState(() {
          _errorMessage = AppLocalizations.of(context)!.tutorPinSetupSaveError;
          _step = _TutorPinSetupStep.enterPin;
          _firstPin = null;
          _digits = '';
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
                backgroundColor: AppColors.tutorPinBadgeBg,
                child: Icon(
                  Icons.lock_person_rounded,
                  size: 36,
                  color: AppColors.tutorPinBadgeIcon,
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isConfirmStep
                            ? l10n.tutorPinSetupConfirmLabel
                            : l10n.tutorPinSetupEnterNewLabel,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.brandInk,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _TutorPinDotsRow(length: _digits.length),
                      const SizedBox(height: 16),
                      if (_errorMessage != null) ...[
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_isSaving)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: CircularProgressIndicator(),
                        )
                      else
                        _TutorPinNumpad(
                          onDigit: _appendDigit,
                          onBackspace: _backspace,
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

/// Four-dot PIN progress indicator. Filled dots reflect digits entered so far.
///
/// Mirrors the indicator in [TutorPinEntryGate] (W6.5) so the setup and entry
/// surfaces are visually consistent (TUT-07).
class _TutorPinDotsRow extends StatelessWidget {
  const _TutorPinDotsRow({required this.length});

  final int length;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final filled = i < length;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? AppTheme.brandInk : AppTheme.brandOutlineMuted,
              border: Border.all(
                color: filled
                    ? AppTheme.brandInk
                    : AppColors.tutorPinKeyDisabled.withValues(alpha: 0.35),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Self-contained always-visible on-screen numpad (TUT-07). Does NOT rely on
/// the device soft-keyboard, so PIN setup works reliably on device — matching
/// [TutorPinEntryGate]'s numpad.
class _TutorPinNumpad extends StatelessWidget {
  const _TutorPinNumpad({required this.onDigit, required this.onBackspace});

  final void Function(String digit) onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    const spacing = 10.0;

    Widget digitBtn(String d) => Expanded(
      child: _TutorPinKey(
        onTap: () => onDigit(d),
        child: Text(
          d,
          style: const TextStyle(
            color: AppTheme.brandInk,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            digitBtn('1'),
            const SizedBox(width: spacing),
            digitBtn('2'),
            const SizedBox(width: spacing),
            digitBtn('3'),
          ],
        ),
        const SizedBox(height: spacing),
        Row(
          children: [
            digitBtn('4'),
            const SizedBox(width: spacing),
            digitBtn('5'),
            const SizedBox(width: spacing),
            digitBtn('6'),
          ],
        ),
        const SizedBox(height: spacing),
        Row(
          children: [
            digitBtn('7'),
            const SizedBox(width: spacing),
            digitBtn('8'),
            const SizedBox(width: spacing),
            digitBtn('9'),
          ],
        ),
        const SizedBox(height: spacing),
        Row(
          children: [
            const Expanded(child: SizedBox()),
            const SizedBox(width: spacing),
            digitBtn('0'),
            const SizedBox(width: spacing),
            Expanded(
              child: _TutorPinKey(
                onTap: onBackspace,
                child: Icon(
                  Icons.backspace_outlined,
                  color: Theme.of(context).colorScheme.error,
                  size: 24,
                  semanticLabel: AppLocalizations.of(context)!.pinBackspace,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TutorPinKey extends StatelessWidget {
  const _TutorPinKey({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.brandCreamSoft,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        // AX-4: size from content instead of a fixed height so an enlarged
        // digit glyph at high accessibility text scales is not clipped.
        // The 14dp vertical padding keeps the tap target close to the
        // original 52dp height at the default text scale.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(child: child),
        ),
      ),
    );
  }
}

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
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
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
  // Digits entered so far via the on-screen numpad. The gate uses a custom
  // numpad (NOT a TextField/soft-keyboard) so PIN entry works reliably on
  // device — matching the parent-PIN and tutor route-guard dialogs. A
  // soft-keyboard-based field would not summon the IME without an explicit
  // autofocus/FocusNode, which is why the old PinEntryWidget appeared dead.
  String _digits = '';
  String? _errorMessage;
  bool _isVerifying = false;
  bool _showSetupScreen = false;
  // TUT-01: set true the moment a PIN is (re)set from the inline setup screen.
  // It forces the gate to render PIN entry immediately — independent of the
  // async tutorPinIsSetProvider re-resolving — so a freshly-set PIN verifies
  // on the FIRST entry rather than after a second, fresh gate open. (When the
  // provider had a cached `false` from the reset flow, `.when(data:)` could
  // momentarily route back to setup or leave stale entry state behind.)
  bool _pinJustSet = false;

  void _appendDigit(String d) {
    if (_isVerifying) return;
    if (_digits.length >= 4) return;
    setState(() {
      _digits += d;
      _errorMessage = null;
    });
    if (_digits.length == 4) {
      _onPinComplete(_digits);
    }
  }

  void _backspace() {
    if (_isVerifying) return;
    if (_digits.isEmpty) return;
    setState(() {
      _digits = _digits.substring(0, _digits.length - 1);
      _errorMessage = null;
    });
  }

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
          setState(() {
            _digits = '';
            _errorMessage = l10n.tutorPinIncorrect;
          });
        case TutorPinLockedOut(:final remainingMinutes):
          setState(() {
            _digits = '';
            _errorMessage = l10n.tutorPinLockedOut(remainingMinutes);
          });
        case TutorPinValidationError(:final message):
          setState(() {
            _digits = '';
            _errorMessage = message;
          });
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
      error: (e, st) {
        AppLogger.instance.error(
          event: 'tutor_pin_is_set_check_failed',
          exception: e,
          stackTrace: st,
        );
        final l10n = AppLocalizations.of(context)!;
        return Scaffold(
          body: Center(
            child: Text(l10n.tutorPinErrorPrefix(l10n.errorSaveFailed)),
          ),
        );
      },
      data: (pinIsSet) {
        // TUT-01: once a PIN was just set inline, render entry immediately and
        // ignore a possibly-stale `pinIsSet == false` (the provider may still
        // be refreshing after invalidate). _pinJustSet is cleared as soon as
        // the provider re-resolves to true (see below).
        if (_pinJustSet && pinIsSet) {
          _pinJustSet = false;
        }
        final showSetup = (!pinIsSet && !_pinJustSet) || _showSetupScreen;
        if (showSetup) {
          return TutorPinSetupScreen(
            profileId: widget.profileId,
            onPinSet: () {
              // TUT-01: enter a clean entry state. Clearing _digits /
              // _errorMessage / _isVerifying guarantees no stale input or
              // premature verify carries over from a prior entry attempt, and
              // _pinJustSet forces the entry screen so the new PIN verifies on
              // the FIRST re-entry. The PIN hash is already flushed to secure
              // storage by setTutorPin() before onPinSet fires.
              setState(() {
                _showSetupScreen = false;
                _pinJustSet = true;
                _digits = '';
                _errorMessage = null;
                _isVerifying = false;
              });
              // Refresh the is-set provider so its cached value catches up.
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                      if (_isVerifying)
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

/// Four-dot PIN progress indicator. Filled dots reflect digits entered so far.
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
              color: filled ? AppTheme.brandInk : const Color(0xFFE8EBF0),
              border: Border.all(
                color: filled
                    ? AppTheme.brandInk
                    : const Color(0xFFC9D0DA).withValues(alpha: 0.35),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Self-contained on-screen numpad. Does NOT rely on the device soft-keyboard,
/// so the gate works reliably on device (the previous TextField-based widget
/// never summoned the IME). Mirrors the parent-PIN numpad layout.
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
        child: SizedBox(height: 52, child: Center(child: child)),
      ),
    );
  }
}

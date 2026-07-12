import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Reusable PIN entry widget for parent-mode authentication.
///
/// Accepts exactly 4 numeric digits with visual feedback for each digit.
/// Shows error states and lockout countdown timer.
class PinEntryWidget extends StatefulWidget {
  const PinEntryWidget({
    required this.onPinComplete,
    this.errorMessage,
    this.isLockedOut = false,
    this.lockoutRemainingMinutes = 0,
    this.title,
    super.key,
  });

  /// Callback when all 4 digits are entered.
  final void Function(String pin) onPinComplete;

  /// Error message to display (e.g., "Incorrect PIN").
  final String? errorMessage;

  /// Whether the PIN entry is currently locked out.
  final bool isLockedOut;

  /// Remaining lockout time in minutes.
  final int lockoutRemainingMinutes;

  /// Title displayed above the PIN entry.
  ///
  /// When null, falls back to the localized
  /// `AppLocalizations.pinEntryDefaultTitle` ("Enter PIN") — resolved in
  /// [State.build] rather than as a field default so it comes from ARB
  /// (AX-2) instead of a hardcoded English literal.
  final String? title;

  @override
  State<PinEntryWidget> createState() => _PinEntryWidgetState();
}

class _PinEntryWidgetState extends State<PinEntryWidget> {
  final List<TextEditingController> _controllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  @override
  void didUpdateWidget(PinEntryWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Clear digits and refocus field 1 when:
    //  • a new error appears (don't leave failed digits visible — security UX), or
    //  • the title changes, which callers use to signal a new step
    //    (e.g. "Enter New PIN" → "Confirm PIN", or "verifyCurrent" →
    //    "enterNew" in the change-PIN flow).
    final errorAppeared =
        widget.errorMessage != null &&
        oldWidget.errorMessage != widget.errorMessage;
    final stepChanged = widget.title != oldWidget.title;
    if (errorAppeared || stepChanged) {
      _clearPin();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onDigitChanged(int index, String value) {
    if (value.isEmpty) {
      // Handle backspace - move to previous field
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
      return;
    }

    if (value.length == 1) {
      // Move to next field
      if (index < 3) {
        _focusNodes[index + 1].requestFocus();
      } else {
        // All digits entered, trigger callback
        _focusNodes[index].unfocus();
        final pin = _controllers.map((c) => c.text).join();
        if (pin.length == 4) {
          widget.onPinComplete(pin);
        }
      }
    }
  }

  void _clearPin() {
    for (final controller in _controllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final hasError = widget.errorMessage != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title
        Text(
          widget.title ?? l10n.pinEntryDefaultTitle,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 32),

        // Lockout message or PIN entry
        if (widget.isLockedOut)
          _buildLockoutMessage(theme, l10n)
        else
          _buildPinEntry(theme, hasError),

        const SizedBox(height: 16),

        // Error message
        if (hasError && !widget.isLockedOut) _buildErrorMessage(theme, l10n),
      ],
    );
  }

  Widget _buildLockoutMessage(ThemeData theme, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.lock_clock, size: 64, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(
            l10n.parentPinLockoutTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onErrorContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.parentPinLockoutBody(widget.lockoutRemainingMinutes),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinEntry(ThemeData theme, bool hasError) {
    // FittedBox scales the fixed-width digit row down to fit any parent
    // (narrow dialogs, small screens) without triggering intrinsic-dimension
    // errors that LayoutBuilder would cause inside AlertDialog's IntrinsicWidth.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          4,
          (index) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _PinDigitField(
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              hasError: hasError,
              onChanged: (value) => _onDigitChanged(index, value),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorMessage(ThemeData theme, AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            widget.errorMessage!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
            softWrap: true,
          ),
        ),
        const SizedBox(width: 8),
        TextButton(onPressed: _clearPin, child: Text(l10n.actionClear)),
      ],
    );
  }
}

/// Individual PIN digit input field.
///
/// Renders a fixed-size rounded slot. The actual digit is held in the
/// controller and obscured at the platform layer (`obscureText: true`) so
/// screen readers, autofill, and IME suggestions do NOT leak the PIN, and
/// the text styling (transparent colour) hides the glyph from sight while
/// keeping the cursor at its natural height.
///
/// The visible filled-slot indicator is drawn by us as a small centred
/// [Container] in a [Stack] overlay — *not* by `obscuringCharacter: '●'`.
/// That obscuring glyph inherits the field's font size; the `●`
/// (BLACK CIRCLE, U+25CF) glyph is metric-wider than the digit glyphs in
/// most fonts, and at the system's max text-scale setting it overflows
/// the slot — visible as a giant half-circle clipped by the right edge.
/// Drawing the dot ourselves makes its size independent of font metrics
/// and text-scale; `obscuringCharacter: ' '` (a space) keeps the platform-
/// layer obscuring semantics without drawing anything visible.
class _PinDigitField extends StatefulWidget {
  const _PinDigitField({
    required this.controller,
    required this.focusNode,
    required this.hasError,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasError;
  final void Function(String) onChanged;

  @override
  State<_PinDigitField> createState() => _PinDigitFieldState();
}

class _PinDigitFieldState extends State<_PinDigitField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChange);
    super.dispose();
  }

  void _onControllerChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDigit = widget.controller.text.isNotEmpty;
    final borderColor = widget.hasError
        ? theme.colorScheme.error
        : theme.colorScheme.outline;

    return SizedBox(
      width: 56,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 1,
            // Keep platform-layer obscuring (`obscureText: true`) so screen
            // readers / autofill don't leak the PIN, but make the glyph
            // invisible so the visible indicator comes from our Stack
            // overlay (sized independently of font metrics — see class doc).
            // Space as the obscuring char so no visible character is drawn.
            obscureText: true,
            obscuringCharacter: ' ',
            // Headline-medium metrics keep the cursor at a natural height;
            // transparent colour hides the glyph the user typed.
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.transparent,
              fontWeight: FontWeight.bold,
            ),
            cursorColor: theme.colorScheme.primary,
            decoration: InputDecoration(
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: widget.hasError
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.error,
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: widget.hasError
                  ? theme.colorScheme.errorContainer.withValues(alpha: 0.1)
                  : theme.colorScheme.surface,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(1),
            ],
            onChanged: widget.onChanged,
          ),
          if (hasDigit)
            IgnorePointer(
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

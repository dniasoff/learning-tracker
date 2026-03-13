import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reusable PIN entry widget for parent and tutor mode authentication.
///
/// Accepts exactly 4 numeric digits with visual feedback for each digit.
/// Shows error states and lockout countdown timer.
class PinEntryWidget extends StatefulWidget {
  const PinEntryWidget({
    required this.onPinComplete,
    this.errorMessage,
    this.isLockedOut = false,
    this.lockoutRemainingMinutes = 0,
    this.title = 'Enter PIN',
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
  final String title;

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
    // Auto-clear digits and return focus to field 1 when an error appears.
    // This is standard security UX — don't leave failed digits visible.
    if (widget.errorMessage != null &&
        oldWidget.errorMessage != widget.errorMessage) {
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
    final hasError = widget.errorMessage != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title
        Text(
          widget.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 32),

        // Lockout message or PIN entry
        if (widget.isLockedOut)
          _buildLockoutMessage(theme)
        else
          _buildPinEntry(theme, hasError),

        const SizedBox(height: 16),

        // Error message
        if (hasError && !widget.isLockedOut) _buildErrorMessage(theme),
      ],
    );
  }

  Widget _buildLockoutMessage(ThemeData theme) {
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
            'Too many failed attempts',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onErrorContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try again in ${widget.lockoutRemainingMinutes} minute(s)',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinEntry(ThemeData theme, bool hasError) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
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
    );
  }

  Widget _buildErrorMessage(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
        const SizedBox(width: 8),
        Text(
          widget.errorMessage!,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
        const SizedBox(width: 8),
        TextButton(onPressed: _clearPin, child: const Text('Clear')),
      ],
    );
  }
}

/// Individual PIN digit input field.
class _PinDigitField extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 56,
      height: 64,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        obscureText: true,
        obscuringCharacter: '●',
        style: theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          counterText: '',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: hasError
                  ? theme.colorScheme.error
                  : theme.colorScheme.outline,
              width: 2,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: hasError
                  ? theme.colorScheme.error
                  : theme.colorScheme.outline,
              width: 2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: hasError
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.colorScheme.error, width: 2),
          ),
          filled: true,
          fillColor: hasError
              ? theme.colorScheme.errorContainer.withValues(alpha: 0.1)
              : theme.colorScheme.surface,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(1),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

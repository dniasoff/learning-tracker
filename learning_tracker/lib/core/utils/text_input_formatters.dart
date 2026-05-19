import 'package:flutter/services.dart';

/// Strips leading whitespace as the user types.
class TrimLeadingSpaceFormatter extends TextInputFormatter {
  const TrimLeadingSpaceFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final trimmed = newValue.text.trimLeft();
    if (trimmed == newValue.text) return newValue;
    return newValue.copyWith(
      text: trimmed,
      selection: TextSelection.collapsed(offset: trimmed.length),
    );
  }
}

/// Strips all whitespace — use on password fields where keyboards (e.g. Samsung)
/// can silently insert spaces after auto-corrections or delete shortcuts.
class NoSpaceFormatter extends TextInputFormatter {
  const NoSpaceFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final stripped = newValue.text.replaceAll(' ', '');
    if (stripped == newValue.text) return newValue;
    return newValue.copyWith(
      text: stripped,
      selection: TextSelection.collapsed(offset: stripped.length),
    );
  }
}

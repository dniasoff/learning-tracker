/// Validation functions for authentication forms.
///
/// Extracted as top-level functions so they can be shared between
/// the account-creation screen and unit tests.
library;

/// Returns an error message if [value] is not a valid email, or `null` if valid.
String? validateEmail(String? value) {
  if (value == null || value.isEmpty) {
    return 'Email is required';
  }
  final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  if (!emailRegex.hasMatch(value)) {
    return 'Please enter a valid email address';
  }
  return null;
}

/// Returns an error message if [value] is not a valid password, or `null` if valid.
String? validatePassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Password is required';
  }
  if (value.length < 6) {
    return 'Password must be at least 6 characters';
  }
  return null;
}

/// Returns an error message if [value] is not a valid display name, or `null` if valid.
String? validateDisplayName(String? value) {
  if (value == null || value.isEmpty) {
    return 'Display name is required';
  }
  return null;
}

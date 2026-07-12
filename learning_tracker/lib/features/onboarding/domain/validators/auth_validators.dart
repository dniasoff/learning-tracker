/// Validation functions for authentication forms.
///
/// Extracted as top-level functions so they can be shared between
/// the account-creation screen and unit tests.
///
/// AUD-onboarding-03: every returned message is resolved through
/// [AppLocalizations] — never a hardcoded English literal — so the
/// sign-up/sign-in inline field errors render correctly under Locale('he').
library;

import 'package:learning_tracker/core/constants/app_constants.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Returns an error message if [value] is not a valid email, or `null` if valid.
String? validateEmail(String? value, AppLocalizations l10n) {
  if (value == null || value.isEmpty) {
    return l10n.authEmailRequired;
  }
  final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  if (!emailRegex.hasMatch(value)) {
    return l10n.authEmailInvalid;
  }
  return null;
}

/// Returns an error message if [value] is not a valid password, or `null` if valid.
String? validatePassword(String? value, AppLocalizations l10n) {
  if (value == null || value.isEmpty) {
    return l10n.authPasswordRequired;
  }
  if (value.length < AppConstants.minLocalPasswordLength) {
    return l10n.passwordMinLengthError;
  }
  return null;
}

/// Returns an error message if [value] is not a valid display name, or `null` if valid.
String? validateDisplayName(String? value, AppLocalizations l10n) {
  if (value == null || value.isEmpty) {
    return l10n.authDisplayNameRequired;
  }
  return null;
}

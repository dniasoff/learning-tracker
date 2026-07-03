/// App-wide constants that don't belong to a specific feature.
class AppConstants {
  AppConstants._();

  /// Contact email for support and program requests.
  static const String supportEmail = 'support@learningtracker.app';

  /// Display name of the application.
  static const String appName = 'Learning Tracker';

  /// Minimum password length for local-born (device-only) accounts.
  ///
  /// This is the single source of truth for the invariant — it is
  /// referenced by both the client-side form validator
  /// (`features/onboarding/domain/validators/auth_validators.dart`) and the
  /// domain-layer check in `LocalAuthService`. Living in `core/` lets both
  /// features/account and features/onboarding depend on it without a
  /// cross-feature import (AUD-account-20).
  static const int minLocalPasswordLength = 6;
}

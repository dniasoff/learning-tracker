// Public surface of the account feature.
//
// Import this barrel (features/account/account.dart) from outside this
// feature. Do NOT import deep paths directly — the barrel enforces
// the public-surface contract.

// Domain models
export 'domain/models/app_user.dart';
export 'domain/models/auth_state.dart';
// Domain repositories
export 'domain/repositories/auth_repository.dart';
// Domain services
export 'domain/services/account_lifecycle_service.dart';
export 'domain/services/account_management_service.dart';
export 'domain/services/local_auth_service.dart';
export 'domain/services/pending_local_signup.dart';
export 'domain/services/session_persistence_service.dart';
export 'domain/services/upgrade_to_cloud_service.dart';
export 'onboarding/domain/validators/auth_validators.dart';
// Onboarding screens
export 'onboarding/presentation/screens/onboarding_intent_screen.dart';
export 'onboarding/presentation/screens/signup_screen.dart';
export 'presentation/providers/account_management_providers.dart';
// Presentation providers
// Note: auth_providers.dart generates authStateProvider (stream); auth_state_provider.dart
// generates authStateProvider (notifier). Both .g.dart files clash on that name.
// Export auth_providers.dart but hide the clashing generated symbol from auth_state_provider.dart
// so that callers get the canonical AuthStateNotifier-based authStateProvider.
export 'presentation/providers/auth_providers.dart'
    hide AuthStateProvider, authStateProvider;
export 'presentation/providers/auth_state_provider.dart';
export 'presentation/providers/connectivity_providers.dart';
export 'presentation/providers/magic_link_providers.dart';
// Presentation screens
export 'presentation/screens/account_picker_screen.dart';
export 'presentation/screens/sign_in_screen.dart';
// Presentation widgets
export 'presentation/widgets/email_verification_confirm_panel.dart';
export 'presentation/widgets/no_backup_badge.dart';
export 'presentation/widgets/offline_top_banner.dart';

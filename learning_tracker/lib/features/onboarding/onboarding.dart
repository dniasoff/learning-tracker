// Public surface of the onboarding feature.
//
// Import this barrel (features/onboarding/onboarding.dart) from outside this
// feature. Do NOT import deep paths directly.
//
// Note: auth/signup half of onboarding is being merged into features/account/
// in Wave 2 (W2.12). Track-setup half remains here for Wave 6 (W6.x).
library onboarding;

// Auth form validators shared with features/account/.
export 'package:learning_tracker/features/onboarding/domain/validators/auth_validators.dart';
// Onboarding-complete SharedPreferences flag, consulted by features/account/
// (sign-in, account picker, account lifecycle) to decide whether onboarding
// still needs to run.
export 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_resume_store.dart'
    show kOnboardingComplete;

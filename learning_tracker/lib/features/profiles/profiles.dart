// Public surface of the profiles feature.
//
// Import this barrel (features/profiles/profiles.dart) from outside this
// feature. Do NOT import deep paths directly.
//
// Populated in Wave 4 (W4.x) — PIN flow machine + profile domain modelling.
//
// AUD-profiles-08: profiles is the single most cross-cut feature in the app
// (65+ deep-import call sites across 10+ other features before this fix).
// The exports below are the feature's actual public surface — every file
// already deep-imported from outside features/profiles/, per the `make
// audit` check 15/15 cross-feature-deep-import grep (self-comparison bug
// fixed by AUD-guardrails-02). New cross-feature consumers MUST import this
// barrel instead of a deep path; existing deep-import call sites migrate
// off incrementally (tracked by the same check 15/15 grep).
//
// ignore_for_file: directives_ordering — exports are grouped by semantic
// section (models, repositories, services, providers, widgets) rather than
// alphabetically.
library profiles;

// ── Domain models ──────────────────────────────────────────────────────
export 'domain/models/learner_profile_entity.dart';

// ── Domain repositories ────────────────────────────────────────────────
export 'domain/repositories/profile_repository.dart';

// ── Domain services ────────────────────────────────────────────────────
export 'domain/services/pin_service.dart';

// ── Presentation providers ─────────────────────────────────────────────
export 'presentation/providers/active_profile_provider.dart';
export 'presentation/providers/profile_providers.dart';
export 'presentation/providers/parent_pin_session_provider.dart';

// ── Presentation widgets ───────────────────────────────────────────────
export 'presentation/widgets/profile_switcher_sheet.dart';
export 'presentation/widgets/parent_pin_keypad_dialog.dart';

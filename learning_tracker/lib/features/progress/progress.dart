// Public surface of the progress feature.
//
// Rule 2 (DNI-386): cross-feature deep imports into `lib/features/progress/`
// sub-paths are forbidden. Other features MUST import this barrel — never
// `lib/features/progress/presentation/...` directly.
//
// Only exports that are demonstrably consumed by another feature live
// here; intra-feature imports inside `lib/features/progress/` keep using
// deep paths and SHOULD NOT route through this barrel (that would create
// circular re-exports and slow analysis).
//
// To add a new export: confirm the type is actually imported by code
// outside `lib/features/progress/`, then add one line below with a comment
// pointing at one such consumer.
library progress;

// Siyum-granularity settings support — the tier enum the selector is keyed on.
// Consumed by:
//   - lib/features/settings/presentation/widgets/siyum_granularity_selector.dart
export 'domain/models/journey_view_model.dart' show MilestoneLevel;

// Siyum-granularity settings support — the tiers offered per curriculum.
// Consumed by:
//   - lib/features/settings/presentation/widgets/siyum_granularity_selector.dart
export 'presentation/providers/journey_providers.dart'
    show availableSiyumTiersProvider;

// Tier counter row — header widget shared between Progress hub and the
// Dashboard body. Consumed by:
//   - lib/features/dashboard/presentation/widgets/dashboard_body.dart
export 'presentation/widgets/progress_tier_counter_row.dart'
    show ProgressTierCounterRow;

// Siyum-granularity settings support — the localized label for each tier.
// Consumed by:
//   - lib/features/settings/presentation/widgets/siyum_granularity_selector.dart
export 'presentation/widgets/siyum_tier_label.dart' show siyumTierLabel;

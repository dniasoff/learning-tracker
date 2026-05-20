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

// Tier counter row — header widget shared between Progress hub and the
// Dashboard body. Consumed by:
//   - lib/features/dashboard/presentation/widgets/dashboard_body.dart
export 'presentation/widgets/progress_tier_counter_row.dart'
    show ProgressTierCounterRow;

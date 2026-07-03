// Public surface of the profiles feature.
//
// Import this barrel (features/profiles/profiles.dart) from outside this
// feature. Do NOT import deep paths directly.
//
// Populated in Wave 4 (W4.x) — PIN flow machine + profile domain modelling.
library profiles;

// AUD-guardrails-02: minimal first export — the account-scoping accessor
// needed by features/account's pending-signup flow. Scoped with `show` so
// this barrel grows deliberately, one real cross-feature need at a time,
// rather than re-exporting the whole (much larger) providers file.
export 'presentation/providers/profile_providers.dart'
    show currentAccountIdProvider;

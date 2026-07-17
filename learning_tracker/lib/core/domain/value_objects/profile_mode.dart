/// The operational mode of a learner profile.
///
/// Determines which UI affordances are available and whether parental
/// controls (Parent PIN) are enforced.
///
/// ## Storage keys
/// - [adult] ↔ `'adult'`
/// - [child] ↔ `'child'`
///
/// ## Migration note
/// Direct string comparisons (`profile.mode == 'child'`) should be replaced
/// with typed enum comparisons (`profile.profileMode == ProfileMode.child`)
/// as part of the W5.10 primitive-obsession sweep.
enum ProfileMode {
  /// Full adult learner — no parental controls.
  adult,

  /// Child learner — parental controls (Parent PIN) are enforced.
  child;

  // ---------------------------------------------------------------------------
  // Persistence helpers
  // ---------------------------------------------------------------------------

  /// The storage key as used in the Drift `learner_profiles.mode` column.
  String get storageKey => name; // 'adult' or 'child'

  /// Parses [key] from storage.
  ///
  /// Throws [ArgumentError] for unrecognised keys.
  ///
  /// Prefer [tryFromStorageKey] when the caller wants to tolerate an
  /// unrecognised value rather than throw — EH-4 forbids catching
  /// [ArgumentError] (an [Error] subtype) as control flow, so a
  /// try/catch around this method is never the right way to get a
  /// fallback.
  static ProfileMode fromStorageKey(String key) {
    return ProfileMode.values.firstWhere(
      (e) => e.storageKey == key,
      orElse: () => throw ArgumentError.value(
        key,
        'key',
        'Unknown ProfileMode storage key.',
      ),
    );
  }

  /// Parses [key] from storage, returning `null` for unrecognised keys
  /// instead of throwing.
  ///
  /// EH-4 (`docs/coding-standards.md`): "never catch `Error` subtypes" —
  /// [fromStorageKey] throws [ArgumentError], an [Error] subtype, so a
  /// caller that wants a non-throwing fallback must not wrap it in
  /// try/catch. Use this accessor instead (see [ProfileModel.profileMode]
  /// in `profile_model.dart` for the established call site — mirrors
  /// [AccountTier.tryFromStorageKey] / `DeviceAccountX.accountTier`'s
  /// shape in `account_tier.dart` / `device_registry_database.dart`).
  static ProfileMode? tryFromStorageKey(String key) => switch (key) {
    'adult' => ProfileMode.adult,
    'child' => ProfileMode.child,
    _ => null,
  };

  // ---------------------------------------------------------------------------
  // Accessors
  // ---------------------------------------------------------------------------

  /// Whether this profile is in adult mode.
  bool get isAdult => this == ProfileMode.adult;

  /// Whether this profile is in child mode (parental controls active).
  bool get isChild => this == ProfileMode.child;
}

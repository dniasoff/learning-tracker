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

  // ---------------------------------------------------------------------------
  // Accessors
  // ---------------------------------------------------------------------------

  /// Whether this profile is in adult mode.
  bool get isAdult => this == ProfileMode.adult;

  /// Whether this profile is in child mode (parental controls active).
  bool get isChild => this == ProfileMode.child;
}

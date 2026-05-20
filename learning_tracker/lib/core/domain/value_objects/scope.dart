/// Hierarchy level within a curriculum's content tree (1–4).
///
/// Level 1 is the top-level grouping (e.g. Seder for Mishnayos, Sefer for
/// Tanach), level 4 is the deepest (e.g. individual Mishna or Pasuk).
///
/// ## Invariants
/// - [value] is in range 1..4.
class ScopeLevel {
  /// Constructs a [ScopeLevel] for [value].
  ///
  /// Throws [ArgumentError] when [value] is outside 1..4.
  ScopeLevel(this.value) {
    if (value < 1 || value > 4) {
      throw ArgumentError.value(
        value,
        'value',
        'ScopeLevel must be between 1 and 4 inclusive.',
      );
    }
  }

  /// The 1-based hierarchy level (1 = top-level, 4 = leaf).
  final int value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScopeLevel && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'ScopeLevel($value)';
}

/// A non-empty string value identifying a node at a particular [ScopeLevel].
///
/// Examples: "Berakhot" (masechta), "Sefer Bereishit" (sefer), "1" (perek #1).
///
/// ## Invariants
/// - Value is non-empty after trimming.
class ScopeValue {
  /// Constructs a [ScopeValue] from [raw].
  ///
  /// Throws [ArgumentError] when [raw] is empty after trimming.
  ScopeValue(String raw) : value = raw.trim() {
    if (value.isEmpty) {
      throw ArgumentError.value(
        raw,
        'raw',
        'ScopeValue cannot be empty.',
      );
    }
  }

  /// The trimmed, non-empty scope value.
  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScopeValue && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'ScopeValue($value)';
}

/// Typed value object pairing a [ScopeLevel] with a [ScopeValue].
///
/// Represents one filter constraint in a curriculum scope: "level 2 = Chullin"
/// means the user's scope is restricted to the Chullin masechta.
///
/// ## Relationship to database
/// The Drift `curriculum_scopes` table stores `scopeLevel` (Int) and
/// `scopeValue` (Text) as raw primitives. Convert to/from [CurriculumScope] at
/// the repository boundary.
///
/// ## Relationship to [ScopeEntry]
/// The features layer's `ScopeEntry` (in `add_track_result.dart`) wraps the
/// same pair as raw `int` + `String`. [CurriculumScope] is the typed equivalent
/// at the core/domain level.
class CurriculumScope {
  /// Constructs a [CurriculumScope] from typed [level] and [scopeValue].
  const CurriculumScope({required this.level, required this.scopeValue});

  /// Convenience constructor from raw primitives.
  ///
  /// Throws [ArgumentError] when [rawLevel] or [rawValue] violate invariants.
  factory CurriculumScope.fromRaw({
    required int rawLevel,
    required String rawValue,
  }) =>
      CurriculumScope(
        level: ScopeLevel(rawLevel),
        scopeValue: ScopeValue(rawValue),
      );

  /// The hierarchy level being filtered.
  final ScopeLevel level;

  /// The value at that hierarchy level (e.g. "Berakhot").
  final ScopeValue scopeValue;

  // ---------------------------------------------------------------------------
  // Equality + hash
  // ---------------------------------------------------------------------------

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CurriculumScope &&
          other.level == level &&
          other.scopeValue == scopeValue;

  @override
  int get hashCode => Object.hash(level, scopeValue);

  @override
  String toString() => 'CurriculumScope(level=$level, value=$scopeValue)';
}

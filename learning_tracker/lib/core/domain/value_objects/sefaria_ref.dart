import 'package:freezed_annotation/freezed_annotation.dart';

part 'sefaria_ref.freezed.dart';

/// Typed value object wrapping a Sefaria reference string.
///
/// A Sefaria reference is a structured identifier for a unit of Jewish text,
/// e.g. "Mishnah Berakhot 1:1", "Shabbat 2a", "Genesis 1:1".
///
/// ## Invariants
/// - Value is non-empty after trimming.
/// - Value does not contain leading/trailing whitespace.
///
/// ## Usage
/// Prefer [SefariaRef] over raw [String] for any field that holds a Sefaria
/// reference. Raw strings remain in the Drift schema and Firestore codec layers
/// (which deal in primitive types); convert to [SefariaRef] at the domain
/// boundary.
///
/// ```dart
/// final ref = SefariaRef.parse('  Mishnah Berakhot 1:1  ');
/// print(ref.value);       // 'Mishnah Berakhot 1:1'
/// print(ref.titlePart);   // 'Mishnah Berakhot'
/// print(ref.addressPart); // '1:1'
/// ```
///
/// ## Construction
/// The only production constructors are the validating factories
/// [SefariaRef.parse], [SefariaRef.tryParse] and [SefariaRef.fromString]
/// below — [SefariaRef._raw] is library-private, so an empty [SefariaRef]
/// can never be constructed from outside this file. `==`/`hashCode` are
/// freezed-generated from [value]; `toString` is hand-written (not
/// freezed-generated) to keep the existing `SefariaRef(value)` display form.
@Freezed(map: FreezedMapOptions.none, when: FreezedWhenOptions.none)
abstract class SefariaRef with _$SefariaRef {
  const SefariaRef._();

  /// Private, validated constructor. Reached only via [SefariaRef.parse] /
  /// [SefariaRef.tryParse] / [SefariaRef.fromString].
  const factory SefariaRef._raw(String value) = _SefariaRef;

  // ---------------------------------------------------------------------------
  // Constructors
  // ---------------------------------------------------------------------------

  /// Parses [raw] into a [SefariaRef].
  ///
  /// Trims whitespace and normalises en-dashes to hyphens before storing.
  /// Throws [FormatException] when [raw] is empty after trimming.
  factory SefariaRef.parse(String raw) {
    final trimmed = _normalise(raw);
    if (trimmed.isEmpty) {
      throw FormatException('SefariaRef cannot be empty.', raw);
    }
    return SefariaRef._raw(trimmed);
  }

  /// Returns a [SefariaRef] for [raw], or `null` when [raw] is empty / blank.
  static SefariaRef? tryParse(String? raw) {
    if (raw == null) return null;
    final trimmed = _normalise(raw);
    return trimmed.isEmpty ? null : SefariaRef._raw(trimmed);
  }

  /// Convenience factory — same as [SefariaRef.parse] but named for symmetry
  /// with Dart numeric constructors.
  static SefariaRef fromString(String raw) => SefariaRef.parse(raw);

  // ---------------------------------------------------------------------------
  // Segment operations
  // ---------------------------------------------------------------------------

  /// The title portion of the reference — everything before the final numeric
  /// address token.
  ///
  /// For `"Mishnah Berakhot 1:1"` this is `"Mishnah Berakhot"`.
  /// For `"Shabbat 2a"` this is `"Shabbat"`.
  /// Returns the full [value] when no address token is found (rare for valid
  /// Sefaria refs, but defensive).
  String get titlePart {
    final pair = _splitTail(value);
    return pair == null ? value : pair.$1;
  }

  /// The address portion of the reference — the trailing numeric (+ optional
  /// letter) token, e.g. `"1:1"`, `"2a"`, `"3"`.
  ///
  /// Returns `null` when the reference has no detectable address tail.
  String? get addressPart {
    final pair = _splitTail(value);
    return pair?.$2;
  }

  /// Normalises this reference to a lower-case, punctuation-stripped, canonical
  /// form suitable for fuzzy equality comparisons.
  ///
  /// This is the same normalisation applied by the existing
  /// `SefariaRefMatcher.normalizeRef` function and is provided here so callers
  /// on the domain side do not need to import the presentation-layer matcher.
  String get normalised {
    return value
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll(':', '.')
        .replaceAll(RegExp(r'[^a-z0-9.\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Whether this reference's title part begins with `"Mishnah "`.
  bool get isMishnah => value.toLowerCase().startsWith('mishnah ');

  /// Whether this reference's title part begins with `"Jerusalem Talmud "`.
  bool get isYerushalmi => value.toLowerCase().startsWith('jerusalem talmud ');

  // ---------------------------------------------------------------------------
  // toString
  // ---------------------------------------------------------------------------

  /// Hand-written (not freezed-generated) to keep the existing
  /// `SefariaRef(value)` display form (freezed's default would render
  /// `SefariaRef(value: value)`).
  @override
  String toString() => 'SefariaRef($value)';

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static String _normalise(String raw) =>
      raw.trim().replaceAll('–', '-'); // en-dash → hyphen

  /// Splits [ref] into `(title, address)` by peeling the trailing address
  /// token from the end: a digit run, optionally followed by `:` and another
  /// digit run (chapter:verse, e.g. `"1:1"`), optionally followed by a
  /// single letter (amud, e.g. `"2a"`).
  static (String, String)? _splitTail(String ref) {
    final match = RegExp(
      r'^(.*?)(\d+(?::\d+)?[a-z]?)$',
    ).firstMatch(ref.replaceAll('_', ' ').trim());
    if (match == null) return null;
    return ((match.group(1) ?? '').trim(), (match.group(2) ?? '').trim());
  }
}

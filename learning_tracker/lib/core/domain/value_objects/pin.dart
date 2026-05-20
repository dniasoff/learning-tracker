/// Typed value object for a 4-digit ASCII numeric PIN.
///
/// Used for the Parent PIN and (in future) the Tutor PIN. Wraps the raw
/// 4-character digit string and validates the invariant on construction so
/// callers never need to check the format themselves.
///
/// ## Invariants
/// - Exactly 4 characters.
/// - All characters are ASCII decimal digits ('0'–'9').
///
/// ## Usage
/// ```dart
/// final pin = Pin.parse('1234');       // valid
/// Pin.parse('12');                     // throws FormatException (too short)
/// Pin.parse('12ab');                   // throws FormatException (non-digit)
///
/// final pin = Pin.tryParse(rawInput);  // null when invalid
/// ```
///
/// The raw digit string can be passed directly to bcrypt hashing:
/// ```dart
/// final hash = BCrypt.hashpw(pin.value, BCrypt.gensalt());
/// ```
class Pin {
  const Pin._(this.value);

  /// The 4-character digit string.
  final String value;

  // ---------------------------------------------------------------------------
  // Constructors
  // ---------------------------------------------------------------------------

  static final _digitRegex = RegExp(r'^\d{4}$');

  /// Parses [raw] into a [Pin].
  ///
  /// Throws [FormatException] when [raw] is not exactly 4 ASCII decimal digits.
  factory Pin.parse(String raw) {
    if (!_digitRegex.hasMatch(raw)) {
      throw FormatException('Pin must be exactly 4 ASCII decimal digits.', raw);
    }
    return Pin._(raw);
  }

  /// Returns a [Pin] for [raw], or `null` when [raw] is not a valid PIN.
  static Pin? tryParse(String? raw) {
    if (raw == null) return null;
    return _digitRegex.hasMatch(raw) ? Pin._(raw) : null;
  }

  // ---------------------------------------------------------------------------
  // Equality + hash
  // ---------------------------------------------------------------------------

  /// Two [Pin]s are equal when their digit strings are identical.
  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Pin && other.value == value;

  @override
  int get hashCode => value.hashCode;

  /// Returns a masked form of the PIN for safe display/logging.
  @override
  String toString() => 'Pin(****)';
}

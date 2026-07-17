import 'package:freezed_annotation/freezed_annotation.dart';

part 'pin.freezed.dart';

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
///
/// ## Construction
/// The only production constructors are the validating factories [Pin.parse]
/// and [Pin.tryParse] below — [Pin._raw] is library-private, so an invalid
/// [Pin] can never be constructed from outside this file. `==`/`hashCode`
/// are freezed-generated from [value]; `toString` is hand-written (not
/// freezed-generated) so the digit string is never leaked via logging.
@Freezed(map: FreezedMapOptions.none, when: FreezedWhenOptions.none)
abstract class Pin with _$Pin {
  const Pin._();

  /// Private, validated constructor. Reached only via [Pin.parse] /
  /// [Pin.tryParse].
  const factory Pin._raw(String value) = _Pin;

  static final _digitRegex = RegExp(r'^\d{4}$');

  /// Parses [raw] into a [Pin].
  ///
  /// Throws [FormatException] when [raw] is not exactly 4 ASCII decimal digits.
  factory Pin.parse(String raw) {
    if (!_digitRegex.hasMatch(raw)) {
      throw FormatException('Pin must be exactly 4 ASCII decimal digits.', raw);
    }
    return Pin._raw(raw);
  }

  /// Returns a [Pin] for [raw], or `null` when [raw] is not a valid PIN.
  static Pin? tryParse(String? raw) {
    if (raw == null) return null;
    return _digitRegex.hasMatch(raw) ? Pin._raw(raw) : null;
  }

  /// Returns a masked form of the PIN for safe display/logging.
  ///
  /// Hand-written (not freezed-generated) so the digit string is never
  /// leaked via `toString`/logging.
  @override
  String toString() => 'Pin(****)';
}

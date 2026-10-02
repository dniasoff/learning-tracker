/// Shared strict-codec helpers for the AD-52 learner-state storage types.
///
/// Everything under `lib/domain/**` is pure Dart: no Firestore, Firebase,
/// Flutter or Riverpod import. Storage maps produced and consumed here use
/// plain Dart values only — a Firestore timestamp is a UTC [DateTime] on
/// this side of the boundary, and the `lib/data/repositories/**`
/// implementation converts it to and from the SDK's timestamp type (AD-41:
/// timestamps are for ordering only; civil dates are `YYYY-MM-DD` strings).
///
/// AD-52: storage names and types are exactly the Storage Schema table, and
/// adding a field means editing that table. The helpers below make every
/// codec fail loudly — with a typed [StorageFormatException] — instead of
/// silently widening that contract.
library;

/// A storage map failed AD-52 validation, on encode or on decode.
///
/// [field] names the offending storage key (or `<doc>` for a whole-map
/// problem such as an unknown key); [reason] is a short machine-friendly
/// explanation. Never carries learner data beyond the key name.
final class StorageFormatException implements Exception {
  /// Creates a validation failure for [field] in [type].
  const StorageFormatException(this.type, this.field, this.reason);

  /// The Dart type whose codec rejected the map (e.g. `LearningEvent`).
  final String type;

  /// The storage key at fault.
  final String field;

  /// Why it was rejected.
  final String reason;

  @override
  String toString() => 'StorageFormatException($type.$field): $reason';
}

/// Crockford base32 ULID, 26 characters (case-insensitive, as the parent
/// spine's profile-id check in `repository_providers.dart` accepts).
final RegExp ulidPattern = RegExp(
  r'^[0-9A-HJKMNP-TV-Z]{26}$',
  caseSensitive: false,
);

/// The AD-41 / AD-46 civil-date shape.
final RegExp civilDatePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// Whether [value] is a ULID string.
bool isUlid(String value) => ulidPattern.hasMatch(value);

/// Whether [value] is a real `YYYY-MM-DD` calendar date (pattern AND a
/// valid day of that month — `2026-02-30` is rejected).
bool isCivilDate(String value) {
  if (!civilDatePattern.hasMatch(value)) return false;
  final year = int.parse(value.substring(0, 4));
  final month = int.parse(value.substring(5, 7));
  final day = int.parse(value.substring(8, 10));
  if (month < 1 || month > 12 || day < 1) return false;
  final parsed = DateTime.utc(year, month, day);
  return parsed.year == year && parsed.month == month && parsed.day == day;
}

/// Reads storage maps for one codec, accumulating nothing: the first
/// violation throws.
final class StorageReader {
  /// Wraps [map] for decoding as [type].
  StorageReader(this.type, this.map);

  /// The Dart type being decoded (for error messages).
  final String type;

  /// The raw storage map.
  final Map<String, Object?> map;

  /// Throws if [map] holds any key outside [allowed] (AD-46 `hasOnly`).
  void requireOnly(Set<String> allowed) {
    for (final key in map.keys) {
      if (!allowed.contains(key)) {
        throw StorageFormatException(type, key, 'unknown key');
      }
    }
  }

  /// Throws if [key] is present (even with a null value).
  void forbid(String key, String reason) {
    if (map.containsKey(key)) {
      throw StorageFormatException(type, key, reason);
    }
  }

  /// A required, non-null value of type [T].
  T required<T extends Object>(String key) {
    if (!map.containsKey(key)) {
      throw StorageFormatException(type, key, 'missing required key');
    }
    final value = map[key];
    if (value is! T) {
      throw StorageFormatException(
        type,
        key,
        'expected $T, got ${value == null ? 'null' : 'other type'}',
      );
    }
    return value;
  }

  /// An optional value of type [T]: an absent key and an explicit `null`
  /// both read as `null` (AD-38: "`null` per field = absent").
  T? optional<T extends Object>(String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is! T) {
      throw StorageFormatException(type, key, 'expected $T');
    }
    return value;
  }

  /// A key that must be present but may hold `null` (e.g. `learned_on`).
  T? requiredNullable<T extends Object>(String key) {
    if (!map.containsKey(key)) {
      throw StorageFormatException(type, key, 'missing required key');
    }
    return optional<T>(key);
  }

  /// A required number, widened to [double] (Firestore may hand back an
  /// `int` for a whole-valued number).
  double requiredNumber(String key) => required<num>(key).toDouble();

  /// An optional number, widened to [double].
  double? optionalNumber(String key) => optional<num>(key)?.toDouble();

  /// A required UTC instant.
  DateTime requiredInstant(String key) => required<DateTime>(key).toUtc();

  /// An optional UTC instant.
  DateTime? optionalInstant(String key) => optional<DateTime>(key)?.toUtc();

  /// A required non-empty string.
  String requiredString(String key) {
    final value = required<String>(key);
    if (value.isEmpty) throw StorageFormatException(type, key, 'empty');
    return value;
  }

  /// A required ULID string.
  String requiredUlid(String key) {
    final value = required<String>(key);
    if (!isUlid(value)) throw StorageFormatException(type, key, 'not a ULID');
    return value;
  }

  /// An optional ULID string.
  String? optionalUlid(String key) {
    final value = optional<String>(key);
    if (value != null && !isUlid(value)) {
      throw StorageFormatException(type, key, 'not a ULID');
    }
    return value;
  }

  /// A required storage-enum value: one of [byStorage]'s keys.
  E requiredEnum<E>(String key, Map<String, E> byStorage) {
    final raw = required<String>(key);
    final value = byStorage[raw];
    if (value == null) {
      throw StorageFormatException(type, key, 'invalid enum value');
    }
    return value;
  }

  /// An optional storage-enum value.
  E? optionalEnum<E>(String key, Map<String, E> byStorage) {
    final raw = optional<String>(key);
    if (raw == null) return null;
    final value = byStorage[raw];
    if (value == null) {
      throw StorageFormatException(type, key, 'invalid enum value');
    }
    return value;
  }

  /// A required string-keyed map.
  Map<String, Object?> requiredMap(String key) {
    final value = required<Map<Object?, Object?>>(key);
    return _stringKeyed(key, value);
  }

  /// A required list.
  List<Object?> requiredList(String key) => required<List<Object?>>(key);

  Map<String, Object?> _stringKeyed(String key, Map<Object?, Object?> raw) {
    final out = <String, Object?>{};
    for (final entry in raw.entries) {
      final k = entry.key;
      if (k is! String) {
        throw StorageFormatException(type, key, 'non-string map key');
      }
      out[k] = entry.value;
    }
    return out;
  }
}

/// Coerces a nested storage value to a string-keyed map, or throws.
Map<String, Object?> asStorageMap(String type, String field, Object? raw) {
  if (raw is! Map<Object?, Object?>) {
    throw StorageFormatException(type, field, 'expected map');
  }
  final out = <String, Object?>{};
  for (final entry in raw.entries) {
    final k = entry.key;
    if (k is! String) {
      throw StorageFormatException(type, field, 'non-string map key');
    }
    out[k] = entry.value;
  }
  return out;
}

/// A deep, unmodifiable snapshot of a storage value: every nested map and
/// list is copied and frozen, so a value type that validated the snapshot
/// at construction cannot be changed afterwards through the caller's
/// references. Primitives and [DateTime]s are immutable and kept as is.
Object? freezeStorageValue(Object? value) {
  if (value is Map<String, Object?>) return freezeStorageMap(value);
  if (value is Map<Object?, Object?>) {
    return Map<Object?, Object?>.unmodifiable({
      for (final entry in value.entries)
        entry.key: freezeStorageValue(entry.value),
    });
  }
  if (value is List<Object?>) {
    return List<Object?>.unmodifiable(value.map(freezeStorageValue));
  }
  return value;
}

/// [freezeStorageValue] for a string-keyed storage map.
Map<String, Object?> freezeStorageMap(Map<String, Object?> map) =>
    Map<String, Object?>.unmodifiable({
      for (final entry in map.entries)
        entry.key: freezeStorageValue(entry.value),
    });

/// Deep structural equality for storage values (maps, lists, primitives,
/// [DateTime]s) — used by the value types' `==`.
bool storageValueEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is Map<Object?, Object?> && b is Map<Object?, Object?>) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key)) return false;
      if (!storageValueEquals(entry.value, b[entry.key])) return false;
    }
    return true;
  }
  if (a is List<Object?> && b is List<Object?>) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!storageValueEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

/// A hash consistent with [storageValueEquals].
int storageValueHash(Object? value) {
  if (value is Map<Object?, Object?>) {
    // Order-independent over entries.
    var h = 0;
    for (final entry in value.entries) {
      h ^= Object.hash(entry.key, storageValueHash(entry.value));
    }
    return h;
  }
  if (value is List<Object?>) {
    return Object.hashAll(value.map(storageValueHash));
  }
  return value.hashCode;
}

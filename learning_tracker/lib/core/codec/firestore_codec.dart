/// Firestore ↔ Dart type-conversion helpers.
///
/// Firestore documents arrive as `Map<String, dynamic>` after the Cloud
/// Firestore SDK deserialises them. Timestamps may appear as:
///   - a `Timestamp` object from `package:cloud_firestore`,
///   - an ISO-8601 `String` (e.g. when fetched via the REST API),
///   - an `int` (Unix epoch seconds), or
///   - a `Map<String, int> {'seconds': …, 'nanoseconds': …}` (Timestamp
///     serialised to JSON).
///
/// [FirestoreCodec] normalises all four shapes into [DateTime] (UTC) and
/// provides the inverse for push payloads.
///
/// This helper is intentionally free of `package:cloud_firestore` imports
/// so that unit tests (which run in the plain Dart VM without Firebase)
/// can use it directly.
library;

/// Static helpers for Firestore type coercions.
abstract class FirestoreCodec {
  const FirestoreCodec._();

  // ── DateTime parsing ─────────────────────────────────────────────────────────

  /// Convert a Firestore timestamp field to a UTC [DateTime].
  ///
  /// Accepts any of the four wire shapes:
  ///   - [DateTime]  — returned as-is (already parsed by the SDK).
  ///   - [String]    — parsed as ISO-8601.
  ///   - [int]       — interpreted as Unix epoch **seconds** (Firestore REST).
  ///   - [Map]       — expects `{'seconds': int}` (Timestamp JSON).
  ///
  /// Returns `null` when [raw] is null or none of the shapes match.
  static DateTime? parseDateTime(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toUtc();
    if (raw is String) {
      final dt = DateTime.tryParse(raw);
      return dt?.toUtc();
    }
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw * 1000, isUtc: true);
    }
    if (raw is Map) {
      final s = raw['seconds'];
      if (s is int) {
        return DateTime.fromMillisecondsSinceEpoch(s * 1000, isUtc: true);
      }
    }
    return null;
  }

  /// Convert a [DateTime] to an ISO-8601 string for push payloads.
  ///
  /// Always produces UTC. Returns `null` when [dt] is `null`.
  ///
  /// This produces a plain ISO-8601 UTC string — `cloud_firestore` stores a
  /// [String] as a `string`-typed field, it does NOT convert it into a
  /// `Timestamp` on write. That makes this format safe to push ONLY for
  /// fields no security rule type-checks as a timestamp (`is timestamp` in
  /// `firestore.rules`); a field guarded that way must be written as a real
  /// `Timestamp` by the repository itself, not via this helper.
  ///
  /// Reference the three collections whose rules actually enforce
  /// `is timestamp` today for how to do this correctly: `completions`'/
  /// `learning_ledger`'s `completed_at` (`firestore_completion_repository.dart`,
  /// `firestore_learning_ledger_repository.dart`) and `points_ledger`'s
  /// `created_at` (`firestore_points_ledger_repository.dart`) all pass the
  /// raw [DateTime] straight into the document map — the SDK auto-converts a
  /// [DateTime] (never a [String]) into a real `Timestamp` on write.
  /// `streak_events`' `created_at` guard (`firestore_streak_event_repository
  /// .dart`) is satisfied a different way: that repository never writes a
  /// `created_at` key at all, so the rule's "field absent" branch always
  /// applies (see that file's "No `Timestamp`-vs-`String` trap here"
  /// section).
  ///
  /// On the read side, note that `Timestamp.toDate()` returns a [DateTime]
  /// flagged local, so callers decoding a real `Timestamp` back into UTC
  /// need an explicit `.toUtc()` — see [parseDateTime]'s `DateTime` branch,
  /// which does this.
  static String? encodeDateTime(DateTime? dt) => dt?.toUtc().toIso8601String();

  // ── Primitive coercions ──────────────────────────────────────────────────────

  /// Parse an `int` from a field that may arrive as `String` or `num`.
  ///
  /// Returns `null` when [raw] is null or cannot be parsed.
  static int? parseInt(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  /// Parse a `double` from a field that may arrive as `String` or `num`.
  ///
  /// Returns `null` when [raw] is null or cannot be parsed.
  static double? parseDouble(Object? raw) {
    if (raw is double) return raw;
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }

  /// Parse a `bool` from a field that may arrive as `String` or `int`.
  ///
  /// `"true"` / `1` → `true`; `"false"` / `0` → `false`.
  /// Returns `null` when [raw] is null or cannot be parsed.
  static bool? parseBool(Object? raw) {
    if (raw is bool) return raw;
    if (raw is int) return raw != 0;
    if (raw is String) {
      if (raw == 'true') return true;
      if (raw == 'false') return false;
    }
    return null;
  }
}

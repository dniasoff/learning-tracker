/// Firestore ⇄ domain value conversion for the AD-52 learner-state codecs.
///
/// The domain codecs (`lib/domain/learner_state/**`) are package-free and
/// represent every Firestore timestamp as a UTC [DateTime]. This is the one
/// place that converts, recursively through maps and lists, so a domain
/// payload can carry timestamps inside nested values too (e.g. a
/// `change_log.after` field holding `ended_at`).
///
/// Writes never contain a `FieldValue` — in particular no
/// `serverTimestamp()` (AD-46): every time in a payload was stamped by the
/// client before the first attempt.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Domain → Firestore: every [DateTime] becomes a [Timestamp] (same
/// instant, microsecond precision); maps and lists are copied recursively.
Object? toFirestoreValue(Object? value) {
  if (value is DateTime) return Timestamp.fromDate(value.toUtc());
  if (value is Map<Object?, Object?>) {
    return <String, Object?>{
      for (final entry in value.entries)
        entry.key! as String: toFirestoreValue(entry.value),
    };
  }
  if (value is List<Object?>)
    return [for (final v in value) toFirestoreValue(v)];
  return value;
}

/// Firestore → domain: every [Timestamp] becomes a UTC [DateTime]; maps and
/// lists are copied recursively with string keys.
Object? fromFirestoreValue(Object? value) {
  if (value is Timestamp) return value.toDate().toUtc();
  if (value is Map<Object?, Object?>) {
    return <String, Object?>{
      for (final entry in value.entries)
        '${entry.key}': fromFirestoreValue(entry.value),
    };
  }
  if (value is List<Object?>) {
    return [for (final v in value) fromFirestoreValue(v)];
  }
  return value;
}

/// [toFirestoreValue] for a top-level document map.
Map<String, Object?> toFirestoreMap(Map<String, Object?> map) =>
    toFirestoreValue(map)! as Map<String, Object?>;

/// [fromFirestoreValue] for a top-level document map.
Map<String, Object?> fromFirestoreMap(Map<String, Object?> map) =>
    fromFirestoreValue(map)! as Map<String, Object?>;

/// Client-side create-only pre-check shared by the append-only learner-state
/// writes (`learning_events/{ulid}`, `change_log/{ulid}` — AD-31, AD-38,
/// AD-46).
///
/// The Flutter Firestore SDK has no queueable "create if absent" write: a
/// `set()` is an upsert, and a transaction cannot run offline. So the
/// repositories read the target document first and only `set()` when it
/// does not exist. The read is layered so an existing document is found
/// wherever the client can see it, without breaking offline capture:
///
/// 1. **Local cache.** A hit is authoritative for "exists". A cache MISS
///    surfaces as `FirebaseException(code: 'unavailable')` and falls through.
///    ANY other cache error is rethrown — it is never collapsed into
///    "absent", because that would turn a read failure into an overwrite.
/// 2. **Server.** Catches an event or entry that exists only remotely (an
///    acknowledged write whose cache entry was evicted or cleared, or one
///    written from another device). A server `unavailable` means the client
///    is offline: the create is queued and the server-side AD-46 rules
///    (create-only plus identical replay, Story 1.9 / DNI-471, follow-up
///    `learning-tracker-fyh.74`) reject a non-identical write at sync time.
///    Any other server error is rethrown.
///
/// The pre-check narrows the window but is not atomic with the `set()`; the
/// rules are the atomic guarantee.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Reads an existing document for a create-only write: its data when it
/// exists, or null when the client can establish it is absent (or is
/// offline, see the library doc). Never returns null for a read failure.
typedef CreateGuardRead =
    Future<Map<String, dynamic>?> Function(
      DocumentReference<Map<String, dynamic>> doc,
    );

/// Firestore's code for a cache miss (`Source.cache`) and for an offline
/// client (`Source.server`).
const _kUnavailable = 'unavailable';

/// The default [CreateGuardRead]: local cache, then server (library doc).
Future<Map<String, dynamic>?> readExistingForCreate(
  DocumentReference<Map<String, dynamic>> doc,
) async {
  try {
    final cached = await doc.get(const GetOptions(source: Source.cache));
    if (cached.exists) return cached.data();
  } on FirebaseException catch (e) {
    if (e.code != _kUnavailable) rethrow;
  }
  try {
    final remote = await doc.get(const GetOptions(source: Source.server));
    return remote.exists ? remote.data() : null;
  } on FirebaseException catch (e) {
    if (e.code != _kUnavailable) rethrow;
    return null; // offline: queue; the AD-46 rules guard at sync time
  }
}

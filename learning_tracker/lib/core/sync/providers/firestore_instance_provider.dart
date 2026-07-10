import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/logging/log_events.dart';
import 'package:learning_tracker/core/logging/logger.dart';

/// The single canonical provider for [FirebaseFirestore].
///
/// Lives in `core/sync/` because Firestore is a sync concern — this is
/// the only allowed import site of `package:cloud_firestore` via provider
/// infrastructure (the actual queries live in `firestore_gateway_impl.dart`).
///
/// All callers that previously imported `firebaseFirestoreProvider` from
/// `core/providers/firebase_providers.dart` should import from here instead.
final firebaseFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

/// Forces the Firestore gRPC channel to re-establish by toggling its
/// network state. Use this on a real foreground return (i.e. after the
/// app has been in a non-resumed lifecycle state) to recover from a
/// stale-DNS / half-open-channel symptom — for example after a WiFi↔cell
/// handoff, a VPN reconnect, or a long background.
///
/// Disables network, then re-enables it. Existing references to
/// `FirebaseFirestore.instance` remain valid; only the underlying
/// connection is recycled. Any in-flight reads switch to cache while
/// disabled and resume against the fresh channel after re-enable.
///
/// This helper lives alongside [firebaseFirestoreProvider] so the
/// cloud_firestore import quarantine (DNI-333 AC) stays confined to
/// `core/sync/`.
///
/// A failure from either [FirebaseFirestore.disableNetwork] or
/// [FirebaseFirestore.enableNetwork] (AUD-core-sync-14 — most dangerously
/// `enableNetwork()` throwing AFTER `disableNetwork()` already succeeded,
/// e.g. a plugin-channel error or a terminated instance) is caught and
/// logged here rather than left to propagate unhandled. Centralising the
/// guard in the function itself means every caller gets the protection for
/// free — a caller does not need its own try/catch to keep a reset failure
/// from aborting whatever sequence it awaited the reset from (in
/// particular the lifecycle-resume chain: timezone redetect → sacred-cache
/// invalidation → resume pull). This is deliberately fire-and-forget: the
/// next connectivity change or lifecycle resume will attempt the reset
/// again, so no bounded retry is needed here.
///
/// [firestore] and [logger] are test-only seams — production callers always
/// get [FirebaseFirestore.instance] and [AppLogger.instance].
Future<void> resetFirestoreNetwork({
  @visibleForTesting FirebaseFirestore? firestore,
  @visibleForTesting AppLogger? logger,
}) async {
  final fs = firestore ?? FirebaseFirestore.instance;
  try {
    await fs.disableNetwork();
    await fs.enableNetwork();
  } catch (e, st) {
    (logger ?? AppLogger.instance).warning(
      event: LogEvents.sync.firestoreNetworkResetFailed,
      exception: e,
      stackTrace: st,
    );
  }
}

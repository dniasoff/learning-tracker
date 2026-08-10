import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/logging/log_events.dart';
import 'package:learning_tracker/core/logging/logger.dart';

/// The default (non-named) app's `FirebaseFirestore` singleton.
///
/// **Phase 1 (AD-1/AD-2) status.** This is the pre-registry, single-instance
/// data path. `AccountFirebase` (`lib/data/firestore/account_firebase.dart`)
/// is now the canonical per-account resolution seam and the only path for
/// NEW call sites — there is no feature flag left choosing between it and
/// this singleton (the old `accountFirebaseRegistryEnabledProvider` flag and
/// its legacy fallback shim in `account_firebase_providers.dart` were
/// deleted once the registry became the sole data path). This function
/// remains the sole implementation for [firebaseFirestoreProvider] and
/// [resetFirestoreNetwork]'s default — deliberately still not routed
/// through the registry itself: this file's existing callers
/// (`tutored_pull_providers.dart`, `outbox_providers.dart`) are the
/// still-live pre-Phase-1 sync engine, which Phase 1 does not cut over
/// ("no collection reads through it until Phase 2/3" — migration plan).
/// Kept as exactly one call site (was two, in [firebaseFirestoreProvider]
/// and [resetFirestoreNetwork] separately) so the AD-2/AD-28 bare-instance
/// ratchet (`tool/check_bare_firebase_instance_ratchet.dart`) counts one
/// site here, not two.
FirebaseFirestore _defaultFirestoreInstance() => FirebaseFirestore.instance;

/// The single canonical provider for [FirebaseFirestore].
///
/// Lives in `core/sync/` because Firestore is a sync concern — this is
/// the only allowed import site of `package:cloud_firestore` via provider
/// infrastructure (the actual queries live in `firestore_gateway_impl.dart`).
///
/// All callers that previously imported `firebaseFirestoreProvider` from
/// `core/providers/firebase_providers.dart` should import from here instead.
final firebaseFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return _defaultFirestoreInstance();
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
  final fs = firestore ?? _defaultFirestoreInstance();
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

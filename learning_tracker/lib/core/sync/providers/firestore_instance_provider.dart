import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
Future<void> resetFirestoreNetwork() async {
  final fs = FirebaseFirestore.instance;
  await fs.disableNetwork();
  await fs.enableNetwork();
}

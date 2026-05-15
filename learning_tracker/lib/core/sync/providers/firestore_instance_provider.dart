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

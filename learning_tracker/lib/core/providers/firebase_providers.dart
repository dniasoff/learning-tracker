import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for [FirebaseStorage].
///
/// Note: `firebaseFirestoreProvider` has moved to
/// `core/sync/providers/firestore_instance_provider.dart` — that is the only
/// file permitted to import `package:cloud_firestore`.
final firebaseStorageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});

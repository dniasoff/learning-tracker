import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';

/// SDK-neutral metadata from the representative account-document listener.
final class FirestoreSyncSnapshot {
  const FirestoreSyncSnapshot({
    required this.hasPendingWrites,
    required this.isFromCache,
  });

  final bool hasPendingWrites;
  final bool isFromCache;
}

/// Converts an SDK snapshot at the repository boundary into the metadata
/// value consumed by feature code.
FirestoreSyncSnapshot firestoreSyncSnapshotFromSdk(Object snapshot) {
  final documentSnapshot =
      snapshot as DocumentSnapshot<Map<String, dynamic>>;
  return FirestoreSyncSnapshot(
    hasPendingWrites: documentSnapshot.metadata.hasPendingWrites,
    isFromCache: documentSnapshot.metadata.isFromCache,
  );
}

/// Repository interface for the settings sync-status projection.
abstract interface class FirestoreSyncStatusRepository {
  Stream<FirestoreSyncSnapshot> watchAccount();
}

final firestoreSyncStatusRepositoryProvider =
    FutureProvider<FirestoreSyncStatusRepository?>((ref) async {
      final handles = await ref.watch(activeAccountFirebaseProvider.future);
      if (handles == null) return null;
      return _FirestoreSyncStatusRepository(
        firestore: handles.firestore,
        uid: handles.uid,
      );
    }, retry: (retryCount, error) => null);

final class _FirestoreSyncStatusRepository
    implements FirestoreSyncStatusRepository {
  _FirestoreSyncStatusRepository({
    required FirebaseFirestore firestore,
    required String uid,
  }) : _firestore = firestore,
       _uid = uid;

  final FirebaseFirestore _firestore;
  final String _uid;

  @override
  Stream<FirestoreSyncSnapshot> watchAccount() => _firestore
      .collection('users')
      .doc(_uid)
      .snapshots(includeMetadataChanges: true)
      .map(
        firestoreSyncSnapshotFromSdk,
      );
}

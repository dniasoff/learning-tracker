import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';

/// The state exposed by the representative Firestore listener used by the
/// settings backup card.
enum FirestoreSyncStatus { unknown, synced, syncing, offline }

/// Maps the SDK's live snapshot metadata to the status shown in Settings.
///
/// Pending writes take precedence over cache state: a local write that has
/// not been acknowledged is specifically a pending/syncing state, even when
/// the SDK also reports that the snapshot is from cache.
FirestoreSyncStatus firestoreSyncStatusFromSnapshot(
  DocumentSnapshot<Map<String, dynamic>> snapshot,
) {
  final metadata = snapshot.metadata;
  if (metadata.hasPendingWrites) return FirestoreSyncStatus.syncing;
  if (metadata.isFromCache) return FirestoreSyncStatus.offline;
  return FirestoreSyncStatus.synced;
}

/// Watches the account document as a representative live Firestore stream.
///
/// This deliberately does not turn a terminal listener error into "synced".
/// The [StreamProvider] surfaces the error to the widget, where the user can
/// explicitly retry the listener.
final firestoreSyncStatusProvider =
    StreamProvider.autoDispose<FirestoreSyncStatus>((ref) async* {
      final handles = await ref.watch(activeAccountFirebaseProvider.future);
      if (handles == null) {
        yield FirestoreSyncStatus.unknown;
        return;
      }

      yield* handles.firestore
          .collection('users')
          .doc(handles.uid)
          .snapshots(includeMetadataChanges: true)
          .map(firestoreSyncStatusFromSnapshot);
    }, retry: (retryCount, error) => null);

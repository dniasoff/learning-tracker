/// Firestore I/O facade.
///
/// `FirestoreGateway` is the public seam between the rest of the sync
/// subsystem and Firestore. Concrete implementations encapsulate
/// `package:cloud_firestore/cloud_firestore.dart`; everything else in `lib/`
/// goes through this interface, so Firestore types never leak across the
/// boundary. (See `core/sync/firestore_gateway_impl.dart` for the only
/// allowed importer of `cloud_firestore`.)
///
/// Methods come in two families:
///   * `push*` — write a single mutation document for an entity kind.
///   * `fetchPage` — paginated read for a collection, used by [PullPipeline].
abstract class FirestoreGateway {
  Future<void> pushCompletion({
    required int profileId,
    required Map<String, dynamic> data,
  });

  Future<void> pushStreak({
    required int profileId,
    required Map<String, dynamic> data,
  });

  Future<void> pushSettings({
    required int profileId,
    required Map<String, dynamic> data,
  });

  Future<void> pushTrack({
    required int profileId,
    required Map<String, dynamic> data,
  });

  Future<void> pushLearningOrder({
    required int profileId,
    required Map<String, dynamic> data,
  });

  Future<void> pushBookmark({
    required int profileId,
    required Map<String, dynamic> data,
  });

  // ── P2a additions ──────────────────────────────────────────────────────────

  Future<void> pushNotificationSettings({
    required int profileId,
    required Map<String, dynamic> data,
  });

  Future<void> pushGamificationSettings({
    required int profileId,
    required Map<String, dynamic> data,
  });

  /// Fetch one page of documents from [collection] for [profileId].
  ///
  /// Pages are ordered server-side by document key. Pass the previous
  /// page's last row back as [cursor] to advance; pass `null` to start from
  /// the beginning. An empty [FirestorePage.rows] signals end-of-stream.
  Future<FirestorePage> fetchPage({
    required int profileId,
    required String collection,
    required int pageSize,
    Map<String, dynamic>? cursor,
  });
}

/// Result of [FirestoreGateway.fetchPage].
///
/// The [rows] list is empty when no more documents remain. The pipeline
/// uses the *last* row as the cursor for the subsequent page (so the row
/// must carry whatever fields the gateway needs to resume).
class FirestorePage {
  const FirestorePage({required this.rows});
  final List<Map<String, dynamic>> rows;
}

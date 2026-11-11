import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/features/social/domain/social_summary.dart';

/// Reads social projections from the server so a revoked summary is not
/// served from Firestore's offline document cache.
final class FirestoreSocialSummaryRepository {
  const FirestoreSocialSummaryRepository(this._firestore);

  final FirebaseFirestore _firestore;

  Future<SocialSummary?> read(String summaryId) async {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(summaryId)) {
      throw const FormatException('Invalid social summary id');
    }
    final snapshot = await _firestore
        .collection('social_summaries')
        .doc(summaryId)
        .get(const GetOptions(source: Source.server));
    if (!snapshot.exists) return null;
    final data = snapshot.data()!;
    final computedAt = data['computed_at'];
    if (computedAt is Timestamp) data['computed_at'] = computedAt.toDate();
    return SocialSummary.fromWire(data);
  }
}

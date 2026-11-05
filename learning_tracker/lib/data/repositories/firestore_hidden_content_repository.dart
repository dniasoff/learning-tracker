import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/core/providers/account_functions_provider.dart';

/// Reads and writes the hidden node refs for one learner profile.
///
/// The field is kept on the profile document so it follows the profile's
/// existing Firestore sync/read scope. Parent writes are currently gated by
/// the client parent-PIN session; the write is isolated here so 7vx can add
/// the server-issued parent session id at one seam.
class FirestoreHiddenContentRepository {
  FirestoreHiddenContentRepository({
    required FirebaseFirestore firestore,
    required String ownerUid,
    required String profileId,
    required AccountFunctionsResolver resolveFunctions,
    String? parentSessionId,
  }) : _resolveFunctions = resolveFunctions,
       _ownerUid = ownerUid,
       _parentSessionId = parentSessionId,
       _doc = firestore
           .collection('users')
           .doc(ownerUid)
           .collection('learner_profiles')
           .doc(profileId);

  final DocumentReference<Map<String, dynamic>> _doc;
  final AccountFunctionsResolver _resolveFunctions;
  final String _ownerUid;
  final String? _parentSessionId;

  static const fieldName = 'hidden_content_refs';

  Future<Set<String>> getHiddenRefs() async {
    final data = (await _doc.get()).data();
    return _decode(data?[fieldName]);
  }

  Stream<Set<String>> watchHiddenRefs() =>
      _doc.snapshots().map((snapshot) => _decode(snapshot.data()?[fieldName]));

  /// Single write seam for both the parent and tutor paths.
  ///
  /// The owner caller must have passed the parent PIN gate. The provider
  /// supplies the server-issued [parentSessionId] for owner writes; tutor
  /// writes continue to use their grant proof instead.
  Future<void> setHiddenRefs(
    Set<String> refs, {
    String? grantId,
    String? ownerUid,
    String? parentSessionId,
  }) async {
    final callable = (await _resolveFunctions()).httpsCallable(
      'setProfileHiddenContent',
    );
    await callable.call<Map<String, dynamic>>(<String, dynamic>{
      'profileId': _doc.id,
      'ownerUid': ownerUid ?? _ownerUid,
      'hiddenRefs': refs.toList(growable: false)..sort(),
      if (grantId != null) 'grantId': grantId,
      if ((parentSessionId ?? _parentSessionId) != null)
        'parentSessionId': parentSessionId ?? _parentSessionId,
    });
  }

  static Set<String> _decode(Object? value) {
    if (value is! Iterable) return const {};
    return {
      for (final ref in value)
        if (ref is String && ref.isNotEmpty) ref,
    };
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';

/// Persists the reward catalogue in the same open-ended settings document
/// written by `tutorUpdateGamificationSettings`.
///
/// The document is intentionally a shared settings bag. Reward state lives
/// under `reward_settings`, so point-settings writes from either side remain
/// siblings in the document and Firestore's merge semantics do not erase them.
class FirestoreRewardSettingsRepository {
  FirestoreRewardSettingsRepository({
    required FirebaseFirestore firestore,
    required String uid,
    required String profileId,
  }) : _firestore = firestore,
       _uid = uid,
       _profileId = profileId;

  final FirebaseFirestore _firestore;
  final String _uid;
  final String _profileId;

  DocumentReference<Map<String, dynamic>> get _settings => _firestore
      .collection('users')
      .doc(_uid)
      .collection('learner_profiles')
      .doc(_profileId)
      .collection('preferences')
      .doc('gamification_settings');

  /// Reads the reward sub-map, or `null` when no reward settings exist yet.
  ///
  /// A present but malformed sub-map throws. Returning an empty reward list
  /// here would turn a backend/schema failure into a fabricated achievement
  /// state (D-E).
  Future<Map<String, dynamic>?> readRewardSettings() async {
    final snapshot = await _settings.get();
    final data = snapshot.data();
    if (data == null || !data.containsKey('reward_settings')) return null;

    final raw = data['reward_settings'];
    if (raw is! Map) {
      throw const FormatException(
        'gamification_settings.reward_settings must be a map',
      );
    }
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }

  /// Merges the owner-produced reward snapshot into the shared settings doc.
  Future<void> writeRewardSettings(Map<String, dynamic> rewardSettings) async {
    await _settings.set(<String, dynamic>{
      'reward_settings': rewardSettings,
    }, SetOptions(merge: true));
  }
}

/// Resolves the owner-side reward settings repository for the active profile.
///
/// This provider is hand-written deliberately: adding a generated provider
/// would require code generation, which is not needed for this small seam.
final firestoreRewardSettingsRepositoryProvider =
    FutureProvider<FirestoreRewardSettingsRepository?>((ref) async {
      final handles = await ref.watch(activeAccountFirebaseProvider.future);
      final profileId = ref.watch(activeProfileDocIdProvider);
      if (handles == null || profileId == null || profileId.isEmpty) {
        return null;
      }
      return FirestoreRewardSettingsRepository(
        firestore: handles.firestore,
        uid: handles.uid,
        profileId: profileId,
      );
    });

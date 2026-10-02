import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/firestore/write_ack.dart';

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

  /// The AD-27 / AD-50 achievement latch field of this document.
  static const unlockedAchievementIdsField = 'unlocked_achievement_ids';

  /// The latched achievement ids (`unlocked_achievement_ids`); empty when
  /// the document or the field is absent. A present but malformed field
  /// throws (D-E: never a fabricated "nothing unlocked").
  Future<Set<String>> readUnlockedAchievementIds() async =>
      _decodeUnlocked((await _settings.get()).data());

  /// Live [readUnlockedAchievementIds]: every achievement surface reads
  /// this list and nothing else (DNI-480, AD-50).
  Stream<Set<String>> watchUnlockedAchievementIds() =>
      _settings.snapshots().map((s) => _decodeUnlocked(s.data()));

  /// Array-unions [achievementIds] into `unlocked_achievement_ids`
  /// (`LearningCommands`' latch, DNI-480). Merge plus array union keeps the
  /// list monotonic and idempotent: a repeated or concurrent latch of the
  /// same id from any device leaves one id, and sibling keys
  /// (`reward_settings`, point settings) are untouched.
  Future<void> latchUnlockedAchievementIds(Set<String> achievementIds) async {
    if (achievementIds.isEmpty) return;
    await _settings.set(<String, dynamic>{
      unlockedAchievementIdsField: FieldValue.arrayUnion([...achievementIds]),
    }, SetOptions(merge: true)).orQueuedOffline;
  }

  static Set<String> _decodeUnlocked(Map<String, dynamic>? data) {
    final raw = data?[unlockedAchievementIdsField];
    if (raw == null) return const {};
    if (raw is! List || raw.any((e) => e is! String)) {
      throw const FormatException(
        'gamification_settings.unlocked_achievement_ids must be a list of '
        'strings',
      );
    }
    return Set.unmodifiable(raw.cast<String>());
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

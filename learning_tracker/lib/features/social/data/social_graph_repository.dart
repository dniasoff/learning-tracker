import 'package:cloud_functions/cloud_functions.dart';
import 'package:learning_tracker/features/social/domain/social_graph.dart';
import 'package:learning_tracker/features/social/domain/social_summary_visibility.dart';

typedef SocialCallableInvoker =
    Future<Object?> Function(String name, Map<String, Object?> data);

/// Callable-only client for social graph state. No client writes to Firestore.
final class SocialGraphRepository {
  const SocialGraphRepository(this._invoke);

  final SocialCallableInvoker _invoke;

  Future<String> upsertProfile({
    required String profileId,
    required String displayName,
    required int avatarId,
    String? parentSessionId,
  }) async {
    _ensureAvatar(avatarId);
    final result = await _invoke('upsertSocialProfile', {
      'profileId': profileId,
      'displayName': displayName,
      'avatarId': avatarId,
      if (parentSessionId != null) 'parentSessionId': parentSessionId,
    });
    if (result is! Map || result['success'] != true) {
      throw const FormatException('Invalid social profile response');
    }
    return SocialProfileCard.fromWire({
      'socialProfileId': result['socialProfileId'],
      'displayName': displayName,
      'avatarId': avatarId,
    }).socialProfileId;
  }

  Future<void> setChildControls({
    required String profileId,
    required String parentSessionId,
    required List<String> allowedSchoolIds,
    required bool paused,
  }) async {
    await _invoke('setChildSocialControls', {
      'profileId': profileId,
      'parentSessionId': parentSessionId,
      'allowedSchoolIds': allowedSchoolIds,
      'paused': paused,
    });
  }

  Future<void> publishSummary({
    required String profileId,
    required Map<String, Object?> summary,
    String? parentSessionId,
  }) async {
    await _invoke('publishSocialSummary', {
      'profileId': profileId,
      if (parentSessionId != null) 'parentSessionId': parentSessionId,
      'summary': summary,
    });
  }

  Future<SocialSummaryVisibility> getSummaryVisibility({
    required String profileId,
    String? parentSessionId,
  }) async {
    final result = await _invoke('getSocialSummaryVisibility', {
      'profileId': profileId,
      if (parentSessionId != null) 'parentSessionId': parentSessionId,
    });
    if (result is! Map) {
      throw const FormatException('Invalid social visibility response');
    }
    return SocialSummaryVisibility.fromWire(result['visibility']);
  }

  Future<void> setSummaryVisibility({
    required String profileId,
    required SocialSummaryVisibility visibility,
    required Map<String, Object?> summary,
    String? parentSessionId,
  }) async {
    await _invoke('setSocialSummaryVisibility', {
      'profileId': profileId,
      if (parentSessionId != null) 'parentSessionId': parentSessionId,
      'visibility': visibility.toWire(),
      'summary': summary,
    });
  }

  Future<SocialChildControls> getChildControls({
    required String profileId,
    required String parentSessionId,
  }) async => SocialChildControls.fromWire(
    await _invoke('getChildSocialControls', {
      'profileId': profileId,
      'parentSessionId': parentSessionId,
    }),
  );

  Future<void> sendRequest({
    required String fromProfileId,
    required String toSocialProfileId,
    String? parentSessionId,
  }) async {
    await _invoke('sendFollowRequest', {
      'fromProfileId': fromProfileId,
      'toSocialProfileId': toSocialProfileId,
      if (parentSessionId != null) 'parentSessionId': parentSessionId,
    });
  }

  Future<void> reviewRequest({
    required String requestId,
    required String profileId,
    required bool accept,
    String? parentSessionId,
  }) async {
    await _invoke('reviewFollowRequest', {
      'requestId': requestId,
      'profileId': profileId,
      'decision': accept ? 'accept' : 'decline',
      if (parentSessionId != null) 'parentSessionId': parentSessionId,
    });
  }

  Future<void> removeConnection({
    required String profileId,
    required String toSocialProfileId,
    String? parentSessionId,
  }) async {
    await _invoke('removeFollow', {
      'profileId': profileId,
      'toSocialProfileId': toSocialProfileId,
      if (parentSessionId != null) 'parentSessionId': parentSessionId,
    });
  }

  Future<void> blockProfile({
    required String profileId,
    required String toSocialProfileId,
    String? parentSessionId,
  }) async {
    await _invoke('blockSocialProfile', {
      'profileId': profileId,
      'toSocialProfileId': toSocialProfileId,
      if (parentSessionId != null) 'parentSessionId': parentSessionId,
    });
  }

  Future<void> unblockProfile({
    required String profileId,
    required String toSocialProfileId,
    String? parentSessionId,
  }) async {
    await _invoke('unblockSocialProfile', {
      'profileId': profileId,
      'toSocialProfileId': toSocialProfileId,
      if (parentSessionId != null) 'parentSessionId': parentSessionId,
    });
  }

  Future<SocialConnections> listConnections(
    String profileId, {
    String? parentSessionId,
  }) async => SocialConnections.fromWire(
    await _invoke('listSocialConnections', {
      'profileId': profileId,
      if (parentSessionId != null) 'parentSessionId': parentSessionId,
    }),
  );

  Future<SocialSearchPage> searchSchool({
    required String profileId,
    required String schoolId,
    required String exactName,
    String? parentSessionId,
    String? pageToken,
    int limit = 20,
  }) async {
    final raw = await _invoke('searchSchoolMembers', {
      'profileId': profileId,
      'schoolId': schoolId,
      'exactName': exactName,
      if (parentSessionId != null) 'parentSessionId': parentSessionId,
      if (pageToken != null) 'pageToken': pageToken,
      'limit': limit,
    });
    return SocialSearchPage.fromWire(raw);
  }

  static void _ensureAvatar(int avatarId) {
    if (avatarId < 0 || avatarId > 9) {
      throw ArgumentError.value(
        avatarId,
        'avatarId',
        'Outside the bounded avatar catalog',
      );
    }
  }
}

SocialCallableInvoker firebaseSocialCallableInvoker(
  Future<FirebaseFunctions> Function() resolveFunctions,
) => (name, data) async {
  final functions = await resolveFunctions();
  final result = await functions.httpsCallable(name).call<Object?>(data);
  return result.data;
};

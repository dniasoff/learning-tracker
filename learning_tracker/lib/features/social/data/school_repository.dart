import 'package:cloud_functions/cloud_functions.dart';
import 'package:learning_tracker/features/social/data/social_graph_repository.dart';
import 'package:learning_tracker/features/social/domain/school.dart';

/// School lifecycle is callable-only; clients never write membership docs.
final class SchoolRepository {
  const SchoolRepository(this._invoke);

  final SocialCallableInvoker _invoke;

  Future<String> create({required String name, String? profileId}) async {
    final raw = await _invoke('createSchool', {
      'name': name,
      if (profileId != null) 'profileId': profileId,
    });
    if (raw is! Map || raw['schoolId'] is! String) {
      throw const FormatException('Invalid school creation response');
    }
    return raw['schoolId'] as String;
  }

  Future<SchoolProfile> getProfile(String schoolId) async =>
      SchoolProfile.fromWire(
        await _invoke('getSchoolProfile', {'schoolId': schoolId}),
      );

  Future<List<SchoolMembership>> listMine({
    required String profileId,
    String? parentSessionId,
  }) async {
    final raw = await _invoke('listMySchools', {
      'profileId': profileId,
      if (parentSessionId != null) 'parentSessionId': parentSessionId,
    });
    if (raw is! List)
      throw const FormatException('Invalid school list response');
    return List.unmodifiable(raw.map(SchoolMembership.fromWire));
  }

  Future<String> createInvite({required String schoolId, int uses = 1}) async {
    final raw = await _invoke('createSchoolInvite', {
      'schoolId': schoolId,
      'uses': uses,
    });
    if (raw is! Map || raw['inviteCode'] is! String) {
      throw const FormatException('Invalid school invite response');
    }
    return raw['inviteCode'] as String;
  }

  Future<void> join({
    required String inviteCode,
    required String profileId,
    required bool progressConsent,
    String? parentSessionId,
  }) async {
    await _invoke('joinSchoolWithInvite', {
      'inviteCode': inviteCode,
      'profileId': profileId,
      'progressConsent': progressConsent,
      if (parentSessionId != null) 'parentSessionId': parentSessionId,
    });
  }

  Future<void> leave({
    required String schoolId,
    required String profileId,
    String? parentSessionId,
  }) async {
    await _invoke('leaveSchool', {
      'schoolId': schoolId,
      'profileId': profileId,
      if (parentSessionId != null) 'parentSessionId': parentSessionId,
    });
  }

  Future<List<SchoolRosterEntry>> listRoster({
    required String schoolId,
    int limit = 50,
  }) async {
    final raw = await _invoke('listSchoolRoster', {
      'schoolId': schoolId,
      'limit': limit,
    });
    if (raw is! List)
      throw const FormatException('Invalid school roster response');
    return List.unmodifiable(raw.map(SchoolRosterEntry.fromWire));
  }

  Future<void> report({
    required String schoolId,
    required String category,
  }) async {
    await _invoke('reportSchool', {'schoolId': schoolId, 'category': category});
  }
}

SchoolCallableInvoker firebaseSchoolCallableInvoker(
  Future<FirebaseFunctions> Function() resolveFunctions,
) => (name, data) async {
  final functions = await resolveFunctions();
  return (await functions.httpsCallable(name).call<Object?>(data)).data;
};

typedef SchoolCallableInvoker = SocialCallableInvoker;

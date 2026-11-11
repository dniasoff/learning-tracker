import 'package:cloud_functions/cloud_functions.dart';
import 'package:learning_tracker/features/social/data/social_graph_repository.dart';
import 'package:learning_tracker/features/social/domain/learning_group.dart';

/// All group state changes go through server callables; Firestore clients never
/// write group, roster, invite or child-consent documents directly.
final class LearningGroupRepository {
  const LearningGroupRepository(this._invoke);

  final SocialCallableInvoker _invoke;

  Future<List<LearningGroupSummary>> listMine({
    required String profileId,
    String? parentSessionId,
  }) async {
    final raw = await _invoke('listMyLearningGroups', {
      'profileId': profileId,
      if (parentSessionId != null) 'parentSessionId': parentSessionId,
    });
    if (raw is! List) throw const FormatException('Invalid group list');
    return List.unmodifiable(raw.map(LearningGroupSummary.fromWire));
  }

  Future<String> create({
    required String name,
    required String profileId,
    String? schoolId,
  }) async {
    final raw = await _invoke('createLearningGroup', {
      'name': name,
      'profileId': profileId,
      if (schoolId != null && schoolId.isNotEmpty) 'schoolId': schoolId,
    });
    if (raw is! Map || raw['groupId'] is! String) {
      throw const FormatException('Invalid group creation response');
    }
    return raw['groupId'] as String;
  }

  Future<String> createInvite({required String groupId, int uses = 1}) async {
    final raw = await _invoke('createLearningGroupInvite', {
      'groupId': groupId,
      'uses': uses,
    });
    if (raw is! Map || raw['inviteCode'] is! String) {
      throw const FormatException('Invalid group invitation');
    }
    return raw['inviteCode'] as String;
  }

  Future<LearningGroupInvitePreview> previewInvite({
    required String inviteCode,
    required String profileId,
    String? parentSessionId,
  }) async => LearningGroupInvitePreview.fromWire(
    await _invoke('getLearningGroupInvite', {
      'inviteCode': inviteCode,
      'profileId': profileId,
      if (parentSessionId != null) 'parentSessionId': parentSessionId,
    }),
  );

  Future<void> join({
    required String inviteCode,
    required String profileId,
    required int memberRevision,
    String? parentSessionId,
  }) async {
    await _invoke('joinLearningGroup', {
      'inviteCode': inviteCode,
      'profileId': profileId,
      'memberRevision': memberRevision,
      if (parentSessionId != null) 'parentSessionId': parentSessionId,
    });
  }

  Future<LearningGroupDetails> getGroup({
    required String groupId,
    required String profileId,
    String? parentSessionId,
  }) async => LearningGroupDetails.fromWire(
    await _invoke('getLearningGroup', {
      'groupId': groupId,
      'profileId': profileId,
      if (parentSessionId != null) 'parentSessionId': parentSessionId,
    }),
  );

  Future<List<GroupParentApproval>> listApprovals({
    required String profileId,
    required String parentSessionId,
  }) async {
    final raw = await _invoke('listGroupParentApprovals', {
      'profileId': profileId,
      'parentSessionId': parentSessionId,
    });
    if (raw is! List)
      throw const FormatException('Invalid parent approval list');
    return List.unmodifiable(raw.map(GroupParentApproval.fromWire));
  }

  Future<void> setApproval({
    required String approvalId,
    required String profileId,
    required bool approved,
    required String parentSessionId,
  }) async {
    await _invoke('setGroupMemberApproval', {
      'approvalId': approvalId,
      'profileId': profileId,
      'approved': approved,
      'parentSessionId': parentSessionId,
    });
  }

  Future<void> removeMember({
    required String groupId,
    required String memberId,
  }) async {
    await _invoke('removeLearningGroupMember', {
      'groupId': groupId,
      'memberId': memberId,
    });
  }

  Future<void> leave({
    required String groupId,
    required String profileId,
    String? parentSessionId,
  }) async {
    await _invoke('leaveLearningGroup', {
      'groupId': groupId,
      'profileId': profileId,
      if (parentSessionId != null) 'parentSessionId': parentSessionId,
    });
  }

  Future<void> transferAdmin({
    required String groupId,
    required String memberId,
  }) async {
    await _invoke('transferLearningGroupAdmin', {
      'groupId': groupId,
      'memberId': memberId,
    });
  }

  Future<void> delete({required String groupId}) async {
    await _invoke('deleteLearningGroup', {'groupId': groupId});
  }
}

LearningGroupRepository firebaseLearningGroupRepository(
  Future<FirebaseFunctions> Function() resolveFunctions,
) => LearningGroupRepository(firebaseSocialCallableInvoker(resolveFunctions));

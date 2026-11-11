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

  Future<({List<LearningGroupTaskScope> scopes, List<String> paceUnits})>
  taskSetup(String curriculumId) async {
    final raw = await _invoke('listGroupTaskScopesForCurriculum', {
      'curriculumId': curriculumId,
    });
    if (raw is! Map ||
        raw['scopes'] is! List ||
        raw['paceUnits'] is! List ||
        (raw['paceUnits'] as List).any((value) => value is! String)) {
      throw const FormatException('Invalid group task setup');
    }
    return (
      scopes: List<LearningGroupTaskScope>.unmodifiable(
        (raw['scopes'] as List).map(LearningGroupTaskScope.fromWire),
      ),
      paceUnits: List<String>.unmodifiable(
        (raw['paceUnits'] as List).cast<String>(),
      ),
    );
  }

  Future<List<String>> taskCurricula() async {
    final raw = await _invoke('listGroupTaskCurricula', const {});
    if (raw is! List || raw.any((value) => value is! String)) {
      throw const FormatException('Invalid group task curricula');
    }
    return List.unmodifiable(raw.cast<String>());
  }

  Future<String> createTask({
    required String groupId,
    required String profileId,
    required String curriculumId,
    required List<String> scopeRefs,
    required String replyBy,
    required String deadline,
  }) async {
    final raw = await _invoke('createLearningGroupTask', {
      'groupId': groupId,
      'profileId': profileId,
      'curriculumId': curriculumId,
      'scopeRefs': scopeRefs,
      'replyBy': replyBy,
      'deadline': deadline,
    });
    if (raw is! Map || raw['taskId'] is! String) {
      throw const FormatException('Invalid group task creation response');
    }
    return raw['taskId'] as String;
  }

  Future<List<LearningGroupTaskCard>> listTasks({
    required String groupId,
    required String profileId,
  }) async {
    final raw = await _invoke('listLearningGroupTasks', {
      'groupId': groupId,
      'profileId': profileId,
    });
    if (raw is! List) throw const FormatException('Invalid group task list');
    return List.unmodifiable(raw.map(LearningGroupTaskCard.fromWire));
  }

  Future<void> respondToTask({
    required String groupId,
    required String taskId,
    required String profileId,
    required bool accept,
    String? parentSessionId,
  }) async {
    await _invoke('respondToLearningGroupTask', {
      'groupId': groupId,
      'taskId': taskId,
      'profileId': profileId,
      'response': accept ? 'accept' : 'decline',
      if (parentSessionId != null) 'parentSessionId': parentSessionId,
    });
  }

  Future<void> saveTaskPreferences({
    required String groupId,
    required String taskId,
    required String profileId,
    required List<String> rankedRefs,
    required String paceUnit,
    required int capacityPerStudyDay,
    required List<int> studyDays,
  }) async {
    await _invoke('submitLearningGroupTaskPreferences', {
      'groupId': groupId,
      'taskId': taskId,
      'profileId': profileId,
      'rankedRefs': rankedRefs,
      'paceUnit': paceUnit,
      'capacityPerStudyDay': capacityPerStudyDay,
      'studyDays': studyDays,
    });
  }

  Future<Map<String, Object?>> allocateTask({
    required String groupId,
    required String taskId,
  }) async {
    final raw = await _invoke('allocateLearningGroupTask', {
      'groupId': groupId,
      'taskId': taskId,
    });
    if (raw is! Map)
      throw const FormatException('Invalid group task allocation');
    return Map<String, Object?>.from(raw);
  }

  Future<void> requestLateTaskJoin({
    required String groupId,
    required String taskId,
    required String profileId,
  }) async {
    await _invoke('requestLateLearningGroupTaskJoin', {
      'groupId': groupId,
      'taskId': taskId,
      'profileId': profileId,
    });
  }

  Future<void> reviewLateTaskJoin({
    required String groupId,
    required String taskId,
    required String memberId,
    required bool approved,
  }) async {
    await _invoke('reviewLateLearningGroupTaskJoin', {
      'groupId': groupId,
      'taskId': taskId,
      'memberId': memberId,
      'approved': approved,
    });
  }
}

LearningGroupRepository firebaseLearningGroupRepository(
  Future<FirebaseFunctions> Function() resolveFunctions,
) => LearningGroupRepository(firebaseSocialCallableInvoker(resolveFunctions));

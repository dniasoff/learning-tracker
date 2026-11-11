final class LearningGroupSummary {
  const LearningGroupSummary({
    required this.groupId,
    required this.name,
    required this.groupType,
    required this.role,
    required this.memberCount,
    this.schoolId,
  });

  final String groupId;
  final String name;
  final String groupType;
  final String role;
  final int memberCount;
  final String? schoolId;

  factory LearningGroupSummary.fromWire(Object? value) {
    final map = _groupMap(value);
    if (map['groupId'] is! String ||
        map['name'] is! String ||
        !const {'private', 'school'}.contains(map['groupType']) ||
        !const {'admin', 'member'}.contains(map['role']) ||
        map['memberCount'] is! int ||
        (map['memberCount'] as int) < 1 ||
        (map['schoolId'] != null && map['schoolId'] is! String)) {
      throw const FormatException('Invalid group summary');
    }
    return LearningGroupSummary(
      groupId: map['groupId'] as String,
      name: map['name'] as String,
      groupType: map['groupType'] as String,
      role: map['role'] as String,
      memberCount: map['memberCount'] as int,
      schoolId: map['schoolId'] as String?,
    );
  }
}

enum LearningGroupMemberMode { adult, child }

final class LearningGroupMember {
  const LearningGroupMember({
    required this.memberId,
    required this.summaryId,
    required this.displayName,
    required this.avatarId,
    required this.role,
    required this.mode,
    required this.isSelf,
  });

  final String memberId;
  final String summaryId;
  final String displayName;
  final String avatarId;
  final String role;
  final LearningGroupMemberMode mode;
  final bool isSelf;

  factory LearningGroupMember.fromWire(Object? value) {
    final map = _groupMap(value);
    if (map['memberId'] is! String ||
        map['summaryId'] is! String ||
        map['displayName'] is! String ||
        map['avatarId'] is! String ||
        !const {'admin', 'member'}.contains(map['role']) ||
        !const {'adult', 'child'}.contains(map['mode']) ||
        map['isSelf'] is! bool) {
      throw const FormatException('Invalid group member');
    }
    return LearningGroupMember(
      memberId: map['memberId'] as String,
      summaryId: map['summaryId'] as String,
      displayName: map['displayName'] as String,
      avatarId: map['avatarId'] as String,
      role: map['role'] as String,
      mode: map['mode'] == 'adult'
          ? LearningGroupMemberMode.adult
          : LearningGroupMemberMode.child,
      isSelf: map['isSelf'] as bool,
    );
  }
}

final class LearningGroupDetails {
  const LearningGroupDetails({
    required this.groupId,
    required this.name,
    required this.groupType,
    required this.role,
    required this.members,
    this.schoolId,
  });

  final String groupId;
  final String name;
  final String groupType;
  final String role;
  final List<LearningGroupMember> members;
  final String? schoolId;

  factory LearningGroupDetails.fromWire(Object? value) {
    final map = _groupMap(value);
    if (map['groupId'] is! String ||
        map['name'] is! String ||
        !const {'private', 'school'}.contains(map['groupType']) ||
        !const {'admin', 'member'}.contains(map['role']) ||
        map['members'] is! List ||
        (map['schoolId'] != null && map['schoolId'] is! String)) {
      throw const FormatException('Invalid group details');
    }
    return LearningGroupDetails(
      groupId: map['groupId'] as String,
      name: map['name'] as String,
      groupType: map['groupType'] as String,
      role: map['role'] as String,
      schoolId: map['schoolId'] as String?,
      members: List.unmodifiable(
        (map['members'] as List).map(LearningGroupMember.fromWire),
      ),
    );
  }
}

final class LearningGroupInvitePreview {
  const LearningGroupInvitePreview({
    required this.groupId,
    required this.name,
    required this.groupType,
    required this.memberRevision,
    required this.adminName,
    required this.members,
    required this.childConsentRequired,
    this.schoolId,
  });

  final String groupId;
  final String name;
  final String groupType;
  final int memberRevision;
  final String adminName;
  final List<String> members;
  final bool childConsentRequired;
  final String? schoolId;

  factory LearningGroupInvitePreview.fromWire(Object? value) {
    final map = _groupMap(value);
    if (map['groupId'] is! String ||
        map['name'] is! String ||
        !const {'private', 'school'}.contains(map['groupType']) ||
        map['memberRevision'] is! int ||
        map['adminName'] is! String ||
        map['members'] is! List ||
        (map['members'] as List).any(
          (item) => item is! Map || item['displayName'] is! String,
        ) ||
        map['childConsentRequired'] is! bool ||
        (map['schoolId'] != null && map['schoolId'] is! String)) {
      throw const FormatException('Invalid group invite preview');
    }
    return LearningGroupInvitePreview(
      groupId: map['groupId'] as String,
      name: map['name'] as String,
      groupType: map['groupType'] as String,
      memberRevision: map['memberRevision'] as int,
      adminName: map['adminName'] as String,
      members: List.unmodifiable(
        (map['members'] as List).map(
          (item) => (item as Map)['displayName'] as String,
        ),
      ),
      childConsentRequired: map['childConsentRequired'] as bool,
      schoolId: map['schoolId'] as String?,
    );
  }
}

final class GroupParentApproval {
  const GroupParentApproval({
    required this.approvalId,
    required this.groupId,
    required this.groupName,
    required this.displayName,
    required this.approved,
  });

  final String approvalId;
  final String groupId;
  final String groupName;
  final String displayName;
  final bool approved;

  factory GroupParentApproval.fromWire(Object? value) {
    final map = _groupMap(value);
    for (final key in const [
      'approvalId',
      'groupId',
      'groupName',
      'displayName',
    ]) {
      if (map[key] is! String || (map[key] as String).isEmpty) {
        throw const FormatException('Invalid group parent approval');
      }
    }
    if (map['approved'] is! bool)
      throw const FormatException('Invalid group parent approval');
    return GroupParentApproval(
      approvalId: map['approvalId'] as String,
      groupId: map['groupId'] as String,
      groupName: map['groupName'] as String,
      displayName: map['displayName'] as String,
      approved: map['approved'] as bool,
    );
  }
}

final class LearningGroupTaskScope {
  const LearningGroupTaskScope({
    required this.ref,
    required this.label,
    required this.weight,
    this.children = const [],
  });

  final String ref;
  final String label;
  final int weight;
  final List<LearningGroupTaskScope> children;

  factory LearningGroupTaskScope.fromWire(Object? value) {
    final map = _groupMap(value);
    if (map['ref'] is! String ||
        map['label'] is! String ||
        map['weight'] is! int ||
        (map['weight'] as int) < 1) {
      throw const FormatException('Invalid group task scope');
    }
    return LearningGroupTaskScope(
      ref: map['ref'] as String,
      label: map['label'] as String,
      weight: map['weight'] as int,
      children: List<LearningGroupTaskScope>.unmodifiable(
        (map['children'] is List
                ? (map['children'] as List).cast<Object?>()
                : const <Object?>[])
            .map(LearningGroupTaskScope.fromWire),
      ),
    );
  }
}

final class LearningGroupTaskCard {
  const LearningGroupTaskCard({
    required this.taskId,
    required this.taskName,
    required this.curriculumId,
    required this.status,
    required this.memberState,
    required this.scopeUnits,
    required this.allocationMembers,
    required this.joinRequests,
    this.replyBy,
    this.deadline,
    this.paceUnit,
    this.capacityPerStudyDay,
    this.feasible,
    this.shortfall,
  });

  final String taskId;
  final String taskName;
  final String curriculumId;
  final String status;
  final String memberState;
  final String? replyBy;
  final String? deadline;
  final String? paceUnit;
  final int? capacityPerStudyDay;
  final bool? feasible;
  final int? shortfall;
  final List<LearningGroupTaskScope> scopeUnits;
  final List<Map<String, Object?>> allocationMembers;
  final List<Map<String, Object?>> joinRequests;

  factory LearningGroupTaskCard.fromWire(Object? value) {
    final map = _groupMap(value);
    for (final key in const [
      'taskId',
      'taskName',
      'curriculumId',
      'status',
      'memberState',
    ]) {
      if (map[key] is! String || (map[key] as String).isEmpty) {
        throw const FormatException('Invalid group task');
      }
    }
    final scopes = map['scopeUnits'];
    if (scopes is! List)
      throw const FormatException('Invalid group task scopes');
    final allocation = map['allocation'];
    final allocationData = allocation is Map
        ? Map<String, Object?>.from(allocation)
        : null;
    final rawMembers = allocationData?['members'];
    final members = rawMembers is List
        ? rawMembers
              .map((item) {
                if (item is! Map ||
                    item['memberId'] is! String ||
                    item['units'] is! List ||
                    item['dailyTasks'] is! List) {
                  throw const FormatException('Invalid group task allocation');
                }
                return Map<String, Object?>.from(item);
              })
              .toList(growable: false)
        : <Map<String, Object?>>[];
    final rawRequests = map['joinRequests'];
    final requests = rawRequests is List
        ? rawRequests
              .whereType<Map<Object?, Object?>>()
              .map((item) => Map<String, Object?>.from(item))
              .toList(growable: false)
        : <Map<String, Object?>>[];
    final feasibility = map['feasibility'];
    if (feasibility != null && feasibility is! Map)
      throw const FormatException('Invalid group task feasibility');
    final feasibilityMap = feasibility is Map ? feasibility : null;
    final shortfall = feasibilityMap?['shortfall'];
    return LearningGroupTaskCard(
      taskId: map['taskId'] as String,
      taskName: map['taskName'] as String,
      curriculumId: map['curriculumId'] as String,
      status: map['status'] as String,
      memberState: map['memberState'] as String,
      replyBy: map['replyBy'] as String?,
      deadline: map['deadline'] as String?,
      paceUnit: map['paceUnit'] as String?,
      capacityPerStudyDay: map['capacityPerStudyDay'] as int?,
      feasible: feasibilityMap?['feasible'] as bool?,
      shortfall: shortfall is int ? shortfall : null,
      scopeUnits: List.unmodifiable(
        scopes.map(LearningGroupTaskScope.fromWire),
      ),
      allocationMembers: List.unmodifiable(members),
      joinRequests: List.unmodifiable(requests),
    );
  }
}

Map<String, Object?> _groupMap(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw const FormatException('Invalid group response');
  }
  return value.cast<String, Object?>();
}

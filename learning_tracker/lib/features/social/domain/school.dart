/// School identity fields intentionally omit account IDs and moderation data.
final class SchoolProfile {
  const SchoolProfile({
    required this.schoolId,
    required this.name,
    required this.verified,
    required this.createdAt,
    required this.adminNames,
    required this.status,
  });

  final String schoolId;
  final String name;
  final bool verified;
  final DateTime? createdAt;
  final List<String> adminNames;
  final String status;

  factory SchoolProfile.fromWire(Object? raw) {
    if (raw is! Map ||
        raw.keys.any(
          (key) => !const {
            'schoolId',
            'name',
            'verified',
            'createdAt',
            'admins',
            'status',
          }.contains(key),
        ) ||
        raw['schoolId'] is! String ||
        raw['name'] is! String ||
        raw['verified'] is! bool) {
      throw const FormatException('Invalid school profile response');
    }
    final rawAdmins = raw['admins'];
    if (rawAdmins is! List) {
      throw const FormatException('Invalid school administrators');
    }
    final admins = <String>[];
    for (final item in rawAdmins) {
      if (item is! Map ||
          item.keys.any((key) => key != 'displayName') ||
          item['displayName'] is! String) {
        throw const FormatException('Invalid school administrator');
      }
      admins.add(item['displayName'] as String);
    }
    final created = raw['createdAt'];
    return SchoolProfile(
      schoolId: raw['schoolId'] as String,
      name: raw['name'] as String,
      verified: raw['verified'] == true,
      createdAt: created is String ? DateTime.tryParse(created) : null,
      adminNames: List.unmodifiable(admins),
      status: raw['status'] is String ? raw['status'] as String : 'active',
    );
  }
}

final class SchoolMembership {
  const SchoolMembership({
    required this.schoolId,
    required this.name,
    required this.verified,
    required this.role,
    required this.joinedAt,
  });

  final String schoolId;
  final String name;
  final bool verified;
  final String role;
  final DateTime? joinedAt;

  factory SchoolMembership.fromWire(Object? raw) {
    if (raw is! Map ||
        raw.keys.any(
          (key) => !const {
            'schoolId',
            'name',
            'verified',
            'role',
            'joinedAt',
          }.contains(key),
        ) ||
        raw['schoolId'] is! String ||
        raw['name'] is! String ||
        raw['role'] is! String ||
        raw['verified'] is! bool) {
      throw const FormatException('Invalid school membership response');
    }
    final joined = raw['joinedAt'];
    return SchoolMembership(
      schoolId: raw['schoolId'] as String,
      name: raw['name'] as String,
      verified: raw['verified'] == true,
      role: raw['role'] as String,
      joinedAt: joined is String ? DateTime.tryParse(joined) : null,
    );
  }
}

/// Staff roster card. `summaryId` points to the shared sanitized projection.
final class SchoolRosterEntry {
  const SchoolRosterEntry({
    required this.summaryId,
    required this.displayName,
    required this.avatarId,
    required this.mode,
  });

  final String summaryId;
  final String displayName;
  final int avatarId;
  final String mode;

  factory SchoolRosterEntry.fromWire(Object? raw) {
    if (raw is! Map ||
        raw.keys.any(
          (key) => !const {
            'summaryId',
            'displayName',
            'avatarId',
            'mode',
          }.contains(key),
        ) ||
        raw['summaryId'] is! String ||
        raw['displayName'] is! String ||
        raw['avatarId'] is! int ||
        !const {'adult', 'child'}.contains(raw['mode'])) {
      throw const FormatException('Invalid school roster response');
    }
    return SchoolRosterEntry(
      summaryId: raw['summaryId'] as String,
      displayName: raw['displayName'] as String,
      avatarId: raw['avatarId'] as int,
      mode: raw['mode'] as String,
    );
  }
}

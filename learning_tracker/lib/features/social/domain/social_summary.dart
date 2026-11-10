/// A server-maintained, sanitized view of one learner profile.
///
/// This decoder deliberately rejects unknown top-level and nested fields so
/// private source data cannot silently become part of the social UI.
final class SocialSummary {
  const SocialSummary({
    required this.ownerUid,
    required this.profileId,
    required this.displayName,
    required this.avatarId,
    required this.streak,
    required this.currentTracks,
    required this.weeklyLearning,
    required this.siyumim,
    required this.computedAt,
    required this.schemaVersion,
  });

  final String ownerUid;
  final String profileId;
  final String displayName;
  final int avatarId;
  final SocialStreakProjection streak;
  final List<SocialCurrentTrackSummary> currentTracks;
  final SocialWeeklyLearningProjection weeklyLearning;
  final List<SocialSiyumSummary> siyumim;
  final DateTime computedAt;
  final int schemaVersion;

  factory SocialSummary.fromWire(Object? value) {
    final data = _map(value, const {
      'owner_uid',
      'profile_id',
      'display_name',
      'avatar_id',
      'streak',
      'current_tracks',
      'weekly_learning',
      'siyumim',
      'computed_at',
      'schema_version',
    });
    if (data['avatar_id'] is! int ||
        (data['avatar_id'] as int) < 0 ||
        (data['avatar_id'] as int) > 9 ||
        data['schema_version'] is! int ||
        data['schema_version'] != 1) {
      throw const FormatException('Invalid social summary metadata');
    }
    return SocialSummary(
      ownerUid: _string(data['owner_uid'], 'owner_uid'),
      profileId: _string(data['profile_id'], 'profile_id'),
      displayName: _string(data['display_name'], 'display_name'),
      avatarId: data['avatar_id'] as int,
      streak: SocialStreakProjection.fromWire(data['streak']),
      currentTracks: _list(
        data['current_tracks'],
        SocialCurrentTrackSummary.fromWire,
      ),
      weeklyLearning: SocialWeeklyLearningProjection.fromWire(
        data['weekly_learning'],
      ),
      siyumim: _list(data['siyumim'], SocialSiyumSummary.fromWire),
      computedAt: _date(data['computed_at']),
      schemaVersion: data['schema_version'] as int,
    );
  }
}

final class SocialStreakProjection {
  const SocialStreakProjection({required this.byCurriculum, this.overall});

  final List<SocialStreakSummary> byCurriculum;
  final SocialStreakSummary? overall;

  factory SocialStreakProjection.fromWire(Object? value) {
    final data = _map(
      value,
      const {'by_curriculum', 'overall'},
      optional: const {'overall'},
    );
    final overall = data['overall'];
    return SocialStreakProjection(
      byCurriculum: _list(data['by_curriculum'], SocialStreakSummary.fromWire),
      overall: overall == null ? null : SocialStreakSummary.fromWire(overall),
    );
  }
}

final class SocialWeeklyLearningProjection {
  const SocialWeeklyLearningProjection({
    required this.byCurriculum,
    this.overall,
  });

  final List<SocialWeeklyLearningSummary> byCurriculum;
  final SocialWeeklyLearningSummary? overall;

  factory SocialWeeklyLearningProjection.fromWire(Object? value) {
    final data = _map(
      value,
      const {'by_curriculum', 'overall'},
      optional: const {'overall'},
    );
    final overall = data['overall'];
    return SocialWeeklyLearningProjection(
      byCurriculum: _list(
        data['by_curriculum'],
        SocialWeeklyLearningSummary.fromWire,
      ),
      overall: overall == null
          ? null
          : SocialWeeklyLearningSummary.fromWire(overall),
    );
  }
}

final class SocialStreakSummary {
  const SocialStreakSummary({
    required this.curriculumId,
    required this.currentDays,
    required this.bestDays,
  });

  final String curriculumId;
  final int currentDays;
  final int bestDays;

  factory SocialStreakSummary.fromWire(Object? value) {
    final data = _map(value, const {
      'curriculum_id',
      'current_days',
      'best_days',
    });
    return SocialStreakSummary(
      curriculumId: _string(data['curriculum_id'], 'curriculum_id'),
      currentDays: _nonNegativeInt(data['current_days'], 'current_days'),
      bestDays: _nonNegativeInt(data['best_days'], 'best_days'),
    );
  }
}

final class SocialCurrentTrackSummary {
  const SocialCurrentTrackSummary({
    required this.curriculumId,
    required this.displayName,
    required this.position,
  });

  final String curriculumId;
  final String displayName;
  final String? position;

  factory SocialCurrentTrackSummary.fromWire(Object? value) {
    final data = _map(value, const {
      'curriculum_id',
      'display_name',
      'position',
    });
    final position = data['position'];
    if (position != null && position is! String) {
      throw const FormatException('position must be a string or null');
    }
    return SocialCurrentTrackSummary(
      curriculumId: _string(data['curriculum_id'], 'curriculum_id'),
      displayName: _string(data['display_name'], 'display_name'),
      position: position as String?,
    );
  }
}

final class SocialWeeklyLearningSummary {
  const SocialWeeklyLearningSummary({
    required this.curriculumId,
    required this.limudim,
    required this.chazaros,
  });

  final String curriculumId;
  final int limudim;
  final int chazaros;

  factory SocialWeeklyLearningSummary.fromWire(Object? value) {
    final data = _map(value, const {'curriculum_id', 'limudim', 'chazaros'});
    return SocialWeeklyLearningSummary(
      curriculumId: _string(data['curriculum_id'], 'curriculum_id'),
      limudim: _nonNegativeInt(data['limudim'], 'limudim'),
      chazaros: _nonNegativeInt(data['chazaros'], 'chazaros'),
    );
  }
}

final class SocialSiyumSummary {
  const SocialSiyumSummary({
    required this.curriculumId,
    required this.label,
    required this.level,
  });

  final String curriculumId;
  final String label;
  final String level;

  factory SocialSiyumSummary.fromWire(Object? value) {
    final data = _map(value, const {'curriculum_id', 'label', 'level'});
    return SocialSiyumSummary(
      curriculumId: _string(data['curriculum_id'], 'curriculum_id'),
      label: _string(data['label'], 'label'),
      level: _string(data['level'], 'level'),
    );
  }
}

Map<String, Object?> _map(
  Object? value,
  Set<String> allowed, {
  Set<String> optional = const {},
}) {
  if (value is! Map) throw const FormatException('Expected an object');
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String || !allowed.contains(entry.key)) {
      throw FormatException('Unsupported social summary field: ${entry.key}');
    }
    result[entry.key as String] = entry.value;
  }
  if ((allowed.difference(optional)).any((key) => !result.containsKey(key))) {
    throw const FormatException('Social summary field is missing');
  }
  return result;
}

List<T> _list<T>(Object? value, T Function(Object?) decode) {
  if (value is! List) throw const FormatException('Expected a summary list');
  return List.unmodifiable(value.map(decode));
}

String _string(Object? value, String name) {
  if (value is! String || value.trim().isEmpty || value.length > 500) {
    throw FormatException('$name must be a non-empty string');
  }
  return value;
}

int _nonNegativeInt(Object? value, String name) {
  if (value is! int || value < 0) {
    throw FormatException('$name must be a non-negative integer');
  }
  return value;
}

DateTime _date(Object? value) {
  if (value is DateTime) return value;
  if (value is String) {
    final date = DateTime.tryParse(value);
    if (date != null) return date;
  }
  if (value is Map &&
      value.length == 2 &&
      value['_seconds'] is int &&
      value['_nanoseconds'] is int) {
    return DateTime.fromMicrosecondsSinceEpoch(
      (value['_seconds'] as int) * Duration.microsecondsPerSecond +
          (value['_nanoseconds'] as int) ~/ 1000,
      isUtc: true,
    );
  }
  throw const FormatException('computed_at must be a timestamp');
}

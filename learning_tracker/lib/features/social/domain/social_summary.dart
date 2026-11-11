import 'package:learning_tracker/core/enums/curriculum_id.dart';

/// Sanitized learner-published summary served through the social projection.
///
/// The wire format carries identifiers and numbers only. Display labels for
/// curricula, positions and completed units are resolved locally by the
/// viewer so the learner cannot inject text into another user's UI.
final class SocialSummary {
  const SocialSummary({
    required this.displayName,
    required this.avatarId,
    this.streak,
    this.currentTracks,
    this.weeklyLearning,
    this.siyumim,
    required this.computedAt,
    required this.schemaVersion,
  });

  final String displayName;
  final int avatarId;
  final SocialStreakProjection? streak;
  final List<SocialCurrentTrackSummary>? currentTracks;
  final SocialWeeklyLearningProjection? weeklyLearning;
  final List<SocialSiyumSummary>? siyumim;
  final DateTime computedAt;
  final int schemaVersion;

  factory SocialSummary.fromWire(Object? value) {
    final data = _map(
      value,
      const {
        'display_name',
        'avatar_id',
        'streak',
        'current_tracks',
        'weekly_learning',
        'siyumim',
        'computed_at',
        'schema_version',
      },
      optional: const {
        'streak',
        'current_tracks',
        'weekly_learning',
        'siyumim',
      },
    );
    if (data['avatar_id'] is! int ||
        (data['avatar_id'] as int) < 0 ||
        (data['avatar_id'] as int) > 9 ||
        data['schema_version'] is! int ||
        data['schema_version'] != 1) {
      throw const FormatException('Invalid social summary metadata');
    }
    return SocialSummary(
      displayName: _string(data['display_name'], 'display_name', max: 60),
      avatarId: data['avatar_id'] as int,
      streak: data['streak'] == null
          ? null
          : SocialStreakProjection.fromWire(data['streak']),
      currentTracks: data['current_tracks'] == null
          ? null
          : _list(data['current_tracks'], SocialCurrentTrackSummary.fromWire),
      weeklyLearning: data['weekly_learning'] == null
          ? null
          : SocialWeeklyLearningProjection.fromWire(data['weekly_learning']),
      siyumim: data['siyumim'] == null
          ? null
          : _list(data['siyumim'], SocialSiyumSummary.fromWire),
      computedAt: _date(data['computed_at']),
      schemaVersion: data['schema_version'] as int,
    );
  }
}

final class SocialStreakProjection {
  const SocialStreakProjection({required this.byCurriculum, this.overall});

  final List<SocialStreakSummary> byCurriculum;
  final SocialOverallStreakSummary? overall;

  factory SocialStreakProjection.fromWire(Object? value) {
    final data = _map(
      value,
      const {'by_curriculum', 'overall'},
      optional: const {'by_curriculum', 'overall'},
    );
    final overall = data['overall'];
    return SocialStreakProjection(
      byCurriculum: data['by_curriculum'] == null
          ? const []
          : _list(data['by_curriculum'], SocialStreakSummary.fromWire),
      overall: overall == null
          ? null
          : SocialOverallStreakSummary.fromWire(overall),
    );
  }
}

final class SocialWeeklyLearningProjection {
  const SocialWeeklyLearningProjection({
    required this.weekStart,
    required this.byCurriculum,
    this.overall,
  });

  final String weekStart;
  final List<SocialWeeklyLearningSummary> byCurriculum;
  final SocialOverallWeeklyLearningSummary? overall;

  factory SocialWeeklyLearningProjection.fromWire(Object? value) {
    final data = _map(
      value,
      const {'week_start', 'by_curriculum', 'overall'},
      optional: const {'by_curriculum', 'overall'},
    );
    final overall = data['overall'];
    return SocialWeeklyLearningProjection(
      weekStart: _sundayDate(data['week_start']),
      byCurriculum: data['by_curriculum'] == null
          ? const []
          : _list(data['by_curriculum'], SocialWeeklyLearningSummary.fromWire),
      overall: overall == null
          ? null
          : SocialOverallWeeklyLearningSummary.fromWire(overall),
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
      curriculumId: _curriculumId(data['curriculum_id']),
      currentDays: _boundedInt(data['current_days'], 'current_days', 100000),
      bestDays: _boundedInt(data['best_days'], 'best_days', 100000),
    );
  }
}

final class SocialCurrentTrackSummary {
  const SocialCurrentTrackSummary({
    required this.curriculumId,
    required this.positionRef,
  });

  final String curriculumId;
  final String? positionRef;

  factory SocialCurrentTrackSummary.fromWire(Object? value) {
    final data = _map(value, const {'curriculum_id', 'position_ref'});
    final ref = data['position_ref'];
    return SocialCurrentTrackSummary(
      curriculumId: _curriculumId(data['curriculum_id']),
      positionRef: ref == null ? null : _sefariaRef(ref, 'position_ref'),
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
      curriculumId: _curriculumId(data['curriculum_id']),
      limudim: _boundedInt(data['limudim'], 'limudim', 100000),
      chazaros: _boundedInt(data['chazaros'], 'chazaros', 100000),
    );
  }
}

final class SocialSiyumSummary {
  const SocialSiyumSummary({
    required this.curriculumId,
    required this.ref,
    required this.level,
  });

  final String curriculumId;
  final String ref;
  final String level;

  factory SocialSiyumSummary.fromWire(Object? value) {
    final data = _map(value, const {'curriculum_id', 'ref', 'level'});
    return SocialSiyumSummary(
      curriculumId: _curriculumId(data['curriculum_id']),
      ref: _sefariaRef(data['ref'], 'ref'),
      level: _identifier(data['level'], 'level', max: 64),
    );
  }
}

final class SocialOverallStreakSummary {
  const SocialOverallStreakSummary({
    required this.currentDays,
    required this.bestDays,
  });

  final int currentDays;
  final int bestDays;

  factory SocialOverallStreakSummary.fromWire(Object? value) {
    final data = _map(value, const {'current_days', 'best_days'});
    return SocialOverallStreakSummary(
      currentDays: _boundedInt(data['current_days'], 'current_days', 100000),
      bestDays: _boundedInt(data['best_days'], 'best_days', 100000),
    );
  }
}

final class SocialOverallWeeklyLearningSummary {
  const SocialOverallWeeklyLearningSummary({
    required this.limudim,
    required this.chazaros,
  });

  final int limudim;
  final int chazaros;

  factory SocialOverallWeeklyLearningSummary.fromWire(Object? value) {
    final data = _map(value, const {'limudim', 'chazaros'});
    return SocialOverallWeeklyLearningSummary(
      limudim: _boundedInt(data['limudim'], 'limudim', 100000),
      chazaros: _boundedInt(data['chazaros'], 'chazaros', 100000),
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
  if (allowed.difference(optional).any((key) => !result.containsKey(key))) {
    throw const FormatException('Social summary field is missing');
  }
  return result;
}

List<T> _list<T>(Object? value, T Function(Object?) decode) {
  if (value is! List || value.length > 100) {
    throw const FormatException('Invalid summary list');
  }
  return List.unmodifiable(value.map(decode));
}

String _string(Object? value, String name, {required int max}) {
  if (value is! String || value.trim().isEmpty || value.length > max) {
    throw FormatException('$name must be a non-empty string');
  }
  return value;
}

String _identifier(Object? value, String name, {required int max}) {
  final text = _string(value, name, max: max);
  if (!RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(text)) {
    throw FormatException('$name must be an identifier');
  }
  return text;
}

String _curriculumId(Object? value) {
  final text = _identifier(value, 'curriculum_id', max: 200);
  if (CurriculumId.fromStorageKey(text) == null) {
    throw const FormatException('Unknown curriculum_id');
  }
  return text;
}

String _sefariaRef(Object? value, String name) {
  final text = _string(value, name, max: 256);
  if (!RegExp(
    r"""^[\p{L}\p{N}][\p{L}\p{N} ,.:;'"״׳–—-]*$""",
    unicode: true,
  ).hasMatch(text)) {
    throw FormatException('$name must be a canonical reference');
  }
  return text;
}

int _boundedInt(Object? value, String name, int max) {
  if (value is! int || value < 0 || value > max) {
    throw FormatException('$name is outside its allowed range');
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

String _sundayDate(Object? value) {
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const FormatException('week_start must be a Sunday civil date');
  }
  final date = DateTime.tryParse('${value}T00:00:00Z');
  if (date == null || date.weekday != DateTime.sunday) {
    throw const FormatException('week_start must be a Sunday civil date');
  }
  return value;
}

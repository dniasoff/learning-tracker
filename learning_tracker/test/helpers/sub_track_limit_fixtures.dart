/// Reader for the shared AD-45 fixture suite
/// `test/fixtures/sub_track_limits/*.json` (Story 2.1 / DNI-492 AC-3,
/// AC-4, AC-5). `functions/test/sub_track_limits.test.mjs` reads the same
/// files with the same rules, and both suites must agree on every case.
///
/// File shape: `{description, base, cases: [...]}`. Each case is
/// `{name, today, curriculum_id, program_id, existing, op, expect}`:
/// - `existing[i]` is `{id, doc}`; the stored row is `{...base, ...doc}`.
/// - `op` is `{kind: create, id, fields}` (row `{...base, ...fields}`),
///   `{kind: edit, id, fields}` (row `{...stored, ...fields}`, a null value
///   clearing the field) or `{kind: set_program, program_id}`.
/// - `program_id` is the live calendar program of `curriculum_id`; any other
///   curriculum has none.
/// - `ended_at` is an ISO-8601 instant string.
/// - `expect` is the sorted list of violated wire codes; `[]` = accepted.
library;

import 'dart:convert';
import 'dart:io';

import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/domain/learner_state/sub_track_validator.dart';

/// The fixture directory, relative to the package root.
const subTrackLimitFixtureDir = 'test/fixtures/sub_track_limits';

const _lastChangeId = '01JFIXTURE0000000000ZZZZZZ';

/// One fixture case with its file.
typedef SubTrackLimitCase = ({String file, Map<String, Object?> json});

/// Every case of every fixture file, in file then case order.
List<SubTrackLimitCase> loadSubTrackLimitCases() {
  final files =
      Directory(subTrackLimitFixtureDir)
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  return [
    for (final file in files)
      for (final c in _cases(file)) (file: file.uri.pathSegments.last, json: c),
  ];
}

Iterable<Map<String, Object?>> _cases(File file) {
  final root = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  final base = root['base']! as Map<String, Object?>;
  return [
    for (final c in root['cases']! as List<Object?>)
      {...c! as Map<String, Object?>, '_base': base},
  ];
}

/// Builds a [SubTrack] from a fixture row WITHOUT the codec's validation, so
/// malformed intent (reversed window, non-positive rate) reaches the
/// validator.
SubTrack subTrackFromFixtureRow(String id, Map<String, Object?> row) {
  final endedAt = row['ended_at'] as String?;
  final endReason = row['end_reason'] as String?;
  return SubTrack(
    id: id,
    curriculumId: row['curriculum_id']! as String,
    name: row['name']! as String,
    type: SubTrackType.byStorage[row['type']! as String]!,
    academicYear: row['academic_year'] as int?,
    windowStart: row['window_start']! as String,
    windowEnd: row['window_end'] as String?,
    ratePerWeek: (row['rate_per_week']! as num).toDouble(),
    weeksPerYear: (row['weeks_per_year']! as num).toDouble(),
    learnsOnShabbos: row['learns_on_shabbos']! as bool,
    ground: [
      for (final g
          in (row['ground']! as List<Object?>).cast<Map<String, Object?>>())
        NodeEntry(level: g['level']! as String, ref: g['ref']! as String),
    ],
    endedAt: endedAt == null ? null : DateTime.parse(endedAt),
    endReason: endReason == null
        ? null
        : SubTrackEndReason.byStorage[endReason],
    lastChangeId: _lastChangeId,
  );
}

Map<String, Object?> _merge(
  Map<String, Object?> into,
  Map<String, Object?> fields,
) {
  final out = {...into};
  fields.forEach((k, v) => v == null ? out.remove(k) : out[k] = v);
  return out;
}

/// Runs [c] through the Dart validator and returns the sorted violated
/// codes (the form `expect` holds).
List<String> runSubTrackLimitCase(SubTrackLimitCase c) {
  final json = c.json;
  final base = json['_base']! as Map<String, Object?>;
  final today = json['today']! as String;
  final caseCurriculum = json['curriculum_id']! as String;
  final programId = json['program_id'] as String?;
  final rows = <String, Map<String, Object?>>{
    for (final e
        in (json['existing']! as List<Object?>).cast<Map<String, Object?>>())
      e['id']! as String: _merge(base, e['doc']! as Map<String, Object?>),
  };
  final existing = [
    for (final MapEntry(:key, :value) in rows.entries)
      subTrackFromFixtureRow(key, value),
  ];
  final op = json['op']! as Map<String, Object?>;
  switch (op['kind']) {
    case 'set_program':
      return subTrackViolationCodes(
        calendarProgramSetViolations(
          curriculumId: caseCurriculum,
          programId: op['program_id'] as String?,
          subTracks: existing,
        ),
      );
    case 'create' || 'edit':
      final id = op['id']! as String;
      final fields = op['fields']! as Map<String, Object?>;
      final prior = op['kind'] == 'edit' ? rows[id]! : null;
      final candidate = subTrackFromFixtureRow(
        id,
        _merge(prior ?? base, fields),
      );
      return subTrackViolationCodes([
        ...subTrackIntentViolations(candidate),
        ...subTrackLimitViolations(
          candidate: candidate,
          prior: prior == null ? null : subTrackFromFixtureRow(id, prior),
          siblings: existing,
          today: today,
          calendarProgramId: candidate.curriculumId == caseCurriculum
              ? programId
              : null,
        ),
      ]);
    default:
      throw ArgumentError('unknown op ${op['kind']}');
  }
}

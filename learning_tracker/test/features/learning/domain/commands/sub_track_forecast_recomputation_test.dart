import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learning/domain/commands/sub_track_forecast_recomputation.dart';

const _trackId = '01ARZ3NDEKTSV4RRFFQ69G5FAA';
const _createEntryId = '01ARZ3NDEKTSV4RRFFQ69G5FAB';
const _actionId = '01ARZ3NDEKTSV4RRFFQ69G5FAC';
const _actor = Actor(uid: 'synthetic', role: ActorRole.parent, displayName: '');

SubTrack _track({double rate = 10, int? year}) => SubTrack(
  id: _trackId,
  curriculumId: 'mishnayos',
  name: 'Synthetic track',
  type: SubTrackType.schoolYear,
  academicYear: year ?? 5786,
  windowStart: '2026-01-01',
  windowEnd: '2026-01-07',
  ratePerWeek: rate,
  weeksPerYear: 40,
  learnsOnShabbos: false,
  ground: const [],
  lastChangeId: _createEntryId,
);

ChangeLogEntry _creation(SubTrack track) => ChangeLogEntry(
  id: _createEntryId,
  entity: GovernedEntity.subTrack,
  entityId: _trackId,
  actionId: _actionId,
  before: {'sub_tracks/$_trackId.name': null},
  after: {
    for (final field in track.toStorage().entries)
      'sub_tracks/$_trackId.${field.key}': field.value,
  },
  at: DateTime.utc(2026),
  actor: _actor,
);

LearningEvent _learn(
  String id,
  String ref,
  String learnedOn, {
  String source = _trackId,
  String? level,
}) => LearningEvent.learn(
  id: id,
  curriculumId: 'mishnayos',
  ref: ref,
  source: source,
  dateState: DateState.dated,
  learnedOn: learnedOn,
  recordedAt: DateTime.utc(2026),
  actor: _actor,
  level: level,
);

void main() {
  test('uses the creation capacity and distinct non-void leaves in window', () {
    final original = _track();
    final current = _track(rate: 1, year: 5787);
    final events = [
      _learn('01ARZ3NDEKTSV4RRFFQ69G5FAD', 'Leaf A', '2026-01-01'),
      _learn('01ARZ3NDEKTSV4RRFFQ69G5FAE', 'Leaf A', '2026-01-07'),
      _learn('01ARZ3NDEKTSV4RRFFQ69G5FAF', 'Leaf B', '2026-01-03'),
      LearningEvent.voidOf(
        id: '01ARZ3NDEKTSV4RRFFQ69G5FAG',
        targetId: '01ARZ3NDEKTSV4RRFFQ69G5FAF',
        recordedAt: DateTime.utc(2026, 2),
        actor: _actor,
      ),
      _learn('01ARZ3NDEKTSV4RRFFQ69G5FAH', 'Outside', '2026-01-08'),
      _learn(
        '01ARZ3NDEKTSV4RRFFQ69G5FAJ',
        'Node',
        '2026-01-04',
        level: 'perek',
      ),
      _learn(
        '01ARZ3NDEKTSV4RRFFQ69G5FAK',
        'Other source',
        '2026-01-04',
        source: 'main',
      ),
    ];

    final result = recomputeSubTrackForecast(
      track: current,
      history: [_creation(original)],
      events: events,
    );

    expect(result?.forecast, 400);
    expect(result?.actual, 1);
    expect(result?.windowWeeks, 1);
  });

  test('includes both window boundaries and returns null without creation', () {
    final track = _track();
    final result = recomputeSubTrackForecast(
      track: track,
      history: [_creation(track)],
      events: [
        _learn('01ARZ3NDEKTSV4RRFFQ69G5FAD', 'First', '2026-01-01'),
        _learn('01ARZ3NDEKTSV4RRFFQ69G5FAE', 'Last', '2026-01-07'),
      ],
    );
    expect(result?.actual, 2);
    expect(
      recomputeSubTrackForecast(track: track, history: [], events: []),
      isNull,
    );
  });
}

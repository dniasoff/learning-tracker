/// Story 2.8 (DNI-499): the sub-track lifecycle through the governed
/// `SubTrackCommands` behind `LearningCommands` — *Add next year* (AC-1),
/// delete (AC-3) and end (AC-4) — over the in-memory ports, plus the AD-47
/// `subtrack_lifecycle` analytics of those explicit actions (T6).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_intent_repository.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_analytics.dart';
import 'package:learning_tracker/features/learning/domain/commands/sub_track_commands.dart';

import '../../../helpers/learner_state/c0_fixtures.dart';
import '../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../helpers/learner_state/in_memory_ports.dart';
import '../../../helpers/learner_state_fixtures.dart';

const _berakhot = NodeEntry(level: 'masechta', ref: 'Berakhot');
const _today = '2026-10-01';
final _now = DateTime.utc(2026, 10, 1, 9);

/// The 2026–27 school year the parent set up: Sep–Jul, 8 a week.
SubTrack _school({
  String id = ulidA,
  int academicYear = 2026,
  String windowStart = '2026-09-01',
  String? windowEnd = '2027-07-31',
}) => SubTrack(
  id: id,
  curriculumId: 'shas',
  name: 'School',
  type: SubTrackType.schoolYear,
  academicYear: academicYear,
  windowStart: windowStart,
  windowEnd: windowEnd,
  ratePerWeek: 8,
  weeksPerYear: 36,
  learnsOnShabbos: true,
  ground: const [_berakhot],
  lastChangeId: ulidE,
);

/// The 2027–28 draft *Add next year* saves (prefill, unedited).
const _nextYear = SubTrackDraft(
  curriculumId: 'shas',
  name: 'School',
  type: SubTrackType.schoolYear,
  academicYear: 2027,
  windowStart: '2027-09-01',
  windowEnd: '2028-07-31',
  ratePerWeek: 8,
  weeksPerYear: 36,
  learnsOnShabbos: true,
  ground: [],
);

/// `01JTEST…` + a counter: valid, distinct ULIDs.
String Function() _ids() {
  var n = 0;
  return () => '01JTEST000000000000000${(++n).toString().padLeft(4, '0')}';
}

LearnerIntent _intent() => LearnerIntent(
  settings: c0Settings,
  mainTracks: {
    'shas': MainTrackIntent(
      curriculumId: 'shas',
      track: MainTrack(curriculumId: 'shas', state: MainTrackState.active),
    ),
  },
  goals: const {},
);

void main() {
  final scope = c0Scope();
  late InMemorySubTrackRepository repo;
  late InMemoryGovernedIntentRepository intent;
  late RecordingLearningAnalytics analytics;
  late SubTrackCommands commands;

  setUp(() {
    repo = InMemorySubTrackRepository()..seed(scope, [_school()]);
    intent = InMemoryGovernedIntentRepository()..emit(scope, _intent());
    analytics = RecordingLearningAnalytics();
    commands = SubTrackCommands(
      scope: scope,
      actor: parentActor,
      subTracks: repo,
      intent: intent,
      today: () => _today,
      nowUtc: () => _now,
      newId: _ids(),
      analytics: analytics,
      ackTimeout: const Duration(milliseconds: 50),
      readTimeout: const Duration(seconds: 2),
    );
  });

  tearDown(() async {
    await commands.dispose();
    await repo.dispose();
    await intent.dispose();
  });

  group('T6 subtrack_lifecycle for the explicit lifecycle actions (AD-47)', () {
    test('Add next year reports add_next_year, not create', () async {
      await commands.createSubTrack(_nextYear, addNextYear: true);
      expect(analytics.lifecycles, [
        (
          curriculumId: 'shas',
          type: SubTrackType.schoolYear,
          action: SubTrackLifecycleAction.addNextYear,
          groundEntries: 0,
        ),
      ]);
      expect(SubTrackLifecycleAction.addNextYear.storage, 'add_next_year');
    });

    test('end and delete report end and delete', () async {
      repo.seed(scope, [_school(id: ulidB, academicYear: 2027)]);
      await commands.endSubTrack(ulidA);
      await commands.deleteSubTrack(ulidB);
      expect(analytics.lifecycles.map((e) => e.action), [
        SubTrackLifecycleAction.end,
        SubTrackLifecycleAction.delete,
      ]);
    });

    test('a refused Add next year emits nothing', () async {
      // 2026–27 is already held: the copy is a duplicate academic year.
      await commands.createSubTrack(
        const SubTrackDraft(
          curriculumId: 'shas',
          name: 'School',
          type: SubTrackType.schoolYear,
          academicYear: 2026,
          windowStart: '2026-09-01',
          windowEnd: '2027-07-31',
          ratePerWeek: 8,
          weeksPerYear: 36,
          learnsOnShabbos: true,
          ground: [],
        ),
        addNextYear: true,
      );
      expect(analytics.lifecycles, isEmpty);
    });

    test('the payload carries no name, ref, date or ULID', () {
      final sent = <Map<String, Object>>[];
      SinkLearningAnalytics(
        (_, parameters) => sent.add(parameters),
      ).subTrackLifecycle(
        curriculumId: 'shas',
        type: SubTrackType.schoolYear,
        action: SubTrackLifecycleAction.addNextYear,
        groundEntries: 0,
      );
      expect(sent.single, {
        'curriculum_id': 'shas',
        'track_type': 'school_year',
        'action': 'add_next_year',
        'ground_entries': 0,
      });
    });
  });
}

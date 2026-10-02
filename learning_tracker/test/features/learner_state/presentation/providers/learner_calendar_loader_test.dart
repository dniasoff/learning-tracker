// Mirror test for
// `lib/features/learner_state/presentation/providers/learner_calendar_loader.dart`
// (DNI-474 T1: the AD-35 calendars input).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_intent_repository.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_calendar_loader.dart';
import 'package:learning_tracker/features/scheduler/domain/services/calendar_program_service.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';

ContentItem _leaf(String ref, int order) => ContentItem(
  curriculumId: engineCurriculum,
  level1: 'Zeraim',
  level2: 'Berakhot',
  displayNameHe: ref,
  displayNameEn: ref,
  sefariaRef: ref,
  sortOrder: order,
  isLeaf: true,
);

CalendarProgramEntry _entry(String ref, DateTime date) => CalendarProgramEntry(
  programId: 'mishna_yomit',
  displayNameEn: 'Mishna Yomit',
  displayNameHe: 'משנה יומית',
  todayRef: ref,
  apiSource: 'local',
  date: date,
);

MainTrackIntent _calendarIntent({String? start = '2026-09-01'}) =>
    MainTrackIntent(
      curriculumId: engineCurriculum,
      track: MainTrack(
        curriculumId: engineCurriculum,
        state: MainTrackState.active,
      ),
      program: MainTrackProgram(
        curriculumId: engineCurriculum,
        programId: 'mishna_yomit',
        trackingStartDate: start,
      ),
    );

void main() {
  final items = [
    _leaf('Mishnah Berakhot 1:1', 1),
    _leaf('Mishnah Berakhot 1:2', 2),
  ];
  final now = DateTime.utc(2026, 9, 3, 12);

  test('maps each calendar day onto corpus nodes from the tracking start '
      'through the horizon', () async {
    final ranges = <(String, DateTime, DateTime)>[];
    final calendars = await loadLearnerCalendars(
      intent: LearnerIntent(
        settings: c0Settings,
        mainTracks: {engineCurriculum: _calendarIntent()},
        goals: const {},
      ),
      settingsHistory: c0SettingsHistory(),
      nowUtc: now,
      corpora: {engineCurriculum: mishnayosCorpus()},
      entriesForRange: (programId, start, end) async {
        ranges.add((programId, start, end));
        return [
          _entry('Mishnah Berakhot 1:1-2', DateTime.utc(2026, 9, 1)),
          _entry('Unknown Ref 9:9', DateTime.utc(2026, 9, 2)),
        ];
      },
      itemsFor: (_) async => items,
    );
    expect(ranges, [
      ('mishna_yomit', DateTime.utc(2026, 9, 1), DateTime.utc(2026, 9, 17)),
    ]);
    expect(calendars['mishna_yomit'], const [
      CalendarAssignment(
        '2026-09-01',
        NodeEntry(level: 'mishnah', ref: 'Mishnah Berakhot 1:1'),
      ),
      CalendarAssignment(
        '2026-09-01',
        NodeEntry(level: 'mishnah', ref: 'Mishnah Berakhot 1:2'),
      ),
    ]);
  });

  test('a curriculum not following a calendar program loads nothing', () async {
    var called = false;
    final calendars = await loadLearnerCalendars(
      intent: LearnerIntent(
        settings: c0Settings,
        mainTracks: {engineCurriculum: engineIntent()},
        goals: const {},
      ),
      settingsHistory: c0SettingsHistory(),
      nowUtc: now,
      corpora: {engineCurriculum: mishnayosCorpus()},
      entriesForRange: (_, _, _) async {
        called = true;
        return const [];
      },
      itemsFor: (_) async => items,
    );
    expect(calendars, isEmpty);
    expect(called, isFalse);
  });

  test('a missing tracking start loads from today', () async {
    DateTime? from;
    await loadLearnerCalendars(
      intent: LearnerIntent(
        settings: c0Settings,
        mainTracks: {engineCurriculum: _calendarIntent(start: null)},
        goals: const {},
      ),
      settingsHistory: c0SettingsHistory(),
      nowUtc: now,
      corpora: {engineCurriculum: mishnayosCorpus()},
      entriesForRange: (_, start, _) async {
        from = start;
        return const [];
      },
      itemsFor: (_) async => items,
    );
    expect(from, DateTime.utc(2026, 9, 3));
  });
}

// Tests for collapseDafTasks — the daily-list "one card per daf" grouping for
// coarse-paced (daf) tracks.

@Tags(['scheduler'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';

ContentItem _leaf(String ref, String l1, String l2, String l3) => ContentItem(
  curriculumId: 'bavli',
  level1: l1,
  level2: l2,
  level3: l3,
  displayNameHe: '',
  displayNameEn: ref,
  sefariaRef: ref,
  sortOrder: 0,
  isLeaf: true,
);

DailyTask _task(
  String ref, {
  CurriculumId curriculum = CurriculumId.bavli,
  int stageOrder = 1,
}) => DailyTask(
  curriculumId: curriculum,
  contentItemSefariaRef: ref,
  stageOrder: stageOrder,
  priority: DailyTaskPriority.todayProgram,
  isOverdue: false,
  reason: '',
  stageName: 'Learn',
  trackLabel: 'Bavli',
);

void main() {
  final index = ContentIndex.fromCurricula({
    CurriculumId.bavli: [
      _leaf('Berakhot 2a', 'Berakhot', '2', 'a'),
      _leaf('Berakhot 2b', 'Berakhot', '2', 'b'),
      _leaf('Berakhot 3a', 'Berakhot', '3', 'a'),
      _leaf('Berakhot 3b', 'Berakhot', '3', 'b'),
    ],
  });

  group('collapseDafTasks', () {
    test('collapses both amudim of a daf into one card for a daf track', () {
      final tasks = [
        _task('Berakhot 2a'),
        _task('Berakhot 2b'),
        _task('Berakhot 3a'),
        _task('Berakhot 3b'),
      ];
      final out = collapseDafTasks(
        tasks,
        coarsePacedTrackIds: {CurriculumId.bavli},
        index: index,
      );
      expect(out.map((t) => t.contentItemSefariaRef), [
        'Berakhot 2a', // daf 2 representative
        'Berakhot 3a', // daf 3 representative
      ]);
    });

    test('does NOT collapse when the track is not coarse-paced', () {
      final tasks = [_task('Berakhot 2a'), _task('Berakhot 2b')];
      final out = collapseDafTasks(
        tasks,
        coarsePacedTrackIds: <CurriculumId>{}, // no coarse tracks
        index: index,
      );
      expect(out.length, 2);
    });

    test('keeps a daf Learn task and Chazara task as separate cards', () {
      final tasks = [
        _task('Berakhot 2a', stageOrder: 1), // Learn
        _task('Berakhot 2b', stageOrder: 1), // Learn (collapses with 2a)
        _task('Berakhot 2a', stageOrder: 2), // Chazara 1 (separate card)
        _task('Berakhot 2b', stageOrder: 2),
      ];
      final out = collapseDafTasks(
        tasks,
        coarsePacedTrackIds: {CurriculumId.bavli},
        index: index,
      );
      expect(out.length, 2); // one Learn card + one Chazara card
      expect(out.map((t) => t.stageOrder), [1, 2]);
    });

    test('groups per curriculum (same daf number stays separate)', () {
      final tasks = [
        _task('Berakhot 2a'),
        _task('Berakhot 2b'),
        _task('Berakhot 2a', curriculum: CurriculumId.mishnayos),
        _task('Berakhot 2b', curriculum: CurriculumId.mishnayos),
      ];
      final out = collapseDafTasks(
        tasks,
        coarsePacedTrackIds: {CurriculumId.bavli, CurriculumId.mishnayos},
        index: index,
      );
      expect(out.length, 2);
      expect(out.map((t) => t.curriculumId), [
        CurriculumId.bavli,
        CurriculumId.mishnayos,
      ]);
    });

    // AUD-core-content-06: collapseDafTasks used a bare ContentIndex.lookup
    // that couldn't tolerate stray whitespace in a task's stored ref, so a
    // daf whose amudim disagree by whitespace failed to collapse into one
    // card. Routing through ProgramRefResolver.lookupWithVariants (the same
    // normalization dashboard/scheduler/reader are meant to share per FR16)
    // fixes it without touching the exact-match fast path.
    test('collapses a daf whose stored ref has stray whitespace via '
        'ProgramRefResolver variant matching', () {
      final tasks = [
        _task('Berakhot  2a'), // double space — stray-whitespace variant
        _task('Berakhot 2b'),
      ];
      final out = collapseDafTasks(
        tasks,
        coarsePacedTrackIds: {CurriculumId.bavli},
        index: index,
      );
      expect(out.map((t) => t.contentItemSefariaRef), ['Berakhot  2a']);
    });
  });
}

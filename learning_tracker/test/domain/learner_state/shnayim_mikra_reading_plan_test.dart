import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/shnayim_mikra_preferences.dart';
import 'package:learning_tracker/domain/learner_state/shnayim_mikra_reading_plan.dart';

import '../../helpers/learner_state/engine_fixtures.dart';

void main() {
  const aliyot = [
    ['a1', 'a2'],
    ['b1'],
    ['c1', 'c2'],
  ];
  const verseLabels = [
    'Genesis 1:1',
    'Genesis 1:2',
    'Genesis 2:1',
    'Genesis 3:1',
    'Genesis 3:2',
  ];
  const aliyahLabels = ['aliyah 1', 'aliyah 2', 'aliyah 3'];

  test('daily completion counts remaining aliyot Sunday through Friday', () {
    const sevenAliyot = [
      ['a'],
      ['b'],
      ['c'],
      ['d'],
      ['e'],
      ['f'],
      ['g'],
    ];
    const sevenLabels = ['1', '2', '3', '4', '5', '6', '7'];
    for (
      var weekday = DateTime.sunday;
      weekday <= DateTime.thursday;
      weekday++
    ) {
      final today = buildShnayimMikraReadingUnits(
        mode: ShnayimMikraMode.aliyah,
        pace: ShnayimMikraPace.dailyAliyah,
        weekday: weekday,
        aliyahLabels: sevenLabels,
        verseLabels: sevenLabels,
        aliyot: sevenAliyot,
      );
      expect(
        remainingShnayimMikraAliyot(
          sevenAliyot,
          today.single.items.toSet(),
          (verse) => verse,
        ),
        6,
      );
    }
    expect(
      remainingShnayimMikraAliyot(sevenAliyot, {
        'a',
        'b',
        'c',
        'd',
        'e',
        'f',
        'g',
      }, (verse) => verse),
      0,
    );
  });

  test('reader resumes after two persisted passes and undo rewinds a pass', () {
    final refs = ['Genesis 1:1', 'Genesis 1:2'];
    const cycle = '2026-10-03:BERESHIT:israel';
    final passEvents = [
      engineLearn(
        21,
        refs[0],
        curriculumId: 'shnayim_mikra',
        source: LearningEvent.sourceShnayimMikraPass1,
        assignmentKey: cycle,
      ),
      engineLearn(
        22,
        refs[1],
        curriculumId: 'shnayim_mikra',
        source: LearningEvent.sourceShnayimMikraPass1,
        assignmentKey: cycle,
      ),
      engineLearn(
        23,
        refs[0],
        curriculumId: 'shnayim_mikra',
        source: LearningEvent.sourceShnayimMikraPass2,
        assignmentKey: cycle,
      ),
      engineLearn(
        24,
        refs[1],
        curriculumId: 'shnayim_mikra',
        source: LearningEvent.sourceShnayimMikraPass2,
        assignmentKey: cycle,
      ),
    ];
    expect(
      completedShnayimMikraPassCount(
        refs: refs,
        events: passEvents,
        assignmentKey: cycle,
        commentarySource: 'onkelos',
      ),
      2,
    );
    expect(
      completedShnayimMikraPassCount(
        refs: refs,
        events: [...passEvents, engineVoid(25, 24)],
        assignmentKey: cycle,
        commentarySource: 'onkelos',
      ),
      1,
    );
  });

  test('year cycles are fresh; catch-up keeps the previous cycle state', () {
    const oldCycle = '2026-10-03:BERESHIT:israel';
    const nextCycle = '2027-10-02:BERESHIT:israel';
    const ref = 'Genesis 1:1';
    final events = [
      engineLearn(
        31,
        ref,
        curriculumId: 'shnayim_mikra',
        source: LearningEvent.sourceMain,
        assignmentKey: oldCycle,
      ),
      engineLearn(
        32,
        ref,
        curriculumId: 'shnayim_mikra',
        source: LearningEvent.sourceShnayimMikraPass1,
        assignmentKey: oldCycle,
      ),
      engineLearn(
        33,
        ref,
        curriculumId: 'shnayim_mikra',
        source: LearningEvent.sourceShnayimMikraPass2,
        assignmentKey: oldCycle,
      ),
      engineLearn(
        34,
        ref,
        curriculumId: 'shnayim_mikra',
        source: LearningEvent.sourceShnayimMikraPass3,
        assignmentKey: oldCycle,
        commentarySource: 'onkelos',
      ),
    ];
    expect(completedShnayimMikraRefs(events: events, assignmentKey: oldCycle), {
      ref,
    });
    expect(
      completedShnayimMikraRefs(events: events, assignmentKey: nextCycle),
      isEmpty,
    );
    expect(
      completedShnayimMikraPassCount(
        refs: [ref],
        events: events,
        assignmentKey: oldCycle,
        commentarySource: 'onkelos',
      ),
      3,
    );
    expect(
      completedShnayimMikraPassCount(
        refs: [ref],
        events: events,
        assignmentKey: nextCycle,
        commentarySource: 'onkelos',
      ),
      0,
    );
  });

  test('switching commentary does not reuse the old pass-three marker', () {
    const cycle = '2026-10-03:BERESHIT:israel';
    const ref = 'Genesis 1:1';
    final events = [
      engineLearn(
        41,
        ref,
        curriculumId: 'shnayim_mikra',
        source: LearningEvent.sourceShnayimMikraPass1,
        assignmentKey: cycle,
      ),
      engineLearn(
        42,
        ref,
        curriculumId: 'shnayim_mikra',
        source: LearningEvent.sourceShnayimMikraPass2,
        assignmentKey: cycle,
      ),
      engineLearn(
        43,
        ref,
        curriculumId: 'shnayim_mikra',
        source: LearningEvent.sourceShnayimMikraPass3,
        assignmentKey: cycle,
        commentarySource: 'onkelos',
      ),
    ];
    expect(
      completedShnayimMikraPassCount(
        refs: [ref],
        events: events,
        assignmentKey: cycle,
        commentarySource: 'rashi',
      ),
      2,
    );
    expect(
      completedShnayimMikraPassCount(
        refs: [ref],
        events: [
          ...events,
          engineLearn(
            44,
            ref,
            curriculumId: 'shnayim_mikra',
            source: LearningEvent.sourceShnayimMikraPass3,
            assignmentKey: cycle,
            commentarySource: 'rashi',
          ),
        ],
        assignmentKey: cycle,
        commentarySource: 'rashi',
      ),
      3,
    );
  });

  test('pasuk mode completes each pasuk with three ordered readings', () {
    final units = buildShnayimMikraReadingUnits(
      mode: ShnayimMikraMode.pasuk,
      pace: ShnayimMikraPace.self,
      weekday: 1,
      aliyahLabels: aliyahLabels,
      verseLabels: verseLabels,
      aliyot: aliyot,
    );

    expect(units.map((unit) => unit.label), verseLabels);
    expect(units.map((unit) => unit.items.single), [
      'a1',
      'a2',
      'b1',
      'c1',
      'c2',
    ]);
  });

  test(
    'aliyah mode groups sections and daily pace covers Sunday to Friday',
    () {
      final full = buildShnayimMikraReadingUnits(
        mode: ShnayimMikraMode.aliyah,
        pace: ShnayimMikraPace.self,
        weekday: 1,
        aliyahLabels: aliyahLabels,
        verseLabels: verseLabels,
        aliyot: aliyot,
      );
      const sevenAliyot = [
        ['a'],
        ['b'],
        ['c'],
        ['d'],
        ['e'],
        ['f'],
        ['g'],
      ];
      const sevenLabels = ['1', '2', '3', '4', '5', '6', '7'];
      final sunday = buildShnayimMikraReadingUnits(
        mode: ShnayimMikraMode.aliyah,
        pace: ShnayimMikraPace.dailyAliyah,
        weekday: DateTime.sunday,
        aliyahLabels: sevenLabels,
        verseLabels: sevenLabels,
        aliyot: sevenAliyot,
      );
      final friday = buildShnayimMikraReadingUnits(
        mode: ShnayimMikraMode.aliyah,
        pace: ShnayimMikraPace.dailyAliyah,
        weekday: DateTime.friday,
        aliyahLabels: sevenLabels,
        verseLabels: sevenLabels,
        aliyot: sevenAliyot,
      );

      expect(full.map((unit) => unit.items), aliyot);
      expect(sunday.single.items, ['a']);
      expect(friday.map((unit) => unit.items), [
        ['f'],
        ['g'],
      ]);
    },
  );

  test('parsha mode performs each of three passes over the whole parsha', () {
    final units = buildShnayimMikraReadingUnits(
      mode: ShnayimMikraMode.parsha,
      pace: ShnayimMikraPace.self,
      weekday: 1,
      aliyahLabels: aliyahLabels,
      verseLabels: verseLabels,
      aliyot: aliyot,
    );

    expect(units, hasLength(1));
    expect(units.single.items, ['a1', 'a2', 'b1', 'c1', 'c2']);
  });
}

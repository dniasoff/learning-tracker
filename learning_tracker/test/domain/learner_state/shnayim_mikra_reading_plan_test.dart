import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/shnayim_mikra_preferences.dart';
import 'package:learning_tracker/domain/learner_state/shnayim_mikra_reading_plan.dart';

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

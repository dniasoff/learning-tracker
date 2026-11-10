import 'package:learning_tracker/domain/learner_state/shnayim_mikra_preferences.dart';

/// One unit that receives all three readings before it is marked complete.
final class ShnayimMikraReadingUnit<T> {
  const ShnayimMikraReadingUnit({required this.label, required this.items});

  final String label;
  final List<T> items;
}

/// Groups aliyah data into the learner's chosen three-pass work units.
List<ShnayimMikraReadingUnit<T>> buildShnayimMikraReadingUnits<T>({
  required ShnayimMikraMode mode,
  required ShnayimMikraPace pace,
  required int weekday,
  required List<String> aliyahLabels,
  required List<String> verseLabels,
  required List<List<T>> aliyot,
}) {
  if (aliyot.length != aliyahLabels.length ||
      aliyot.fold<int>(0, (count, aliyah) => count + aliyah.length) !=
          verseLabels.length) {
    throw ArgumentError('labels must match the supplied aliyah verses');
  }

  if (mode == ShnayimMikraMode.parsha) {
    return [
      ShnayimMikraReadingUnit(
        label: 'parsha',
        items: List.unmodifiable(aliyot.expand((aliyah) => aliyah)),
      ),
    ];
  }

  if (mode == ShnayimMikraMode.aliyah) {
    final indexes = pace == ShnayimMikraPace.dailyAliyah
        ? switch (weekday) {
            DateTime.sunday => [0],
            DateTime.monday => [1],
            DateTime.tuesday => [2],
            DateTime.wednesday => [3],
            DateTime.thursday => [4],
            DateTime.friday => [5, 6],
            _ => <int>[],
          }
        : [for (var index = 0; index < aliyot.length; index++) index];
    return [
      for (final index in indexes)
        if (index < aliyot.length)
          ShnayimMikraReadingUnit(
            label: aliyahLabels[index],
            items: List.unmodifiable(aliyot[index]),
          ),
    ];
  }

  var verseIndex = 0;
  return [
    for (final aliyah in aliyot)
      for (final verse in aliyah)
        ShnayimMikraReadingUnit(
          label: verseLabels[verseIndex++],
          items: [verse],
        ),
  ];
}

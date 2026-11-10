import 'package:learning_tracker/domain/learner_state/counted_events.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
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

/// Number of aliyot that still contain at least one unfinished verse.
int remainingShnayimMikraAliyot<T>(
  List<List<T>> aliyot,
  Set<String> completedVerseRefs,
  String Function(T item) verseRefOf,
) => aliyot
    .where(
      (aliyah) => aliyah.any(
        (verse) => !completedVerseRefs.contains(verseRefOf(verse)),
      ),
    )
    .length;

/// The first pass not yet complete for [refs], after applying event voids.
/// The result is suitable for resuming a reader on another device.
int completedShnayimMikraPassCount({
  required List<String> refs,
  required List<LearningEvent> events,
}) {
  final counted = countEvents(events);
  final byId = {for (final event in events) event.id: event};
  var passes = 0;
  for (final source in LearningEvent.shnayimMikraPassSources) {
    final recorded = {
      for (final event in byId.values)
        if (event.isLearn &&
            event.source == source &&
            !counted.voidedIds.contains(event.id) &&
            !counted.lockIgnoredIds.contains(event.id))
          event.ref!,
    };
    if (!refs.every(recorded.contains)) break;
    passes++;
  }
  return passes;
}

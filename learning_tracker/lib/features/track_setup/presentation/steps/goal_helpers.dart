import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

/// Pace-unit options shown to the user in the self-paced goal step.
///
/// Two variants:
///  - [PaceUnitOptions.dual] — curriculum has a coarse (e.g. Daf, Perek,
///    Siman) and a fine (Amud, Mishna, Pasuk, Seif, Halacha) choice.
///  - [PaceUnitOptions.single] — curriculum has only one natural pace
///    level (Yerushalmi = Daf). No segmented picker is rendered.
class PaceUnitOptions {
  const PaceUnitOptions._({
    required this.coarseKey,
    required this.coarse,
    this.fineKey,
    this.fine,
    required this.defaultKey,
  });

  factory PaceUnitOptions.dual({
    required String coarseKey,
    required LevelLabels coarse,
    required String fineKey,
    required LevelLabels fine,
    required String defaultKey,
  }) => PaceUnitOptions._(
    coarseKey: coarseKey,
    coarse: coarse,
    fineKey: fineKey,
    fine: fine,
    defaultKey: defaultKey,
  );

  factory PaceUnitOptions.single({
    required String key,
    required LevelLabels level,
  }) => PaceUnitOptions._(coarseKey: key, coarse: level, defaultKey: key);

  final String coarseKey;
  final LevelLabels coarse;
  final String? fineKey;
  final LevelLabels? fine;
  final String defaultKey;

  bool get hasChoice => fineKey != null;

  LevelLabels levelFor(String key) {
    if (key == coarseKey) return coarse;
    if (key == fineKey && fine != null) return fine!;
    return coarse;
  }
}

/// Inclusive count of dates in [startInclusive, endInclusive] whose weekday
/// is a study day per [studyDays] map (same keys as kDefaultStudyDays).
int countStudyDaysInInclusiveMapRange(
  Map<int, String> studyDays,
  DateTime startInclusive,
  DateTime endInclusive,
) {
  final studyWeekdays = <int>{
    for (final e in studyDays.entries)
      if (e.value == 'study') e.key,
  };
  if (studyWeekdays.isEmpty) {
    for (var i = 1; i <= 7; i++) {
      studyWeekdays.add(i);
    }
  }
  var d = DateTime(
    startInclusive.year,
    startInclusive.month,
    startInclusive.day,
  );
  final end = DateTime(endInclusive.year, endInclusive.month, endInclusive.day);
  if (d.isAfter(end)) return 0;
  var n = 0;
  while (!d.isAfter(end)) {
    if (studyWeekdays.contains(d.weekday)) n++;
    d = d.add(const Duration(days: 1));
  }
  return n;
}

DateTime localDateOnlyFromDt(DateTime utc) {
  final l = utc.toLocal();
  return DateTime(l.year, l.month, l.day);
}

/// Returns [PaceUnitOptions] for the given [curriculumId].
PaceUnitOptions paceUnitOptionsFor(CurriculumId id) {
  return switch (id) {
    CurriculumId.mishnayos => PaceUnitOptions.dual(
      coarseKey: 'perek',
      coarse: CurriculumLabels.level(id, 3),
      fineKey: 'mishna',
      fine: CurriculumLabels.leaf(id),
      defaultKey: 'mishna',
    ),
    CurriculumId.bavli => PaceUnitOptions.dual(
      coarseKey: 'daf',
      coarse: CurriculumLabels.level(id, 3),
      fineKey: 'amud',
      fine: CurriculumLabels.leaf(id),
      defaultKey: 'daf',
    ),
    CurriculumId.yerushalmi => PaceUnitOptions.single(
      key: 'daf',
      level: CurriculumLabels.leaf(id),
    ),
    CurriculumId.chumash => PaceUnitOptions.dual(
      coarseKey: 'perek',
      coarse: CurriculumLabels.level(id, 2),
      fineKey: 'pasuk',
      fine: CurriculumLabels.leaf(id),
      defaultKey: 'pasuk',
    ),
    CurriculumId.nach || CurriculumId.tanach => PaceUnitOptions.dual(
      coarseKey: 'perek',
      coarse: CurriculumLabels.level(id, 3),
      fineKey: 'pasuk',
      fine: CurriculumLabels.leaf(id),
      defaultKey: 'pasuk',
    ),
    CurriculumId.mussar => PaceUnitOptions.dual(
      coarseKey: 'perek',
      coarse: CurriculumLabels.level(id, 2),
      fineKey: 'pasuk',
      fine: CurriculumLabels.leaf(id),
      defaultKey: 'pasuk',
    ),
    CurriculumId.mishnaBerurah => PaceUnitOptions.dual(
      coarseKey: 'siman',
      coarse: CurriculumLabels.level(id, 2),
      fineKey: 'seif',
      fine: CurriculumLabels.leaf(id),
      defaultKey: 'seif',
    ),
    CurriculumId.mishnehTorah => PaceUnitOptions.dual(
      coarseKey: 'perek',
      coarse: CurriculumLabels.level(id, 3),
      fineKey: 'halacha',
      fine: CurriculumLabels.leaf(id),
      defaultKey: 'halacha',
    ),
  };
}

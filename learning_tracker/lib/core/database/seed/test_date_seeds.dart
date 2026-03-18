/// Generates test date seeds for Dirshu programs.
///
/// Dirshu tests are typically on the first Sunday of each month.
/// This generates 12 months of upcoming test dates from a given start date.
List<Map<String, Object>> generateTestDateSeeds({
  DateTime? from,
  int monthsAhead = 12,
}) {
  final start = from ?? DateTime.now().toUtc();
  final seeds = <Map<String, Object>>[];

  // Dirshu program names that have tests
  const dirshuPrograms = [
    'dirshu_kinyan_torah',
    'dirshu_amud_hayomi',
    'dirshu_kinyan_yerushalmi',
    'dirshu_daf_hayomi_bhalacha',
  ];

  for (final programName in dirshuPrograms) {
    for (var i = 0; i < monthsAhead; i++) {
      final month = DateTime.utc(start.year, start.month + i, 1);
      final firstSunday = _firstSundayOfMonth(month.year, month.month);

      // Only include future dates
      if (firstSunday.isAfter(start) ||
          firstSunday.year == start.year &&
              firstSunday.month == start.month &&
              firstSunday.day == start.day) {
        seeds.add({
          'program_name': programName,
          'test_date': firstSunday,
          'material_description': '',
        });
      }
    }
  }

  return seeds;
}

/// Returns the first Sunday of the given month.
DateTime _firstSundayOfMonth(int year, int month) {
  var date = DateTime.utc(year, month, 1);
  while (date.weekday != DateTime.sunday) {
    date = date.add(const Duration(days: 1));
  }
  return date;
}

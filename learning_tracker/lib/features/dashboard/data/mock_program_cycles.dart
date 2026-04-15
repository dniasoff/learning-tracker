/// Mock cycle data for known calendar programs.
///
/// Keyed by curriculum type string matching CalendarProgramRegistry IDs.
/// Calendar data is now sourced from the pre-computed CalendarCycles table.
class ProgramCycleData {
  const ProgramCycleData({
    required this.totalDays,
    required this.cycleStartDate,
    required this.sampleTodayRef,
    required this.sampleTodayDisplayHe,
  });

  final int totalDays;
  final DateTime cycleStartDate;
  final String sampleTodayRef;
  final String sampleTodayDisplayHe;
}

final mockProgramCycles = <String, ProgramCycleData>{
  'bavli': ProgramCycleData(
    totalDays: 2711,
    cycleStartDate: DateTime.utc(2020, 1, 5),
    sampleTodayRef: 'Bava Kamma 42',
    sampleTodayDisplayHe: 'בבא קמא דף מ״ב',
  ),
  'mishnayos': ProgramCycleData(
    totalDays: 2000,
    cycleStartDate: DateTime.utc(2022, 3, 20),
    sampleTodayRef: 'Mishnah Berakhot 3:1',
    sampleTodayDisplayHe: 'משנה ברכות ג׳:א׳',
  ),
  'yerushalmi': ProgramCycleData(
    totalDays: 1554,
    cycleStartDate: DateTime.utc(2023, 1, 1),
    sampleTodayRef: 'Yerushalmi Berakhot 12',
    sampleTodayDisplayHe: 'ירושלמי ברכות דף י״ב',
  ),
  'mishna_berurah': ProgramCycleData(
    totalDays: 1100,
    cycleStartDate: DateTime.utc(2022, 1, 1),
    sampleTodayRef: 'Shulchan Arukh OC 301',
    sampleTodayDisplayHe: 'שו״ע או״ח ש״א',
  ),
  'nach': ProgramCycleData(
    totalDays: 929,
    cycleStartDate: DateTime.utc(2023, 8, 1),
    sampleTodayRef: 'Joshua 15',
    sampleTodayDisplayHe: 'יהושע פרק ט״ו',
  ),
  'mussar': ProgramCycleData(
    totalDays: 730,
    cycleStartDate: DateTime.utc(2024, 1, 1),
    sampleTodayRef: 'Mesilat Yesharim 5',
    sampleTodayDisplayHe: 'מסילת ישרים פרק ה׳',
  ),
};

/// Default fallback for unknown program types.
final defaultProgramCycleData = ProgramCycleData(
  totalDays: 365,
  cycleStartDate: DateTime.utc(2024, 1, 1),
  sampleTodayRef: 'Unknown',
  sampleTodayDisplayHe: 'לא ידוע',
);

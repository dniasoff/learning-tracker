import 'package:kosher_dart/kosher_dart.dart';

/// A single upcoming regular weekly sedra and its Shabbos deadline.
///
/// [now] passed to [ShnayimMikraWeeklyAssignment.resolve] must use the
/// learner's configured time zone. This keeps the civil Shabbos date aligned
/// with the existing Shabbat location setting rather than device locale.
final class ShnayimMikraWeeklyAssignment {
  const ShnayimMikraWeeklyAssignment({
    required this.portionKey,
    required this.shabbosDate,
    required this.dueDate,
    required this.catchUpThrough,
    required this.inIsrael,
  });

  final String portionKey;
  final DateTime shabbosDate;
  final DateTime dueDate;
  final DateTime catchUpThrough;
  final bool inIsrael;

  /// Finds the next Shabbos with a regular weekly parsha.
  ///
  /// Festival Shabbosos return `Parsha.NONE`; they are skipped rather than
  /// turned into a fabricated weekly assignment. Paired portions remain one
  /// enum key and therefore one weekly assignment.
  static ShnayimMikraWeeklyAssignment resolve({
    required DateTime now,
    required bool inIsrael,
  }) {
    var candidate = DateTime(now.year, now.month, now.day);
    final daysUntilSaturday = (DateTime.saturday - candidate.weekday + 7) % 7;
    candidate = candidate.add(Duration(days: daysUntilSaturday));

    while (true) {
      final assignment = forShabbos(candidate, inIsrael: inIsrael);
      if (assignment != null) return assignment;
      candidate = candidate.add(const Duration(days: 7));
    }
  }

  /// Creates an assignment only when [shabbosDate] has a regular weekly
  /// parsha. Festival readings return null.
  static ShnayimMikraWeeklyAssignment? forShabbos(
    DateTime shabbosDate, {
    required bool inIsrael,
  }) {
    final date = DateTime(shabbosDate.year, shabbosDate.month, shabbosDate.day);
    final calendar = JewishCalendar.fromDateTime(date)..inIsrael = inIsrael;
    final parsha = calendar.getParshah();
    if (parsha == Parsha.NONE) return null;

    final dueDate = date.subtract(const Duration(days: 1));
    final catchUpThrough = _nextSimchasTorah(dueDate, inIsrael);
    return ShnayimMikraWeeklyAssignment(
      portionKey: parsha.name,
      shabbosDate: date,
      dueDate: dueDate,
      catchUpThrough: catchUpThrough,
      inIsrael: inIsrael,
    );
  }

  static ShnayimMikraScheduleProjection project({
    required DateTime now,
    required bool inIsrael,
    Set<String> completedAssignmentKeys = const {},
  }) {
    final current = resolve(now: now, inIsrael: inIsrael);
    final today = _day(now);
    final firstSearchDate = today.subtract(const Duration(days: 400));
    var candidate = firstSearchDate.add(
      Duration(days: (DateTime.saturday - firstSearchDate.weekday + 7) % 7),
    );
    final catchUp = <ShnayimMikraWeeklyAssignment>[];
    while (!candidate.isAfter(_day(current.shabbosDate))) {
      final assignment = forShabbos(candidate, inIsrael: inIsrael);
      if (assignment != null &&
          assignment.key != current.key &&
          assignment.isCatchUpAvailableOn(now) &&
          !completedAssignmentKeys.contains(assignment.key)) {
        catchUp.add(assignment);
      }
      candidate = candidate.add(const Duration(days: 7));
    }
    return ShnayimMikraScheduleProjection(
      current: current,
      catchUp: List.unmodifiable(catchUp),
    );
  }

  String get key => '${_dateKey(shabbosDate)}:$portionKey';

  bool isOverdueOn(DateTime date) => _day(date).isAfter(_day(dueDate));

  /// The unfinished assignment remains available through Simchas Torah,
  /// inclusive. A later assignment can still be resolved independently.
  bool isCatchUpAvailableOn(DateTime date) =>
      isOverdueOn(date) && !_day(date).isAfter(_day(catchUpThrough));

  static DateTime _nextSimchasTorah(DateTime from, bool inIsrael) {
    for (var offset = 0; offset <= 400; offset++) {
      final date = from.add(Duration(days: offset));
      final calendar = JewishCalendar.fromDateTime(date)..inIsrael = inIsrael;
      final simchasTorahDay = inIsrael ? 22 : 23;
      if (calendar.getJewishMonth() == JewishDate.TISHREI &&
          calendar.getJewishDayOfMonth() == simchasTorahDay) {
        return date;
      }
    }
    throw StateError('Simchas Torah not found within the next Hebrew year');
  }

  static DateTime _day(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

final class ShnayimMikraScheduleProjection {
  const ShnayimMikraScheduleProjection({
    required this.current,
    required this.catchUp,
  });

  final ShnayimMikraWeeklyAssignment current;
  final List<ShnayimMikraWeeklyAssignment> catchUp;
}

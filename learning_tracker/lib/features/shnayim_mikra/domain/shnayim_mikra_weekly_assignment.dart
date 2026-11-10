import 'package:kosher_dart/kosher_dart.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';

/// Learner-local instant when this Shabbos assignment becomes overdue.
/// Uses the lock window's candle-lighting bound when location is available;
/// otherwise it is the final microsecond of Friday.
DateTime shnayimMikraDueAtForShabbos(
  DateTime shabbosDate,
  LearnerSettingsHistory history,
) {
  final settings = history.current;
  final zone = LearnerZone.of(settings.timeZone);
  if (!settings.hasLocation) {
    return DateTime.utc(
      shabbosDate.year,
      shabbosDate.month,
      shabbosDate.day,
    ).subtract(const Duration(microseconds: 1));
  }
  final noon = zone.at(shabbosDate, hour: 12);
  final window = lockWindows(
    history,
    noon,
    noon,
  ).where((candidate) => candidate.contains(noon));
  return window.isEmpty
      ? DateTime.utc(
          shabbosDate.year,
          shabbosDate.month,
          shabbosDate.day,
        ).subtract(const Duration(microseconds: 1))
      : zone.wallTimeOf(window.first.startUtc);
}

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
    required this.dueAt,
    required this.catchUpThrough,
    required this.inIsrael,
  });

  final String portionKey;
  final DateTime shabbosDate;
  final DateTime dueDate;

  /// Learner-local wall time when the assignment becomes overdue.
  final DateTime dueAt;
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
    DateTime Function(DateTime shabbosDate)? dueAtForShabbos,
  }) {
    var candidate = DateTime(now.year, now.month, now.day);
    final daysUntilSaturday = (DateTime.saturday - candidate.weekday + 7) % 7;
    candidate = candidate.add(Duration(days: daysUntilSaturday));

    while (true) {
      final assignment = forShabbos(
        candidate,
        inIsrael: inIsrael,
        dueAt: dueAtForShabbos?.call(candidate),
      );
      if (assignment != null) return assignment;
      candidate = candidate.add(const Duration(days: 7));
    }
  }

  /// Creates an assignment only when [shabbosDate] has a regular weekly
  /// parsha. Festival readings return null.
  static ShnayimMikraWeeklyAssignment? forShabbos(
    DateTime shabbosDate, {
    required bool inIsrael,
    DateTime? dueAt,
  }) {
    final date = DateTime(shabbosDate.year, shabbosDate.month, shabbosDate.day);
    final calendar = JewishCalendar.fromDateTime(date)..inIsrael = inIsrael;
    final parsha = calendar.getParshah();
    if (parsha == Parsha.NONE) return null;

    final dueDate = date.subtract(const Duration(days: 1));
    final dueWallTime =
        dueAt ??
        DateTime.utc(
          date.year,
          date.month,
          date.day,
        ).subtract(const Duration(microseconds: 1));
    final catchUpThrough = _nextSimchasTorah(dueDate, inIsrael);
    return ShnayimMikraWeeklyAssignment(
      portionKey: parsha.name,
      shabbosDate: date,
      dueDate: dueDate,
      dueAt: dueWallTime,
      catchUpThrough: catchUpThrough,
      inIsrael: inIsrael,
    );
  }

  static ShnayimMikraScheduleProjection project({
    required DateTime now,
    required bool inIsrael,
    DateTime Function(DateTime shabbosDate)? dueAtForShabbos,
    Set<String> completedAssignmentKeys = const {},
  }) {
    final current = resolve(
      now: now,
      inIsrael: inIsrael,
      dueAtForShabbos: dueAtForShabbos,
    );
    final today = _day(now);
    final firstSearchDate = today.subtract(const Duration(days: 400));
    var candidate = firstSearchDate.add(
      Duration(days: (DateTime.saturday - firstSearchDate.weekday + 7) % 7),
    );
    final catchUp = <ShnayimMikraWeeklyAssignment>[];
    while (!candidate.isAfter(_day(current.shabbosDate))) {
      final assignment = forShabbos(
        candidate,
        inIsrael: inIsrael,
        dueAt: dueAtForShabbos?.call(candidate),
      );
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

  String get key =>
      '${_dateKey(shabbosDate)}:$portionKey:${inIsrael ? 'israel' : 'diaspora'}';

  bool isOverdueOn(DateTime date) => !date.isBefore(dueAt);

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

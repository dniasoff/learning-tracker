import 'package:freezed_annotation/freezed_annotation.dart';

part 'calendar_position.freezed.dart';

/// Calendar position status relative to the program schedule.
enum CalendarStatus { caughtUp, ahead, behind }

/// Position within a program calendar cycle (e.g., Daf Yomi).
///
/// [delta] is the signed distance from expected position:
///   positive = ahead of schedule
///   zero     = caught up (on today's item)
///   negative = behind schedule
@freezed
abstract class CalendarPosition with _$CalendarPosition {
  const factory CalendarPosition({
    /// User's actual position in the cycle (1-based day number).
    required int currentDay,

    /// Total days in the program cycle.
    required int totalDays,

    /// Sefaria ref for today's scheduled item.
    required String todayRef,

    /// Hebrew display text for today's item.
    required String todayDisplayHe,

    /// Signed distance from expected position.
    /// Positive = ahead, negative = behind, zero = caught up.
    required int delta,

    /// Derived status from [delta].
    required CalendarStatus status,
  }) = _CalendarPosition;
}

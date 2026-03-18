import 'package:learning_tracker/features/stages/domain/models/schedule_type.dart';
import 'package:learning_tracker/features/stages/domain/models/stage_definition.dart';

/// Validates stage definitions have the required fields for their schedule type.
class StageValidator {
  StageValidator._();

  /// Returns null if valid, or an error message if validation fails.
  static String? validate(StageDefinition stage) {
    switch (stage.scheduleType) {
      case ScheduleType.delay:
        // delayDays is required (always present as non-nullable int)
        return null;
      case ScheduleType.weekly:
        if (stage.daysOfWeek == null || stage.daysOfWeek!.isEmpty) {
          return 'Weekly stages require at least one day of week';
        }
        for (final day in stage.daysOfWeek!) {
          if (day < 1 || day > 7) {
            return 'Days of week must be 1 (Mon) through 7 (Sun), got $day';
          }
        }
        return null;
      case ScheduleType.rolling:
        if (stage.rollingWindowSize == null || stage.rollingWindowSize! <= 0) {
          return 'Rolling stages require a positive window size';
        }
        return null;
    }
  }
}

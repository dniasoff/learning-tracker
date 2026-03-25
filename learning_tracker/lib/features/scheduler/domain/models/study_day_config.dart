import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';

part 'study_day_config.freezed.dart';

@freezed
abstract class StudyDayConfigEntry with _$StudyDayConfigEntry {
  const factory StudyDayConfigEntry({
    required int dayOfWeek, // 1=Mon..7=Sun (ISO 8601)
    required DayType dayType,
  }) = _StudyDayConfigEntry;
}

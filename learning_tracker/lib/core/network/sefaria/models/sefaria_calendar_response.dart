import 'package:freezed_annotation/freezed_annotation.dart';

part 'sefaria_calendar_response.freezed.dart';
part 'sefaria_calendar_response.g.dart';

/// A single calendar entry from the Sefaria Calendars API.
@freezed
abstract class CalendarEntry with _$CalendarEntry {
  const factory CalendarEntry({
    required CalendarTitle title,
    required String url,
    @JsonKey(name: 'ref') required String sefariaRef,
    String? category,
    int? order,
    String? description,
  }) = _CalendarEntry;

  factory CalendarEntry.fromJson(Map<String, dynamic> json) =>
      _$CalendarEntryFromJson(json);
}

/// Title object within a calendar entry.
@freezed
abstract class CalendarTitle with _$CalendarTitle {
  const factory CalendarTitle({required String en, required String he}) =
      _CalendarTitle;

  factory CalendarTitle.fromJson(Map<String, dynamic> json) =>
      _$CalendarTitleFromJson(json);
}

/// Full response from the Sefaria Calendars API.
@freezed
abstract class SefariaCalendarResponse with _$SefariaCalendarResponse {
  const factory SefariaCalendarResponse({
    @JsonKey(name: 'calendar_items') required List<CalendarEntry> calendarItems,
    String? date,
    String? timezone,
  }) = _SefariaCalendarResponse;

  factory SefariaCalendarResponse.fromJson(Map<String, dynamic> json) =>
      _$SefariaCalendarResponseFromJson(json);
}

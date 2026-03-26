import 'package:dio/dio.dart';
import 'package:learning_tracker/core/network/sefaria/models/sefaria_calendar_response.dart';

/// Client for the Sefaria Calendars API.
///
/// Fetches daily calendar entries (Daf Yomi, Mishna Yomit, etc.)
/// from the Sefaria `/calendars` endpoint.
class SefariaCalendarClient {
  final Dio _dio;

  SefariaCalendarClient(this._dio);

  /// Fetch calendar entries for a specific date.
  ///
  /// If no date is provided, returns today's calendar.
  Future<SefariaCalendarResponse> fetchCalendar({
    int? year,
    int? month,
    int? day,
  }) async {
    final queryParams = <String, dynamic>{};
    if (year != null) queryParams['year'] = year;
    if (month != null) queryParams['month'] = month;
    if (day != null) queryParams['day'] = day;

    final response = await _dio.get<Map<String, dynamic>>(
      '/calendars',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    return SefariaCalendarResponse.fromJson(response.data!);
  }
}

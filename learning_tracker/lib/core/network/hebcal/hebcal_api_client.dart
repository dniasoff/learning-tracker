import 'package:dio/dio.dart';
import 'package:learning_tracker/core/network/hebcal/models/hebcal_learning_response.dart';

/// Client for the Hebcal API.
///
/// Fetches daily learning programs that Sefaria doesn't cover
/// (Chofetz Chaim, Kitzur Shulchan Aruch, Daily Tehillim, etc.)
class HebcalApiClient {
  final Dio _dio;

  HebcalApiClient(this._dio);

  /// Fetch daily learning entries for a specific date.
  Future<HebcalLearningResponse> fetchDailyLearning({
    required DateTime date,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/hebcal',
      queryParameters: {
        'v': '1',
        'cfg': 'json',
        'year': date.year,
        'month': date.month,
        'start': _formatDate(date),
        'end': _formatDate(date),
        // Enable learning programs
        'F': 'on', // Daf Yomi
        'myomi': 'on', // Mishna Yomi
        'nyomi': 'on', // Nach Yomi
        'dr1': 'on', // Rambam 1 chapter
        'dr3': 'on', // Rambam 3 chapters
        'dcc': 'on', // Chofetz Chaim
        'dksa': 'on', // Kitzur Shulchan Aruch
      },
    );

    return HebcalLearningResponse.fromJson(response.data!);
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

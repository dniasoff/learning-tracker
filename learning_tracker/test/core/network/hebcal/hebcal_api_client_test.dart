import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/network/hebcal/hebcal_api_client.dart';

/// A Dio interceptor that captures the query parameters from requests.
class _CaptureInterceptor extends Interceptor {
  Map<String, dynamic>? capturedQueryParams;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    capturedQueryParams = options.queryParameters;
    // Return a fake successful response to avoid actual network call
    handler.resolve(Response(
      data: <String, dynamic>{
        'items': <dynamic>[],
        'title': 'test',
      },
      statusCode: 200,
      requestOptions: options,
    ));
  }
}

void main() {
  group('HebcalApiClient.fetchDailyLearning', () {
    test('includes dcc and dksa flags in query parameters', () async {
      final interceptor = _CaptureInterceptor();
      final dio = Dio(BaseOptions(baseUrl: 'https://www.hebcal.com'))
        ..interceptors.add(interceptor);
      final client = HebcalApiClient(dio);
      final date = DateTime(2026, 3, 29);

      await client.fetchDailyLearning(date: date);

      final params = interceptor.capturedQueryParams!;

      // Verify all required flags are present
      expect(params['F'], 'on', reason: 'Daf Yomi flag');
      expect(params['myomi'], 'on', reason: 'Mishna Yomi flag');
      expect(params['nyomi'], 'on', reason: 'Nach Yomi flag');
      expect(params['dr1'], 'on', reason: 'Rambam 1 chapter flag');
      expect(params['dr3'], 'on', reason: 'Rambam 3 chapters flag');
      expect(params['dcc'], 'on', reason: 'Chofetz Chaim flag');
      expect(params['dksa'], 'on', reason: 'Kitzur Shulchan Aruch flag');
    });
  });
}

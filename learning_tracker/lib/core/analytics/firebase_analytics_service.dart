// core/analytics/firebase_analytics_service.dart — W7.13
//
// Firebase Analytics-backed implementation of [AnalyticsService].
//
// Only this file may import `package:firebase_analytics/`.
// The custom lint `no_firebase_outside_core` does not restrict
// `firebase_analytics`, but by convention all Firebase SDK usage
// stays within `lib/core/`.

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';

/// Production implementation of [AnalyticsService] that delegates to
/// [FirebaseAnalytics.instance].
///
/// Wire via [analyticsServiceProvider] in release builds by overriding with
/// this class (see [analytics_provider.dart]).
class FirebaseAnalyticsService extends AnalyticsService {
  FirebaseAnalyticsService([FirebaseAnalytics? analytics])
    : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  @override
  Future<void> logEvent(String name, {Map<String, Object?>? parameters}) {
    // FirebaseAnalytics.logEvent requires Map<String, Object> (non-nullable
    // values). Replace any nullable values with an empty string so no event
    // parameter is silently lost.
    final safeParams = parameters?.map(
      (k, v) => MapEntry(k, v ?? '' as Object),
    );
    return _analytics.logEvent(name: name, parameters: safeParams);
  }
}

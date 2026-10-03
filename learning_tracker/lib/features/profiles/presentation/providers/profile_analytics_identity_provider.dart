/// Publishes the active learner's salted hash as an Analytics user property.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/analytics/profile_analytics_hash.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';

final profileAnalyticsHasherProvider = Provider<ProfileAnalyticsHasher>((ref) {
  return ProfileAnalyticsHasher(
    saltStore: SecureAnalyticsSaltStore(
      ref.watch(flutterSecureStorageProvider),
    ),
  );
});

/// Kept alive by the app shell. Every active-profile change replaces or clears
/// the user property; the raw profile id never crosses AnalyticsService.
final profileAnalyticsIdentityProvider = Provider<void>((ref) {
  final analytics = ref.watch(analyticsServiceProvider);
  final hasher = ref.watch(profileAnalyticsHasherProvider);
  var generation = 0;
  ref.listen<String?>(activeProfileIdProvider, (_, profileId) {
    final ticket = ++generation;
    unawaited(
      _setProfileHash(analytics, hasher, profileId, () => ticket == generation),
    );
  }, fireImmediately: true);
});

Future<void> _setProfileHash(
  AnalyticsService analytics,
  ProfileAnalyticsHasher hasher,
  String? profileId,
  bool Function() isCurrent,
) async {
  try {
    final value = profileId == null ? null : await hasher.hash(profileId);
    if (!isCurrent()) return;
    await analytics.setUserProperty('profile_hash', value);
  } on Object {
    // Analytics identity is best-effort and cannot interrupt profile changes.
  }
}

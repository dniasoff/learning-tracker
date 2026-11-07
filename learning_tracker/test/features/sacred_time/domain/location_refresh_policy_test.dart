import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/features/sacred_time/domain/location_refresh_policy.dart';

void main() {
  final now = DateTime.utc(2026, 11, 7, 12);

  LearnerSettings settings(String? source, DateTime? fixedAt) =>
      LearnerSettings(
        profileId: '01ARZ3NDEKTSV4RRFFQ69G5FAV',
        timeZone: 'Europe/London',
        latitude: 51.5,
        longitude: -0.1,
        locationSource: source,
        locationFixedAt: fixedAt,
      );

  test('refreshes a detected fix at 24 hours', () {
    expect(
      shouldRefreshDetectedLocation(
        settings('detected', now.subtract(const Duration(hours: 24))),
        now,
      ),
      isTrue,
    );
  });

  test('does not refresh fresh, manual, or legacy fixes', () {
    expect(
      shouldRefreshDetectedLocation(
        settings('detected', now.subtract(const Duration(hours: 23))),
        now,
      ),
      isFalse,
    );
    expect(
      shouldRefreshDetectedLocation(
        settings('manual_city', now.subtract(const Duration(days: 3))),
        now,
      ),
      isFalse,
    );
    expect(shouldRefreshDetectedLocation(settings(null, null), now), isFalse);
  });
}

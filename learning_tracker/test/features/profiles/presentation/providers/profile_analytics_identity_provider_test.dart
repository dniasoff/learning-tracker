import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/analytics/profile_analytics_hash.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_analytics_identity_provider.dart';

final class _MemorySaltStore implements AnalyticsSaltStore {
  String? salt;
  @override
  Future<String?> read() async => salt;
  @override
  Future<void> write(String salt) async => this.salt = salt;
}

final class _ThrowingAnalytics extends FakeAnalyticsService {
  @override
  Future<void> setUserProperty(String name, String? value) async =>
      throw StateError('analytics down');
}

final class _FakeActiveProfileId extends ActiveProfileId {
  @override
  String? build() => null;
  // ignore: use_setters_to_change_properties
  void set(String? id) => state = id;
}

void main() {
  late FakeAnalyticsService analytics;
  late ProfileAnalyticsHasher hasher;
  late _MemorySaltStore store;

  ProviderContainer build({AnalyticsService? service}) {
    final c = ProviderContainer.test(
      overrides: [
        analyticsServiceProvider.overrideWithValue(service ?? analytics),
        profileAnalyticsHasherProvider.overrideWithValue(hasher),
        activeProfileIdProvider.overrideWith(_FakeActiveProfileId.new),
      ],
    );
    c.listen(profileAnalyticsIdentityProvider, (_, _) {});
    return c;
  }

  setUp(() {
    analytics = FakeAnalyticsService();
    store = _MemorySaltStore();
    hasher = ProfileAnalyticsHasher(saltStore: store);
  });

  test('no active profile clears the user property', () async {
    build();
    await pumpEventQueue();
    expect(analytics.userProperties, {'profile_hash': null});
  });

  test('publishes the salted hash, never the raw profile id', () async {
    final c = build();
    (c.read(activeProfileIdProvider.notifier) as _FakeActiveProfileId).set(
      'profile-1',
    );
    await pumpEventQueue();
    final value = analytics.userProperties['profile_hash'];
    expect(value, await hasher.hash('profile-1'));
    expect(value, isNot(contains('profile-1')));
    expect(value, hasLength(32));
  });

  test('switching profile replaces the hash; logout clears it', () async {
    final c = build();
    (c.read(activeProfileIdProvider.notifier) as _FakeActiveProfileId).set('a');
    await pumpEventQueue();
    final first = analytics.userProperties['profile_hash'];
    (c.read(activeProfileIdProvider.notifier) as _FakeActiveProfileId).set('b');
    await pumpEventQueue();
    final second = analytics.userProperties['profile_hash'];
    expect(second, isNot(first));
    expect(second, await hasher.hash('b'));
    (c.read(activeProfileIdProvider.notifier) as _FakeActiveProfileId).set(
      null,
    );
    await pumpEventQueue();
    expect(analytics.userProperties['profile_hash'], isNull);
  });

  test('an analytics failure does not interrupt profile changes', () async {
    final c = build(service: _ThrowingAnalytics());
    (c.read(activeProfileIdProvider.notifier) as _FakeActiveProfileId).set('a');
    await pumpEventQueue();
    expect(c.read(activeProfileIdProvider), 'a');
  });
}

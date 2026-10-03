import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/analytics/profile_analytics_hash.dart';

final class _MemorySaltStore implements AnalyticsSaltStore {
  _MemorySaltStore(this.salt);

  String? salt;
  int writes = 0;

  @override
  Future<String?> read() async => salt;

  @override
  Future<void> write(String value) async {
    writes++;
    salt = value;
  }
}

void main() {
  test('persists a generated salt and hashes the profile id stably', () async {
    final store = _MemorySaltStore(null);
    final hasher = ProfileAnalyticsHasher(saltStore: store, random: Random(1));

    final first = await hasher.hash('synthetic-profile-id');
    final again = await hasher.hash('synthetic-profile-id');

    expect(first, isNot('synthetic-profile-id'));
    expect(first, hasLength(32));
    expect(again, first);
    expect(store.writes, 1);
    expect(store.salt, isNotNull);
  });

  test('different install salts produce different learner hashes', () async {
    final first = ProfileAnalyticsHasher(
      saltStore: _MemorySaltStore('install-salt-one'),
    );
    final second = ProfileAnalyticsHasher(
      saltStore: _MemorySaltStore('install-salt-two'),
    );

    expect(
      await first.hash('synthetic-profile-id'),
      isNot(await second.hash('synthetic-profile-id')),
    );
  });
}

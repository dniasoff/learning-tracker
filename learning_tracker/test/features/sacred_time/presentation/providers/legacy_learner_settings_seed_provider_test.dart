// Mirror test for
// `lib/features/sacred_time/presentation/providers/legacy_learner_settings_seed_provider.dart`
// (stuck Sacred-Time lock hotfix, 1.0.74).
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';
import 'package:learning_tracker/features/sacred_time/data/repositories/legacy_learner_settings_seeder.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/account_lock_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/legacy_learner_settings_seed_provider.dart';

import '../../../../helpers/learner_state/lock_fixtures.dart';
import '../../../../helpers/learner_state_fixtures.dart';

final class _Seeder implements LegacyLearnerSettingsSeeder {
  final calls = <LearnerScope>[];
  Exception? failWith;

  @override
  Future<bool> seedIfLegacy(LearnerScope scope) async {
    calls.add(scope);
    final error = failWith;
    if (error != null) throw error;
    return true;
  }
}

final _scope = LearnerScope(ownerUid: 'owner-uid', profileId: profileUlid);

const _missingZone = StorageFormatException(
  'LearnerSettings',
  'time_zone',
  'missing',
);

void main() {
  late _Seeder seeder;
  late ProviderContainer c;
  late StreamController<LearnerSettingsHistory> settings;

  Future<void> emitError(Object e) async {
    settings.addError(e);
    await pumpEventQueue();
  }

  setUp(() {
    seeder = _Seeder();
    settings = StreamController<LearnerSettingsHistory>.broadcast();
    addTearDown(settings.close);
    c = ProviderContainer.test(
      overrides: [
        legacyLearnerSettingsSeederProvider.overrideWithValue(seeder),
        lockDrivingScopesProvider.overrideWithValue(AsyncData([_scope])),
        learnerLockSettingsProvider(
          _scope,
        ).overrideWith((ref) => settings.stream),
      ],
    );
    final sub = c.listen(legacyLearnerSettingsSeedProvider, (_, _) {});
    addTearDown(sub.close);
  });

  test('a learner whose settings do not decode (a legacy profile with no '
      'time_zone) is seeded once', () async {
    await pumpEventQueue();
    await emitError(_missingZone);
    await emitError(_missingZone);
    expect(seeder.calls, [_scope]);
  });

  test('readable, loading or not-ready settings are never seeded', () async {
    await pumpEventQueue();
    settings.add(constantHistory(lakewood));
    await pumpEventQueue();
    await emitError(const LearnerSettingsNotReadyException(profileUlid));
    expect(seeder.calls, isEmpty);
  });

  test('a failed seed (e.g. offline) is retried on the next error', () async {
    seeder.failWith = Exception('offline');
    await pumpEventQueue();
    await emitError(_missingZone);
    seeder.failWith = null;
    await emitError(StateError('still unreadable'));
    expect(seeder.calls, [_scope, _scope]);
  });
}

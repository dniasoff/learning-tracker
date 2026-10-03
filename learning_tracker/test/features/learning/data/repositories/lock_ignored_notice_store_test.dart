// DNI-504 AC-9: the per-device record of announced lock-ignored events.
@Tags(['learning'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/learning/data/repositories/lock_ignored_notice_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/learner_state_fixtures.dart';

final _a = LearnerScope(ownerUid: 'owner', profileId: ulidA);
final _b = LearnerScope(ownerUid: 'owner', profileId: ulidB);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const store = SharedPreferencesLockIgnoredNoticeStore();

  test('nothing is announced at first', () async {
    expect(await store.announced(_a), isEmpty);
  });

  test('round-trips the announced set per learner', () async {
    await store.setAnnounced(_a, {'e2', 'e1'});
    expect(await store.announced(_a), {'e1', 'e2'});
    expect(await store.announced(_b), isEmpty);
  });

  test('a new set replaces the old one, so it never grows unbounded', () async {
    await store.setAnnounced(_a, {'e1', 'e2'});
    await store.setAnnounced(_a, {'e3'});
    expect(await store.announced(_a), {'e3'});
  });
}

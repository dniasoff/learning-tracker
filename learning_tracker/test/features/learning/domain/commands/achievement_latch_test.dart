// AD-27 / AD-50 achievement latch (DNI-480): after a write it latches every
// threshold the lifetime total newly crosses, once; a failed check retries
// on the configured delays and never throws to the caller.
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/points.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/learning/domain/commands/achievement_latch.dart';

final class _Port implements AchievementLatchPort {
  int lifetime = 0;
  int failTimes = 0;
  int totalsCalls = 0;
  final Set<String> latched = {};
  final List<Set<String>> excluded = [];

  @override
  Future<void> pendingWritesSettled(LearnerScope scope) async {}

  @override
  Future<PointsTotals> totalsIncluding(
    LearnerScope scope,
    Set<String> learnEventIds, {
    Set<String> excluding = const {},
  }) async {
    totalsCalls++;
    excluded.add(excluding);
    if (failTimes > 0) {
      failTimes--;
      throw StateError('offline');
    }
    return PointsTotals(balance: lifetime, lifetimeEarned: lifetime);
  }

  @override
  Future<List<AchievementThreshold>> thresholds(LearnerScope scope) async =>
      const [
        AchievementThreshold(id: 'bronze', points: 20),
        AchievementThreshold(id: 'silver', points: 30),
      ];

  @override
  Future<Set<String>> unlocked(LearnerScope scope) async => {...latched};

  @override
  Future<void> latch(LearnerScope scope, Set<String> achievementIds) async =>
      latched.addAll(achievementIds);
}

void main() {
  final scope = LearnerScope(
    ownerUid: 'owner',
    profileId: '01HZY0000000000000000000AA',
  );

  test('latches newly crossed thresholds once', () async {
    final port = _Port()..lifetime = 25;
    final latch = AchievementLatch(port);
    addTearDown(latch.dispose);

    expect(await latch.afterWrite(scope, {'e1'}), {'bronze'});
    expect(await latch.afterWrite(scope, {'e2'}), isEmpty);
    port.lifetime = 31;
    expect(await latch.reconcile(scope), {'silver'});
    expect(port.latched, {'bronze', 'silver'});
  });

  test('a write with no learn events checks nothing', () async {
    final port = _Port()..lifetime = 99;
    final latch = AchievementLatch(port);
    addTearDown(latch.dispose);

    expect(await latch.afterWrite(scope, const {}), isEmpty);
    expect(port.totalsCalls, 0);
  });

  test('passes the unsaved events to exclude from the totals', () async {
    final port = _Port()..lifetime = 25;
    final latch = AchievementLatch(port);
    addTearDown(latch.dispose);

    await latch.afterWrite(scope, {'e1'}, unsaved: () => {'e0'});
    expect(port.excluded.single, {'e0'});
  });

  test('a failed check returns nothing and retries on the delays', () {
    fakeAsync((async) {
      final port = _Port()
        ..lifetime = 25
        ..failTimes = 1;
      final latch = AchievementLatch(
        port,
        retryDelays: const [Duration(seconds: 1)],
      );
      Set<String>? result;
      latch.afterWrite(scope, {'e1'}).then((r) => result = r);
      async.flushMicrotasks();
      expect(result, isEmpty);
      expect(port.latched, isEmpty);

      async.elapse(const Duration(seconds: 1));
      expect(port.latched, {'bronze'});
      latch.dispose();
    });
  });

  test('dispose cancels pending retries', () {
    fakeAsync((async) {
      final port = _Port()
        ..lifetime = 25
        ..failTimes = 1;
      final latch = AchievementLatch(
        port,
        retryDelays: const [Duration(seconds: 1)],
      );
      latch.afterWrite(scope, {'e1'});
      async.flushMicrotasks();
      latch.dispose();
      async.elapse(const Duration(seconds: 5));
      expect(port.totalsCalls, 1);
      expect(port.latched, isEmpty);
    });
  });
}

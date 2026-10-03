// DNI-480: unit tests of the AD-27 / AD-50 achievement latch over a fake
// port (the integration behaviour lives in learning_commands_achievements).
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/points.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/learning/domain/commands/achievement_latch.dart';

final class _Port implements AchievementLatchPort {
  List<AchievementThreshold> thresholdList = const [
    AchievementThreshold(id: 'bronze', points: 10),
    AchievementThreshold(id: 'silver', points: 20),
  ];
  int lifetime = 15;
  Set<String> stored = {};
  int failTotals = 0;
  final calls = <String>[];
  final excluded = <Set<String>>[];
  final requested = <Set<String>>[];

  @override
  Future<void> pendingWritesSettled(LearnerScope scope) async =>
      calls.add('settled');

  @override
  Future<PointsTotals> totalsIncluding(
    LearnerScope scope,
    Set<String> learnEventIds, {
    Set<String> excluding = const {},
  }) async {
    calls.add('totals');
    requested.add(learnEventIds);
    excluded.add(excluding);
    if (failTotals > 0) {
      failTotals--;
      throw StateError('offline');
    }
    return PointsTotals(balance: lifetime, lifetimeEarned: lifetime);
  }

  @override
  Future<List<AchievementThreshold>> thresholds(LearnerScope scope) async {
    calls.add('thresholds');
    return thresholdList;
  }

  @override
  Future<Set<String>> unlocked(LearnerScope scope) async => {...stored};

  @override
  Future<void> latch(LearnerScope scope, Set<String> ids) async {
    calls.add('latch');
    stored.addAll(ids);
  }
}

void main() {
  final scope = LearnerScope(
    ownerUid: 'u',
    profileId: '01J0000000000000000000A480',
  );
  late _Port port;
  late AchievementLatch latch;

  setUp(() {
    port = _Port();
    latch = AchievementLatch(port);
  });
  tearDown(() => latch.dispose());

  test('afterWrite with no events does nothing', () async {
    expect(await latch.afterWrite(scope, {}), isEmpty);
    expect(port.calls, isEmpty);
  });

  test('afterWrite latches only crossed thresholds, after settling', () async {
    expect(await latch.afterWrite(scope, {'e1'}), {'bronze'});
    expect(port.stored, {'bronze'});
    expect(port.calls, ['thresholds', 'settled', 'totals', 'latch']);
    expect(port.requested.single, {'e1'});
  });

  test('is idempotent: a repeated check latches nothing more', () async {
    await latch.afterWrite(scope, {'e1'});
    port.calls.clear();
    expect(await latch.afterWrite(scope, {'e1'}), isEmpty);
    expect(port.calls, isNot(contains('latch')));
    expect(port.stored, {'bronze'});
  });

  test('is monotonic: lower totals never remove a latched id', () async {
    await latch.afterWrite(scope, {'e1'});
    port.lifetime = 0;
    expect(await latch.afterWrite(scope, {'e2'}), isEmpty);
    expect(port.stored, {'bronze'});
  });

  test('no thresholds short-circuits before reading totals', () async {
    port.thresholdList = const [];
    expect(await latch.afterWrite(scope, {'e1'}), isEmpty);
    expect(port.calls, ['thresholds']);
  });

  test('passes the unsaved set evaluated at attempt time', () async {
    var rejected = {'bad'};
    await latch.afterWrite(scope, {'e1'}, unsaved: () => rejected);
    expect(port.excluded.single, {'bad'});
    rejected = {};
  });

  test('reconcile latches everything the current totals crossed', () async {
    port.lifetime = 25;
    expect(await latch.reconcile(scope), {'bronze', 'silver'});
    expect(port.requested.single, isEmpty);
  });

  test('a failure never throws and is retried on the delays', () {
    fakeAsync((async) {
      port.failTotals = 2;
      final l = AchievementLatch(
        port,
        retryDelays: const [Duration(seconds: 1), Duration(seconds: 5)],
      );
      Set<String>? result;
      l.afterWrite(scope, {'e1'}).then((v) => result = v);
      async.flushMicrotasks();
      expect(result, isEmpty);
      expect(port.stored, isEmpty);

      async.elapse(const Duration(seconds: 1));
      expect(port.stored, isEmpty, reason: 'second attempt also fails');
      async.elapse(const Duration(seconds: 5));
      expect(port.stored, {'bronze'}, reason: 'third attempt succeeds');
      l.dispose();
    });
  });

  test('retries stop after the last delay', () {
    fakeAsync((async) {
      port.failTotals = 99;
      final l = AchievementLatch(
        port,
        retryDelays: const [Duration(seconds: 1)],
      );
      l.afterWrite(scope, {'e1'});
      async.elapse(const Duration(minutes: 10));
      expect(port.calls.where((c) => c == 'totals'), hasLength(2));
      l.dispose();
    });
  });

  test('dispose cancels pending retries', () {
    fakeAsync((async) {
      port.failTotals = 99;
      final l = AchievementLatch(
        port,
        retryDelays: const [Duration(seconds: 1)],
      );
      l.afterWrite(scope, {'e1'});
      async.flushMicrotasks();
      l.dispose();
      async.elapse(const Duration(minutes: 1));
      expect(port.calls.where((c) => c == 'totals'), hasLength(1));
    });
  });
}

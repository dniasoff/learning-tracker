// DNI-480 (Story 1.18) AC-2, integration level: after a write,
// `LearningCommands` detects newly crossed achievement thresholds and
// array-unions their ids into `preferences/gamification_settings
// .unlocked_achievement_ids` (AD-27 latch record, AD-50).
//
// The latch port here is real where it matters: the totals run the real
// engine over every event the commands wrote and sum their pts_ awards
// with `pointsTotals`, and the latch record is the real
// `FirestoreRewardSettingsRepository` over a fake Firestore (array union).
import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/repositories/firestore_reward_settings_repository.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/points.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/learning/domain/commands/achievement_latch.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../../helpers/learner_state/in_memory_ports.dart';

const _uid = 'owner-uid';
const _profileId = '01J0000000000000000000L480';
const _b11 = 'Mishnah Berakhot 1:1';
const _b12 = 'Mishnah Berakhot 1:2';
const _b13 = 'Mishnah Berakhot 1:3';

/// Tuesday 2026-09-01 10:00Z: unlocked for the UTC fixture learner.
final _tuesday = engineAt(600);

/// An [AchievementLatchPort] over what the commands wrote: the engine's
/// earning set filters the written pts_ awards; the latch record is the
/// Firestore settings document.
final class _EnginePort implements AchievementLatchPort {
  _EnginePort(this.writes, this.settings);

  final InMemoryLearningWritePort writes;
  final FirestoreRewardSettingsRepository settings;
  List<AchievementThreshold> thresholdList = const [
    AchievementThreshold(id: 'bronze', points: 20),
    AchievementThreshold(id: 'silver', points: 30),
  ];

  /// Events voided outside the commands (e.g. on another device).
  final List<LearningEvent> extra = [];
  final List<Set<String>> totalsRequests = [];
  int latchCalls = 0;

  /// When set, [unlocked] waits for it (to line up concurrent checks).
  Completer<void>? holdUnlocked;
  bool failTotals = false;

  @override
  Future<PointsTotals> totalsIncluding(
    LearnerScope scope,
    Set<String> learnEventIds,
  ) async {
    totalsRequests.add(learnEventIds);
    if (failTotals) throw StateError('ledger unreadable');
    final events = [for (final c in writes.chunks) ...c.events, ...extra];
    final state = const LearnerStateEngine().run(engineInputs(events: events));
    return pointsTotals([
      for (final c in writes.chunks)
        for (final a in c.awards)
          PointsLedgerRow(
            id: 'pts_${a.eventId}',
            amount: a.amount,
            eventId: a.eventId,
          ),
    ], state.earningEventIds);
  }

  @override
  Future<List<AchievementThreshold>> thresholds(LearnerScope scope) async =>
      thresholdList;

  @override
  Future<Set<String>> unlocked(LearnerScope scope) async {
    final read = await settings.readUnlockedAchievementIds();
    await holdUnlocked?.future;
    return read;
  }

  @override
  Future<void> latch(LearnerScope scope, Set<String> achievementIds) {
    latchCalls++;
    return settings.latchUnlockedAchievementIds(achievementIds);
  }
}

final class _Harness {
  _Harness(FakeFirebaseFirestore firestore)
    : settings = FirestoreRewardSettingsRepository(
        firestore: firestore,
        uid: _uid,
        profileId: _profileId,
      ) {
    port = _EnginePort(writes, settings);
    latch = AchievementLatch(port);
    commands = DefaultLearningCommands(
      scope: c0Scope(),
      actor: const Actor(
        uid: 'owner-uid',
        role: ActorRole.parent,
        displayName: '',
      ),
      reads: reads,
      writePort: writes,
      gate: const LockWindowCaptureGate(),
      analytics: RecordingLearningAnalytics(),
      failureReporter: RecordingLearningFailureReporter(),
      clock: () => _tuesday,
      newUlid: (_) => engineUlid(_seq++),
      ackWait: const Duration(milliseconds: 40),
      pointsWait: const Duration(milliseconds: 40),
      achievements: latch,
    );
    addTearDown(commands.dispose);
  }

  final FirestoreRewardSettingsRepository settings;
  final writes = InMemoryLearningWritePort();
  final reads = FakeLearningCommandReads(
    history: c0SettingsHistory(),
    corpora: {engineCurriculum: mishnayosCorpus()},
  );
  late final _EnginePort port;
  late final AchievementLatch latch;
  late final DefaultLearningCommands commands;
  int _seq = 40000;

  Future<CaptureResult> capture(List<String> refs, {String? source}) =>
      commands.capture(
        curriculumId: engineCurriculum,
        refs: refs,
        source: source ?? LearningEvent.sourceMain,
        dateState: DateState.dated,
        stage: source == null ? 1 : null,
      );

  Future<Set<String>> unlocked() async {
    await pumpEventQueue();
    return settings.readUnlockedAchievementIds();
  }
}

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() => firestore = FakeFirebaseFirestore());

  test('threshold crossing latches achievement once and all reads use '
      'latch', () async {
    final h = _Harness(firestore);

    // 10 points: below bronze (20); nothing latched.
    await h.capture([_b11]);
    expect(await h.unlocked(), isEmpty);
    expect(h.port.latchCalls, 0);

    // 20 points: bronze is crossed by this write and latched.
    final second = await h.capture([_b12]);
    expect(await h.unlocked(), {'bronze'});
    expect(h.port.totalsRequests.last, {
      ...(second as CaptureSuccess).eventIds,
    }, reason: 'the latch waits for the state to include this write');

    // A replayed check of the same write latches nothing new.
    expect(
      await h.latch.afterWrite(c0Scope(), {second.eventIds.single}),
      isEmpty,
    );
    expect(h.port.latchCalls, 1);

    // A repeat tick of a learnt leaf earns nothing: no new crossing.
    await h.capture([_b11]);
    expect(await h.unlocked(), {'bronze'});
    expect(h.port.latchCalls, 1);

    // A void that drops lifetime below bronze never unlatches it.
    h.port.extra.add(engineVoid(90000, 40001, minutes: 700));
    await h.capture([_b13], source: engineUlid(900));
    expect(await h.unlocked(), {'bronze'});

    // Stored list, sibling keys intact.
    final doc = await firestore
        .doc(
          'users/$_uid/learner_profiles/$_profileId/preferences/'
          'gamification_settings',
        )
        .get();
    expect(doc.data()!['unlocked_achievement_ids'], ['bronze']);
  });

  test('concurrent threshold checks on two devices leave one id', () async {
    final h = _Harness(firestore);
    await h.capture([_b11]);
    await h.capture([_b12]);
    expect(await h.unlocked(), {'bronze'});

    // Both devices read the list before either latches silver (30).
    h.port.thresholdList = const [
      AchievementThreshold(id: 'bronze', points: 20),
      AchievementThreshold(id: 'silver', points: 30),
    ];
    final other = _EnginePort(h.writes, h.settings);
    final gate = Completer<void>();
    h.port.holdUnlocked = gate;
    other.holdUnlocked = gate;
    await h.capture([_b13]); // 30 points: silver crossed
    final ids = {h.writes.chunks.last.events.single.id};
    final mine = h.latch.afterWrite(c0Scope(), ids);
    final theirs = AchievementLatch(other).afterWrite(c0Scope(), ids);
    await pumpEventQueue();
    gate.complete();

    expect(await mine, {'silver'});
    expect(await theirs, {'silver'});
    final stored =
        (await firestore
                .doc(
                  'users/$_uid/learner_profiles/$_profileId/preferences/'
                  'gamification_settings',
                )
                .get())
            .data()!['unlocked_achievement_ids'];
    expect(stored, unorderedEquals(['bronze', 'silver']));
    expect((stored as List).length, 2, reason: 'array union: one silver');
  });

  test('a void-only write runs no latch; a latch failure never fails the '
      'command', () async {
    final h = _Harness(firestore);
    final first = await h.capture([_b11]) as CaptureSuccess;
    await pumpEventQueue();
    final requests = h.port.totalsRequests.length;

    h.reads.eventLog.addAll([for (final c in h.writes.chunks) ...c.events]);
    expect(
      await h.commands.voidEvent(first.eventIds.single),
      isA<CaptureSuccess>(),
    );
    await pumpEventQueue();
    expect(h.port.totalsRequests, hasLength(requests));

    h.port.failTotals = true;
    expect(await h.capture([_b12]), isA<CaptureSuccess>());
    expect(await h.unlocked(), isEmpty);
  });

  test('no configured thresholds reads nothing else', () async {
    final h = _Harness(firestore);
    h.port.thresholdList = const [];
    await h.capture([_b11, _b12, _b13]);
    await pumpEventQueue();
    expect(h.port.totalsRequests, isEmpty);
    expect(h.port.latchCalls, 0);
  });
}

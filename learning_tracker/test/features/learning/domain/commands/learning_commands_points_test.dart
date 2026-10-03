// DNI-480 (Story 1.18) AC-3 / R15 port: the still-valid cases of the
// retired points readers and their tests (the Firestore points
// repository, the completion-based `PointsService` totals, the curriculum eligibility
// gate, the old-store balance and lifetime adapters), now pinned on what
// replaces them: `DefaultLearningCommands` writes, the engine's
// `earningEventIds`, and `pointsTotals`.
//
// Retired, not ported: per-curriculum eligibility by goal or program (the
// engine is the only eligibility authority, AD-50), the completion-tier
// points history and the autoDispose checks of the deleted per-curriculum
// points and points-history providers.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/points.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../../helpers/learner_state/in_memory_ports.dart';

const _b11 = 'Mishnah Berakhot 1:1';
const _b12 = 'Mishnah Berakhot 1:2';

/// Tuesday 2026-09-01 10:00Z: unlocked for the UTC fixture learner.
final _tuesday = engineAt(600);

final class _Harness {
  _Harness() {
    commands = DefaultLearningCommands(
      scope: c0Scope(),
      actor: const Actor(
        uid: 'owner-uid',
        role: ActorRole.parent,
        displayName: '',
      ),
      reads: reads,
      writePort: port,
      gate: const LockWindowCaptureGate(),
      analytics: RecordingLearningAnalytics(),
      failureReporter: RecordingLearningFailureReporter(),
      clock: () => _tuesday,
      newUlid: (_) => engineUlid(_seq++),
      ackWait: const Duration(milliseconds: 40),
      pointsWait: const Duration(milliseconds: 40),
    );
    addTearDown(commands.dispose);
  }

  final reads = FakeLearningCommandReads(
    history: c0SettingsHistory(),
    corpora: {engineCurriculum: mishnayosCorpus()},
  );
  final port = InMemoryLearningWritePort();
  late final DefaultLearningCommands commands;
  int _seq = 50000;

  List<LearningEvent> get written => [for (final c in port.chunks) ...c.events];

  /// Makes everything committed so far visible to the command reads.
  void sync() {
    final ids = {for (final e in reads.eventLog) e.id};
    reads.eventLog.addAll(written.where((e) => ids.add(e.id)));
  }

  Future<CaptureResult> capture(List<String> refs) => commands.capture(
    curriculumId: engineCurriculum,
    refs: refs,
    source: LearningEvent.sourceMain,
    dateState: DateState.dated,
    stage: 1,
  );

  /// Every pts_ row ever sent (failed attempts included), as the ledger
  /// keys them, plus [extra] non-event rows.
  List<PointsLedgerRow> ledger([List<PointsLedgerRow> extra = const []]) => [
    for (final chunk in port.attempts)
      for (final a in chunk.awards)
        PointsLedgerRow(
          id: 'pts_${a.eventId}',
          amount: a.amount,
          eventId: a.eventId,
          entryKind: 'completion',
        ),
    ...extra,
  ];

  PointsTotals totals([List<PointsLedgerRow> extra = const []]) {
    final state = const LearnerStateEngine().run(engineInputs(events: written));
    return pointsTotals(ledger(extra), state.earningEventIds);
  }
}

void main() {
  test('retired point and achievement behavior is covered by engine and '
      'command tests', () async {
    // Ledger balance and lifetime (was the Firestore points repository /
    // the old-store adapters): earned rows, a debit, a refund and parent
    // adjustments.
    final h = _Harness();
    await h.capture([_b11, _b12]);
    final spends = [
      const PointsLedgerRow(
        id: 'd1',
        amount: -15,
        entryKind: 'redemption_debit',
      ),
      const PointsLedgerRow(
        id: 'r1',
        amount: 5,
        entryKind: 'redemption_refund',
      ),
      const PointsLedgerRow(id: 'a1', amount: 4, entryKind: 'parent_add'),
      const PointsLedgerRow(id: 'x1', amount: -2, entryKind: 'parent_deduct'),
    ];
    // 10 + 10 earned; balance 20 - 15 + 5 + 4 - 2 = 12; lifetime counts
    // earned rows and parent_add only.
    expect(
      h.totals(spends),
      const PointsTotals(balance: 12, lifetimeEarned: 24),
    );

    // Threshold unlock (was the derived "lifetime >= threshold" check): the
    // crossing is latched once and never removed.
    const thresholds = [
      AchievementThreshold(id: 'bronze', points: 20),
      AchievementThreshold(id: 'gold', points: 100),
    ];
    final crossed = newlyCrossedAchievements(h.totals(), thresholds, const {});
    expect(crossed, {'bronze'});
    expect(newlyCrossedAchievements(h.totals(), thresholds, crossed), isEmpty);
  });

  test('a retried capture re-sends the same pts_ ids and earns once', () async {
    final h = _Harness();
    final failures = <List<PendingFailure>>[];
    final sub = h.commands.watchPendingFailures().listen(failures.add);
    addTearDown(sub.cancel);
    h.port.failNextWith(const PermanentWriteRejection('permission-denied'));

    expect(
      await h.capture([_b11]),
      const CaptureResult.rejected(CaptureRejection.notSaved),
    );
    await pumpEventQueue();
    expect(
      await h.commands.retry(failures.last.single.id),
      isA<CaptureSuccess>(),
    );

    final ids = [for (final r in h.ledger()) r.id];
    expect(ids, hasLength(2), reason: 'the failed attempt and the retry');
    expect(ids.toSet(), hasLength(1), reason: 'same pts_{eventId} doc id');
    expect(h.totals(), const PointsTotals(balance: 10, lifetimeEarned: 10));
  });

  test('a duplicate main tick carries a pts_ row that does not earn', () async {
    final h = _Harness();
    await h.capture([_b11]);
    await h.capture([_b11]);
    expect(h.ledger(), hasLength(2));
    expect(h.totals(), const PointsTotals(balance: 10, lifetimeEarned: 10));
  });

  test('a correction moves the earning to the replacement without a '
      'reversal row', () async {
    final h = _Harness();
    final first = await h.capture([_b11]) as CaptureSuccess;
    h.sync();

    final replaced = await h.commands.replace(
      first.eventIds.single,
      const EventReplacement(ref: _b12),
    );
    expect(replaced, isA<CaptureSuccess>());
    expect(h.ledger().every((r) => r.amount > 0), isTrue);
    // The voided original's pts_ row no longer counts; the replacement is
    // the first learn of 1:2 and earns.
    expect(h.totals(), const PointsTotals(balance: 10, lifetimeEarned: 10));
  });

  test('voiding an earning event lowers balance and lifetime', () async {
    final h = _Harness();
    final first = await h.capture([_b11]) as CaptureSuccess;
    await h.capture([_b12]);
    h.sync();
    expect(h.totals(), const PointsTotals(balance: 20, lifetimeEarned: 20));

    expect(
      await h.commands.voidEvent(first.eventIds.single),
      isA<CaptureSuccess>(),
    );
    expect(h.totals(), const PointsTotals(balance: 10, lifetimeEarned: 10));
    expect(h.ledger(), hasLength(2), reason: 'no reversal entry');
  });
}

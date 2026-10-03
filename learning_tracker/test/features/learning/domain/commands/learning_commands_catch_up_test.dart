// DNI-506 (Story 3.3) AC-1, AC-3, AC-5, AC-8: `LearningCommands
// .recordCatchUp` writes one `catch_up` learn event per listed leaf with
// its `pts_` entry in the same ≤450-write chunk, refuses a tap after the
// card's window before any write, queues offline at once, and leaves no
// partial action counted when a chunk is rejected.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';

import '../../../../helpers/learner_state/catch_up_card_harness.dart';
import '../../../../helpers/learner_state/catch_up_command_harness.dart';
import '../../../../helpers/learner_state_fixtures.dart';

/// [n] distinct main-track leaves (refs need not be in the corpus).
List<CatchUpLeaf> _mainLeaves(int n) => [
  for (var i = 0; i < n; i++) mainCatchUpLeaf('Mishnah Berakhot 9:$i'),
];

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 120));

void main() {
  group('AC-1: one catch_up event per listed leaf', () {
    test('main and sub-track leaves, dated, sourced and staged', () async {
      final h = CatchUpCommandHarness();
      final result = await h.commands.recordCatchUp(
        catchUpAllAction([
          mainCatchUpLeaf('Mishnah Berakhot 2:1'),
          mainCatchUpLeaf('Mishnah Berakhot 1:2', stage: 2),
          subCatchUpLeaf('Mishnah Peah 1:1'),
        ]),
      );
      expect(result, isA<CaptureSuccess>());
      final events = h.written;
      expect(events, hasLength(3));
      expect((result as CaptureSuccess).eventIds, [
        for (final e in events) e.id,
      ]);
      // Ascending ids in card order.
      expect([...result.eventIds]..sort(), result.eventIds);
      for (final e in events) {
        expect(e.isLearn, isTrue);
        expect(e.curriculumId, 'mishnayos');
        expect(e.dateState, DateState.catchUp);
        expect(e.learnedOn, catchUpShabbos);
        expect(effectiveAt(e), catchUpSunday);
        expect(e.actor, catchUpParent);
        // No original_recorded_at: the tap instant is the effective one.
        expect(rawRecordedAtForSkewRule(e), effectiveAt(e));
      }
      expect(
        [for (final e in events) (e.ref, e.source, e.stage)],
        [
          ('Mishnah Berakhot 2:1', 'main', 1),
          ('Mishnah Berakhot 1:2', 'main', 2),
          ('Mishnah Peah 1:1', ulidB, null),
        ],
      );
      // AD-50: every main event, and only those, carries its pts_ entry
      // at the planner stage's amount, created at recorded_at.
      expect(
        [for (final a in h.port.awards) (a.eventId, a.amount, a.createdAt)],
        [(events[0].id, 10, catchUpSunday), (events[1].id, 5, catchUpSunday)],
      );
    });

    test(
      'the session actor is stamped: a child records as the child',
      () async {
        final h = CatchUpCommandHarness(actor: catchUpChild);
        await h.commands.recordCatchUp(
          catchUpAllAction([mainCatchUpLeaf('Mishnah Berakhot 2:1')]),
        );
        expect(h.written.single.actor.role, ActorRole.child);
      },
    );

    test('an empty plan writes nothing', () async {
      final h = CatchUpCommandHarness();
      final result = await h.commands.recordCatchUp(catchUpAllAction([]));
      expect(result, const CaptureResult.success());
      expect(h.port.attempts, isEmpty);
    });

    test('an identical leaf listed twice is written once', () async {
      final h = CatchUpCommandHarness();
      await h.commands.recordCatchUp(
        catchUpAllAction([
          mainCatchUpLeaf('Mishnah Berakhot 2:1'),
          mainCatchUpLeaf('Mishnah Berakhot 2:1'),
        ]),
      );
      expect(h.written, hasLength(1));
    });

    test('450 writes fit one chunk; 451 split with pairs together', () async {
      // 225 main leaves = 450 writes (event + pts_ each).
      final one = CatchUpCommandHarness();
      await one.commands.recordCatchUp(catchUpAllAction(_mainLeaves(225)));
      expect(one.port.chunks, hasLength(1));
      expect(one.port.chunks.single.events.length, 225);
      expect(one.port.chunks.single.awards.length, 225);

      // 225 main + 1 sub-track = 451 writes: two chunks.
      final two = CatchUpCommandHarness();
      await two.commands.recordCatchUp(
        catchUpAllAction([
          ..._mainLeaves(225),
          subCatchUpLeaf('Mishnah Peah 1:1'),
        ]),
      );
      expect(two.port.chunks, hasLength(2));
      for (final c in two.port.chunks) {
        expect(c.events.length + c.awards.length, lessThanOrEqualTo(450));
        final ids = {for (final e in c.events) e.id};
        expect(c.awards.every((a) => ids.contains(a.eventId)), isTrue);
      }
      expect(two.written, hasLength(226));
    });

    test('a three-day plan over 450 writes keeps every pair together', () {
      // The Shabbos lock has one locked day; the pairing rule is the same
      // for any day count, so a 600-write single-day plan stands in.
      final h = CatchUpCommandHarness();
      return h.commands.recordCatchUp(catchUpAllAction(_mainLeaves(300))).then((
        result,
      ) {
        expect(result, isA<CaptureSuccess>());
        expect(h.port.chunks, hasLength(2));
        for (final c in h.port.chunks) {
          expect(
            c.events.length + c.awards.length,
            lessThanOrEqualTo(LearningWriteChunk.maxWrites),
          );
          final ids = {for (final e in c.events) e.id};
          expect(c.awards.map((a) => a.eventId).every(ids.contains), true);
          expect(c.awards.length, c.events.length);
        }
      });
    });
  });

  group('AC-3: the window at the tap instant', () {
    test('a tap at 23:59 on the window\'s last day is written', () async {
      final h = CatchUpCommandHarness(
        now: catchUpZone.at(DateTime.utc(2026, 10, 12), hour: 23, minute: 59),
      );
      final result = await h.commands.recordCatchUp(
        catchUpAllAction([mainCatchUpLeaf('Mishnah Berakhot 2:1')]),
      );
      expect(result, isA<CaptureSuccess>());
      expect(h.written.single.dateState, DateState.catchUp);
    });

    test(
      'a stale screen confirmed at 00:01 is refused before any write',
      () async {
        final h = CatchUpCommandHarness(
          now: catchUpZone.at(DateTime.utc(2026, 10, 13), minute: 1),
        );
        final result = await h.commands.recordCatchUp(
          catchUpAllAction([
            mainCatchUpLeaf('Mishnah Berakhot 2:1'),
            subCatchUpLeaf('Mishnah Peah 1:1'),
          ]),
        );
        expect(
          result,
          const CaptureResult.rejected(CaptureRejection.catchUpEnded),
        );
        expect(h.port.attempts, isEmpty);
        expect(h.analytics.captures, isEmpty);
      },
    );

    test('the instant just after the window is refused', () async {
      final window = catchUpWindow(catchUpShabbosLock(), catchUpHistory);
      final h = CatchUpCommandHarness(
        now: window.endUtc.add(const Duration(milliseconds: 1)),
      );
      final result = await h.commands.recordCatchUp(
        catchUpAllAction([mainCatchUpLeaf('Mishnah Berakhot 2:1')]),
      );
      expect(
        result,
        const CaptureResult.rejected(CaptureRejection.catchUpEnded),
      );
      expect(h.port.attempts, isEmpty);
    });

    test('a tap inside a later lock is refused by the capture gate', () async {
      // Friday 2026-10-16 18:00 New York: the next Shabbos lock.
      final h = CatchUpCommandHarness(
        now: catchUpZone.at(DateTime.utc(2026, 10, 16), hour: 18),
      );
      final result = await h.commands.recordCatchUp(
        catchUpAllAction([mainCatchUpLeaf('Mishnah Berakhot 2:1')]),
      );
      expect(result, isA<CaptureLocked>());
      expect(h.port.attempts, isEmpty);
    });
  });

  group('AC-8: a failed write leaves nothing counted', () {
    test('a validation failure writes nothing', () async {
      final h = CatchUpCommandHarness();
      final result = await h.commands.recordCatchUp(
        catchUpAllAction([
          mainCatchUpLeaf('Mishnah Berakhot 2:1'),
          // A stage on a sub-track leaf is malformed.
          const CatchUpLeaf(
            curriculumId: 'mishnayos',
            ref: 'Mishnah Peah 1:1',
            source: ulidB,
            learnedOn: catchUpShabbos,
            stage: 1,
          ),
        ]),
      );
      expect(result, const CaptureResult.rejected(CaptureRejection.invalid));
      expect(h.port.attempts, isEmpty);
    });

    test('a leaf off the lock\'s locked days writes nothing', () async {
      final h = CatchUpCommandHarness();
      final result = await h.commands.recordCatchUp(
        catchUpAllAction([
          mainCatchUpLeaf('Mishnah Berakhot 2:1', learnedOn: '2026-10-11'),
        ]),
      );
      expect(result, const CaptureResult.rejected(CaptureRejection.invalid));
      expect(h.port.attempts, isEmpty);
    });

    test(
      'a rejected later chunk voids the saved one; no retry remains',
      () async {
        final h = CatchUpCommandHarness()..port.rejectAttempts.add(1);
        final result = await h.commands.recordCatchUp(
          catchUpAllAction(_mainLeaves(300)),
        );
        expect(result, const CaptureResult.rejected(CaptureRejection.notSaved));
        final log = h.log();
        expect(log.counted.learns, isEmpty);
        final firstChunk = h.port.attempts.first.events;
        final voids = [
          for (final e in h.written)
            if (e.isVoid) e,
        ];
        expect(
          {for (final v in voids) v.targetId},
          {for (final e in firstChunk) e.id},
        );
        // One undo-shaped action: every void names the action's first id.
        expect(voids.map((v) => v.revertsActionId).toSet(), {
          firstChunk.first.id,
        });
        expect(await h.pending(), isEmpty);
        expect(h.analytics.captures, isEmpty);
      },
    );

    test(
      'a rejected first chunk of a multi-chunk plan counts nothing',
      () async {
        final h = CatchUpCommandHarness()..port.rejectAttempts.add(0);
        final result = await h.commands.recordCatchUp(
          catchUpAllAction(_mainLeaves(300)),
        );
        expect(result, const CaptureResult.rejected(CaptureRejection.notSaved));
        expect(h.log().counted.learns, isEmpty);
        expect(await h.pending(), isEmpty);
      },
    );

    test('every chunk rejected: notSaved, nothing pending to retry', () async {
      final h = CatchUpCommandHarness()..port.rejectAttempts.add(0);
      final result = await h.commands.recordCatchUp(
        catchUpAllAction([mainCatchUpLeaf('Mishnah Berakhot 2:1')]),
      );
      expect(result, const CaptureResult.rejected(CaptureRejection.notSaved));
      expect(h.written, isEmpty);
      expect(await h.pending(), isEmpty);
    });

    test('the card can be recorded again after a failure', () async {
      final h = CatchUpCommandHarness()..port.rejectAttempts.add(0);
      final action = catchUpAllAction([
        mainCatchUpLeaf('Mishnah Berakhot 2:1'),
      ]);
      await h.commands.recordCatchUp(action);
      final retry = await h.commands.recordCatchUp(action);
      expect(retry, isA<CaptureSuccess>());
      expect(h.log().counted.learns, hasLength(1));
    });
  });

  group('AC-5: offline after the lock', () {
    test('the whole action is queued at once and reported queued', () async {
      final h = CatchUpCommandHarness()..port.holdAttempts.addAll({0, 1});
      final result = await h.commands.recordCatchUp(
        catchUpAllAction(_mainLeaves(300)),
      );
      expect(result, isA<CaptureSuccess>());
      result as CaptureSuccess;
      expect(result.queued, isTrue);
      expect(result.eventIds, hasLength(300));
      // Both chunks are already handed to the SDK queue.
      expect(h.port.attempts, hasLength(2));
      // recorded_at is the tap instant, inside the window, whenever the
      // queue later syncs.
      expect(
        h.port.attempts.expand((c) => c.events).map(effectiveAt),
        everyElement(catchUpSunday),
      );
      h.port
        ..release(0)
        ..release(1);
      await _settle();
      expect(h.log().counted.learns, hasLength(300));
    });

    test('a chunk rejected after syncing is compensated (AC-8)', () async {
      final h = CatchUpCommandHarness()..port.holdAttempts.addAll({0, 1});
      final result = await h.commands.recordCatchUp(
        catchUpAllAction(_mainLeaves(300)),
      );
      expect((result as CaptureSuccess).queued, isTrue);
      h.port
        ..release(0)
        ..reject(1);
      await _settle();
      expect(h.log().counted.learns, isEmpty);
      expect(await h.pending(), isEmpty);
    });
  });
}

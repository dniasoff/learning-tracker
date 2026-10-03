/// DNI-514 T1: every undo command result maps to one [UndoResult], the
/// classification the Change history shows (AC-1, AC-3, AC-8, AC-9).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/undo_result.dart';

import '../../../../helpers/learner_state_fixtures.dart';

const _rav = Actor(uid: 'rav', role: ActorRole.tutor, displayName: 'Rav Cohen');
const _deadline = ChangedFieldKey('goals', 'g', 'target_date');
const _goalType = ChangedFieldKey('goals', 'g', 'goal_type');
const _order = ChangedFieldKey('track_learning_order', 'o1', 'user_sort_order');

void main() {
  test('a write is applied; changed-since fields make it partial', () {
    final full = UndoResult.of(
      const CaptureResult.success(changeIds: [ulidB], actionId: ulidB),
    );
    expect(full, isA<UndoApplied>());
    expect((full as UndoApplied).isPartial, isFalse);
    expect(full.actionId, ulidB);
    expect(full.writtenIds, [ulidB]);

    final partial = UndoResult.of(
      const CaptureResult.success(
        changeIds: [ulidB],
        actionId: ulidB,
        queued: true,
        changedSince: [ChangedSinceField(_deadline, _rav)],
      ),
    );
    expect((partial as UndoApplied).isPartial, isTrue);
    expect(partial.queued, isTrue);
    expect(partial.changedSince.single.changedBy, _rav);
  });

  test('an event undo is applied with the events it wrote', () {
    final r = UndoResult.of(
      const CaptureResult.success(eventIds: [ulidC, ulidD]),
    );
    expect((r as UndoApplied).writtenIds, [ulidC, ulidD]);
    expect(r.actionId, isNull);
  });

  test('a success that wrote nothing is "nothing to undo", with why', () {
    final r = UndoResult.of(
      const CaptureResult.success(
        changedSince: [ChangedSinceField(_deadline, _rav)],
      ),
    );
    expect(r, isA<UndoNothingToUndo>());
    expect((r as UndoNothingToUndo).changedSince.single.key, _deadline);
  });

  test('online required, locked, not saved and refusals', () {
    expect(
      UndoResult.of(const CaptureResult.onlineRequired()),
      isA<UndoOnlineRequired>(),
    );
    final window = LockWindow(t0, t1);
    expect(
      (UndoResult.of(CaptureResult.locked(window)) as UndoLocked).window,
      window,
    );
    expect(
      UndoResult.of(const CaptureResult.rejected(CaptureRejection.notSaved)),
      isA<UndoNotSaved>(),
    );
    for (final reason in [
      CaptureRejection.undoIsFinal,
      CaptureRejection.undoNotOffered,
      CaptureRejection.lockIgnoredTarget,
      CaptureRejection.targetNotFound,
      CaptureRejection.invalid,
    ]) {
      final r = UndoResult.of(CaptureResult.rejected(reason));
      expect((r as UndoRefused).reason, reason);
    }
    expect(
      (UndoResult.of(const CaptureResult.childLimit()) as UndoRefused).reason,
      CaptureRejection.undoNotOffered,
    );
  });

  test('changed-since fields group by actor in first-seen order', () {
    final grouped = changedSinceByActor(const [
      ChangedSinceField(_deadline, _rav),
      ChangedSinceField(_order, parentActor),
      ChangedSinceField(_goalType, _rav),
      ChangedSinceField(_deadline, _rav),
    ]);
    expect(grouped.map((g) => g.$1), [_rav, parentActor]);
    expect(grouped.map((g) => g.$2), [
      [_deadline, _goalType],
      [_order],
    ]);
  });
}

// Mirror test for
// `lib/features/learning/domain/commands/capture_result.dart`
// (C0, DNI-524 AC-6: exhaustive switch over CaptureResult).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';

import '../../../../helpers/learner_state_fixtures.dart';

/// Exhaustive: adding a CaptureResult subtype breaks this switch at
/// compile time.
String describe(CaptureResult r) => switch (r) {
  CaptureSuccess(:final eventIds, :final queued) =>
    'success ${eventIds.length} queued=$queued',
  CaptureLocked() => 'locked',
  CaptureChildLimit() => 'childLimit',
  CaptureOnlineRequired() => 'onlineRequired',
  CaptureRejected(:final reason) => 'rejected ${reason.name}',
};

void main() {
  final lock = LockWindow(t0, t1);

  test('the redirecting factories build each subtype', () {
    expect(describe(const CaptureResult.success()), 'success 0 queued=false');
    expect(
      describe(const CaptureResult.success(eventIds: [ulidA], queued: true)),
      'success 1 queued=true',
    );
    expect(describe(CaptureResult.locked(lock)), 'locked');
    expect(describe(const CaptureResult.childLimit()), 'childLimit');
    expect(describe(const CaptureResult.onlineRequired()), 'onlineRequired');
    expect(
      describe(const CaptureResult.rejected(CaptureRejection.undoIsFinal)),
      'rejected undoIsFinal',
    );
  });

  test('success defaults are empty and unqueued', () {
    const s = CaptureSuccess();
    expect(s.eventIds, isEmpty);
    expect(s.changeIds, isEmpty);
    expect(s.actionId, isNull);
    expect(s.queued, isFalse);
    expect(s.changedSince, isEmpty);
    expect(s.rejectedEventIds, isEmpty);
  });

  test('results compare by value', () {
    const changed = ChangedSinceField(
      ChangedFieldKey('profile_programs', 'mishnayos', 'rate'),
      parentActor,
    );
    expect(
      const CaptureResult.success(
        eventIds: [ulidA],
        changeIds: [ulidD],
        actionId: ulidD,
        changedSince: [changed],
      ),
      const CaptureSuccess(
        eventIds: [ulidA],
        changeIds: [ulidD],
        actionId: ulidD,
        changedSince: [changed],
      ),
    );
    expect(
      const CaptureResult.success(eventIds: [ulidA]),
      isNot(const CaptureResult.success(eventIds: [ulidB])),
    );
    expect(
      const CaptureResult.success(eventIds: [ulidA], rejectedEventIds: [ulidB]),
      const CaptureSuccess(eventIds: [ulidA], rejectedEventIds: [ulidB]),
    );
    expect(
      const CaptureResult.success(eventIds: [ulidA], rejectedEventIds: [ulidB]),
      isNot(const CaptureResult.success(eventIds: [ulidA])),
    );
    expect(CaptureResult.locked(lock), CaptureLocked(LockWindow(t0, t1)));
    expect(
      const CaptureResult.rejected(CaptureRejection.invalid),
      isNot(const CaptureResult.rejected(CaptureRejection.targetNotFound)),
    );
    expect(const CaptureResult.childLimit(), const CaptureChildLimit());
  });

  test('PendingFailure compares by value', () {
    const f = PendingFailure(
      id: 'p1',
      eventIds: [ulidA],
      changeIds: [],
      reason: PendingFailureReason.permissionDenied,
    );
    expect(
      f,
      const PendingFailure(
        id: 'p1',
        eventIds: [ulidA],
        changeIds: [],
        reason: PendingFailureReason.permissionDenied,
      ),
    );
  });
}

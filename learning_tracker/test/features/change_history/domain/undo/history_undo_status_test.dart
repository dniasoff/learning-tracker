/// DNI-514 T3: a history row's Undo status comes only from the persisted
/// `reverts_action_id` relation (AC-1, AC-2, AC-6, AC-7, AC-8).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/change_history/domain/undo/history_undo_status.dart';

import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state_fixtures.dart';

ChangeLogEntry _entry(
  String id, {
  String? actionId,
  String? reverts,
  GovernedEntity entity = GovernedEntity.goal,
  Map<String, Object?>? before,
  Map<String, Object?>? after,
}) => ChangeLogEntry(
  id: id,
  entity: entity,
  entityId: entity == GovernedEntity.learnerSettings ? profileUlid : 'g',
  actionId: actionId ?? id,
  revertsActionId: reverts,
  before: before ?? {'goals/g.target_date': '2027-07-01'},
  after: after ?? {'goals/g.target_date': '2027-06-01'},
  at: t0,
  actor: parentActor,
);

LearningEvent _undoVoid(int id, int target, String reverts) =>
    LearningEvent.voidOf(
      id: engineUlid(id),
      targetId: engineUlid(target),
      recordedAt: engineAt(5),
      actor: parentActor,
      revertsActionId: reverts,
    );

bool _never(String _) => false;

void main() {
  group('governed rows', () {
    test('an action nothing reverts offers Undo', () {
      final a = _entry(ulidA);
      expect(
        HistoryUndoIndex(entries: [a]).governed([a]),
        HistoryUndoStatus.offered,
      );
    });

    test('an action an entry reverts is Undone on every device, and the '
        'revert itself is final', () {
      final a = _entry(ulidA);
      final undo = _entry(ulidB, reverts: ulidA);
      final index = HistoryUndoIndex(entries: [a, undo]);
      expect(index.isReverted(ulidA), isTrue);
      expect(index.governed([a]), HistoryUndoStatus.undone);
      expect(index.governed([undo]), HistoryUndoStatus.revert);
    });

    test('every member of a multi-entity action shares its status', () {
      final a1 = _entry(ulidA);
      final a2 = _entry(
        ulidB,
        actionId: ulidA,
        entity: GovernedEntity.mainTrackStudyDays,
      );
      final undo = _entry(ulidC, reverts: ulidA);
      expect(
        HistoryUndoIndex(entries: [undo]).governed([a1, a2]),
        HistoryUndoStatus.undone,
      );
    });

    test('a learnerSettings seed (before all-null) offers no Undo; a later '
        'settings change does', () {
      final seed = _entry(
        ulidA,
        entity: GovernedEntity.learnerSettings,
        before: {'learner_profiles/$profileUlid.time_zone': null},
        after: {'learner_profiles/$profileUlid.time_zone': 'UTC'},
      );
      final later = _entry(
        ulidB,
        entity: GovernedEntity.learnerSettings,
        before: {'learner_profiles/$profileUlid.time_zone': 'UTC'},
        after: {'learner_profiles/$profileUlid.time_zone': 'Asia/Jerusalem'},
      );
      final index = HistoryUndoIndex(entries: [seed, later]);
      expect(HistoryUndoIndex.isSettingsSeed(seed), isTrue);
      expect(index.governed([seed]), HistoryUndoStatus.notOffered);
      expect(index.governed([later]), HistoryUndoStatus.offered);
    });

    test('an action over 10 docs of one entity needs a connection', () {
      ChangeLogEntry order(int docs) => _entry(
        ulidA,
        entity: GovernedEntity.mainTrackOrder,
        before: {
          for (var i = 0; i < docs; i++)
            'track_learning_order/o$i.user_sort_order': i,
        },
        after: {
          for (var i = 0; i < docs; i++)
            'track_learning_order/o$i.user_sort_order': i + 1,
        },
      );
      expect(HistoryUndoIndex.needsOnline([order(10)]), isFalse);
      expect(HistoryUndoIndex.needsOnline([order(11)]), isTrue);
    });
  });

  group('learning capture rows', () {
    final capture = [
      engineLearn(3, 'Mishnah Berakhot 1:3'),
      engineLearn(1, 'Mishnah Berakhot 1:1'),
      engineLearn(2, 'Mishnah Berakhot 1:2'),
    ];

    test('the undo id is the first (lowest) event id', () {
      expect(HistoryUndoIndex.captureUndoId(capture), engineUlid(1));
    });

    test('a capture offers Undo until a void reverts its first event id; '
        'then it is Undone and those voids are final', () {
      expect(
        HistoryUndoIndex(
          events: capture,
        ).capture(capture, isLockIgnored: _never),
        HistoryUndoStatus.offered,
      );
      final voids = [
        for (var i = 1; i <= 3; i++) _undoVoid(10 + i, i, engineUlid(1)),
      ];
      final index = HistoryUndoIndex(events: [...capture, ...voids]);
      expect(
        index.capture(capture, isLockIgnored: _never),
        HistoryUndoStatus.undone,
      );
      expect(
        index.capture(voids, isLockIgnored: _never),
        HistoryUndoStatus.revert,
      );
    });

    test('a lock-ignored capture offers no Undo; one counted member is '
        'enough to offer it', () {
      final index = HistoryUndoIndex(events: capture);
      expect(
        index.capture(capture, isLockIgnored: (_) => true),
        HistoryUndoStatus.notOffered,
      );
      expect(
        index.capture(capture, isLockIgnored: (id) => id != engineUlid(2)),
        HistoryUndoStatus.offered,
      );
    });

    test('an ordinary void (not an undo) offers Undo', () {
      final v = engineVoid(9, 1);
      expect(
        HistoryUndoIndex(events: [v]).capture([v], isLockIgnored: _never),
        HistoryUndoStatus.offered,
      );
    });
  });
}

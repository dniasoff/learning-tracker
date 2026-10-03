/// DNI-513 AC-2 / E-1: the merged history items — one per `action_id`
/// (AD-38) and one per learning capture — their identity, sort instant,
/// actor and the stable tie order between them.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/change_history/domain/models/history_item.dart';

import '../../../../helpers/change_history_fixtures.dart';

void main() {
  group('GovernedActionItem', () {
    test('orders its entries by id and names the action by the entry whose '
        'id is the action id', () {
      final item = GovernedActionItem(historyId(1), [
        historyEntry(3, minutes: 5, actionOf: 1, actor: historyTutor),
        historyEntry(1, minutes: 5, entity: GovernedEntity.mainTrack),
        historyEntry(2, minutes: 7, actionOf: 1, actor: historyTutor),
      ]);
      expect(item.entries.map((e) => e.id), [
        historyId(1),
        historyId(2),
        historyId(3),
      ]);
      expect(item.primary.id, historyId(1));
      expect(item.primary.entity, GovernedEntity.mainTrack);
      expect(item.actor, historyParent, reason: 'the primary entry acted');
      expect(item.key, 'action:${historyId(1)}');
      expect(item.sortAt, historyAt(7), reason: 'its newest entry');
      expect(item.sourceRank, 0);
      expect(item.revertsActionId, isNull);
    });

    test('without its first entry loaded, the smallest loaded id names '
        'it', () {
      final item = GovernedActionItem(historyId(1), [
        historyEntry(3, minutes: 5, actionOf: 1),
        historyEntry(2, minutes: 5, actionOf: 1),
      ]);
      expect(item.primary.id, historyId(2));
    });

    test('an undo exposes the action it reverts', () {
      final item = GovernedActionItem(historyId(9), [
        historyEntry(9, minutes: 50, reverts: 4),
      ]);
      expect(item.revertsActionId, historyId(4));
    });

    test('an imported action sorts by original_at, not the day it was '
        'written', () {
      final imported = historyEntry(1, minutes: 9000, originalMinutes: 10);
      expect(changeAt(imported), historyAt(10));
      expect(changeAt(historyEntry(2, minutes: 30)), historyAt(30));
      final item = GovernedActionItem(historyId(1), [imported]);
      expect(item.sortAt, historyAt(10));
      final learning = LearningBatchItem([historyLearn(3, minutes: 20)]);
      expect([item, learning]..sort(compareHistoryItems), [
        learning,
        item,
      ], reason: 'learning at minute 20 is newer than the change it imports');
    });

    test('an empty action is refused', () {
      expect(
        () => GovernedActionItem(historyId(1), const []),
        throwsArgumentError,
      );
    });
  });

  group('LearningBatchItem', () {
    test('sorts by original_recorded_at ?? recorded_at and keys by its '
        'capture', () {
      final item = LearningBatchItem([
        historyLearn(2, minutes: 60, originalMinutes: 10),
        historyLearn(1, minutes: 60, originalMinutes: 10),
      ]);
      expect(item.events.map((e) => e.id), [historyId(1), historyId(2)]);
      expect(item.sortAt, historyAt(10));
      expect(item.isLearn, isTrue);
      expect(item.actor, historyParent);
      expect(item.sourceRank, 1);
      expect(item.key, 'events:${historyId(1)}', reason: 'its first event');
    });

    test('a replacement or re-issue shares its target\'s fields and '
        'effective instant, but not its command, so it is another batch', () {
      final capture = historyLearn(1, minutes: 10);
      final sameCommand = historyLearn(2, minutes: 10);
      // A correction at minute 40 keeps the capture's instant (AD-31).
      final replacement = historyLearn(3, minutes: 40, originalMinutes: 10);
      expect(
        LearningBatchItem.batchKeyOf(replacement),
        LearningBatchItem.batchKeyOf(capture),
        reason: 'the visible fields alone cannot tell them apart',
      );
      expect(LearningBatchItem.sameBatch(capture, sameCommand), isTrue);
      expect(LearningBatchItem.sameBatch(capture, replacement), isFalse);
      expect(
        LearningBatchItem.sameBatch(
          capture,
          historyLearn(4, minutes: 10, actor: historyTutor),
        ),
        isFalse,
        reason: 'another actor is another command',
      );
    });

    test('events of different captures key apart', () {
      final a = historyLearn(1, minutes: 10);
      expect(
        LearningBatchItem.batchKeyOf(a),
        LearningBatchItem.batchKeyOf(historyLearn(2, minutes: 10)),
      );
      for (final other in [
        historyLearn(2, minutes: 11),
        historyLearn(2, minutes: 10, actor: historyTutor),
        historyLearn(2, minutes: 10, source: historyId(77)),
        historyLearn(2, minutes: 10, dateState: DateState.catchUp),
        historyLearn(2, minutes: 10, learnedOn: '2026-08-31'),
        historyVoid(2, target: 1, minutes: 10),
      ]) {
        expect(
          LearningBatchItem.batchKeyOf(other),
          isNot(LearningBatchItem.batchKeyOf(a)),
          reason: other.toString(),
        );
      }
    });

    test('a void batch is not learning', () {
      expect(
        LearningBatchItem([historyVoid(2, target: 1, minutes: 10)]).isLearn,
        isFalse,
      );
    });

    test('an empty batch is refused', () {
      expect(() => LearningBatchItem(const []), throwsArgumentError);
    });
  });

  test('compareHistoryItems: newest first, governed before learning at '
      'the same instant, then key descending', () {
    final newer = LearningBatchItem([historyLearn(5, minutes: 20)]);
    final learning = LearningBatchItem([historyLearn(4, minutes: 10)]);
    final governedLow = GovernedActionItem(historyId(1), [
      historyEntry(1, minutes: 10),
    ]);
    final governedHigh = GovernedActionItem(historyId(2), [
      historyEntry(2, minutes: 10),
    ]);
    final sorted = [learning, governedLow, newer, governedHigh]
      ..sort(compareHistoryItems);
    expect(sorted, [newer, governedHigh, governedLow, learning]);
  });
}

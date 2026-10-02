/// DNI-513 AC-2 and E-1: the client merge of the two history sources —
/// newest first, stable tie order, one row per `action_id`, no item lost
/// or duplicated across a page boundary, independent cursors, and the
/// next page of a source read only when the merged list reaches it.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/history_page.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/change_history/domain/models/history_item.dart';
import 'package:learning_tracker/features/change_history/domain/services/change_history_merge.dart';
import 'package:learning_tracker/features/change_history/domain/services/change_history_pager.dart';

import '../../../../helpers/change_history_fixtures.dart';
import '../../../../helpers/fake_history_ports.dart';
import '../../../../helpers/learner_state_fixtures.dart';

final _scope = LearnerScope(ownerUid: 'owner-uid', profileId: profileUlid);

bool _never(List<HistoryItem> _) => false;

void main() {
  group('E-1 tie order and page boundaries', () {
    test('equal instants across sources order governed first, then by '
        'key, the same every time', () {
      final buffer = ChangeHistoryBuffer()
        ..addChangeLogPage(
          HistoryPage(
            items: [historyEntry(2, minutes: 10), historyEntry(1, minutes: 10)],
            next: null,
            exhausted: true,
            watermark: historyAt(10),
          ),
        )
        ..addLearningEventPage(
          HistoryPage(
            items: [historyLearn(3, minutes: 10)],
            next: null,
            exhausted: true,
            watermark: historyAt(10),
          ),
        );
      final keys = buffer.visibleItems().map((i) => i.key).toList();
      expect(keys, [
        'action:${historyId(2)}',
        'action:${historyId(1)}',
        startsWith('events:'),
      ]);
      expect(
        ChangeHistoryBuffer().allItems(),
        isEmpty,
        reason: 'a fresh buffer is empty',
      );
    });

    test('an imported entry waits for the frontier to pass its '
        'original_at, then sorts there', () {
      final buffer = ChangeHistoryBuffer()
        ..addChangeLogPage(
          HistoryPage(
            // Written at minute 500, imported from minute 20.
            items: [historyEntry(1, minutes: 500, originalMinutes: 20)],
            next: null,
            exhausted: true,
            watermark: historyAt(500),
          ),
        )
        ..addLearningEventPage(
          HistoryPage(
            items: [historyLearn(3, minutes: 60), historyLearn(5, minutes: 40)],
            next: const HistoryCursor('page-2'),
            exhausted: false,
            watermark: historyAt(40),
          ),
        );
      expect(buffer.visibleItems().map((i) => i.key), [
        startsWith('events:'),
      ], reason: 'an unread event at or below minute 40 may still come');
      buffer.addLearningEventPage(
        HistoryPage(
          items: [historyLearn(4, minutes: 30)],
          next: null,
          exhausted: true,
          watermark: historyAt(30),
        ),
      );
      expect(buffer.visibleItems().map((i) => i.key), [
        startsWith('events:'),
        startsWith('events:'),
        startsWith('events:'),
        'action:${historyId(1)}',
      ]);
    });

    test('an item at a page boundary is neither lost nor duplicated, and '
        'the cursors advance independently', () async {
      // Three entries at the same instant straddle a 2-row page.
      final repo = FakeHistoryPorts(
        entries: [
          historyEntry(1, minutes: 50),
          historyEntry(2, minutes: 50),
          historyEntry(3, minutes: 50),
          historyEntry(4, minutes: 10),
        ],
        events: [for (var n = 0; n < 5; n++) historyLearn(100 + n, minutes: n)],
      );
      final pager = ChangeHistoryPager(
        changeLog: repo.changeLog,
        events: repo.events,
        scope: _scope,
        pageSize: 2,
      );
      await pager.fill((v) => v.isNotEmpty);
      // After page 1 of change_log the two loaded rows at minute 50 are not
      // final yet (one more may sort with them); page 2 makes them final.
      final visible = pager.buffer.visibleItems();
      expect(visible.map((i) => i.key), [
        'action:${historyId(3)}',
        'action:${historyId(2)}',
        'action:${historyId(1)}',
      ]);
      expect(repo.changeLogReads, 2);
      expect(repo.eventReads, 1, reason: 'events bounded by minute 3');

      await pager.fill(_never);
      final all = pager.buffer.visibleItems();
      expect(all, hasLength(4 + 5));
      expect(all.map((i) => i.key).toSet(), hasLength(9));
      final times = all.map((i) => i.sortAt).toList();
      for (var i = 1; i < times.length; i++) {
        expect(times[i].isAfter(times[i - 1]), isFalse);
      }
      expect(pager.buffer.changeLog.exhausted, isTrue);
      expect(pager.buffer.learningEvents.exhausted, isTrue);
    });
  });

  group('AC-2 lazy merge', () {
    test('the next page of a source is read only when the merged list '
        'reaches its end', () async {
      // Governed changes are all newer than every learning event.
      final repo = FakeHistoryPorts(
        entries: [
          for (var n = 1; n <= 250; n++) historyEntry(n, minutes: 10000 + n),
        ],
        events: [
          for (var n = 1; n <= 400; n++) historyLearn(1000 + n, minutes: n),
        ],
      );
      final pager = ChangeHistoryPager(
        changeLog: repo.changeLog,
        events: repo.events,
        scope: _scope,
      );
      await pager.fill((v) => v.length >= 30);
      expect(repo.reads, [('change_log', 0), ('learning_events', 0)]);
      expect(
        pager.buffer.visibleItems(),
        hasLength(99),
        reason: 'the 100th entry is the page boundary',
      );

      await pager.fill((v) => v.length >= 150);
      expect(repo.changeLogReads, 2);
      expect(repo.eventReads, 1, reason: 'events are still below the end');

      await pager.fill(_never);
      expect(repo.changeLogReads, 3);
      expect(repo.eventReads, 5);
      expect(pager.buffer.visibleItems(), hasLength(650));
      expect(
        repo.reads.where((r) => r.$1 == 'learning_events').map((r) => r.$2),
        [0, 100, 200, 300, 400],
      );
    });

    test('change_log entries sharing an action_id are one item, even when '
        'a page splits them', () async {
      final repo = FakeHistoryPorts(
        entries: [
          historyEntry(
            1,
            minutes: 20,
            entity: GovernedEntity.mainTrack,
            entityId: 'mishnayos',
          ),
          historyEntry(
            2,
            minutes: 20,
            entity: GovernedEntity.subTrack,
            actionOf: 1,
          ),
          historyEntry(
            3,
            minutes: 20,
            entity: GovernedEntity.subTrack,
            actionOf: 1,
          ),
          historyEntry(4, minutes: 5),
        ],
      );
      final pager = ChangeHistoryPager(
        changeLog: repo.changeLog,
        events: repo.events,
        scope: _scope,
        pageSize: 2,
      );
      await pager.fill(_never);
      final items = pager.buffer.visibleItems();
      expect(items, hasLength(2));
      final action = items.first as GovernedActionItem;
      expect(action.actionId, historyId(1));
      expect(action.entries.map((e) => e.id), [
        historyId(1),
        historyId(2),
        historyId(3),
      ]);
      expect(action.primary.entity, GovernedEntity.mainTrack);
    });

    test('events order by original_recorded_at ?? recorded_at while the '
        'source pages by recorded_at', () async {
      final repo = FakeHistoryPorts(
        entries: [historyEntry(1, minutes: 30)],
        events: [
          // Re-recorded at minute 60, originally learnt at minute 10.
          historyLearn(2, minutes: 60, originalMinutes: 10),
          historyLearn(3, minutes: 40),
        ],
      );
      final pager = ChangeHistoryPager(
        changeLog: repo.changeLog,
        events: repo.events,
        scope: _scope,
      );
      await pager.fill(_never);
      expect(pager.buffer.visibleItems().map((i) => i.sortAt), [
        historyAt(40),
        historyAt(30),
        historyAt(10),
      ]);
    });
  });
}

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

import '../../../helpers/change_history_fixtures.dart';
import '../../../helpers/fake_history_ports.dart';
import '../../../helpers/learner_state_fixtures.dart';

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

  group('AC-4 an undo whose reverted action is older than the loaded '
      'pages', () {
    // The deadline change (minute 1) sits below 150 newer entries; its
    // undo (minute 1000) is on the first page.
    ChangeLogEntry deadline() => historyEntry(
      1,
      minutes: 1,
      actor: historyTutor,
      entityId: 'deadline',
      before: {'goals/deadline.target_date': '2026-10-01'},
      after: {'goals/deadline.target_date': '2026-11-03'},
    );
    ChangeLogEntry undo() => historyEntry(
      500,
      minutes: 1000,
      entityId: 'deadline',
      reverts: 1,
      before: {'goals/deadline.target_date': '2026-11-03'},
      after: {'goals/deadline.target_date': '2026-10-01'},
    );
    FakeHistoryPorts repoWithFiller() => FakeHistoryPorts(
      entries: [
        deadline(),
        for (var n = 1; n <= 150; n++) historyEntry(100 + n, minutes: 100 + n),
        undo(),
      ],
    );

    test('the pager reads the reverted action by action_id without paging '
        'down to it, once', () async {
      final repo = repoWithFiller();
      final pager = ChangeHistoryPager(
        changeLog: repo.changeLog,
        events: repo.events,
        scope: _scope,
      );
      await pager.fill((v) => v.isNotEmpty);
      expect(repo.changeLogReads, 1, reason: 'no page read to reach it');
      expect(repo.actionLookups, [
        {historyId(1)},
      ]);
      expect(
        pager.buffer.visibleItems().whereType<GovernedActionItem>().map(
          (i) => i.actionId,
        ),
        isNot(contains(historyId(1))),
        reason: 'a looked-up action is context, not a row',
      );
      expect(pager.buffer.entriesOfAction(historyId(1)).single, deadline());

      await pager.fill((v) => v.isNotEmpty);
      expect(repo.actionLookups, hasLength(1), reason: 'looked up once');
    });

    test('a failed lookup is not a history failure and is retried on the '
        'next fill', () async {
      final repo = repoWithFiller()..failActionLookups = 1;
      final pager = ChangeHistoryPager(
        changeLog: repo.changeLog,
        events: repo.events,
        scope: _scope,
      );
      await pager.fill((v) => v.isNotEmpty);
      expect(pager.buffer.entriesOfAction(historyId(1)), isEmpty);

      await pager.fill((v) => v.isNotEmpty);
      expect(repo.actionLookups, hasLength(2));
      expect(pager.buffer.entriesOfAction(historyId(1)).single, deadline());
    });

    test('no lookup once change_log is read to its end', () async {
      final repo = FakeHistoryPorts(entries: [deadline(), undo()]);
      final pager = ChangeHistoryPager(
        changeLog: repo.changeLog,
        events: repo.events,
        scope: _scope,
      );
      await pager.fill(_never);
      expect(repo.actionLookups, isEmpty);
    });
  });

  group('AC-9 failure and retry', () {
    test('a failed page keeps what was loaded and retries the same page '
        'without duplicating rows', () async {
      final repo = FakeHistoryPorts(
        entries: [for (var n = 1; n <= 5; n++) historyEntry(n, minutes: n)],
        events: [for (var n = 1; n <= 3; n++) historyLearn(10 + n, minutes: n)],
      );
      final pager = ChangeHistoryPager(
        changeLog: repo.changeLog,
        events: repo.events,
        scope: _scope,
        pageSize: 2,
      );
      await pager.fill((v) => v.isNotEmpty);
      final before = pager.buffer.visibleItems().map((i) => i.key).toList();
      repo.failChangeLogReads = 1;
      await expectLater(
        pager.fill(_never),
        throwsA(isA<FakeHistoryReadFailure>()),
      );
      expect(
        pager.buffer.visibleItems().map((i) => i.key).take(before.length),
        before,
      );
      await pager.fill(_never);
      final keys = pager.buffer.visibleItems().map((i) => i.key).toList();
      expect(keys, hasLength(8));
      expect(keys.toSet(), hasLength(8));
    });

    test(
      'a void whose target is on an unread page is looked up by id',
      () async {
        final repo = FakeHistoryPorts(
          events: [
            historyVoid(9, target: 1, minutes: 100),
            for (var n = 1; n <= 4; n++) historyLearn(n, minutes: n),
          ],
        );
        final pager = ChangeHistoryPager(
          changeLog: repo.changeLog,
          events: repo.events,
          scope: _scope,
          pageSize: 2,
        );
        await pager.fill((v) => v.isNotEmpty);
        expect(repo.lookups.single, {historyId(1)});
        expect(
          pager.buffer.eventById(historyId(1))?.ref,
          'Mishnah Berakhot 1:1',
        );
      },
    );
  });
}

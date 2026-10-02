/// DNI-513 AC-4 and AC-9 in the pager: the action an undo reverts and the
/// target of a void are read by id when they sit below the loaded pages
/// (once, and again after a failed lookup), and a failed page keeps what
/// was loaded and is retried without duplicating rows.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/change_history/domain/models/history_item.dart';
import 'package:learning_tracker/features/change_history/domain/services/change_history_pager.dart';

import '../../../../helpers/change_history_fixtures.dart';
import '../../../../helpers/fake_history_ports.dart';
import '../../../../helpers/learner_state_fixtures.dart';

final _scope = LearnerScope(ownerUid: 'owner-uid', profileId: profileUlid);

bool _never(List<HistoryItem> _) => false;

void main() {
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

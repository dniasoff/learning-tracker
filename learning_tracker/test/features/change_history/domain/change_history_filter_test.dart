/// DNI-513 AC-8: the four client filters over paged, mixed history, and
/// paging that continues until the filtered view is full or both sources
/// are exhausted.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/change_history/domain/models/change_history_filter.dart';
import 'package:learning_tracker/features/change_history/domain/models/history_item.dart';
import 'package:learning_tracker/features/change_history/domain/services/change_history_pager.dart';

import '../../../helpers/change_history_fixtures.dart';
import '../../../helpers/fake_change_history_repository.dart';
import '../../../helpers/learner_state_fixtures.dart';

final _scope = LearnerScope(ownerUid: 'owner-uid', profileId: profileUlid);

void main() {
  test('each chip keeps exactly its rows', () {
    final items = <HistoryItem>[
      GovernedActionItem(historyId(1), [
        historyEntry(1, minutes: 6, actor: historyTutor),
      ]),
      GovernedActionItem(historyId(2), [
        historyEntry(2, minutes: 5, actor: historyParent),
      ]),
      GovernedActionItem(historyId(3), [
        historyEntry(3, minutes: 4, actor: historyChild),
      ]),
      LearningBatchItem([historyLearn(4, minutes: 3, actor: historyTutor)]),
      LearningBatchItem([historyLearn(5, minutes: 2, actor: historyParent)]),
      LearningBatchItem([historyLearn(6, minutes: 1, actor: historyChild)]),
    ];
    List<int> kept(ChangeHistoryFilter f) => [
      for (var i = 0; i < items.length; i++)
        if (f.acceptsItem(items[i])) i,
    ];
    expect(kept(ChangeHistoryFilter.all), [0, 1, 2, 3, 4, 5]);
    expect(kept(ChangeHistoryFilter.tutor), [0]);
    expect(kept(ChangeHistoryFilter.parent), [1, 2]);
    expect(kept(ChangeHistoryFilter.learning), [3, 4, 5]);
    expect(
      ChangeHistoryFilter.parent.accepts(
        isLearning: false,
        role: ActorRole.child,
      ),
      isTrue,
    );
  });

  test('a filter with few rows keeps loading pages until its view is '
      'full', () async {
    // 150 newer parent changes hide the 5 tutor changes on page 2.
    final repo = FakeChangeHistoryRepository(
      entries: [
        for (var n = 1; n <= 5; n++)
          historyEntry(n, minutes: n, actor: historyTutor),
        for (var n = 6; n <= 155; n++) historyEntry(n, minutes: 100 + n),
      ],
      events: [for (var n = 1; n <= 3; n++) historyLearn(500 + n, minutes: n)],
    );
    final pager = ChangeHistoryPager(repository: repo, scope: _scope);
    int tutorRows(List<HistoryItem> v) =>
        v.where(ChangeHistoryFilter.tutor.acceptsItem).length;

    await pager.fill((v) => tutorRows(v) >= 3);
    expect(tutorRows(pager.buffer.visibleItems()), 5);
    expect(repo.changeLogReads, 2);
  });

  test('a filter that matches nothing reads both sources to the end, then '
      'stops', () async {
    final repo = FakeChangeHistoryRepository(
      entries: [for (var n = 1; n <= 230; n++) historyEntry(n, minutes: n)],
    );
    final pager = ChangeHistoryPager(repository: repo, scope: _scope);
    await pager.fill(
      (v) => v.where(ChangeHistoryFilter.learning.acceptsItem).length >= 10,
    );
    expect(pager.buffer.exhausted, isTrue);
    expect(repo.changeLogReads, 3);
    expect(repo.eventReads, 1);
    expect(
      pager.buffer.visibleItems().where(
        ChangeHistoryFilter.learning.acceptsItem,
      ),
      isEmpty,
    );
  });
}

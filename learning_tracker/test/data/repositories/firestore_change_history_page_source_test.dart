/// DNI-513 AC-2 and AC-7 at the repository level:
/// the C0 history reads — `FirestoreChangeLogRepository.historyPage` and
/// `FirestoreLearningEventRepository.historyPage` — read `change_log` and
/// `learning_events` independently, newest first, at most 100 per page,
/// skips (and reports) a malformed document without losing the page, adds
/// no Firestore index, and keeps both of two concurrent governed changes
/// while the doc holds the later commit.
library;

import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/repositories/firestore_change_log_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_learning_event_repository.dart';
import 'package:learning_tracker/data/repositories/learner_state_firestore_values.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/change_log_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/history_page.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';

import '../../helpers/change_history_fixtures.dart';
import '../../helpers/learner_state_fixtures.dart';

final _scope = LearnerScope(ownerUid: 'owner-uid', profileId: profileUlid);

String get _base =>
    'users/${_scope.ownerUid}/learner_profiles/${_scope.profileId}';

Future<void> _seedEntries(
  FirebaseFirestore db,
  Iterable<ChangeLogEntry> entries,
) async {
  for (final e in entries) {
    await db
        .collection('$_base/change_log')
        .doc(e.id)
        .set(toFirestoreMap(e.toStorage()));
  }
}

Future<void> _seedEvents(
  FirebaseFirestore db,
  Iterable<LearningEvent> events,
) async {
  for (final e in events) {
    await db
        .collection('$_base/learning_events')
        .doc(e.id)
        .set(toFirestoreMap(e.toStorage()));
  }
}

/// Every page of a source until it is exhausted.
Future<List<HistoryPage<T>>> _drain<T>(
  Future<HistoryPage<T>> Function(HistoryCursor? after) read,
) async {
  final pages = <HistoryPage<T>>[];
  HistoryCursor? after;
  while (true) {
    final page = await read(after);
    pages.add(page);
    if (page.exhausted) return pages;
    after = page.next;
  }
}

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreChangeLogRepository changeLog;
  late FirestoreLearningEventRepository events;

  setUp(() {
    db = FakeFirebaseFirestore();
    changeLog = FirestoreChangeLogRepository(firestore: db);
    events = FirestoreLearningEventRepository(firestore: db);
  });

  group('AC-2 independent 100-row pages, newest first', () {
    test('250 change_log entries page 100 / 100 / 50 by `at` desc', () async {
      // Ids and times deliberately disagree, so ordering by id would fail.
      await _seedEntries(db, [
        for (var n = 1; n <= 250; n++) historyEntry(n, minutes: (n * 37) % 251),
      ]);
      final pages = await _drain(
        (after) => changeLog.historyPage(_scope, after: after),
      );
      expect(pages.map((p) => p.items.length), [100, 100, 50]);
      expect(pages.map((p) => p.exhausted), [false, false, true]);
      final all = [for (final p in pages) ...p.items];
      expect(all.map((e) => e.id).toSet(), hasLength(250));
      for (var i = 1; i < all.length; i++) {
        expect(
          all[i].at.isAfter(all[i - 1].at),
          isFalse,
          reason: 'newest first',
        );
      }
      for (final page in pages) {
        expect(page.watermark, page.items.last.at);
      }
    });

    test(
      '400 learning events page by `recorded_at` desc, 100 at a time',
      () async {
        await _seedEvents(db, [
          for (var n = 1; n <= 400; n++)
            historyLearn(n, minutes: (n * 53) % 401),
        ]);
        final pages = await _drain(
          (after) => events.historyPage(_scope, after: after),
        );
        expect(pages.map((p) => p.items.length), [100, 100, 100, 100, 0]);
        expect(pages.last.exhausted, isTrue);
        expect(pages.last.next, isNull);
        expect(pages.last.watermark, isNull);
        final all = [for (final p in pages) ...p.items];
        expect(all.map((e) => e.id).toSet(), hasLength(400));
        final times = all.map(effectiveAt).toList();
        for (var i = 1; i < times.length; i++) {
          expect(times[i].isAfter(times[i - 1]), isFalse);
        }
      },
    );

    test('each source keeps its own cursor', () async {
      await _seedEntries(db, [
        for (var n = 1; n <= 120; n++) historyEntry(n, minutes: n),
      ]);
      await _seedEvents(db, [
        for (var n = 1; n <= 30; n++) historyLearn(1000 + n, minutes: n),
      ]);
      final log1 = await changeLog.historyPage(_scope);
      final learning = await events.historyPage(_scope);
      final log2 = await changeLog.historyPage(_scope, after: log1.next);
      expect(learning.exhausted, isTrue);
      expect(learning.items, hasLength(30));
      expect(log1.exhausted, isFalse);
      expect(log2.items, hasLength(20));
      expect(log2.exhausted, isTrue);
      expect({
        ...log1.items.map((e) => e.id),
        ...log2.items.map((e) => e.id),
      }, hasLength(120));
    });

    test('a page larger than 100 is refused', () {
      expect(
        () => changeLog.historyPage(_scope, limit: 101),
        throwsArgumentError,
      );
    });
  });

  group('E-2 malformed documents', () {
    test('are skipped and reported; the page and cursor advance', () async {
      await _seedEntries(db, [
        for (var n = 1; n <= 5; n++) historyEntry(n, minutes: n * 10),
      ]);
      // A row with an unknown entity, newest of all.
      await db.collection('$_base/change_log').doc(historyId(99)).set({
        'entity': 'nonsense',
        'at': Timestamp.fromDate(historyAt(1000)),
      });
      final page = await changeLog.historyPage(_scope, limit: 3);
      expect(page.items.map((e) => e.id), [historyId(5), historyId(4)]);
      expect(page.rejected.single.docId, historyId(99));
      expect(page.watermark, historyAt(40));
      final next = await changeLog.historyPage(
        _scope,
        after: page.next,
        limit: 3,
      );
      expect(next.items.map((e) => e.id), [
        historyId(3),
        historyId(2),
        historyId(1),
      ]);
    });

    test('eventsById returns only stored, decodable events', () async {
      await _seedEvents(db, [historyLearn(1, minutes: 1)]);
      await db.collection('$_base/learning_events').doc(historyId(2)).set({
        'kind': 'bogus',
      });
      final found = await events.eventsById(_scope, {
        historyId(1),
        historyId(2),
        historyId(3),
      });
      expect(found.map((e) => e.id), [historyId(1)]);
    });

    test('the reverted-action lookup is the undo path\'s entriesOfAction: '
        'every entry of the named action only', () async {
      await _seedEntries(db, [
        historyEntry(1, minutes: 1, entity: GovernedEntity.mainTrack),
        historyEntry(
          2,
          minutes: 1,
          entity: GovernedEntity.subTrack,
          actionOf: 1,
        ),
        historyEntry(3, minutes: 2),
      ]);
      expect(
        (await changeLog.entriesOfAction(
          _scope,
          historyId(1),
        )).map((e) => e.id),
        [historyId(1), historyId(2)],
      );
      expect(await changeLog.entriesOfAction(_scope, historyId(9)), isEmpty);
    });
  });

  test('AC-2 / AD-54: no index names change_log or learning_events', () {
    final file = File('firestore.indexes.json').existsSync()
        ? File('firestore.indexes.json')
        : File('learning_tracker/firestore.indexes.json');
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final groups = [
      for (final i in json['indexes'] as List<dynamic>)
        (i as Map<String, dynamic>)['collectionGroup'],
      for (final f in (json['fieldOverrides'] as List<dynamic>? ?? const []))
        (f as Map<String, dynamic>)['collectionGroup'],
    ];
    expect(groups, isNot(contains('change_log')));
    expect(groups, isNot(contains('learning_events')));
  });

  test(
    'AC-7 concurrent parent and tutor changes: both kept, later wins',
    () async {
      const goalId = 'goal_deadline';
      const key = 'goals/$goalId.target_date';
      GovernedBatch batch(int n, Actor actor, String date, int seconds) =>
          GovernedBatch(
            entry: ChangeLogEntry(
              id: historyId(n),
              entity: GovernedEntity.goal,
              entityId: goalId,
              actionId: historyId(n),
              before: const {key: '2027-01-01'},
              after: {key: date},
              at: historyAt(0).add(Duration(seconds: seconds)),
              actor: actor,
            ),
            merges: [
              GovernedDocMerge(
                collection: 'goals',
                docId: goalId,
                fields: {'target_date': date},
              ),
            ],
          );
      // The parent writes first, the tutor a second later.
      await changeLog.commitGoverned(
        _scope,
        batch(1, historyParent, '2027-03-01', 0),
      );
      await changeLog.commitGoverned(
        _scope,
        batch(2, historyTutor, '2027-04-01', 1),
      );

      final page = await changeLog.historyPage(_scope);
      expect(page.items.map((e) => (e.actor, e.at)), [
        (historyTutor, historyAt(0).add(const Duration(seconds: 1))),
        (historyParent, historyAt(0)),
      ]);
      final goal = await db.doc('$_base/goals/$goalId').get();
      expect(goal.data()!['target_date'], '2027-04-01');
    },
  );
}

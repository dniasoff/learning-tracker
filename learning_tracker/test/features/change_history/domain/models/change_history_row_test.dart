/// DNI-513 AC-4 / AC-6 / E-3: when a Change history row may offer Undo
/// (Story 4.6 executes it) — never for an undo, an undone action, a void,
/// a lock-ignored record or a fully removed learning batch.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/change_history/domain/models/change_history_row.dart';

import '../../../../helpers/change_history_fixtures.dart';

final _stamp = HistoryStamp(
  actor: historyTutor,
  at: historyAt(10),
  day: '2026-09-01',
  localTime: DateTime(2026, 8, 31, 20, 10),
);

ChangeHistoryRow _governed({bool isRevert = false, HistoryStamp? undoneBy}) =>
    ChangeHistoryRow(
      key: 'action:a',
      kind: ChangeHistoryRowKind.governed,
      stamp: _stamp,
      summary: GovernedSummary(
        primary: GovernedPart(
          entity: GovernedEntity.goal,
          change: GovernedChangeKind.updated,
          fields: const ['target_date'],
        ),
        others: const [],
      ),
      notifiesParent: true,
      isRevert: isRevert,
      lockIgnored: false,
      eventCount: 1,
      undoneBy: undoneBy,
    );

ChangeHistoryRow _learning({
  LearningEventKind kind = LearningEventKind.learn,
  bool lockIgnored = false,
  int eventCount = 2,
  int voidedCount = 0,
}) => ChangeHistoryRow(
  key: 'events:b',
  kind: ChangeHistoryRowKind.learning,
  stamp: _stamp,
  summary: LearningSummary(
    kind: kind,
    refs: const ['Mishnah Berakhot 1:1', 'Mishnah Berakhot 1:2'],
    source: const MainTrackSource(),
    dateState: DateState.dated,
    learnedOn: '2026-09-01',
  ),
  notifiesParent: false,
  isRevert: false,
  lockIgnored: lockIgnored,
  eventCount: eventCount,
  voidedBy: voidedCount > 0 ? _stamp : null,
  voidedCount: voidedCount,
);

void main() {
  test('a governed change may be undone', () {
    final row = _governed();
    expect(row.canUndo, isTrue);
    expect(row.isLearning, isFalse);
    expect(row.isVoid, isFalse);
  });

  test('an undo (AC-4 "Reverted change") offers no Undo', () {
    expect(_governed(isRevert: true).canUndo, isFalse);
  });

  test('an undone action offers no Undo (undo is final)', () {
    expect(_governed(undoneBy: _stamp).canUndo, isFalse);
  });

  test('a learning record may be undone while any of it is kept', () {
    expect(_learning().canUndo, isTrue);
    expect(_learning(voidedCount: 1).canUndo, isTrue);
    expect(_learning().isLearning, isTrue);
  });

  test('a fully removed learning batch offers no Undo', () {
    expect(_learning(voidedCount: 2).canUndo, isFalse);
  });

  test('a void offers no Undo', () {
    final row = _learning(kind: LearningEventKind.void_);
    expect(row.isVoid, isTrue);
    expect(row.canUndo, isFalse);
  });

  test('AC-6: a lock-ignored record offers no Undo', () {
    expect(_learning(lockIgnored: true).canUndo, isFalse);
  });

  test('summaries copy their lists unmodifiably', () {
    final fields = ['name'];
    final part = GovernedPart(
      entity: GovernedEntity.subTrack,
      change: GovernedChangeKind.renamed,
      fields: fields,
    );
    fields.add('ground');
    expect(part.fields, ['name']);
    expect(() => part.fields.add('x'), throwsUnsupportedError);
  });
}

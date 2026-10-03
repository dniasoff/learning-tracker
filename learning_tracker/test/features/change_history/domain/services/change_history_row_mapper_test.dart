/// DNI-513 AC-3 – AC-6, E-2, E-3: mapping merged history items to rows —
/// actor, learner-time-zone day and time, governed and learning summaries,
/// source names at event time, voids, undo state, the AD-39 bell and the
/// AD-36 lock label.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/history_page.dart';
import 'package:learning_tracker/features/change_history/domain/models/change_history_row.dart';
import 'package:learning_tracker/features/change_history/domain/services/change_history_merge.dart';
import 'package:learning_tracker/features/change_history/domain/services/change_history_row_mapper.dart';

import '../../../../helpers/change_history_fixtures.dart';
import '../../../../helpers/learner_state/lock_fixtures.dart';

final _ny = constantHistory(newYorkNoLocation);

/// Rows of everything in [entries] and [events], both sources exhausted.
List<ChangeHistoryRow> _rows({
  List<ChangeLogEntry> entries = const [],
  List<LearningEvent> events = const [],
  LearnerSettingsHistory? history,
  Map<String, String> names = const {},
}) {
  final buffer = ChangeHistoryBuffer()
    ..addChangeLogPage(
      HistoryPage(items: entries, next: null, exhausted: true, watermark: null),
    )
    ..addLearningEventPage(
      HistoryPage(items: events, next: null, exhausted: true, watermark: null),
    );
  return ChangeHistoryRowMapper(
    settingsHistory: history ?? _ny,
    currentSubTrackNames: names,
  ).map(buffer.visibleItems(), buffer);
}

GovernedSummary _governed(ChangeHistoryRow row) =>
    row.summary as GovernedSummary;

LearningSummary _learning(ChangeHistoryRow row) =>
    row.summary as LearningSummary;

ChangeLogEntry _subTrackEntry(
  int n, {
  required int minutes,
  required String subTrackId,
  required Map<String, Object?> before,
  required Map<String, Object?> after,
  Actor actor = historyTutor,
  int? actionOf,
  int? originalMinutes,
  int? reverts,
}) => historyEntry(
  n,
  minutes: minutes,
  originalMinutes: originalMinutes,
  reverts: reverts,
  entity: GovernedEntity.subTrack,
  entityId: subTrackId,
  actor: actor,
  actionOf: actionOf,
  before: {for (final k in before.keys) 'sub_tracks/$subTrackId.$k': before[k]},
  after: {for (final k in after.keys) 'sub_tracks/$subTrackId.$k': after[k]},
);

void main() {
  group('AC-3 actor, time and day in the learner time zone', () {
    test('a tutor change at 02:00Z is 10 pm on the previous civil day in '
        'New York', () {
      // 2026-09-02T02:00Z = 2026-09-01 22:00 EDT.
      final row = _rows(
        entries: [historyEntry(1, minutes: 24 * 60 + 120, actor: historyTutor)],
      ).single;
      expect(row.stamp.actor, historyTutor);
      expect(row.stamp.actor.role, ActorRole.tutor);
      expect(row.stamp.day, '2026-09-01');
      expect(row.stamp.localTime, DateTime(2026, 9, 1, 22));
      expect(row.kind, ChangeHistoryRowKind.governed);
    });

    test('the deadline change names the field and its new date', () {
      final row = _rows(
        entries: [
          historyEntry(
            1,
            minutes: 0,
            actor: historyTutor,
            entityId: 'deadline',
            before: {'goals/deadline.target_date': '2027-01-01'},
            after: {'goals/deadline.target_date': '2026-11-03'},
          ),
        ],
      ).single;
      final part = _governed(row).primary;
      expect(part.entity, GovernedEntity.goal);
      expect(part.change, GovernedChangeKind.updated);
      expect(part.fields, ['target_date']);
      expect(part.newDate, '2026-11-03');
    });

    test('creating a sub-track names it; a track removal is one row with '
        'its sub-track tombstones', () {
      final sub1 = historyId(7001);
      final sub2 = historyId(7002);
      final rows = _rows(
        entries: [
          _subTrackEntry(
            1,
            minutes: 0,
            subTrackId: sub1,
            // A create writes every set field, the immutable
            // curriculum_id among them (SubTrackCommands.createSubTrack).
            before: {'curriculum_id': null, 'name': null, 'ground': null},
            after: {
              'curriculum_id': 'mishnayos',
              'name': 'Rebbe',
              'ground': ['Mishnah Beitzah 4'],
            },
          ),
          historyEntry(
            2,
            minutes: 60,
            entity: GovernedEntity.mainTrack,
            entityId: 'mishnayos',
            actor: historyParent,
            before: {'curriculum_tracks/mishnayos.ended_at': null},
            after: {'curriculum_tracks/mishnayos.ended_at': historyAt(60)},
          ),
          for (final (n, sub) in [(3, sub1), (4, sub2)])
            _subTrackEntry(
              n,
              minutes: 60,
              subTrackId: sub,
              actor: historyParent,
              actionOf: 2,
              before: {'ended_at': null, 'end_reason': null},
              after: {'ended_at': historyAt(60), 'end_reason': 'track_deleted'},
            ),
        ],
        names: {sub2: 'Chavrusa'},
      );
      expect(rows, hasLength(2));
      final removal = _governed(rows.first);
      expect(removal.primary.entity, GovernedEntity.mainTrack);
      expect(removal.primary.change, GovernedChangeKind.ended);
      expect(removal.others.map((p) => (p.change, p.subjectName)), [
        (GovernedChangeKind.removed, 'Rebbe'),
        (GovernedChangeKind.removed, 'Chavrusa'),
      ]);
      final created = _governed(rows.last).primary;
      expect(created.change, GovernedChangeKind.created);
      expect(created.subjectName, 'Rebbe');
      expect(created.fields, ['curriculum_id', 'ground', 'name']);
    });

    test('setting a field that was unset is an edit, not a create: an '
        "existing sub-track's window_end going from null to a date", () {
      final sub = historyId(7001);
      final part = _governed(
        _rows(
          entries: [
            _subTrackEntry(
              1,
              minutes: 0,
              subTrackId: sub,
              before: {'window_end': null},
              after: {'window_end': '2027-06-30'},
            ),
          ],
          names: {sub: 'Rebbe'},
        ).single,
      ).primary;
      expect(part.change, GovernedChangeKind.updated);
      expect(part.fields, ['window_end']);
      expect(part.subjectName, 'Rebbe');
    });

    test('an all-null before on other entities is an edit unless the entry '
        'wrote curriculum_id', () {
      ChangeHistoryRow row(GovernedEntity entity, Map<String, Object?> after) =>
          _rows(
            entries: [
              historyEntry(
                1,
                minutes: 0,
                entity: entity,
                entityId: 'mishnayos',
                before: {for (final k in after.keys) k: null},
                after: after,
              ),
            ],
          ).single;
      expect(
        _governed(
          row(GovernedEntity.mainTrack, {
            'curriculum_tracks/mishnayos.paused': true,
          }),
        ).primary.change,
        GovernedChangeKind.updated,
      );
      expect(
        _governed(
          row(GovernedEntity.mainTrack, {
            'curriculum_tracks/mishnayos.curriculum_id': 'mishnayos',
            'curriculum_tracks/mishnayos.paused': false,
          }),
        ).primary.change,
        GovernedChangeKind.created,
      );
      expect(
        _governed(
          row(GovernedEntity.learnerSettings, {
            'learner_profiles/mishnayos.time_zone': 'America/New_York',
          }),
        ).primary.change,
        GovernedChangeKind.updated,
        reason: 'a learnerSettings seed is a settings change',
      );
    });

    test('learning rows show the source name at event time, the refs of '
        'one capture and the date state', () {
      final sub = historyId(7001);
      final rows = _rows(
        entries: [
          _subTrackEntry(
            1,
            minutes: 100,
            subTrackId: sub,
            before: {'name': 'Rebbe'},
            after: {'name': 'Rav Cohen shiur'},
          ),
        ],
        events: [
          for (final (n, ref) in [
            (10, 'Mishnah Beitzah 4:1'),
            (11, 'Mishnah Beitzah 4:2'),
            (12, 'Mishnah Beitzah 4:3'),
          ])
            historyLearn(
              n,
              minutes: 50,
              ref: ref,
              source: sub,
              dateState: DateState.catchUp,
              learnedOn: '2026-08-29',
            ),
          historyLearn(20, minutes: 200, source: sub),
        ],
        names: {sub: 'Rav Cohen shiur'},
      );
      expect(rows, hasLength(3));
      final later = _learning(rows[0]);
      expect((later.source! as SubTrackSource).name, 'Rav Cohen shiur');
      final rename = _governed(rows[1]).primary;
      expect(rename.change, GovernedChangeKind.renamed);
      final batch = _learning(rows[2]);
      expect((batch.source! as SubTrackSource).name, 'Rebbe');
      expect(batch.refs, [
        'Mishnah Beitzah 4:1',
        'Mishnah Beitzah 4:2',
        'Mishnah Beitzah 4:3',
      ]);
      expect(batch.dateState, DateState.catchUp);
      expect(batch.learnedOn, '2026-08-29');
      expect(rows[2].eventCount, 3);
      expect(rows[2].canUndo, isTrue);
    });
  });

  group('imported entries take effect at original_at', () {
    test('an imported change is stamped, ordered and undone at its '
        'original instant, not the day it was written', () {
      // Written 2026-09-08 (minute 7 days + 600), imported from
      // 2026-09-01T12:00Z (08:00 in New York).
      final rows = _rows(
        entries: [
          historyEntry(1, minutes: 7 * 24 * 60 + 600, originalMinutes: 720),
          historyEntry(2, minutes: 7 * 24 * 60 + 601, reverts: 1),
        ],
        events: [historyLearn(10, minutes: 24 * 60)],
      );
      expect(rows.map((r) => r.key), [
        'action:${historyId(2)}',
        rows[1].key,
        'action:${historyId(1)}',
      ]);
      expect(rows[1].kind, ChangeHistoryRowKind.learning);
      final imported = rows.last;
      expect(imported.stamp.at, historyAt(720));
      expect(imported.stamp.day, '2026-09-01');
      expect(imported.stamp.localTime, DateTime(2026, 9, 1, 8));
      expect(imported.undoneBy?.at, historyAt(7 * 24 * 60 + 601));
    });

    test('an imported rename names sources by its original instant', () {
      final sub = historyId(7001);
      final rows = _rows(
        entries: [
          // Renamed at minute 100, imported (written) at minute 1000.
          _subTrackEntry(
            1,
            minutes: 1000,
            originalMinutes: 100,
            subTrackId: sub,
            before: {'name': 'Rebbe'},
            after: {'name': 'Rav Cohen shiur'},
          ),
        ],
        events: [
          historyLearn(10, minutes: 50, source: sub),
          historyLearn(11, minutes: 200, source: sub),
        ],
        names: {sub: 'Rav Cohen shiur'},
      );
      String? nameOf(String key) =>
          ((rows.singleWhere((r) => r.key == key).summary as LearningSummary)
                      .source!
                  as SubTrackSource)
              .name;
      final learnRows = [
        for (final r in rows)
          if (r.kind == ChangeHistoryRowKind.learning) r.key,
      ];
      expect(nameOf(learnRows.first), 'Rav Cohen shiur', reason: 'minute 200');
      expect(nameOf(learnRows.last), 'Rebbe', reason: 'minute 50');
    });
  });

  group('E-3 a source is never named with a later name as historical', () {
    final sub = historyId(7001);
    // The sub-track was named "Rebbe" until minute 100 ("Gemara shiur"
    // after), then "Rav Cohen shiur" from minute 500. Only the minute-500
    // rename is on a loaded change_log page (watermark 500); the minute-100
    // one is on an unread page.
    ChangeLogEntry laterRename() => _subTrackEntry(
      2,
      minutes: 500,
      subTrackId: sub,
      before: {'name': 'Gemara shiur'},
      after: {'name': 'Rav Cohen shiur'},
    );

    ChangeHistoryBuffer buffer({
      required List<LearningEvent> events,
      List<ChangeLogEntry> entries = const [],
    }) => ChangeHistoryBuffer()
      ..addChangeLogPage(
        HistoryPage(
          items: [laterRename(), ...entries],
          next: const HistoryCursor(1),
          exhausted: false,
          watermark: historyAt(500),
        ),
      )
      ..addLearningEventPage(
        HistoryPage(
          items: events,
          next: null,
          exhausted: true,
          watermark: null,
        ),
      );

    List<ChangeHistoryRow> rowsOf(
      ChangeHistoryBuffer buffer, {
      Map<String, String> names = const {},
    }) => ChangeHistoryRowMapper(
      settingsHistory: _ny,
      currentSubTrackNames: names,
    ).map(buffer.visibleItems(), buffer);

    test('a void of a record older than the loaded renames names the '
        'source as it was when the record was removed', () {
      final b = buffer(events: [historyVoid(20, target: 1, minutes: 600)])
        ..addLookups([historyLearn(1, minutes: 10, source: sub)]);
      final row = rowsOf(b, names: {sub: 'Rav Cohen shiur'}).single;
      expect(row.isVoid, isTrue);
      expect(
        (_learning(row).source! as SubTrackSource).name,
        'Rav Cohen shiur',
        reason:
            'the minute-500 rename\'s "before" (Gemara shiur) is not the '
            'name at minute 10: an unread rename sits between them',
      );
    });

    test('an undo of an action older than the loaded renames names the '
        'sub-track as it was when undone', () {
      final b =
          buffer(
            events: const [],
            entries: [
              _subTrackEntry(
                30,
                minutes: 700,
                subTrackId: sub,
                actor: historyParent,
                before: {'window_end': '2026-12-01'},
                after: {'window_end': null},
                reverts: 3,
              ),
            ],
          )..addActionLookups([
            _subTrackEntry(
              3,
              minutes: 20,
              subTrackId: sub,
              before: {'window_end': null},
              after: {'window_end': '2026-12-01'},
            ),
          ]);
      final rows = rowsOf(b);
      final undo = rows.firstWhere((r) => r.isRevert);
      expect(_governed(undo).primary.subjectName, 'Rav Cohen shiur');
    });

    test('a visible row with no rename since it takes the name the pages '
        'end on, not a newer live name', () {
      final rows = rowsOf(
        buffer(events: [historyLearn(10, minutes: 600, source: sub)]),
        names: {sub: 'Renamed after the history opened'},
      );
      final learn = rows.firstWhere(
        (r) => r.kind == ChangeHistoryRowKind.learning,
      );
      expect(
        (_learning(learn).source! as SubTrackSource).name,
        'Rav Cohen shiur',
      );
    });

    test('with no rename loaded, a visible row takes the name the history '
        'opened with: no rename since its instant exists', () {
      final rows = _rows(
        events: [historyLearn(10, minutes: 600, source: sub)],
        names: {sub: 'Rav Cohen shiur'},
      );
      expect(
        (_learning(rows.single).source! as SubTrackSource).name,
        'Rav Cohen shiur',
      );
    });

    test('a record older than the sub-track\'s first name has no known '
        'name, never today\'s', () {
      final rows = _rows(
        entries: [
          _subTrackEntry(
            1,
            minutes: 20,
            subTrackId: sub,
            before: {'curriculum_id': null, 'name': null},
            after: {'curriculum_id': 'mishnayos', 'name': 'Rebbe'},
          ),
        ],
        events: [historyLearn(10, minutes: 10, source: sub)],
        names: {sub: 'Rebbe'},
      );
      final learn = rows.firstWhere(
        (r) => r.kind == ChangeHistoryRowKind.learning,
      );
      expect((_learning(learn).source! as SubTrackSource).name, isNull);
    });
  });

  group('E-3 voids stay visible with who and when', () {
    test('the voided learn names its void; the void names what it '
        'removed; neither offers Undo once removed', () {
      final rows = _rows(
        events: [
          historyLearn(1, minutes: 10, actor: historyChild),
          historyVoid(2, target: 1, minutes: 30, actor: historyParent),
        ],
      );
      final voidRow = rows.first;
      expect(voidRow.isVoid, isTrue);
      expect(voidRow.stamp.actor, historyParent);
      expect(_learning(voidRow).refs, ['Mishnah Berakhot 1:1']);
      expect(_learning(voidRow).source, isA<MainTrackSource>());
      expect(voidRow.canUndo, isFalse);

      final learnRow = rows.last;
      expect(learnRow.stamp.actor, historyChild);
      expect(learnRow.voidedBy?.actor, historyParent);
      expect(learnRow.voidedBy?.at, historyAt(30));
      expect(learnRow.voidedCount, 1);
      expect(learnRow.canUndo, isFalse);
    });

    test('a correction reads as a removal and a new record: the corrected '
        'capture is fully removed with no Undo, the replacement is its own '
        'row with Undo', () {
      final rows = _rows(
        events: [
          historyLearn(1, minutes: 10),
          // The correction at minute 40 keeps the capture's instant.
          historyVoid(2, target: 1, minutes: 40),
          historyLearn(
            3,
            minutes: 40,
            originalMinutes: 10,
            ref: 'Mishnah Berakhot 1:2',
          ),
        ],
      );
      expect(rows, hasLength(3));
      final learnRows = rows.where((r) => !r.isVoid).toList();
      final capture = learnRows.singleWhere(
        (r) => _learning(r).refs.single == 'Mishnah Berakhot 1:1',
      );
      expect(capture.eventCount, 1);
      expect(capture.voidedCount, 1);
      expect(capture.canUndo, isFalse);
      final replacement = learnRows.singleWhere(
        (r) => _learning(r).refs.single == 'Mishnah Berakhot 1:2',
      );
      expect(replacement.eventCount, 1);
      expect(replacement.voidedBy, isNull);
      expect(replacement.canUndo, isTrue);
      expect(replacement.key, isNot(capture.key));
    });

    test('an un-learn across sources is one row that names no single '
        'source, and voids each source\'s capture', () {
      final sub = historyId(9001);
      final rows = _rows(
        names: {sub: 'Rebbe'},
        events: [
          historyLearn(1, minutes: 10),
          historyLearn(
            2,
            minutes: 20,
            source: sub,
            ref: 'Mishnah Berakhot 1:2',
            dateState: DateState.catchUp,
          ),
          // One un-learn command voids both.
          historyVoid(3, target: 1, minutes: 40),
          historyVoid(4, target: 2, minutes: 40),
        ],
      );
      expect(rows, hasLength(3));
      final unlearn = rows.first;
      expect(unlearn.isVoid, isTrue);
      expect(unlearn.eventCount, 2);
      expect(_learning(unlearn).refs, [
        'Mishnah Berakhot 1:1',
        'Mishnah Berakhot 1:2',
      ]);
      expect(_learning(unlearn).source, isA<SeveralSources>());
      expect(_learning(unlearn).dateState, isNull, reason: 'not shared');
      expect(_learning(unlearn).learnedOn, '2026-09-01', reason: 'shared');
      for (final capture in rows.skip(1)) {
        expect(capture.voidedCount, 1);
        expect(capture.canUndo, isFalse);
      }

      // A void of one source's learning still names that source.
      final single = _rows(
        names: {sub: 'Rebbe'},
        events: [
          historyLearn(2, minutes: 20, source: sub),
          historyVoid(4, target: 2, minutes: 40),
        ],
      ).first;
      expect((_learning(single).source! as SubTrackSource).name, 'Rebbe');
      expect(_learning(single).dateState, DateState.dated);
    });

    test('a persisted void whose target is another void maps without '
        'crashing, as a generic removal with its own who and when', () {
      final rows = _rows(
        events: [
          historyLearn(1, minutes: 10, actor: historyChild),
          historyVoid(2, target: 1, minutes: 30, actor: historyParent),
          historyVoid(3, target: 2, minutes: 50, actor: historyTutor),
        ],
      );
      expect(rows, hasLength(3));
      final voidOfVoid = rows.first;
      expect(voidOfVoid.isVoid, isTrue);
      expect(_learning(voidOfVoid).refs, isEmpty);
      expect(_learning(voidOfVoid).source, isNull);
      expect(voidOfVoid.stamp.actor, historyTutor);
      expect(voidOfVoid.stamp.at, historyAt(50));
      expect(voidOfVoid.canUndo, isFalse);

      // The first void still names the learn it removed, and a void of a
      // void cancels nothing (countEvents): the learn stays removed.
      expect(_learning(rows[1]).refs, ['Mishnah Berakhot 1:1']);
      expect(rows.last.voidedBy?.actor, historyParent);
      expect(rows.last.voidedCount, 1);
    });

    test('a void of a void resolved only by an id lookup (target off the '
        'loaded pages) also maps as a generic removal', () {
      final buffer = ChangeHistoryBuffer()
        ..addChangeLogPage(
          HistoryPage(
            items: const [],
            next: null,
            exhausted: true,
            watermark: null,
          ),
        )
        ..addLearningEventPage(
          HistoryPage(
            items: [historyVoid(3, target: 2, minutes: 50)],
            next: null,
            exhausted: true,
            watermark: null,
          ),
        )
        ..addLookups([historyVoid(2, target: 1, minutes: 30)]);
      final row = ChangeHistoryRowMapper(
        settingsHistory: _ny,
      ).map(buffer.visibleItems(), buffer).single;
      expect(row.isVoid, isTrue);
      expect(_learning(row).refs, isEmpty);
      expect(_learning(row).source, isNull);
    });

    test('E-2 a void whose target is unknown and an actor with no display '
        'name still map, keeping role and time', () {
      const anonymous = Actor(uid: 'x', role: ActorRole.tutor, displayName: '');
      final row = _rows(
        events: [historyVoid(2, target: 1, minutes: 30, actor: anonymous)],
      ).single;
      expect(_learning(row).refs, isEmpty);
      expect(_learning(row).source, isNull);
      expect(row.stamp.actor.role, ActorRole.tutor);
      expect(row.stamp.at, historyAt(30));
    });
  });

  group('AC-4 undo state from reverts_action_id', () {
    test('the undone action reads Undone; its undo is a Reverted change '
        'with no Undo', () {
      final rows = _rows(
        entries: [
          historyEntry(1, minutes: 10, actor: historyTutor),
          historyEntry(
            2,
            minutes: 20,
            actor: historyParent,
            entityId: 'goal_1',
            reverts: 1,
          ),
        ],
      );
      final revert = rows.first;
      expect(revert.isRevert, isTrue);
      expect(revert.canUndo, isFalse);
      expect(_governed(revert).primary.entity, GovernedEntity.goal);
      final undone = rows.last;
      expect(undone.undoneBy?.actor, historyParent);
      expect(undone.undoneBy?.at, historyAt(20));
      expect(undone.canUndo, isFalse);
    });
  });

  group('AC-4 an undo whose reverted action is off the loaded pages', () {
    ChangeHistoryRow undoRow({required bool lookedUp}) {
      final buffer = ChangeHistoryBuffer()
        ..addChangeLogPage(
          HistoryPage(
            items: [
              historyEntry(
                500,
                minutes: 1000,
                entityId: 'deadline',
                reverts: 1,
                before: {'goals/deadline.target_date': '2026-11-03'},
                after: {'goals/deadline.target_date': '2026-10-01'},
              ),
            ],
            next: const HistoryCursor(1),
            exhausted: false,
            watermark: historyAt(900),
          ),
        )
        ..addLearningEventPage(
          HistoryPage(
            items: const [],
            next: null,
            exhausted: true,
            watermark: null,
          ),
        );
      if (lookedUp) {
        buffer.addActionLookups([
          historyEntry(
            1,
            minutes: 1,
            actor: historyTutor,
            entityId: 'deadline',
            before: {'goals/deadline.target_date': '2026-10-01'},
            after: {'goals/deadline.target_date': '2026-11-03'},
          ),
        ]);
      }
      return ChangeHistoryRowMapper(
        settingsHistory: _ny,
      ).map(buffer.visibleItems(), buffer).single;
    }

    test('the undo describes the looked-up action it reverted', () {
      final row = undoRow(lookedUp: true);
      expect(row.isRevert, isTrue);
      expect(row.canUndo, isFalse);
      expect(row.stamp.actor, historyParent, reason: 'who undid it');
      expect(row.stamp.at, historyAt(1000));
      expect(_governed(row).primary.newDate, '2026-11-03');
    });

    test('until the lookup lands it falls back to its own entries', () {
      final row = undoRow(lookedUp: false);
      expect(row.isRevert, isTrue);
      expect(_governed(row).primary.newDate, '2026-10-01');
    });
  });

  group('AC-5 the bell mirrors the AD-39 allowlist', () {
    test('tutor changes to goal and main-track entities ring; others and '
        'non-tutor changes do not', () {
      final rows = _rows(
        entries: [
          for (final (n, entity) in [
            (1, GovernedEntity.goal),
            (2, GovernedEntity.mainTrack),
            (3, GovernedEntity.mainTrackOrder),
            (4, GovernedEntity.mainTrackProgram),
            (5, GovernedEntity.mainTrackStudyDays),
            (6, GovernedEntity.subTrack),
            (7, GovernedEntity.mainTrackStages),
            (8, GovernedEntity.mainTrackScope),
            (9, GovernedEntity.learnerSettings),
          ])
            historyEntry(n, minutes: n, entity: entity, actor: historyTutor),
          historyEntry(10, minutes: 10, actor: historyParent),
        ],
      );
      final bells = {
        for (final r in rows)
          (_governed(r).primary.entity, r.stamp.actor.role): r.notifiesParent,
      };
      expect(bells, {
        (GovernedEntity.goal, ActorRole.tutor): true,
        (GovernedEntity.mainTrack, ActorRole.tutor): true,
        (GovernedEntity.mainTrackOrder, ActorRole.tutor): true,
        (GovernedEntity.mainTrackProgram, ActorRole.tutor): true,
        (GovernedEntity.mainTrackStudyDays, ActorRole.tutor): true,
        (GovernedEntity.subTrack, ActorRole.tutor): false,
        (GovernedEntity.mainTrackStages, ActorRole.tutor): false,
        (GovernedEntity.mainTrackScope, ActorRole.tutor): false,
        (GovernedEntity.learnerSettings, ActorRole.tutor): false,
        (GovernedEntity.goal, ActorRole.parent): false,
      });
    });
  });

  group('AC-6 lock-ignored learning', () {
    // 2026-09-05 is a Saturday; with no location the New York lock is
    // Fri 12:00 → Sun 01:00 local (fail-closed fallback).
    final saturday = DateTime.utc(2026, 9, 5, 19);
    final fridayMorningUtc = DateTime.utc(2026, 9, 4, 14); // 10:00 in NY
    int minutesTo(DateTime t) => t.difference(historyAt(0)).inMinutes;

    test('an event inside a lock is kept, not counted, with no Undo', () {
      final rows = _rows(
        events: [
          historyLearn(1, minutes: minutesTo(saturday)),
          historyLearn(2, minutes: minutesTo(fridayMorningUtc)),
        ],
      );
      expect(rows.first.lockIgnored, isTrue);
      expect(rows.first.canUndo, isFalse);
      expect(rows.last.lockIgnored, isFalse);
      expect(rows.last.canUndo, isTrue);
    });

    test('the lock is judged with the settings in force at the effective '
        'instant', () {
      // In UTC until Friday 15:00Z, so Friday 14:00Z is inside the UTC
      // fallback lock (Fri 12:00Z →) though not inside New York's.
      final moved = movedHistory(
        lockSettings(timeZone: 'UTC'),
        DateTime.utc(2026, 9, 4, 15),
        newYorkNoLocation,
      );
      final row = _rows(
        events: [historyLearn(1, minutes: minutesTo(fridayMorningUtc))],
        history: moved,
      ).single;
      expect(row.lockIgnored, isTrue);
      expect(row.stamp.day, '2026-09-04');
    });

    test('a lock-ignored void removes nothing', () {
      final rows = _rows(
        events: [
          historyLearn(1, minutes: minutesTo(fridayMorningUtc)),
          historyVoid(2, target: 1, minutes: minutesTo(saturday)),
        ],
      );
      expect(rows.first.lockIgnored, isTrue);
      expect(rows.last.voidedBy, isNull);
      expect(rows.last.canUndo, isTrue);
    });
  });
}

/// DNI-513 widget level: the parent Change history screen — rows with
/// actor, role, time and plain-language action under learner-time-zone
/// day headers (AC-3), Undone and Reverted change (AC-4), lock-ignored
/// learning (AC-6), filters (AC-8), empty / error / retry (AC-9), retained
/// voids (E-3), and the lock overlay and learner switch (E-4).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/domain/learner_state/ports/change_log_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/history_page.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_event_repository.dart';
import 'package:learning_tracker/features/change_history/presentation/providers/change_history_providers.dart';
import 'package:learning_tracker/features/change_history/presentation/widgets/change_history_row_tile.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_window.dart';

import '../../../../helpers/change_history_fixtures.dart';
import '../../../../helpers/fake_history_ports.dart';
import '../../../../helpers/learner_state/lock_fixtures.dart';
import '../change_history_harness.dart';

/// Minutes from 2026-09-01T00:00Z to [t].
int _m(DateTime t) => t.difference(historyAt(0)).inMinutes;

/// The tutor's deadline change, 2026-09-02 10:00Z (06:00 in New York).
ChangeLogEntry _deadline({int n = 1}) => historyEntry(
  n,
  minutes: _m(DateTime.utc(2026, 9, 2, 10)),
  actor: historyTutor,
  entityId: 'deadline',
  before: {'goals/deadline.target_date': '2027-01-01'},
  after: {'goals/deadline.target_date': '2026-11-03'},
);

Finder _tile(String text) => find.ancestor(
  of: find.text(text),
  matching: find.byType(ChangeHistoryRowTile),
);

/// Delegates to a fake per learner.
final class _PerLearner implements HistoryPorts {
  _PerLearner(this.byScope);
  final Map<LearnerScope, HistoryPorts> byScope;

  @override
  late final ChangeLogRepository changeLog = _PerLearnerLog(byScope);

  @override
  late final LearningEventRepository events = _PerLearnerEvents(byScope);
}

final class _PerLearnerLog implements ChangeLogRepository {
  _PerLearnerLog(this.byScope);
  final Map<LearnerScope, HistoryPorts> byScope;

  ChangeLogRepository _of(LearnerScope scope) => byScope[scope]!.changeLog;

  @override
  Future<HistoryPage<ChangeLogEntry>> historyPage(
    LearnerScope scope, {
    HistoryCursor? after,
    int limit = kChangeHistoryPageSize,
  }) => _of(scope).historyPage(scope, after: after, limit: limit);

  @override
  Future<List<ChangeLogEntry>> entriesOfAction(
    LearnerScope scope,
    String actionId,
  ) => _of(scope).entriesOfAction(scope, actionId);

  @override
  Future<List<ChangeLogEntry>> entriesForEntity(
    LearnerScope scope,
    GovernedEntity entity,
  ) => _of(scope).entriesForEntity(scope, entity);

  @override
  Stream<CompleteRead<ChangeLogEntry>> watchIntentHistory(LearnerScope scope) =>
      _of(scope).watchIntentHistory(scope);

  @override
  Stream<bool> watchIsReverted(LearnerScope scope, String actionId) =>
      _of(scope).watchIsReverted(scope, actionId);

  @override
  Future<void> commitGoverned(LearnerScope scope, GovernedBatch batch) =>
      _of(scope).commitGoverned(scope, batch);
}

final class _PerLearnerEvents implements LearningEventRepository {
  _PerLearnerEvents(this.byScope);
  final Map<LearnerScope, HistoryPorts> byScope;

  LearningEventRepository _of(LearnerScope scope) => byScope[scope]!.events;

  @override
  Future<HistoryPage<LearningEvent>> historyPage(
    LearnerScope scope, {
    HistoryCursor? after,
    int limit = kChangeHistoryPageSize,
  }) => _of(scope).historyPage(scope, after: after, limit: limit);

  @override
  Future<List<LearningEvent>> eventsById(LearnerScope scope, Set<String> ids) =>
      _of(scope).eventsById(scope, ids);

  @override
  Stream<CompleteRead<LearningEvent>> watchAll(LearnerScope scope) =>
      _of(scope).watchAll(scope);

  @override
  Future<void> create(LearnerScope scope, LearningEvent event) =>
      _of(scope).create(scope, event);
}

void main() {
  group('AC-3 rows and day headers', () {
    testWidgets('actor, role, time and the plain-language action, under '
        'the learner-time-zone day', (tester) async {
      final repo = FakeHistoryPorts(
        entries: [
          _deadline(),
          // 2026-09-02T02:00Z is still 1 Sep in New York.
          historyEntry(
            2,
            minutes: _m(DateTime.utc(2026, 9, 2, 2)),
            actor: historyParent,
            entity: GovernedEntity.mainTrackStudyDays,
          ),
        ],
      );
      await pumpChangeHistory(tester, changeHistoryOverrides(repository: repo));

      expect(find.text('Change history'), findsOneWidget);
      expect(find.text('Today · Wed, Sep 2 · 1 update'), findsOneWidget);
      expect(find.text('Yesterday · Tue, Sep 1 · 1 update'), findsOneWidget);
      final tutorRow = _tile('Changed the deadline to Nov 3');
      expect(tutorRow, findsOneWidget);
      for (final text in [
        'Rav Cohen',
        'Tutor',
        '· ${DateFormat.jm('en').format(DateTime(2026, 9, 2, 6))}',
      ]) {
        expect(
          find.descendant(of: tutorRow, matching: find.text(text)),
          findsOneWidget,
        );
      }
      final parentRow = _tile('Changed the study days');
      expect(
        find.descendant(of: parentRow, matching: find.text('Parent')),
        findsOneWidget,
      );
    });

    testWidgets('learning rows show the refs as a range, the source and '
        'the date state', (tester) async {
      final at = _m(DateTime.utc(2026, 9, 2, 9));
      final repo = FakeHistoryPorts(
        events: [
          for (final (n, ref) in [
            (1, 'Mishnah Beitzah 4:1'),
            (2, 'Mishnah Beitzah 4:2'),
            (3, 'Mishnah Beitzah 4:3'),
          ])
            historyLearn(
              n,
              minutes: at,
              ref: ref,
              actor: historyTutor,
              dateState: DateState.catchUp,
              learnedOn: '2026-08-29',
            ),
        ],
      );
      await pumpChangeHistory(tester, changeHistoryOverrides(repository: repo));
      expect(
        find.text('Learned Beitzah 4:1 – Beitzah 4:3 (3) · Main track'),
        findsOneWidget,
      );
      expect(find.text('catch-up'), findsOneWidget);
    });
  });

  group('AC-4 Undone and Reverted change', () {
    testWidgets('the undone action reads Undone and the undo reads '
        'Reverted change; neither offers Undo', (tester) async {
      final repo = FakeHistoryPorts(
        entries: [
          _deadline(),
          historyEntry(
            2,
            minutes: _m(DateTime.utc(2026, 9, 2, 11)),
            actor: historyParent,
            entityId: 'deadline',
            reverts: 1,
            before: {'goals/deadline.target_date': '2026-11-03'},
            after: {'goals/deadline.target_date': '2027-01-01'},
          ),
          historyEntry(
            3,
            minutes: _m(DateTime.utc(2026, 9, 2, 8)),
            entity: GovernedEntity.mainTrackOrder,
          ),
        ],
      );
      final undone = <String>[];
      await pumpChangeHistory(
        tester,
        changeHistoryOverrides(
          repository: repo,
          undo: (row) async => undone.add(row.key),
        ),
      );

      final original = _tile('Changed the deadline to Nov 3');
      final revert = _tile('Reverted change: Changed the deadline to Nov 3');
      final plain = _tile('Changed the learning order');
      expect(
        find.descendant(of: original, matching: find.text('Undone')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: original, matching: find.text('Undo')),
        findsNothing,
      );
      expect(
        find.descendant(of: revert, matching: find.text('Undo')),
        findsNothing,
      );
      expect(
        find.descendant(of: plain, matching: find.text('Undo')),
        findsOneWidget,
      );
      await tester.tap(find.descendant(of: plain, matching: find.text('Undo')));
      expect(undone, ['action:${historyId(3)}']);
    });

    testWidgets('an undo whose reverted action is older than the loaded '
        'pages still reads Reverted change: <that action>', (tester) async {
      final base = _m(DateTime.utc(2026, 9, 2, 10));
      final repo = FakeHistoryPorts(
        entries: [
          _deadline(),
          // 150 newer changes push the deadline change off the first page.
          for (var n = 1; n <= 150; n++)
            historyEntry(
              100 + n,
              minutes: base + n,
              entity: GovernedEntity.mainTrackOrder,
            ),
          historyEntry(
            500,
            minutes: base + 1000,
            actor: historyParent,
            entityId: 'deadline',
            reverts: 1,
            before: {'goals/deadline.target_date': '2026-11-03'},
            after: {'goals/deadline.target_date': '2027-01-01'},
          ),
        ],
      );
      await pumpChangeHistory(tester, changeHistoryOverrides(repository: repo));

      expect(repo.changeLogReads, 1, reason: 'the action was not paged to');
      expect(repo.actionLookups, [
        {historyId(1)},
      ]);
      expect(
        find.text('Reverted change: Changed the deadline to Nov 3'),
        findsOneWidget,
      );
    });

    testWidgets('without the Story 4.6 handler no Undo is shown', (
      tester,
    ) async {
      final repo = FakeHistoryPorts(entries: [historyEntry(1, minutes: 60)]);
      await pumpChangeHistory(tester, changeHistoryOverrides(repository: repo));
      expect(find.text('Undo'), findsNothing);
    });
  });

  group('AC-5 the bell', () {
    testWidgets('rings on tutor goal and main-track changes only', (
      tester,
    ) async {
      final at = _m(DateTime.utc(2026, 9, 2, 6));
      final entities = [
        GovernedEntity.goal,
        GovernedEntity.mainTrack,
        GovernedEntity.mainTrackOrder,
        GovernedEntity.mainTrackProgram,
        GovernedEntity.mainTrackStudyDays,
        GovernedEntity.subTrack,
        GovernedEntity.mainTrackStages,
        GovernedEntity.mainTrackScope,
        GovernedEntity.learnerSettings,
      ];
      final repo = FakeHistoryPorts(
        entries: [
          for (var i = 0; i < entities.length; i++)
            historyEntry(
              i + 1,
              minutes: at + i,
              entity: entities[i],
              actor: historyTutor,
            ),
          // The same goal change by the parent: no bell.
          historyEntry(20, minutes: at - 60, actor: historyParent),
        ],
      );
      await pumpChangeHistory(
        tester,
        changeHistoryOverrides(repository: repo),
        size: const Size(400, 3000),
      );
      bool rings(int n) => find
          .descendant(
            of: find.byKey(ValueKey('action:${historyId(n)}')),
            matching: find.byKey(const ValueKey('changeHistoryBell')),
          )
          .evaluate()
          .isNotEmpty;
      expect(
        [for (var n = 1; n <= 9; n++) rings(n)],
        [true, true, true, true, true, false, false, false, false],
      );
      expect(rings(20), isFalse);
      final semantics = tester.ensureSemantics();
      await tester.pump();
      expect(
        find.bySemanticsLabel(RegExp('Parent notified')),
        findsNWidgets(5),
      );
      semantics.dispose();
    });
  });

  group('AC-6 lock-ignored learning', () {
    testWidgets('is labelled kept, not counted, with no Undo', (tester) async {
      // Saturday 2026-09-05 15:00 in the configured New York location.
      final repo = FakeHistoryPorts(
        // Historical lock-ignored event; the screen is now open on Wed 2 Sep.
        events: [historyLearn(1, minutes: _m(DateTime.utc(2026, 8, 29, 19)))],
      );
      await pumpChangeHistory(
        tester,
        changeHistoryOverrides(
          repository: repo,
          settings: constantHistory(newYorkLocated),
          undo: (_) async {},
        ),
      );
      expect(
        find.text('kept, not counted — recorded during Shabbos/Yom Tov'),
        findsOneWidget,
      );
      expect(find.text('Undo'), findsNothing);
    });
  });

  group('AC-8 filter chips', () {
    testWidgets('Tutor, Parent and Learning keep their rows', (tester) async {
      final repo = FakeHistoryPorts(
        entries: [
          _deadline(),
          historyEntry(
            2,
            minutes: 100,
            actor: historyChild,
            entity: GovernedEntity.mainTrackOrder,
          ),
        ],
        events: [historyLearn(3, minutes: 50, actor: historyTutor)],
      );
      await pumpChangeHistory(tester, changeHistoryOverrides(repository: repo));
      expect(find.byType(ChangeHistoryRowTile), findsNWidgets(3));

      Future<void> pick(String chip) async {
        await tester.tap(find.widgetWithText(ChoiceChip, chip));
        await tester.pumpAndSettle();
      }

      await pick('Tutor');
      expect(_tile('Changed the deadline to Nov 3'), findsOneWidget);
      expect(find.byType(ChangeHistoryRowTile), findsOneWidget);
      await pick('Parent');
      expect(_tile('Changed the learning order'), findsOneWidget);
      expect(find.byType(ChangeHistoryRowTile), findsOneWidget);
      await pick('Learning');
      expect(_tile('Learned Berakhot 1:1 · Main track'), findsOneWidget);
      expect(find.byType(ChangeHistoryRowTile), findsOneWidget);
      await pick('All');
      expect(find.byType(ChangeHistoryRowTile), findsNWidgets(3));
    });
  });

  group('AC-9 empty, error and retry', () {
    testWidgets('no changes and no events: "No changes yet."', (tester) async {
      await pumpChangeHistory(
        tester,
        changeHistoryOverrides(repository: FakeHistoryPorts()),
      );
      expect(find.text('No changes yet.'), findsOneWidget);
    });

    testWidgets('a failed first load shows AppErrorView; retry loads the '
        'history', (tester) async {
      final repo = FakeHistoryPorts(entries: [historyEntry(1, minutes: 60)])
        ..failEventReads = 1;
      await pumpChangeHistory(tester, changeHistoryOverrides(repository: repo));
      expect(find.byType(AppErrorView), findsOneWidget);
      expect(find.byType(ChangeHistoryRowTile), findsNothing);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byType(AppErrorView), findsNothing);
      expect(find.byType(ChangeHistoryRowTile), findsOneWidget);
    });

    testWidgets('a failed next page keeps the loaded rows, offers retry and '
        'adds no duplicate', (tester) async {
      final repo = FakeHistoryPorts(
        entries: [
          for (var n = 1; n <= 130; n++)
            historyEntry(n, minutes: n, entity: GovernedEntity.mainTrackOrder),
        ],
      );
      await pumpChangeHistory(tester, changeHistoryOverrides(repository: repo));
      expect(repo.changeLogReads, 1);
      repo.failChangeLogReads = 1;

      final list = find.byKey(const ValueKey('changeHistoryTimeline'));
      Future<void> toEnd() async {
        for (var i = 0; i < 60; i++) {
          await tester.drag(list, const Offset(0, -3000));
          await tester.pumpAndSettle();
        }
      }

      await toEnd();
      expect(
        find.byKey(const ValueKey('changeHistoryPageError')),
        findsOneWidget,
      );
      expect(repo.changeLogReads, 1, reason: 'the failed read is not counted');

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      await toEnd();
      expect(
        find.byKey(const ValueKey('changeHistoryPageError')),
        findsNothing,
      );
      expect(repo.reads.where((r) => r.$1 == 'change_log').map((r) => r.$2), [
        0,
        100,
      ]);
      // The oldest row is there exactly once.
      expect(find.byKey(ValueKey('action:${historyId(1)}')), findsOneWidget);
    });
  });

  group('E-3 retained voids', () {
    testWidgets('a voided learn and its void stay visible with who and '
        'when', (tester) async {
      final repo = FakeHistoryPorts(
        events: [
          historyLearn(
            1,
            minutes: _m(DateTime.utc(2026, 9, 2, 9)),
            actor: historyChild,
          ),
          historyVoid(
            2,
            target: 1,
            minutes: _m(DateTime.utc(2026, 9, 2, 10)),
            actor: historyParent,
          ),
        ],
      );
      await pumpChangeHistory(tester, changeHistoryOverrides(repository: repo));
      expect(find.text('Removed Berakhot 1:1 · Main track'), findsOneWidget);
      final learned = _tile('Learned Berakhot 1:1 · Main track');
      expect(
        find.descendant(
          of: learned,
          matching: find.text(
            'Removed by Abba · Wed, Sep 2 · '
            '${DateFormat.jm('en').format(DateTime(2026, 9, 2, 6))}',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: learned, matching: find.text('Yehuda')),
        findsOneWidget,
      );
    });
  });

  group('E-4 lock and learner switch', () {
    testWidgets('while the lock overlay is up no timeline content is '
        'readable', (tester) async {
      final repo = FakeHistoryPorts(entries: [_deadline()]);
      await pumpChangeHistory(
        tester,
        changeHistoryOverrides(
          repository: repo,
          lock: SacredWindow(
            startUtc: DateTime.utc(2026, 9, 1),
            endUtc: DateTime.utc(2026, 9, 3),
            kind: SacredWindowKind.shabbos,
          ),
        ),
      );
      expect(find.textContaining('Changed the deadline'), findsNothing);
      expect(find.byType(ChangeHistoryRowTile), findsNothing);
      expect(repo.reads, isEmpty);
    });

    testWidgets("the learner's own lock hides the timeline with no device "
        'lock', (tester) async {
      final repo = FakeHistoryPorts(entries: [_deadline()]);
      await pumpChangeHistory(
        tester,
        changeHistoryOverrides(
          repository: repo,
          // Saturday 2026-09-05 15:00 in New York.
          settings: constantHistory(newYorkLocated),
          now: DateTime.utc(2026, 9, 5, 19),
        ),
      );
      expect(find.byKey(const ValueKey('changeHistoryLocked')), findsOneWidget);
      expect(find.byType(ChangeHistoryRowTile), findsNothing);
      // Any initial read while settings were still loading must no longer
      // produce visible history after the configured lock is resolved.
    });

    testWidgets("an open history becomes unreadable when the learner's lock "
        'begins, and readable again when it ends', (tester) async {
      final settings = constantHistory(newYorkLocated);
      // The Shabbos lock of 2026-09-05 in New York.
      final lock = lockWindows(
        settings,
        DateTime.utc(2026, 9, 4),
        DateTime.utc(2026, 9, 6),
      ).single;
      var now = lock.startUtc.subtract(const Duration(minutes: 5));
      final repo = FakeHistoryPorts(entries: [_deadline()]);
      await pumpChangeHistory(
        tester,
        changeHistoryOverrides(
          repository: repo,
          settings: settings,
          clock: () => now,
        ),
      );
      expect(find.byType(ChangeHistoryRowTile), findsOneWidget);

      // The lock begins with the screen still open: no rebuild of the route.
      now = lock.startUtc;
      await tester.pump(const Duration(minutes: 5));
      await tester.pump();
      expect(find.byKey(const ValueKey('changeHistoryLocked')), findsOneWidget);
      expect(find.byType(ChangeHistoryRowTile), findsNothing);
      expect(find.textContaining('Changed the deadline'), findsNothing);

      // Inside the lock it stays unreadable at every recheck.
      now = lock.startUtc.add(const Duration(hours: 1));
      await tester.pump(kChangeHistoryLockRecheck);
      await tester.pump();
      expect(find.byType(ChangeHistoryRowTile), findsNothing);

      // One tick after the lock's last instant the history reads again.
      now = lock.endUtc.add(civilTick);
      await tester.pump(kChangeHistoryLockRecheck);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('changeHistoryLocked')), findsNothing);
      expect(find.byType(ChangeHistoryRowTile), findsOneWidget);
    });

    testWidgets("while the learner's lock is unknown it is not locked", (
      tester,
    ) async {
      final repo = FakeHistoryPorts(entries: [_deadline()]);
      await pumpChangeHistory(
        tester,
        changeHistoryOverrides(repository: repo, settingsPending: true),
        settle: false,
      );
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('changeHistoryLocked')), findsNothing);
    });

    testWidgets('switching learner clears the previous rows before the new '
        "learner's history shows", (tester) async {
      final other = LearnerScope(
        ownerUid: 'owner-uid',
        profileId: historyId(4242),
      );
      final gate = Completer<void>();
      final second = FakeHistoryPorts(
        entries: [
          historyEntry(1, minutes: 10, entity: GovernedEntity.mainTrackScope),
        ],
      )..gate = gate.future;
      final scopeHolder = StateProviderLike(historyScope);
      final container = ProviderContainer(
        overrides: changeHistoryOverrides(
          repository: _PerLearner({
            historyScope: FakeHistoryPorts(entries: [_deadline()]),
            other: second,
          }),
          scopeOf: (ref) async => ref.watch(scopeHolder.provider),
        ),
      );
      addTearDown(container.dispose);
      await pumpChangeHistory(tester, const [], container: container);
      expect(find.textContaining('Changed the deadline'), findsOneWidget);

      container.read(scopeHolder.provider.notifier).set(other);
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Changed the deadline'), findsNothing);
      expect(find.byType(ChangeHistoryRowTile), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Changed what the main track covers'), findsOneWidget);
      expect(find.textContaining('Changed the deadline'), findsNothing);

      // The lock's boundary timer lives with the container: end it here,
      // before the framework checks for pending timers.
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });
  });

  testWidgets('AC-1 outside the parent role nothing is read', (tester) async {
    final repo = FakeHistoryPorts(entries: [_deadline()]);
    await pumpChangeHistory(
      tester,
      changeHistoryOverrides(repository: repo, access: false),
    );
    expect(
      find.text('Change history is open to the parent only.'),
      findsOneWidget,
    );
    expect(repo.reads, isEmpty);
    expect(find.byType(ChangeHistoryRowTile), findsNothing);
  });

  testWidgets('dark mode renders the same rows', (tester) async {
    final repo = FakeHistoryPorts(entries: [_deadline()]);
    await pumpChangeHistory(
      tester,
      changeHistoryOverrides(repository: repo),
      brightness: Brightness.dark,
    );
    expect(_tile('Changed the deadline to Nov 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('E-2 and accessibility', () {
    testWidgets('an actor with no display name is shown by role', (
      tester,
    ) async {
      const nameless = Actor(uid: 't', role: ActorRole.tutor, displayName: '');
      final repo = FakeHistoryPorts(
        entries: [historyEntry(1, minutes: 60, actor: nameless)],
      );
      await pumpChangeHistory(tester, changeHistoryOverrides(repository: repo));
      final row = find.byType(ChangeHistoryRowTile);
      expect(
        find.descendant(of: row, matching: find.text('Tutor')),
        findsNWidgets(2), // the name fallback and the role tag
      );
    });

    testWidgets('Hebrew, right to left, at 2x text: no overflow', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repo = FakeHistoryPorts(
        entries: [_deadline()],
        events: [historyLearn(2, minutes: 600, actor: historyChild)],
      );
      await pumpChangeHistory(
        tester,
        changeHistoryOverrides(repository: repo),
        locale: const Locale('he'),
        size: const Size(360, 800),
      );
      expect(find.text('היסטוריית שינויים'), findsOneWidget);
      expect(find.text('מורה'), findsWidgets);
      expect(
        Directionality.of(
          tester.element(find.byType(ChangeHistoryRowTile).first),
        ),
        TextDirection.rtl,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('chips and rows meet the 48dp target', (tester) async {
      final repo = FakeHistoryPorts(entries: [_deadline()]);
      await pumpChangeHistory(tester, changeHistoryOverrides(repository: repo));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    });
  });
}

/// A tiny mutable holder exposed as a provider (switches the learner).
final class StateProviderLike {
  StateProviderLike(LearnerScope initial)
    : provider = NotifierProvider<_ScopeNotifier, LearnerScope>(
        () => _ScopeNotifier(initial),
      );

  final NotifierProvider<_ScopeNotifier, LearnerScope> provider;
}

class _ScopeNotifier extends Notifier<LearnerScope> {
  _ScopeNotifier(this._initial);
  final LearnerScope _initial;

  @override
  LearnerScope build() => _initial;

  void set(LearnerScope scope) => state = scope;
}

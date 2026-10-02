/// DNI-514 AC-7 (widget): no Undo is offered on a `learnerSettings` seed
/// entry (before all-null) or on a lock-ignored learning record, including
/// one whose EFFECTIVE instant (`original_recorded_at`) falls in the lock;
/// and AC-2 / AC-6: no Undo on a revert row or its undo voids.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/change_history/domain/undo/history_undo_status.dart';
import 'package:learning_tracker/features/change_history/presentation/undo/change_history_undo_button.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_event_plans.dart';

import '../../helpers/learner_state/c0_fixtures.dart';
import '../../helpers/learner_state/engine_fixtures.dart';
import '../../helpers/learner_state/fake_learning_commands.dart';
import '../../helpers/learner_state/learner_state_overrides.dart';
import '../../helpers/learner_state_fixtures.dart';
import '../../helpers/pump_app.dart';

// The UTC no-location learner (c0SettingsHistory): Shabbos lock
// Fri 2026-09-04 12:00Z → Sun 2026-09-06 01:00Z. engineAt(6000) is inside.
final _now = DateTime.utc(2026, 9, 7, 10);

ChangeLogEntry _settings(String id, Object? before) => ChangeLogEntry(
  id: id,
  entity: GovernedEntity.learnerSettings,
  entityId: profileUlid,
  actionId: id,
  before: {
    'learner_profiles/$profileUlid.time_zone': before,
    'learner_profiles/$profileUlid.in_israel': before == null ? null : false,
  },
  after: {
    'learner_profiles/$profileUlid.time_zone': 'Asia/Jerusalem',
    'learner_profiles/$profileUlid.in_israel': true,
  },
  at: t0,
  actor: parentActor,
);

void main() {
  late FakeLearningCommands commands;

  setUp(() => commands = FakeLearningCommands());
  tearDown(() => commands.dispose());

  Future<void> pumpRow(
    WidgetTester tester,
    HistoryUndoStatus status, {
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      pumpApp(
        overrides: learnerStateOverrides(scope: c0Scope(), commands: commands),
        locale: locale,
        child: Scaffold(
          body: Center(
            child: ChangeHistoryUndoButton(
              status: status,
              target: const GovernedUndoTarget(ulidA),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a learnerSettings seed row offers no Undo; a later settings '
      'change does', (tester) async {
    final seed = _settings(ulidA, null);
    final later = _settings(ulidB, 'UTC');
    final index = HistoryUndoIndex(entries: [seed, later]);

    await pumpRow(tester, index.governed([seed]));
    expect(find.byType(TextButton), findsNothing);
    expect(find.text('Undo'), findsNothing);

    await pumpRow(tester, index.governed([later]));
    expect(find.widgetWithText(TextButton, 'Undo'), findsOneWidget);
  });

  testWidgets('a lock-ignored capture offers no Undo, also when only its '
      'effective instant is in the lock (English and Hebrew)', (tester) async {
    final inLock = engineLearn(1, 'Mishnah Berakhot 1:1', minutes: 6000);
    // Recorded after the lock, but its original instant is inside it.
    final importedIntoLock = engineLearn(
      2,
      'Mishnah Berakhot 1:2',
      minutes: 9000,
      originalMinutes: 6000,
    );
    final counted = engineLearn(3, 'Mishnah Berakhot 1:3', minutes: 600);
    final events = [inLock, importedIntoLock, counted];
    final log = LearningLogView.of(events, c0SettingsHistory(), _now);
    expect(log.isLockIgnored(importedIntoLock.id), isTrue);
    expect(log.isLockIgnored(counted.id), isFalse);
    final index = HistoryUndoIndex(events: events);

    for (final row in [
      [inLock],
      [importedIntoLock],
      [inLock, importedIntoLock],
    ]) {
      for (final locale in const [Locale('en'), Locale('he')]) {
        await pumpRow(
          tester,
          index.capture(row, isLockIgnored: log.isLockIgnored),
          locale: locale,
        );
        expect(find.byType(TextButton), findsNothing);
      }
    }

    await pumpRow(
      tester,
      index.capture([counted], isLockIgnored: log.isLockIgnored),
    );
    expect(find.widgetWithText(TextButton, 'Undo'), findsOneWidget);
  });

  testWidgets('an undone capture shows Undone; its undo voids offer no '
      'Undo', (tester) async {
    final capture = [engineLearn(1, 'Mishnah Berakhot 1:1')];
    final undoVoid = LearningEvent.voidOf(
      id: engineUlid(9),
      targetId: engineUlid(1),
      recordedAt: engineAt(700),
      actor: parentActor,
      revertsActionId: engineUlid(1),
    );
    final index = HistoryUndoIndex(events: [...capture, undoVoid]);
    bool never(String _) => false;

    await pumpRow(tester, index.capture(capture, isLockIgnored: never));
    expect(find.text('Undone'), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);

    await pumpRow(tester, index.capture([undoVoid], isLockIgnored: never));
    expect(find.byType(TextButton), findsNothing);
    expect(find.text('Undone'), findsNothing);
  });
}

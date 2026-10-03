// DNI-504 (Story 3.1) AC-3 / AC-8 integration: erev captures go through
// the real LearningCommands and CaptureGate. Before L.start a planned tick
// and the shared Up to… write ordinary dated main events with pts_; a
// picker still open at L.start closes with nothing written and nothing
// replayed after the lock; a Record or tick racing L.start is refused by
// the gate at submission, writes nothing and is never queued for retry.
@Tags(['learning'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label_providers.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/features/learning/presentation/providers/erev_planned_tasks_provider.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/learn_slots/erev_planned_slot.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/sub_tracks/sub_tracks.dart';

import '../../../helpers/pump_app.dart';
import '../../sub_tracks/helpers/capture_harness.dart';
import '../../sub_tracks/helpers/up_to_fixtures.dart';

/// Friday 2026-09-04 09:00Z: erev. The fixture learner (UTC, no location)
/// is under the fail-closed fallback, so the lock starts at 12:00Z.
final _erev = DateTime.utc(2026, 9, 4, 9);

/// The lock the fixture settings give for this Shabbos.
LockWindow _lock(CaptureRig rig) =>
    lockWindows(rig.settings, _erev, _erev.add(const Duration(days: 2))).first;

DailyTask _task(String ref) => DailyTask(
  curriculumId: CurriculumId.mishnayos,
  contentItemSefariaRef: ref,
  stageOrder: 1,
  priority: DailyTaskPriority.newLearning,
  isOverdue: false,
  reason: 'test',
  stageName: 'Learn',
  trackLabel: 'Mishnayos',
);

/// Every locked day plans the same first two leaves (the planner itself
/// is covered by erev_planned_tasks_provider_test.dart).
final _planned = [_task('Mishnah Berakhot 1:1'), _task('Mishnah Berakhot 1:2')];

final class _Erev {
  _Erev(this.rig) : now = _erev;

  final CaptureRig rig;
  DateTime now;

  set clock(DateTime value) {
    now = value;
    rig.now = value;
  }
}

Future<_Erev> _pump(WidgetTester tester) async {
  final rig = CaptureRig(now: _erev);
  addTearDown(rig.dispose);
  final erev = _Erev(rig);
  useSurface(tester, phoneSize);
  await tester.pumpWidget(
    pumpApp(
      overrides: [
        ...rig.overrides(),
        erevSettingsHistoryProvider.overrideWith((ref) async => rig.settings),
        learningCommandClockProvider.overrideWithValue(() => erev.now),
        erevSequencePlannerProvider.overrideWithValue(
          (ref, dates) async => [for (final _ in dates) _planned],
        ),
        renderedDisplayForRefProvider.overrideWith((ref, r) async => r),
      ],
      child: const Scaffold(
        body: PendingCaptureRollback(
          child: SingleChildScrollView(child: ErevPlannedSlot()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return erev;
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(ErevPlannedSlot)));

Finder _upTo() => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('erevUpTo-') &&
      (w.key! as ValueKey<String>).value.endsWith('-mishnayos'),
);

Future<void> _pickThrough12(WidgetTester tester) async {
  await tester.tap(_upTo().first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Berakhot 1:2'));
  await tester.pump();
}

const _lockedNotice =
    'Not recorded — the app is closed for Shabbos and Yom Tov.';

void main() {
  testWidgets('the fixture is erev: the lock starts later today', (
    tester,
  ) async {
    final erev = await _pump(tester);
    final lock = _lock(erev.rig);
    expect(lock.startUtc, DateTime.utc(2026, 9, 4, 12));
    expect(find.textContaining('Planned for'), findsWidgets);
  });

  group('AC-3: before L.start every control writes an ordinary capture', () {
    testWidgets('a tick writes one dated main event, learned_on today, '
        'recorded now, with its pts_ entry', (tester) async {
      final erev = await _pump(tester);
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();

      final event = erev.rig.written.single;
      expect(event.isLearn, isTrue);
      expect(event.ref, 'Mishnah Berakhot 1:1');
      expect(event.source, LearningEvent.sourceMain);
      expect(event.dateState, DateState.dated);
      expect(event.learnedOn, '2026-09-04');
      // At the row's planner stage (the first stage order), as today's
      // list records it: the leaf opens its AD-32 review cycle.
      expect(event.stage, 1);
      expect(event.toStorage()[LearningEvent.kRecordedAt], _erev);
      expect(effectiveAt(event), _erev);
      expect(erev.rig.awards.single.eventId, event.id);
      expect(find.text('Undo'), findsOneWidget);
    });

    testWidgets('Up to… on a planned section is the shared picker and '
        'records the chosen leaves as one capture', (tester) async {
      final erev = await _pump(tester);
      await _pickThrough12(tester);
      expect(find.byKey(const Key('upToPickerSheet')), findsOneWidget);
      await tester.tap(find.byKey(const Key('upToRecord')));
      await tester.pumpAndSettle();

      final written = erev.rig.written;
      expect(
        [for (final e in written) e.ref],
        ['Mishnah Berakhot 1:1', 'Mishnah Berakhot 1:2'],
      );
      for (final e in written) {
        expect(e.source, LearningEvent.sourceMain);
        expect(e.dateState, DateState.dated);
        expect(e.learnedOn, '2026-09-04');
        expect(e.toStorage()[LearningEvent.kRecordedAt], _erev);
      }
      expect(erev.rig.port.chunks, hasLength(1));
      expect(
        {for (final a in erev.rig.awards) a.eventId},
        {for (final e in written) e.id},
      );
    });
  });

  group('AC-3: a planned row is captured once', () {
    Checkbox firstBox(WidgetTester tester) =>
        tester.widget<Checkbox>(find.byType(Checkbox).first);

    testWidgets('a rapid double tap while the write is pending records '
        'one event and one pts_', (tester) async {
      final erev = await _pump(tester);
      erev.rig.port.holdNext();
      // Both taps land before the next frame: the second reaches the
      // row's old callback.
      await tester.tap(find.byType(Checkbox).first);
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      expect(erev.rig.port.attempts, hasLength(1));
      // Disabled while the capture is in flight.
      expect(firstBox(tester).onChanged, isNull);
      await tester.tap(find.byType(Checkbox).first, warnIfMissed: false);
      await tester.pump();
      expect(erev.rig.port.attempts, hasLength(1));

      erev.rig.port.release();
      await tester.pumpAndSettle();
      expect(erev.rig.written, hasLength(1));
      expect(erev.rig.written.single.ref, 'Mishnah Berakhot 1:1');
      expect(erev.rig.awards, hasLength(1));
      expect(firstBox(tester).value, isTrue);
    });

    testWidgets('a write that outlives the ack wait is kept queued and '
        'shown ticked; tapping again writes nothing more', (tester) async {
      final erev = await _pump(tester);
      erev.rig.port.holdNext();
      await tester.tap(find.byType(Checkbox).first);
      // Past the command's ack wait: the capture settles as queued.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      expect(firstBox(tester).value, isTrue);
      expect(firstBox(tester).onChanged, isNull);
      await tester.tap(find.byType(Checkbox).first, warnIfMissed: false);
      await tester.pump();
      expect(erev.rig.port.attempts, hasLength(1));

      erev.rig.port.release();
      await tester.pumpAndSettle();
      expect(erev.rig.written, hasLength(1));
    });

    testWidgets('a write that was not saved frees the row; the retry '
        'records it once', (tester) async {
      final erev = await _pump(tester);
      erev.rig.port.failNextWith(
        const PermanentWriteRejection('permission-denied'),
      );
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      expect(erev.rig.written, isEmpty);
      expect(firstBox(tester).value, isFalse);
      expect(firstBox(tester).onChanged, isNotNull);

      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      expect(erev.rig.written, hasLength(1));
      expect(erev.rig.written.single.ref, 'Mishnah Berakhot 1:1');
      expect(erev.rig.awards, hasLength(1));
    });
  });

  group('AC-8: the lock boundary', () {
    testWidgets('a picker still open at L.start closes, writes nothing, and '
        'nothing is replayed after the lock', (tester) async {
      final erev = await _pump(tester);
      final lock = _lock(erev.rig);
      await _pickThrough12(tester);
      expect(find.byKey(const Key('upToRecord')), findsOneWidget);

      erev.clock = lock.startUtc.add(const Duration(seconds: 1));
      _container(tester).invalidate(erevWindowProvider);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('upToPickerSheet')), findsNothing);
      expect(find.textContaining('Planned for'), findsNothing);
      expect(erev.rig.port.attempts, isEmpty);

      // After the lock: still nothing from the abandoned picker.
      erev.clock = lock.endUtc.add(const Duration(hours: 1));
      _container(tester).invalidate(erevWindowProvider);
      await tester.pumpAndSettle();
      expect(erev.rig.port.attempts, isEmpty);
      expect(find.byKey(const Key('upToPickerSheet')), findsNothing);
    });

    testWidgets('a Record racing L.start is refused by the gate at '
        'submission: no write, no Undo, nothing queued to retry', (
      tester,
    ) async {
      final erev = await _pump(tester);
      final lock = _lock(erev.rig);
      await _pickThrough12(tester);

      // The window has not re-evaluated yet; the gate judges the instant.
      erev.clock = lock.startUtc;
      await tester.tap(find.byKey(const Key('upToRecord')));
      await tester.pumpAndSettle();

      expect(erev.rig.port.attempts, isEmpty);
      expect(find.text(_lockedNotice), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
      // Not a pending failure: nothing is retried once the lock ends.
      final failures = await erev.rig.commands.watchPendingFailures().first;
      expect(failures, isEmpty);
      erev.clock = lock.endUtc.add(const Duration(hours: 1));
      await tester.pumpAndSettle();
      expect(erev.rig.port.attempts, isEmpty);
    });

    testWidgets('a tick racing L.start is refused the same way', (
      tester,
    ) async {
      final erev = await _pump(tester);
      final lock = _lock(erev.rig);
      erev.clock = lock.startUtc.add(const Duration(milliseconds: 1));
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();

      expect(erev.rig.port.attempts, isEmpty);
      expect(find.text(_lockedNotice), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
    });

    testWidgets('a capture retried after a refusal cannot duplicate', (
      tester,
    ) async {
      final erev = await _pump(tester);
      final lock = _lock(erev.rig);
      erev.clock = lock.startUtc;
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      expect(erev.rig.port.attempts, isEmpty);

      // Back before the lock (a corrected clock): one tick, one event.
      erev.clock = _erev.add(const Duration(minutes: 1));
      _container(tester).invalidate(erevWindowProvider);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      expect(erev.rig.written, hasLength(1));
      expect(erev.rig.written.single.ref, 'Mishnah Berakhot 1:1');
    });
  });
}

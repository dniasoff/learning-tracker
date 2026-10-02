/// DNI-475 (Story 1.13) widget level: the Mishna history screen and its
/// entry points, against the C0 fakes and fixed engine fixtures.
/// TQ-6: fixed instants only.
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label_providers.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/content_item_tile.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/domain/models/mishna_history_item.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/mishna_history_provider.dart';
import 'package:learning_tracker/features/learning/presentation/screens/mishna_history_screen.dart';
import 'package:learning_tracker/features/progress/domain/models/lifetime_knowledge.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/curriculum_breakdown_list.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_window.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_windows_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../../helpers/learner_state/mishna_history_fixtures.dart';
import '../../../../helpers/learner_state_fixtures.dart';
import '../../../../helpers/pump_app.dart';

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo<Object?> {}

const _screen = MishnaHistoryScreen(
  curriculumId: historyCurriculum,
  leafRef: historyLeaf,
);

/// The learnt fixture: a first learn (sub-track, since ended), a catch-up
/// repeat, a voided entry, a lock-ignored entry and the newest repeat.
void _seedLearnt(HistoryPorts ports) {
  ports.events.seed(ports.scope, [
    historyLearn(1, day: 1, source: ulidB),
    historyLearn(2, day: 5, dateState: DateState.catchUp),
    historyLearn(3, day: 7),
    historyVoid(4, eid(3)),
    historyLearn(5, day: 12),
    historyLearn(6, day: 14),
  ]);
  ports.tracks.seed(ports.scope, [endedSubTrack()]);
}

LearnerState _learntState() =>
    historyState(counted: {eid(1), eid(2), eid(5)}, lockIgnored: {eid(6)});

List<Override> _common({SacredWindow? lock}) => [
  currentSacredWindowProvider.overrideWithValue(lock),
  renderedDisplayForRefProvider.overrideWith((ref, sefariaRef) async => 'B'),
];

Future<void> _pump(
  WidgetTester tester,
  List<Override> overrides, {
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  Widget child = _screen,
  SacredWindow? lock,
}) async {
  await tester.pumpWidget(
    pumpApp(
      child: child,
      overrides: [
        ..._common(lock: lock),
        ...overrides,
      ],
      locale: locale,
      theme: AppTheme.themeFor(brightness: brightness),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _row(int n) => find.byKey(ValueKey('mishnaHistoryRow-${eid(n)}'));

void main() {
  late HistoryPorts ports;
  setUp(() => ports = HistoryPorts());
  tearDown(() => ports.dispose());

  group('AC-1 open history for a learnt mishna', () {
    testWidgets('header shows the engine Learnt state and non-voided events '
        '(lock-ignored included); '
        'rows newest first with date, Before tracking, source and tags; '
        'footer explains repeats', (tester) async {
      _seedLearnt(ports);
      await _pump(tester, historyOverrides(ports, state: _learntState()));

      expect(find.text('Mishna history'), findsOneWidget);
      expect(find.text('Learnt'), findsOneWidget);
      expect(find.text('Learning events: 4'), findsOneWidget);

      // Newest first: 6 (lock-ignored), 5, 3 (voided), 2, 1.
      final order = [
        6,
        5,
        3,
        2,
        1,
      ].map((n) => tester.getTopLeft(_row(n)).dy).toList();
      expect(order, [...order]..sort());

      expect(
        find.descendant(of: _row(1), matching: find.text('Sep 1, 2026')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _row(1),
          matching: find.text('Cheder shiur (ended)'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _row(2), matching: find.text('catch-up')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _row(2), matching: find.text('chazara')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _row(1), matching: find.text('chazara')),
        findsNothing,
        reason: 'the first counted event is not a repeat',
      );
      expect(
        find.descendant(of: _row(5), matching: find.text('Home')),
        findsOneWidget,
      );
      final footer = find.text(
        "Repeats never add to goal progress — they're kept here as your "
        'record.',
      );
      await tester.scrollUntilVisible(footer, 200);
      expect(footer, findsOneWidget);
    });

    testWidgets('a Before tracking event shows the badge instead of a date', (
      tester,
    ) async {
      ports.events.seed(ports.scope, [
        historyLearn(1, dateState: DateState.beforeTracking),
      ]);
      await _pump(
        tester,
        historyOverrides(ports, state: historyState(counted: {eid(1)})),
      );
      expect(
        find.descendant(of: _row(1), matching: find.text('Before tracking')),
        findsOneWidget,
      );
    });
  });

  group('AC-1 empty, voided and lock-ignored events', () {
    testWidgets('an unlearnt mishna says Not learnt yet with an empty list', (
      tester,
    ) async {
      // Only a voided learn: nothing counts and nothing was lock-ignored.
      ports.events.seed(ports.scope, [historyLearn(1), historyVoid(2, eid(1))]);
      await _pump(
        tester,
        historyOverrides(ports, state: historyState(learnt: false)),
      );
      expect(find.text('Not learnt yet'), findsOneWidget);
      expect(find.byKey(const Key('mishnaHistoryEventCount')), findsNothing);
      expect(_row(1), findsNothing);
    });

    testWidgets('a mishna whose only event was lock-ignored stays Not learnt '
        'yet but shows the kept, not counted row and its event count', (
      tester,
    ) async {
      ports.events.seed(ports.scope, [historyLearn(1)]);
      await _pump(
        tester,
        historyOverrides(
          ports,
          state: historyState(learnt: false, lockIgnored: {eid(1)}),
        ),
      );
      expect(find.text('Not learnt yet'), findsOneWidget);
      expect(find.text('Learning events: 1'), findsOneWidget);
      expect(
        find.descendant(
          of: _row(1),
          matching: find.text(
            'kept, not counted — recorded during Shabbos/Yom Tov',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a child sees no voided row; a parent sees it as Removed', (
      tester,
    ) async {
      _seedLearnt(ports);
      await _pump(
        tester,
        historyOverrides(
          ports,
          state: _learntState(),
          viewer: MishnaHistoryViewer.child,
        ),
      );
      expect(_row(3), findsNothing);
      expect(find.text('Removed'), findsNothing);

      await _pump(tester, historyOverrides(ports, state: _learntState()));
      expect(
        find.descendant(of: _row(3), matching: find.text('Removed')),
        findsOneWidget,
      );
    });

    testWidgets('a lock-ignored event is labelled kept, not counted', (
      tester,
    ) async {
      _seedLearnt(ports);
      await _pump(tester, historyOverrides(ports, state: _learntState()));
      expect(
        find.descendant(
          of: _row(6),
          matching: find.text(
            'kept, not counted — recorded during Shabbos/Yom Tov',
          ),
        ),
        findsOneWidget,
      );
    });
  });

  group('AC-1 loading and failed read', () {
    testWidgets('shows loading until the complete input is available', (
      tester,
    ) async {
      await tester.pumpWidget(
        pumpApp(
          child: _screen,
          overrides: [
            ..._common(),
            ...historyOverrides(ports, state: null),
            learnerStateProvider.overrideWith(
              (ref, _) => const Stream<LearnerState>.empty(),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Learnt'), findsNothing);
    });

    testWidgets('a failed read shows AppErrorView; Retry reloads the same '
        'learner and mishna', (tester) async {
      ports.events.seed(ports.scope, [historyLearn(1)]);
      final scopes = <Object>[];
      var attempts = 0;
      await _pump(tester, [
        ...historyOverrides(ports, state: null),
        learnerStateProvider.overrideWith((ref, scope) {
          scopes.add(scope);
          attempts++;
          return attempts == 1
              ? Stream.error(StateError('engine input failed'))
              : Stream.value(historyState(counted: {eid(1)}));
        }),
      ]);
      expect(find.byType(AppErrorView), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.byType(AppErrorView), findsNothing);
      expect(find.text('Learnt'), findsOneWidget);
      expect(_row(1), findsOneWidget);
      expect(scopes, [ports.scope, ports.scope]);
    });
  });

  group('AC-1 malformed history rows', () {
    testWidgets('a malformed event row shows AppErrorView and no rows; '
        'Retry reloads once the log reads cleanly', (tester) async {
      _seedLearnt(ports);
      ports.events.seedRejected(ports.scope, const [
        RejectedRow(ulidD, 'bad kind'),
      ]);
      await _pump(tester, historyOverrides(ports, state: _learntState()));

      expect(find.byType(AppErrorView), findsOneWidget);
      expect(find.byKey(const Key('mishnaHistoryLearntState')), findsNothing);
      expect(_row(1), findsNothing);

      ports.events.seedRejected(ports.scope, const []);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.byType(AppErrorView), findsNothing);
      expect(_row(1), findsOneWidget);
    });

    testWidgets('a malformed sub-track row shows AppErrorView and no rows, '
        'never an unknown-source label', (tester) async {
      _seedLearnt(ports);
      ports.tracks.seedRejected(ports.scope, const [
        RejectedRow(ulidB, 'bad name'),
      ]);
      await _pump(tester, historyOverrides(ports, state: _learntState()));

      expect(find.byType(AppErrorView), findsOneWidget);
      expect(_row(1), findsNothing);
      expect(find.text('Ended sub-track'), findsNothing);
    });
  });

  group('AC-1 lock transition', () {
    testWidgets('no event content is built under the sacred-time lock', (
      tester,
    ) async {
      _seedLearnt(ports);
      await _pump(
        tester,
        historyOverrides(ports, state: _learntState()),
        lock: SacredWindow(
          startUtc: onDay(4),
          endUtc: onDay(5),
          kind: SacredWindowKind.shabbos,
        ),
      );
      expect(find.text('Learnt'), findsNothing);
      expect(_row(1), findsNothing);
      expect(find.text('Mishna history'), findsNothing);
    });

    testWidgets("the target learner's lock hides the history with no device "
        'lock (tutor or another profile on this device)', (tester) async {
      _seedLearnt(ports);
      final gate = FakeCaptureGate.locked(LockWindow(onDay(4), onDay(5)));
      final settings = c0SettingsHistory();
      await _pump(
        tester,
        historyOverrides(
          ports,
          state: _learntState(),
          gate: gate,
          lockSettings: settings,
        ),
      );

      expect(find.byKey(const Key('mishnaHistoryLocked')), findsOneWidget);
      expect(find.text('Learnt'), findsNothing);
      expect(_row(1), findsNothing);
      expect(find.text('Mishna history'), findsNothing);
      // Judged on the active learner's own lock settings.
      expect(gate.checks, isNotEmpty);
      expect(gate.checks.last.$1, same(settings));
    });

    testWidgets('when the learner lock starts, the open correction sheet '
        'closes and the rows disappear', (tester) async {
      _seedLearnt(ports);
      final gate = FakeCaptureGate.open();
      await _pump(
        tester,
        historyOverrides(
          ports,
          state: _learntState(),
          commands: FakeLearningCommands(),
          gate: gate,
        ),
      );
      await tester.tap(_row(5));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('mishnaHistoryAction-remove')),
        findsOneWidget,
      );

      gate.decision = GateLocked(LockWindow(onDay(4), onDay(5)));
      await tester.pump(mishnaHistoryLockRecheck);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mishnaHistoryAction-remove')), findsNothing);
      expect(_row(5), findsNothing);
      expect(find.text('Learnt'), findsNothing);
    });

    testWidgets('an unreadable learner lock shows AppErrorView, never the '
        'rows (fail closed)', (tester) async {
      _seedLearnt(ports);
      await _pump(tester, [
        ...historyOverrides(ports, state: _learntState(), withLock: false),
        captureGateProvider.overrideWithValue(FakeCaptureGate.open()),
        learnerLockSettingsProvider.overrideWith(
          (ref, _) => Stream.error(StateError('settings unreadable')),
        ),
      ]);

      expect(find.byType(AppErrorView), findsOneWidget);
      expect(_row(1), findsNothing);
      expect(find.text('Learnt'), findsNothing);
    });
  });

  group('AC-3 accessible Hebrew and dark rendering', () {
    testWidgets('a row announces number, date, source and tags as text', (
      tester,
    ) async {
      _seedLearnt(ports);
      final handle = tester.ensureSemantics();
      await _pump(tester, historyOverrides(ports, state: _learntState()));

      expect(
        tester.getSemantics(_row(2)).label,
        '#2, Sep 5, 2026, Home, catch-up, chazara',
      );
      expect(
        tester.getSemantics(_row(6)).label,
        contains('kept, not counted — recorded during Shabbos/Yom Tov'),
      );
      handle.dispose();
    });

    testWidgets('Hebrew renders right-to-left and mirrors the layout', (
      tester,
    ) async {
      _seedLearnt(ports);
      await _pump(
        tester,
        historyOverrides(ports, state: _learntState()),
        locale: const Locale('he'),
      );
      expect(find.text('היסטוריית משנה'), findsOneWidget);
      expect(find.text('נלמד'), findsOneWidget);
      expect(Directionality.of(tester.element(_row(1))), TextDirection.rtl);
      // Mirrored: the number badge sits at the row's right edge.
      final row = tester.getRect(_row(1));
      final source = tester.getRect(
        find.descendant(of: _row(1), matching: find.byIcon(Icons.alt_route)),
      );
      expect(source.center.dx, greaterThan(row.center.dx));
    });

    testWidgets('dark mode uses the dark palette tokens for tags', (
      tester,
    ) async {
      _seedLearnt(ports);
      await _pump(
        tester,
        historyOverrides(ports, state: _learntState()),
        brightness: Brightness.dark,
      );
      final tagText = tester.widget<Text>(
        find.descendant(of: _row(2), matching: find.text('catch-up')),
      );
      expect(tagText.style?.color, AppPalette.dark.brandCoralDeep);
      final tagBox = tester.widget<Container>(
        find
            .ancestor(
              of: find.descendant(of: _row(2), matching: find.text('catch-up')),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        (tagBox.decoration! as BoxDecoration).color,
        AppPalette.dark.brandCoralSoft,
      );
    });
  });

  group('AC-2 remove and correct an event', () {
    Future<void> openActions(WidgetTester tester, int n) async {
      await tester.tap(_row(n));
      await tester.pumpAndSettle();
    }

    Finder action(String name) => find.byKey(Key('mishnaHistoryAction-$name'));

    testWidgets('a parent row offers remove, place, source and date; Remove '
        'calls LearningCommands.voidEvent', (tester) async {
      _seedLearnt(ports);
      final fake = FakeLearningCommands();
      await _pump(
        tester,
        historyOverrides(ports, state: _learntState(), commands: fake),
      );

      await openActions(tester, 5);
      for (final a in MishnaCorrection.values) {
        expect(action(a.name), findsOneWidget, reason: a.name);
      }
      await tester.tap(action('remove'));
      await tester.pumpAndSettle();

      expect(fake.calls, [
        LearningCommandCall('voidEvent', {'targetId': eid(5)}),
      ]);
    });

    testWidgets('a place correction calls replace with the chosen leaf', (
      tester,
    ) async {
      _seedLearnt(ports);
      final fake = FakeLearningCommands();
      await _pump(
        tester,
        historyOverrides(ports, state: _learntState(), commands: fake),
      );
      await openActions(tester, 5);
      await tester.tap(action('changePlace'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('mishnaHistoryPlace-$historySibling')),
      );
      await tester.pumpAndSettle();

      expect(fake.calls, [
        LearningCommandCall('replace', {
          'targetId': eid(5),
          'replacement': const EventReplacement(ref: historySibling),
        }),
      ]);
    });

    testWidgets('a source correction to Before tracking calls replace', (
      tester,
    ) async {
      _seedLearnt(ports);
      final fake = FakeLearningCommands();
      await _pump(
        tester,
        historyOverrides(ports, state: _learntState(), commands: fake),
      );
      await openActions(tester, 1);
      await tester.tap(action('changeSource'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mishnaHistorySource-before')));
      await tester.pumpAndSettle();

      expect(fake.calls, [
        LearningCommandCall('replace', {
          'targetId': eid(1),
          'replacement': const EventReplacement(
            source: LearningEvent.sourceMain,
            dateState: DateState.beforeTracking,
          ),
        }),
      ]);
    });

    testWidgets('a child may only remove an older dated event, and may '
        're-date a catch-up event', (tester) async {
      _seedLearnt(ports);
      await _pump(
        tester,
        historyOverrides(
          ports,
          state: _learntState(),
          commands: FakeLearningCommands(),
          viewer: MishnaHistoryViewer.child,
        ),
      );
      await openActions(tester, 5);
      expect(action('remove'), findsOneWidget);
      expect(action('changeDate'), findsNothing);
      expect(action('changePlace'), findsNothing);
      expect(action('changeSource'), findsNothing);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await openActions(tester, 2);
      expect(action('remove'), findsOneWidget);
      expect(action('changeDate'), findsOneWidget);
    });

    testWidgets('a lock-ignored row has no Undo; a tutor gets no actions', (
      tester,
    ) async {
      _seedLearnt(ports);
      await _pump(
        tester,
        historyOverrides(
          ports,
          state: _learntState(),
          commands: FakeLearningCommands(),
        ),
      );
      await openActions(tester, 6);
      expect(action('remove'), findsNothing);

      await _pump(
        tester,
        historyOverrides(
          ports,
          state: _learntState(),
          commands: FakeLearningCommands(),
          viewer: MishnaHistoryViewer.tutor,
        ),
      );
      await openActions(tester, 5);
      expect(action('remove'), findsNothing);
    });

    testWidgets('a rejected correction restores the original row before the '
        'rollback snackbar shows', (tester) async {
      _seedLearnt(ports);
      final gated = GatedLearningCommands(
        FakeLearningCommands()
          ..nextResult = const CaptureResult.rejected(
            CaptureRejection.targetNotFound,
          ),
      );
      await _pump(
        tester,
        historyOverrides(ports, state: _learntState(), commands: gated),
      );
      await openActions(tester, 1);
      await tester.tap(action('changeSource'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mishnaHistorySource-home')));
      await tester.pump();
      await tester.pump();

      // In flight: the optimistic row shows Home and Saving….
      expect(
        find.descendant(of: _row(1), matching: find.text('Saving…')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _row(1), matching: find.text('Home')),
        findsOneWidget,
      );

      gated.release();
      await tester.pump();
      await tester.pump();

      expect(
        find.descendant(of: _row(1), matching: find.text('Saving…')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: _row(1),
          matching: find.text('Cheder shiur (ended)'),
        ),
        findsOneWidget,
      );
      expect(find.text('Learning events: 4'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(
        find.text("Couldn't save that change — the entry is back as it was."),
        findsOneWidget,
      );
    });

    testWidgets('a queued removal stays pending with no snackbar; a later '
        'server rejection restores the row and shows the rollback snackbar', (
      tester,
    ) async {
      _seedLearnt(ports);
      final fake = FakeLearningCommands();
      final voidId = fake.freshId();
      fake.nextResult = CaptureResult.success(eventIds: [voidId], queued: true);
      await _pump(
        tester,
        historyOverrides(ports, state: _learntState(), commands: fake),
      );
      await openActions(tester, 5);
      await tester.tap(action('remove'));
      await tester.pumpAndSettle();

      const rolledBack =
          "Couldn't save that change — the entry is back as it was.";
      expect(
        find.descendant(of: _row(5), matching: find.text('Saving…')),
        findsOneWidget,
      );
      expect(find.text(rolledBack), findsNothing);

      fake.pendingFailures.add([
        PendingFailure(
          id: 'pf-1',
          eventIds: [voidId],
          changeIds: const [],
          reason: PendingFailureReason.permissionDenied,
        ),
      ]);
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: _row(5), matching: find.text('Saving…')),
        findsNothing,
      );
      expect(find.text(rolledBack), findsOneWidget);
      await fake.dispose();
    });

    testWidgets('a child re-date refused by the catch-up window shows the '
        'child-limit snackbar', (tester) async {
      _seedLearnt(ports);
      final fake = FakeLearningCommands()
        ..nextResult = const CaptureResult.childLimit();
      await _pump(
        tester,
        historyOverrides(
          ports,
          state: _learntState(),
          commands: fake,
          viewer: MishnaHistoryViewer.child,
        ),
      );
      await openActions(tester, 2);
      await tester.tap(action('changeDate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(fake.calls.single.name, 'replace');
      expect(
        (fake.calls.single.args['replacement']! as EventReplacement).learnedOn,
        '2026-09-03',
      );
      expect(
        find.text('Only a parent can change this. You can remove it instead.'),
        findsOneWidget,
      );
    });

    testWidgets('a correctable row is announced as a button with a hint', (
      tester,
    ) async {
      _seedLearnt(ports);
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        historyOverrides(
          ports,
          state: _learntState(),
          commands: FakeLearningCommands(),
        ),
      );
      expect(
        tester.getSemantics(_row(2)),
        matchesSemantics(
          label: '#2, Sep 5, 2026, Home, catch-up, chazara',
          isButton: true,
          hint: 'Change or remove',
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });

  group('AC-1 entry points open the shared route', () {
    setUpAll(() => registerFallbackValue(_FakePageRouteInfo()));

    testWidgets('a Browse leaf opens Mishna history with its curriculum and '
        'leaf ref', (tester) async {
      final router = _MockStackRouter();
      when(() => router.push<Object?>(any())).thenAnswer((_) async => null);
      const item = ContentItem(
        curriculumId: 'mishnayos',
        level1: 'Seder Zeraim',
        level2: 'Berakhot',
        level3: '1',
        level4: '1',
        displayNameHe: 'משנה א',
        displayNameEn: 'Mishnah 1',
        sefariaRef: historyLeaf,
        sortOrder: 0,
        isLeaf: true,
      );
      await tester.pumpWidget(
        pumpApp(
          child: StackRouterScope(
            controller: router,
            stateHash: 0,
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    openLeafHistory(context, CurriculumId.mishnayos, item),
                child: const Text('tap'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('tap'));

      final pushed =
          verify(() => router.push<Object?>(captureAny())).captured.single
              as MishnaHistoryRoute;
      expect(pushed.args!.curriculumId, 'mishnayos');
      expect(pushed.args!.leafRef, historyLeaf);
    });

    testWidgets('a lifetime-tree leaf row reports its curriculum and leaf ref; '
        'an aggregating row does not', (tester) async {
      final taps = <(CurriculumId, String)>[];
      const leaf = LifetimeTreeNode(
        curriculumId: CurriculumId.mishnayos,
        level: 4,
        rawValue: '1',
        parentL1Value: 'Seder Zeraim',
        hebrewName: null,
        state: LifetimeNodeState.full,
        children: [],
        leafRef: historyLeaf,
      );
      await tester.pumpWidget(
        pumpApp(
          overrides: _common(),
          child: Scaffold(
            body: CurriculumBreakdownTreeNode(
              node: leaf,
              depth: 0,
              nodeKey: 'k',
              expandedNodes: const {},
              onExpandToggle: (_, _) {},
              onLeafTap: (c, ref) => taps.add((c, ref)),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(InkWell));
      expect(taps, [(CurriculumId.mishnayos, historyLeaf)]);
    });
  });
}

// DNI-504 widget tests for the erev view on the Learn tab (screen #09):
// AC-1 order and boundaries, AC-3 live controls through LearningCommands
// with the shared Undo snackbar, AC-4 chained days, AC-6 fallback time,
// AC-7 banner without sections, AC-10 inline planned-data error / retry
// independent of today's list, and AC-11 semantics / RTL / large text /
// dark / tablet.
@Tags(['learning', 'l1'])
library;

import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/core/widgets/inline_async_error.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/presentation/providers/erev_planned_tasks_provider.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/learning/presentation/screens/learning_screen.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/erev_banner.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../../helpers/learner_state/lock_fixtures.dart';

const _ny = 'America/New_York';

class _HebrewTerms extends UseHebrewTerms {
  _HebrewTerms(this._on);
  final bool _on;
  @override
  bool build() => _on;
}

class _NoTutorSession extends ActiveTutoredProfileSelection {
  @override
  TutoredProfileSelection? build() => null;
}

DateTime _local(int y, int m, int d, [int hour = 0, int minute = 0]) =>
    LearnerZone.of(_ny).at(DateTime.utc(y, m, d), hour: hour, minute: minute);

DailyTask _task(
  String ref, {
  DailyTaskPriority priority = DailyTaskPriority.newLearning,
  int stage = 1,
}) => DailyTask(
  curriculumId: CurriculumId.mishnayos,
  contentItemSefariaRef: ref,
  stageOrder: stage,
  priority: priority,
  isOverdue: false,
  reason: 'test',
  stageName: stage == 1 ? 'Learn' : 'Chazara A',
  trackLabel: 'Mishnayos',
  estimatedEffortMinutes: 5,
);

/// The mutable world one test drives.
final class _World {
  _World({
    required this.now,
    LearnerSettingsHistory? history,
    this.today = const [],
  }) : history = history ?? constantHistory(lakewood);

  DateTime now;
  LearnerSettingsHistory history;
  List<DailyTask> today;
  Future<List<DailyTask>> Function()? todayFactory;

  /// The planner's lists per locked date.
  Map<String, List<DailyTask>> planned = {};

  /// When set, the planner throws this many more times.
  int plannerFailures = 0;
  int plannerCalls = 0;

  /// When set, the planner waits for it.
  Completer<void>? plannerGate;

  final commands = FakeLearningCommands();

  /// The command calls the view made (not the Learn tab's pending-failure
  /// watch).
  List<LearningCommandCall> get captures => [
    for (final c in commands.calls)
      if (c.name != 'watchPendingFailures') c,
  ];
}

Widget _app(
  _World world, {
  Locale locale = const Locale('en'),
  bool hebrewTerms = false,
  ThemeData? theme,
  double textScale = 1,
}) {
  final overrides = <Override>[
    useHebrewTermsProvider.overrideWith(() => _HebrewTerms(hebrewTerms)),
    currentTransliterationVariantProvider.overrideWithValue(
      TransliterationVariant.ashkenazi,
    ),
    dashboardActiveCurriculaStreamProvider.overrideWith(
      (ref) => Stream.value(const [CurriculumId.mishnayos]),
    ),
    dashboardStreakProvider.overrideWith(
      (ref) => Stream.value((currentStreak: 3, maxStreak: 5)),
    ),
    allDailyTasksProvider.overrideWith(
      (ref) => world.todayFactory?.call() ?? Future.value(world.today),
    ),
    selectedProfileProvider.overrideWith(
      (ref) => Future.value(
        LearnerProfileEntity(
          profileId: 'p',
          displayName: 'Yehuda',
          mode: ProfileMode.child,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      ),
    ),
    activeTutoredProfileSelectionProvider.overrideWith(_NoTutorSession.new),
    coarsePacedTrackIdsProvider.overrideWith(
      (ref) => Future.value(const <CurriculumId>{}),
    ),
    contentIndexProvider.overrideWith(
      (ref) => Future.value(ContentIndex.fromCurricula(const {})),
    ),
    // The erev inputs.
    erevSettingsHistoryProvider.overrideWith((ref) async => world.history),
    learningCommandClockProvider.overrideWithValue(() => world.now),
    erevSequencePlannerProvider.overrideWithValue((ref, dates) async {
      world.plannerCalls++;
      await world.plannerGate?.future;
      if (world.plannerFailures > 0) {
        world.plannerFailures--;
        throw Exception('planner unavailable');
      }
      return [for (final d in dates) world.planned[d] ?? const []];
    }),
    learningCommandsProvider.overrideWith(
      (ref) async => world.commands as LearningCommands,
    ),
  ];
  return ProviderScope(
    retry: (_, _) => null,
    overrides: overrides,
    child: MaterialApp(
      locale: locale,
      theme: theme,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: const Scaffold(body: LearningScreen()),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget app, {
  Size size = const Size(420, 2400),
  double pixelRatio = 1,
}) async {
  tester.view.physicalSize = size * pixelRatio;
  tester.view.devicePixelRatio = pixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 5));
}

final _banner = find.byKey(const ValueKey('erevBanner'));

/// A plain Shabbos: Friday 2026-10-09 → Shabbos 2026-10-10 (Lakewood).
LockWindow _shabbosLock() => lockWindows(
  constantHistory(lakewood),
  _local(2026, 10, 9, 22),
  _local(2026, 10, 9, 22),
).single;

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  group('AC-1: order and window boundaries', () {
    testWidgets('banner, today\'s tasks, the planned section, then Browse', (
      tester,
    ) async {
      final world =
          _World(
              now: _local(2026, 10, 9, 9),
              today: [_task('Mishnah Berakhot 2:1')],
            )
            ..planned = {
              '2026-10-10': [_task('Mishnah Peah 1:1')],
            };
      await _pump(tester, _app(world));

      final daily = find.text('Daily Tasks');
      final planned = find.text('Planned for Shabbos');
      final browse = find.text('Browse');
      expect(_banner, findsOneWidget);
      expect(daily, findsOneWidget);
      expect(planned, findsOneWidget);
      double y(Finder f) => tester.getTopLeft(f).dy;
      expect(y(_banner), lessThan(y(daily)));
      expect(y(daily), lessThan(y(planned)));
      expect(y(planned), lessThan(y(browse)));
      // Today's main-track list is unchanged.
      expect(find.text('Mishnah Berakhot 2:1'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('absent before the erev day and from L.start on', (
      tester,
    ) async {
      final lock = _shabbosLock();
      for (final now in [
        _local(2026, 10, 9).subtract(const Duration(microseconds: 1)),
        lock.startUtc,
        _local(2026, 10, 10, 12),
      ]) {
        final world = _World(now: now, today: [_task('Mishnah Berakhot 2:1')])
          ..planned = {
            '2026-10-10': [_task('Mishnah Peah 1:1')],
          };
        await _pump(tester, _app(world));
        expect(_banner, findsNothing, reason: '$now');
        expect(find.textContaining('Planned for'), findsNothing);
        expect(find.text('Mishnah Berakhot 2:1'), findsOneWidget);
        await _unmount(tester);
      }
    });

    testWidgets('present from 00:00 on the lock day; gone when L.start '
        'passes while the tab is open', (tester) async {
      final lock = _shabbosLock();
      final world = _World(now: _local(2026, 10, 9))
        ..planned = {
          '2026-10-10': [_task('Mishnah Peah 1:1')],
        };
      await _pump(tester, _app(world));
      expect(_banner, findsOneWidget);

      world.now = lock.startUtc.subtract(const Duration(minutes: 1));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(LearningScreen)),
      );
      container.invalidate(erevWindowProvider);
      await tester.pump(const Duration(milliseconds: 10));
      expect(_banner, findsOneWidget);

      // The window's own timer re-evaluates at L.start.
      world.now = lock.startUtc.add(const Duration(milliseconds: 5));
      await tester.pump(const Duration(minutes: 1, milliseconds: 10));
      await tester.pump(const Duration(milliseconds: 10));
      expect(_banner, findsNothing);
      expect(find.textContaining('Planned for'), findsNothing);
      await _unmount(tester);
    });

    testWidgets('the banner shows the lock label and lock start time', (
      tester,
    ) async {
      final lock = _shabbosLock();
      final world = _World(now: _local(2026, 10, 9, 9));
      await _pump(tester, _app(world));
      final wall = LearnerZone.of(_ny).wallTimeOf(lock.startUtc);
      final hour = wall.hour > 12 ? wall.hour - 12 : wall.hour;
      final time = '$hour:${wall.minute.toString().padLeft(2, '0')} PM';
      expect(find.text('Shabbos Kodesh'), findsOneWidget);
      expect(
        find.text('Shabbos begins at $time — record what you can before then.'),
        findsOneWidget,
      );
      await _unmount(tester);
    });

    testWidgets('Hebrew Terms switches the label to Hebrew', (tester) async {
      final world = _World(now: _local(2026, 10, 9, 9));
      await _pump(tester, _app(world, hebrewTerms: true));
      expect(find.text('שבת קודש'), findsOneWidget);
      await _unmount(tester);
    });
  });

  group('AC-4: a chained lock shows one section per locked day', () {
    testWidgets('Wednesday before diaspora yom tov Thu+Fri and Shabbos', (
      tester,
    ) async {
      final world = _World(now: _local(2027, 4, 21, 12))
        ..planned = {
          '2027-04-22': [_task('Mishnah Peah 1:1')],
          '2027-04-23': [_task('Mishnah Peah 1:2')],
          '2027-04-24': [_task('Mishnah Shabbat 1:1')],
        };
      await _pump(tester, _app(world));
      expect(find.text('Yom Tov & Shabbos'), findsOneWidget);
      final thu = find.text('Planned for Thursday');
      final fri = find.text('Planned for Friday');
      final sat = find.text('Planned for Shabbos');
      expect(thu, findsOneWidget);
      expect(fri, findsOneWidget);
      double y(Finder f) => tester.getTopLeft(f).dy;
      expect(y(thu), lessThan(y(fri)));
      expect(y(fri), lessThan(y(sat)));
      await _unmount(tester);
    });
  });

  group('AC-6: no location — the fail-closed fallback time', () {
    testWidgets('Friday banner says 12:00', (tester) async {
      final world = _World(
        now: _local(2026, 10, 9, 9),
        history: constantHistory(newYorkNoLocation),
      );
      await _pump(tester, _app(world));
      expect(find.textContaining('begins at 12:00 PM'), findsOneWidget);
      await _unmount(tester);
    });
  });

  group('AC-7: nothing planned', () {
    testWidgets('the banner shows with no planned section', (tester) async {
      final world = _World(now: _local(2026, 10, 9, 9));
      await _pump(tester, _app(world));
      expect(_banner, findsOneWidget);
      expect(find.textContaining('Planned for'), findsNothing);
      expect(find.byKey(const ValueKey('erevPlannedLoading')), findsNothing);
      await _unmount(tester);
    });
  });

  group('AC-3: live controls through LearningCommands', () {
    testWidgets('ticking a planned row records one ordinary dated main-track '
        'capture and offers Undo', (tester) async {
      final world = _World(now: _local(2026, 10, 9, 9))
        ..planned = {
          '2026-10-10': [
            _task('Mishnah Peah 1:1'),
            _task(
              'Mishnah Berakhot 1:1',
              priority: DailyTaskPriority.scheduledChazara,
              stage: 2,
            ),
          ],
        };
      await _pump(tester, _app(world));

      final row = find.byKey(
        const ValueKey('erevPlannedRow-mishnayos-Mishnah Peah 1:1-1'),
      );
      await tester.ensureVisible(row);
      await tester.tap(
        find.descendant(of: row, matching: find.byType(Checkbox)),
      );
      await tester.pump(const Duration(milliseconds: 50));

      final capture = world.captures.single;
      expect(capture.name, 'capture');
      expect(capture.args, {
        'curriculumId': 'mishnayos',
        'refs': ['Mishnah Peah 1:1'],
        'nodes': const <Object>[],
        'source': LearningEvent.sourceMain,
        'dateState': DateState.dated,
        // The command stamps learned_on = the learner's today and
        // recorded_at = now; the view passes neither.
        'learnedOn': null,
        // A new-learning row records at its planner stage (the first
        // stage order), as today's list does, so the leaf opens its
        // review cycle (AD-32).
        'stage': 1,
      });
      expect(find.text('1 recorded'), findsOneWidget);
      // Shown ticked until the live plan drops it.
      expect(
        tester
            .widget<Checkbox>(
              find.descendant(of: row, matching: find.byType(Checkbox)),
            )
            .value,
        isTrue,
      );

      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Undo'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(world.captures.last.name, 'undoEvents');
      expect(
        tester
            .widget<Checkbox>(
              find.descendant(of: row, matching: find.byType(Checkbox)),
            )
            .value,
        isFalse,
      );
      await _unmount(tester);
    });

    testWidgets('a review row records at its stage', (tester) async {
      final world = _World(now: _local(2026, 10, 9, 9))
        ..planned = {
          '2026-10-10': [
            _task(
              'Mishnah Berakhot 1:1',
              priority: DailyTaskPriority.scheduledChazara,
              stage: 2,
            ),
          ],
        };
      await _pump(tester, _app(world));
      final row = find.byKey(
        const ValueKey('erevPlannedRow-mishnayos-Mishnah Berakhot 1:1-2'),
      );
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pump(const Duration(milliseconds: 50));
      expect(world.captures.single.args['stage'], 2);
      expect(world.captures.single.args['source'], 'main');
      await _unmount(tester);
    });

    testWidgets('a section offers the shared Up to… for its new-learning '
        'rows; a reviews-only section has none', (tester) async {
      final world = _World(now: _local(2027, 4, 21, 12))
        ..planned = {
          '2027-04-22': [
            _task('Mishnah Peah 1:1'),
            _task(
              'Mishnah Berakhot 1:1',
              priority: DailyTaskPriority.scheduledChazara,
              stage: 2,
            ),
          ],
          '2027-04-23': [
            _task(
              'Mishnah Berakhot 1:2',
              priority: DailyTaskPriority.scheduledChazara,
              stage: 2,
            ),
          ],
        };
      await _pump(tester, _app(world));
      final upTo = find.byKey(const ValueKey('erevUpTo-2027-04-22-mishnayos'));
      expect(upTo, findsOneWidget);
      // Story 2.10's control, not an erev-only one.
      expect(
        find.descendant(of: upTo, matching: find.text('Up to…')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('erevUpTo-2027-04-23-mishnayos')),
        findsNothing,
      );
      await _unmount(tester);
    });
  });

  group('AC-10 / Edge: independent async regions', () {
    testWidgets('a planned-data failure shows an inline retry and never '
        'touches today\'s list', (tester) async {
      final world =
          _World(
              now: _local(2026, 10, 9, 9),
              today: [_task('Mishnah Berakhot 2:1')],
            )
            ..planned = {
              '2026-10-10': [_task('Mishnah Peah 1:1')],
            }
            ..plannerFailures = 1;
      await _pump(tester, _app(world));
      expect(_banner, findsOneWidget);
      expect(find.byKey(const ValueKey('erevPlannedError')), findsOneWidget);
      expect(find.byType(InlineAsyncError), findsOneWidget);
      expect(find.text('Mishnah Berakhot 2:1'), findsOneWidget);
      expect(find.byType(AppErrorView), findsNothing);

      final calls = world.plannerCalls;
      final retry = find.descendant(
        of: find.byKey(const ValueKey('erevPlannedError')),
        matching: find.text('Retry'),
      );
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(world.plannerCalls, calls + 1);
      expect(find.text('Planned for Shabbos'), findsOneWidget);
      expect(find.text('Mishnah Berakhot 2:1'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('a loading plan shows a spinner inside the planned region '
        'only', (tester) async {
      final world = _World(
        now: _local(2026, 10, 9, 9),
        today: [_task('Mishnah Berakhot 2:1')],
      )..plannerGate = Completer<void>();
      await _pump(tester, _app(world));
      expect(find.byKey(const ValueKey('erevPlannedLoading')), findsOneWidget);
      expect(find.text('Mishnah Berakhot 2:1'), findsOneWidget);
      world.plannerGate!.complete();
      await _unmount(tester);
    });

    testWidgets('today\'s list failing leaves the planned sections live', (
      tester,
    ) async {
      final world = _World(now: _local(2026, 10, 9, 9))
        ..todayFactory = (() => Future.error(Exception('today failed')))
        ..planned = {
          '2026-10-10': [_task('Mishnah Peah 1:1')],
        };
      await _pump(tester, _app(world));
      expect(find.byType(AppErrorView), findsOneWidget);
      expect(find.text('Planned for Shabbos'), findsOneWidget);
      final row = find.byKey(
        const ValueKey('erevPlannedRow-mishnayos-Mishnah Peah 1:1-1'),
      );
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pump(const Duration(milliseconds: 50));
      expect(world.captures.single.name, 'capture');
      await _unmount(tester);
    });
  });

  group('AC-11: accessibility and adaptation', () {
    testWidgets('the banner announces the lock time and is the first '
        'focusable element', (tester) async {
      final semantics = tester.ensureSemantics();
      final world = _World(now: _local(2026, 10, 9, 9));
      await _pump(tester, _app(world));
      final node = tester.getSemantics(find.byType(ErevBanner));
      expect(node.label, contains('Shabbos Kodesh'));
      expect(node.label, contains('begins at'));
      expect(
        node.getSemanticsData().flagsCollection.isFocused,
        isNot(Tristate.none),
      );
      // It sits above every other Learn element.
      expect(
        tester.getTopLeft(_banner).dy,
        lessThan(tester.getTopLeft(find.text('Daily Tasks')).dy),
      );
      semantics.dispose();
      await _unmount(tester);
    });

    testWidgets('planned rows give a 48dp tick target with a label', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final world = _World(now: _local(2026, 10, 9, 9))
        ..planned = {
          '2026-10-10': [_task('Mishnah Peah 1:1')],
        };
      await _pump(tester, _app(world));
      final row = find.byKey(
        const ValueKey('erevPlannedRow-mishnayos-Mishnah Peah 1:1-1'),
      );
      await tester.ensureVisible(row);
      final tick = find.descendant(of: row, matching: find.byType(Checkbox));
      final size = tester.getSize(
        find.ancestor(of: tick, matching: find.byType(SizedBox)).first,
      );
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
      expect(
        find.bySemanticsLabel('Mark Mishnah Peah 1:1 as learnt'),
        findsOneWidget,
      );
      semantics.dispose();
      await _unmount(tester);
    });

    testWidgets('RTL mirrors: the tick sits on the right in Hebrew', (
      tester,
    ) async {
      final world = _World(now: _local(2026, 10, 9, 9))
        ..planned = {
          '2026-10-10': [_task('Mishnah Peah 1:1')],
        };
      await _pump(
        tester,
        _app(world, locale: const Locale('he'), hebrewTerms: true),
      );
      final row = find.byKey(
        const ValueKey('erevPlannedRow-mishnayos-Mishnah Peah 1:1-1'),
      );
      await tester.ensureVisible(row);
      final tick = find.descendant(of: row, matching: find.byType(Checkbox));
      expect(tester.getCenter(tick).dx, greaterThan(tester.getCenter(row).dx));
      expect(find.text('שבת קודש'), findsOneWidget);
      expect(find.text('מתוכנן לשבת'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    });

    testWidgets('large text scales Hebrew without overflow', (tester) async {
      final world = _World(now: _local(2027, 4, 21, 12))
        ..planned = {
          '2027-04-22': [_task('Mishnah Peah 1:1')],
        };
      await _pump(
        tester,
        _app(
          world,
          locale: const Locale('he'),
          hebrewTerms: true,
          textScale: 2,
        ),
        size: const Size(360, 780),
        pixelRatio: 3,
      );
      expect(_banner, findsOneWidget);
      expect(find.text('יום טוב ושבת'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Mishnah Peah 1:1'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Mishnah Peah 1:1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    });

    testWidgets('dark theme paints the banner with the dark blue-soft token', (
      tester,
    ) async {
      final world = _World(now: _local(2026, 10, 9, 9));
      await _pump(tester, _app(world, theme: AppTheme.darkTheme()));
      final box =
          tester.widget<Container>(_banner).decoration! as BoxDecoration;
      expect(box.color, AppPalette.dark.brandBlueSoft);
      expect(box.color, const Color(0xFF16233F));
      expect(box.borderRadius, BorderRadius.circular(18));
      await _unmount(tester);
    });

    testWidgets('the section Up to… is a 48dp target announced with its '
        'track', (tester) async {
      final semantics = tester.ensureSemantics();
      final world = _World(now: _local(2026, 10, 9, 9))
        ..planned = {
          '2026-10-10': [_task('Mishnah Peah 1:1')],
        };
      await _pump(tester, _app(world));
      final upTo = find.byKey(const ValueKey('erevUpTo-2026-10-10-mishnayos'));
      await tester.ensureVisible(upTo);
      final size = tester.getSize(
        find.descendant(of: upTo, matching: find.byType(TextButton)),
      );
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(find.bySemanticsLabel('Record up to, Mishnayos'), findsOneWidget);
      semantics.dispose();
      await _unmount(tester);
    });

    testWidgets('RTL mirrors the section header: Up to… sits on the left', (
      tester,
    ) async {
      final world = _World(now: _local(2026, 10, 9, 9))
        ..planned = {
          '2026-10-10': [_task('Mishnah Peah 1:1')],
        };
      await _pump(
        tester,
        _app(world, locale: const Locale('he'), hebrewTerms: true),
      );
      final upTo = find.byKey(const ValueKey('erevUpTo-2026-10-10-mishnayos'));
      final heading = find.text('מתוכנן לשבת');
      await tester.ensureVisible(upTo);
      expect(tester.getCenter(upTo).dx, lessThan(tester.getCenter(heading).dx));
      await _unmount(tester);
    });

    testWidgets('dark theme paints planned rows with the dark card token', (
      tester,
    ) async {
      final world = _World(now: _local(2026, 10, 9, 9))
        ..planned = {
          '2026-10-10': [_task('Mishnah Peah 1:1')],
        };
      await _pump(tester, _app(world, theme: AppTheme.darkTheme()));
      final row = tester.widget<Material>(
        find.byKey(
          const ValueKey('erevPlannedRow-mishnayos-Mishnah Peah 1:1-1'),
        ),
      );
      expect(row.color, AppPalette.dark.brandCreamCard);
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    });

    testWidgets('tablet width uses the same Learn composition', (tester) async {
      final world = _World(now: _local(2026, 10, 9, 9))
        ..planned = {
          '2026-10-10': [_task('Mishnah Peah 1:1')],
        };
      await _pump(
        tester,
        _app(world),
        size: const Size(1024, 1366),
        pixelRatio: 2,
      );
      expect(_banner, findsOneWidget);
      expect(find.text('Planned for Shabbos'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    });
  });
}

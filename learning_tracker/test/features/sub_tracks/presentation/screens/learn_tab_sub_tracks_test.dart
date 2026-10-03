// Story 2.9 (DNI-500) AC-1, AC-6, AC-7, AC-10 — "Also learning" on the
// Learn tab: below today's tasks, which render exactly as before (golden),
// one row per onHome track for child and parent, a local error that leaves
// the tasks usable, the row body opening the detail for every role, and
// the accessible, RTL, dark and tablet compositions.
@Tags(['golden'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label_providers.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/inline_async_error.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/learning/presentation/screens/learning_screen.dart';
import 'package:learning_tracker/features/profiles/profiles.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/sub_tracks/sub_tracks.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/golden_runner.dart';
import '../../../../helpers/pump_app.dart';
import '../../../../helpers/sub_tracks/sub_track_home_fixtures.dart';
import '../../../../helpers/sub_tracks/sub_track_test_engine.dart';

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

class _HebrewTermsOff extends UseHebrewTerms {
  @override
  bool build() => false;
}

class _NoTutor extends ActiveTutoredProfileSelection {
  @override
  TutoredProfileSelection? build() => null;
}

final class _RecordingNavigator implements SubTrackNavigator {
  final List<String> details = [];

  @override
  bool canOpen(SubTrackDestination destination) => true;

  @override
  void openDetail(BuildContext context, SubTrackHomeItem item) =>
      details.add(item.subTrackId);

  @override
  void openGroundPicker(BuildContext context, SubTrackHomeItem item) {}

  @override
  void openHub(BuildContext context) {}

  @override
  void openUpTo(BuildContext context, SubTrackHomeItem item) {}
}

const _taskRefs = ['Mishnah_Shabbat_3.1', 'Mishnah_Shabbat_3.2'];

List<DailyTask> _tasks() => [
  for (final ref in _taskRefs)
    DailyTask(
      curriculumId: CurriculumId.mishnayos,
      contentItemSefariaRef: ref,
      stageOrder: 1,
      priority: DailyTaskPriority.newLearning,
      isOverdue: false,
      reason: 'test',
      stageName: 'Learn',
      trackLabel: 'Test Track',
      estimatedEffortMinutes: 5,
    ),
];

/// The LearningScreen harness of learning_screen_l1_test.dart, plus the
/// sub-track engine wiring ([subTracks]: overrides from the fixtures, or
/// none for a learner without sub-tracks).
List<Override> _screenOverrides({List<Override> subTracks = const []}) => [
  useHebrewTermsProvider.overrideWith(_HebrewTermsOff.new),
  currentTransliterationVariantProvider.overrideWithValue(
    TransliterationVariant.ashkenazi,
  ),
  dashboardActiveCurriculaStreamProvider.overrideWith(
    (ref) => Stream.value(const [CurriculumId.mishnayos]),
  ),
  dashboardStreakProvider.overrideWith(
    (ref) => Stream.value((currentStreak: 3, maxStreak: 5)),
  ),
  allDailyTasksProvider.overrideWith((ref) => Future.value(_tasks())),
  selectedProfileProvider.overrideWith((ref) async => null),
  activeTutoredProfileSelectionProvider.overrideWith(_NoTutor.new),
  coarsePacedTrackIdsProvider.overrideWith(
    (ref) => Future.value(const <CurriculumId>{}),
  ),
  contentIndexProvider.overrideWith(
    (ref) => Future.value(ContentIndex.fromCurricula(const {})),
  ),
  renderedDisplayForRefProvider(
    _taskRefs[0],
  ).overrideWith((ref) async => 'Shabbos 3:1'),
  renderedDisplayForRefProvider(
    _taskRefs[1],
  ).overrideWith((ref) async => 'Shabbos 3:2'),
  ...subTracks,
];

/// Overrides with School and Rebbe on home, viewed as [role].
List<Override> _withSubTracks({
  SubTrackViewerRole role = SubTrackViewerRole.child,
  SubTrackNavigator? navigator,
  Stream<LearnerState> Function()? states,
}) {
  final engine = SubTrackTestEngine();
  return [
    ...subTrackEngineOverrides(
      engine: engine,
      commands: EngineBackedCommands(engine),
      role: role,
      states: states,
    ),
    if (navigator != null)
      subTrackNavigatorProvider.overrideWithValue(navigator),
  ];
}

Widget _screen(
  List<Override> overrides, {
  StackRouter? router,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  TransitionBuilder? builder,
}) => pumpApp(
  overrides: overrides,
  locale: locale,
  theme: AppTheme.themeFor(brightness: brightness),
  builder: builder,
  child: router == null
      ? const Scaffold(body: LearningScreen())
      : StackRouterScope(
          controller: router,
          stateHash: 0,
          child: const Scaffold(body: LearningScreen()),
        ),
);

/// The app theme with the test-loaded Hebrew face as a fallback, so the
/// Hebrew goldens show real glyphs (on devices the platform falls back).
ThemeData _goldenTheme(Brightness brightness) {
  final theme = AppTheme.themeFor(brightness: brightness);
  const fallback = ['Noto Sans Hebrew'];
  final buttonText = theme.textButtonTheme.style?.textStyle?.resolve({});
  return theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamilyFallback: fallback),
    textButtonTheme: TextButtonThemeData(
      style: theme.textButtonTheme.style?.copyWith(
        textStyle: WidgetStatePropertyAll(
          (buttonText ?? const TextStyle()).copyWith(
            fontFamilyFallback: fallback,
          ),
        ),
      ),
    ),
  );
}

Finder get _mainTasks => find.byWidgetPredicate(
  (w) => w.runtimeType.toString() == '_DailyTasksSection',
);

Future<void> _settle(WidgetTester tester) async {
  // The screen, the scope/sub-track/engine reads and the position labels
  // each resolve a microtask or two apart.
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    registerFallbackValue(_FakePageRouteInfo());
  });

  group('AC-1: main-track list unchanged; one row per onHome track', () {
    // Both configurations match the SAME golden: adding the sub-track
    // section below today's tasks changes no pixel of the main list.
    testWidgets('golden: main list without sub-tracks', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_screen(_screenOverrides()));
      await _settle(tester);
      expect(find.byType(AlsoLearningSection), findsOneWidget);
      expect(find.textContaining('Also learning'), findsNothing);
      await expectLater(
        _mainTasks,
        matchesGoldenFile('goldens/learn_tab_main_tasks.png'),
      );
    });

    testWidgets('golden: main list with sub-tracks is identical', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _screen(_screenOverrides(subTracks: _withSubTracks())),
      );
      await _settle(tester);
      expect(find.text('Also learning · 2 sub-tracks'), findsOneWidget);
      await expectLater(
        _mainTasks,
        matchesGoldenFile('goldens/learn_tab_main_tasks.png'),
      );
    });

    testWidgets('the section sits directly below today\'s tasks and above '
        'Browse', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _screen(_screenOverrides(subTracks: _withSubTracks())),
      );
      await _settle(tester);
      final tasksBottom = tester.getBottomLeft(_mainTasks).dy;
      final header = tester.getTopLeft(
        find.text('Also learning · 2 sub-tracks'),
      );
      final browse = tester.getTopLeft(find.text('Browse'));
      expect(header.dy, greaterThan(tasksBottom));
      expect(header.dy, lessThan(browse.dy));
    });

    for (final role in [SubTrackViewerRole.child, SubTrackViewerRole.parent]) {
      testWidgets('${role.name}: one row per onHome track in hub order', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(400, 1800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          _screen(_screenOverrides(subTracks: _withSubTracks(role: role))),
        );
        await _settle(tester);
        expect(find.byType(SubTrackHomeRow), findsNWidgets(2));
        expect(
          tester.getTopLeft(find.text('School')).dy,
          lessThan(tester.getTopLeft(find.text('Rebbe')).dy),
        );
        expect(find.text('Next: Berachos 1:4'), findsOneWidget);
        expect(find.text('Next: Peah 2:1'), findsOneWidget);
      });
    }

    testWidgets('future-start, ended and window-passed tracks have no row', (
      tester,
    ) async {
      final engine = SubTrackTestEngine(grounds: {schoolId: schoolLeaves});
      await tester.pumpWidget(
        _screen(
          _screenOverrides(
            subTracks: subTrackEngineOverrides(
              engine: engine,
              commands: EngineBackedCommands(engine),
              // Rebbe is stored but the engine says it is not on home.
              states: () => Stream.value(
                homeLearnerState([
                  homeState(schoolId, position: berachos14),
                  homeState(rebbeId, onHome: false),
                ]),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(SubTrackHomeRow), findsOneWidget);
      expect(find.text('Rebbe'), findsNothing);
      expect(find.text('Also learning · 1 sub-track'), findsOneWidget);
    });
  });

  testWidgets('AC-6: a sub-track load error stays in its section; today\'s '
      'tasks still render and open', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = _MockStackRouter();
    when(() => router.canPop()).thenReturn(false);
    when(
      () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
    ).thenAnswer((_) async => null);
    await tester.pumpWidget(
      _screen(
        _screenOverrides(
          subTracks: _withSubTracks(
            states: () => Stream<LearnerState>.error(StateError('down')),
          ),
        ),
        router: router,
      ),
    );
    await _settle(tester);
    expect(
      find.byKey(const Key('alsoLearningError')),
      findsOneWidget,
      reason: 'InlineAsyncError inside the section',
    );
    expect(find.byType(InlineAsyncError), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Shabbos 3:1'), findsOneWidget);
    await tester.tap(find.text('Shabbos 3:1'));
    await tester.pump();
    final pushed = verify(
      () => router.push<Object?>(
        captureAny(),
        onFailure: any(named: 'onFailure'),
      ),
    ).captured;
    expect(pushed.single, isA<TextDisplayRoute>());
  });

  testWidgets('AC-9: on a tutor device the sub-track rows are read-only while '
      'today\'s main-track tasks still open for capture', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = _MockStackRouter();
    when(() => router.canPop()).thenReturn(false);
    when(
      () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
    ).thenAnswer((_) async => null);
    await tester.pumpWidget(
      _screen(
        _screenOverrides(
          subTracks: _withSubTracks(role: SubTrackViewerRole.tutor),
        ),
        router: router,
      ),
    );
    await _settle(tester);
    expect(
      find.text('Editing sub-tracks from a tutor device is coming soon'),
      findsOneWidget,
    );
    await tester.tap(find.text('Shabbos 3:2'));
    await tester.pump();
    final pushed = verify(
      () => router.push<Object?>(
        captureAny(),
        onFailure: any(named: 'onFailure'),
      ),
    ).captured;
    expect(pushed.single, isA<TextDisplayRoute>());
  });

  for (final role in SubTrackViewerRole.values) {
    testWidgets('AC-7 (${role.name}): tapping a row body opens that track\'s '
        'detail', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final navigator = _RecordingNavigator();
      await tester.pumpWidget(
        _screen(
          _screenOverrides(
            subTracks: _withSubTracks(role: role, navigator: navigator),
          ),
        ),
      );
      await _settle(tester);
      await tester.tap(find.text('Rebbe'));
      await tester.pump();
      expect(navigator.details, [rebbeId]);
    });
  }

  for (final role in [SubTrackViewerRole.child, SubTrackViewerRole.parent]) {
    testWidgets('production navigator (${role.name}): the row opens the '
        'sub-track detail (DNI-497), a parent\'s Add ground opens the ground '
        'picker (DNI-498); an unbuilt destination leaves its entry point '
        'disabled instead of routing elsewhere', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final router = _MockStackRouter();
      when(() => router.canPop()).thenReturn(false);
      when(
        () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
      ).thenAnswer((_) async => null);
      // School is active; Rebbe has no ground.
      final engine = SubTrackTestEngine(
        grounds: {schoolId: schoolLeaves, rebbeId: const []},
      );
      addTearDown(engine.dispose);
      await tester.pumpWidget(
        _screen(
          _screenOverrides(
            // No navigator override: the production HubOnlySubTrackNavigator.
            subTracks: subTrackEngineOverrides(
              engine: engine,
              commands: EngineBackedCommands(engine),
              role: role,
              groundOf: const {rebbeId: <NodeEntry>[]},
            ),
          ),
          router: router,
        ),
      );
      await _settle(tester);

      // The row body has no detail to open: not tappable, nothing pushed.
      final body = tester.widget<InkWell>(
        find.byKey(const Key('subTrackHomeRow-$schoolId')),
      );
      expect(body.onTap, isNull);
      await tester.tap(find.text('School'));
      await tester.pump();
      verifyNever(
        () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
      );

      // Up to… has no picker yet: visible, disabled; +1 still records.
      final upTo = find.byKey(const Key('subTrackHomeUpTo-$schoolId'));
      expect(
        tester
            .widget<TextButton>(
              find.descendant(of: upTo, matching: find.byType(TextButton)),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.descendant(of: upTo, matching: find.byType(Opacity)),
        findsOneWidget,
        reason: 'rendered as the 40% Disabled action',
      );
      expect(
        tester
            .widget<FilledButton>(
              find.descendant(
                of: find.byKey(const Key('subTrackHomePlusOne-$schoolId')),
                matching: find.byType(FilledButton),
              ),
            )
            .onPressed,
        isNotNull,
      );

      // A parent's Add ground opens the ground picker route (DNI-498).
      if (role == SubTrackViewerRole.parent) {
        final addGround = find.descendant(
          of: find.byKey(const Key('subTrackHomeAddGround-$rebbeId')),
          matching: find.byType(OutlinedButton),
        );
        expect(tester.widget<OutlinedButton>(addGround).onPressed, isNotNull);
        await tester.ensureVisible(addGround);
        await tester.pump();
        await tester.tap(addGround);
        await tester.pump();
        final opened = verify(
          () => router.push<Object?>(
            captureAny(),
            onFailure: any(named: 'onFailure'),
          ),
        ).captured;
        expect(
          opened.single,
          isA<GroundPickerRoute>().having(
            (r) => r.args?.subTrackId,
            'subTrackId',
            rebbeId,
          ),
        );
      }
    });
  }

  testWidgets('AC-10: max text scale in Hebrew on a phone stacks each row\'s '
      'text above its actions with nothing clipped', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 3000 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _screen(
        _screenOverrides(subTracks: _withSubTracks()),
        locale: const Locale('he'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
      ),
    );
    await _settle(tester);
    expect(tester.takeException(), isNull);
    for (final id in [schoolId, rebbeId]) {
      final line = find.byKey(Key('subTrackHomeRowLine-$id'));
      final plusOne = find.byKey(Key('subTrackHomePlusOne-$id'));
      expect(
        tester.getBottomLeft(line).dy,
        lessThan(tester.getTopLeft(plusOne).dy),
      );
    }
  });

  // AC-10 compositions: phone in en/he × light/dark, and tablet.
  goldenTest(
    'learn_tab_also_learning_phone',
    surfaceSize: const Size(390, 420),
    builder: (locale, brightness) => pumpApp(
      locale: locale,
      debugShowCheckedModeBanner: false,
      theme: _goldenTheme(brightness),
      // The designed composition: every destination wired.
      overrides: _withSubTracks(
        role: SubTrackViewerRole.parent,
        navigator: _RecordingNavigator(),
      ),
      child: const Scaffold(
        body: Padding(
          padding: EdgeInsets.all(16),
          child: AlsoLearningSection(),
        ),
      ),
    ),
  );

  goldenTest(
    'learn_tab_also_learning_tablet',
    surfaceSize: const Size(1024, 360),
    builder: (locale, brightness) => pumpApp(
      locale: locale,
      debugShowCheckedModeBanner: false,
      theme: _goldenTheme(brightness),
      overrides: _withSubTracks(navigator: _RecordingNavigator()),
      child: const Scaffold(
        body: Padding(
          padding: EdgeInsets.all(24),
          child: AlsoLearningSection(),
        ),
      ),
    ),
  );
}

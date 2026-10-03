// Story 5.3 (DNI-518) AC-9, AC-10: the Per-source pace and On-track
// sections show for an evaluated curriculum in a parent session only.
//
// AC-9 runs both a fake state and the real `LearnerStateEngine` (retired
// and archived main tracks). AC-10 resolves the report in child mode by a
// direct deep link, by nested navigation from Lifetime and by a PIN lock
// on an open report, through a real AppRouter whose other guards let
// everything through.
@Tags(['progress', 'lifetime', 'route_guards', 'story_5_3'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/navigation/guards/child_mode_guard.dart';
import 'package:learning_tracker/core/navigation/guards/parent_session_guard.dart';
import 'package:learning_tracker/core/navigation/guards/pin_guard.dart';
import 'package:learning_tracker/core/navigation/guards/profile_guard.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/features/learner_state/data/repositories/learner_state_sources.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_pin_session_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_session_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/items_learned_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_report_provider.dart';
import 'package:learning_tracker/features/progress/presentation/screens/lifetime_knowledge_screen.dart';
import 'package:learning_tracker/features/progress/presentation/screens/lifetime_report_screen.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/lifetime_report_sections.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/on_track_report_block.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/per_source_pace_section.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_windows_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/progress/lifetime_report_fixtures.dart';
import '../../../../helpers/progress/pace_report_fixtures.dart';
import '../../../../helpers/pump_app.dart';

final _paceSection = find.byType(PerSourcePaceSection);
final _onTrack = find.byType(OnTrackReportBlock);
final _totals = find.byType(LifetimeReportTotals);
final _entry = find.byKey(const ValueKey('lifetimeReportEntry'));

/// Text that may only ever reach a parent (NFR-9, UX-DR-48).
const _parentOnly = [
  'Per-source pace',
  '/ week',
  'Too early to tell',
  'On track',
  'Behind pace',
  'Projected finish',
  'Daily target',
  'may not reach',
  'behind the calendar',
  'Goal status',
];

/// Every painted string and every semantics label on screen.
Iterable<String> _everything(WidgetTester tester) sync* {
  for (final t in tester.widgetList<RichText>(find.byType(RichText))) {
    yield t.text.toPlainText();
  }
  for (final s in tester.widgetList<Semantics>(find.byType(Semantics))) {
    if (s.properties.label case final label?) yield label;
    if (s.properties.tooltip case final tooltip?) yield tooltip;
  }
  for (final t in tester.widgetList<Tooltip>(find.byType(Tooltip))) {
    if (t.message case final message?) yield message;
  }
}

void _expectNoParentData(WidgetTester tester) {
  expect(_paceSection, findsNothing);
  expect(_onTrack, findsNothing);
  for (final text in _everything(tester)) {
    for (final banned in _parentOnly) {
      expect(text, isNot(contains(banned)), reason: '"$text" in child mode');
    }
  }
}

Future<void> _pumpScreen(WidgetTester tester, LearnerState state) async {
  await tester.binding.setSurfaceSize(const Size(400, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final overrides = <Override>[
    parentSessionProvider.overrideWith((ref) async => true),
    effectiveUseHebrewTermsProvider.overrideWithValue(false),
    activeLearnerScopeProvider.overrideWith((ref) async => c0Scope()),
    learnerStateProvider.overrideWith((ref, _) => Stream.value(state)),
  ];
  await tester.pumpWidget(
    pumpApp(
      child: const LifetimeReportScreen(curriculumId: reportCurriculum),
      overrides: overrides,
    ),
  );
  await tester.pumpAndSettle();
}

/// The real engine over a main track in [state] with three weeks of
/// dated learning and a deadline.
LearnerState _engineState(MainTrackState state) =>
    const LearnerStateEngine().run(
      engineInputs(
        nowUtc: DateTime.utc(2026, 10, 8, 12),
        intents: {
          engineCurriculum: MainTrackIntent(
            curriculumId: engineCurriculum,
            track: MainTrack(curriculumId: engineCurriculum, state: state),
            program: MainTrackProgram(
              curriculumId: engineCurriculum,
              trackingStartDate: '2026-09-01',
            ),
          ),
        },
        events: [
          engineLearn(1, 'Mishnah Berakhot 1:1', learnedOn: '2026-09-20'),
          engineLearn(2, 'Mishnah Berakhot 1:2', learnedOn: '2026-10-01'),
        ],
      ),
    );

class _AllowAll extends AutoRouteGuard {
  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) =>
      resolver.next(true);
}

class _PinService extends Mock implements PinService {}

final class _AllowProfile extends ProfileGuard {
  _AllowProfile()
    : super(
        getProfiles: () async => const [],
        getSelectedProfileId: () => null,
        setSelectedProfileId: (_) {},
        isTutoredSession: () => false,
        profilePickerRoute: () => const SettingsRoute(),
      );

  @override
  Future<void> onNavigation(
    NavigationResolver resolver,
    StackRouter router,
  ) async => resolver.next(true);
}

final class _AllowChildMode extends ChildModeGuard {
  _AllowChildMode()
    : super(
        getProfileById: (_) async => null,
        getSelectedProfileId: () => null,
      );

  @override
  Future<void> onNavigation(
    NavigationResolver resolver,
    StackRouter router,
  ) async => resolver.next(true);
}

final class _AllowPin extends PinGuard {
  _AllowPin()
    : super(
        pinService: _PinService(),
        promptForPin: () async => true,
        getScope: () => null,
        pinSetupRoute: () => const SettingsRoute(),
      );

  @override
  Future<void> onNavigation(
    NavigationResolver resolver,
    StackRouter router,
  ) async => resolver.next(true);
}

const _profileId = 'profile-1';

/// A child profile on the real router; [unlocked] starts it with the
/// parent PIN entered.
class _ChildHarness {
  _ChildHarness({bool unlocked = false}) {
    container = ProviderContainer(
      // Counts every lifetime report the session builds (reads of the
      // real provider), without replacing it.
      observers: [_ReportReads(() => reportReads++)],
      overrides: [
        activeProfileProvider.overrideWith(
          (ref) async => LearnerProfileEntity(
            profileId: _profileId,
            displayName: 'Yehuda',
            mode: ProfileMode.child,
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
          ),
        ),
        effectiveUseHebrewTermsProvider.overrideWithValue(false),
        currentSacredWindowProvider.overrideWithValue(null),
        activeLearnerScopeProvider.overrideWith((ref) async => c0Scope()),
        learnerStateProvider.overrideWith((ref, _) {
          return Stream.value(paceState([paceCurriculumState(paceReport())]));
        }),
        lifetimeViewSummariesProvider.overrideWith((ref) async => const []),
        itemsLearnedSummariesProvider.overrideWith((ref) async => const []),
        lifetimeHeaderCountersProvider.overrideWith(
          (ref) async =>
              const LifetimeHeaderCounters(itemsLearned: 0, totalChazaros: 0),
        ),
        trackOnlyHeaderCountersProvider.overrideWith(
          (ref) async =>
              const LifetimeHeaderCounters(itemsLearned: 0, totalChazaros: 0),
        ),
      ],
    );
    if (unlocked) {
      container
          .read(parentPinAuthenticatedProfileIdProvider.notifier)
          .setAuthenticated(_profileId);
    }
    router = AppRouter(
      sacredTimeLocationGuard: _AllowAll(),
      authGuard: _AllowAll(),
      profileGuard: _AllowProfile(),
      childModeGuard: _AllowChildMode(),
      pinGuard: _AllowPin(),
      parentSessionGuard: ParentSessionGuard(
        isParentSession: () async {
          final sub = container.listen(parentSessionProvider.future, (_, _) {});
          try {
            return await sub.read();
          } finally {
            sub.close();
          }
        },
      ),
    );
  }

  late final ProviderContainer container;
  late final AppRouter router;
  var reportReads = 0;

  void lockPin() =>
      container.read(parentPinAuthenticatedProfileIdProvider.notifier).clear();

  Future<void> pump(WidgetTester tester, String path) async {
    await tester.binding.setSurfaceSize(const Size(400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(container.dispose);
    await tester.pumpWidget(
      pumpApp(
        routerConfig: router.config(
          deepLinkBuilder: (_) => DeepLink.path(path),
        ),
        container: container,
      ),
    );
    await tester.pumpAndSettle();
  }
}

void main() {
  group('AC-9 retired and archived reports retain totals only', () {
    testWidgets('an evaluated curriculum shows both sections after the '
        'totals', (tester) async {
      await _pumpScreen(tester, paceState([paceCurriculumState(paceReport())]));
      expect(_totals, findsOneWidget);
      expect(_onTrack, findsOneWidget);
      expect(_paceSection, findsOneWidget);
      // After the totals; the On-track block above the per-source rows.
      final totalsY = tester.getTopLeft(_totals).dy;
      final onTrackY = tester.getTopLeft(_onTrack).dy;
      final paceY = tester.getTopLeft(_paceSection).dy;
      expect(onTrackY, greaterThan(totalsY));
      expect(paceY, greaterThan(onTrackY));
    });

    testWidgets('a curriculum that is not evaluated hides both', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        paceState([paceCurriculumState(paceReport(), evaluated: false)]),
      );
      expect(_totals, findsOneWidget);
      expect(find.bySemanticsLabel('Learning events · 260'), findsOneWidget);
      expect(_onTrack, findsNothing);
      expect(_paceSection, findsNothing);
    });

    for (final state in [MainTrackState.retired, MainTrackState.archived]) {
      testWidgets('engine: a ${state.name} main track keeps its totals and '
          'hides pace and status', (tester) async {
        await _pumpScreen(tester, _engineState(state));
        expect(_totals, findsOneWidget);
        expect(find.bySemanticsLabel('Learning events · 2'), findsOneWidget);
        expect(_onTrack, findsNothing);
        expect(_paceSection, findsNothing);
      });
    }

    testWidgets('engine: the active main track shows them', (tester) async {
      await _pumpScreen(tester, _engineState(MainTrackState.active));
      expect(_onTrack, findsOneWidget);
      expect(_paceSection, findsOneWidget);
    });
  });

  group('AC-10 child cannot reach parent report data', () {
    testWidgets('direct deep link: lands on Lifetime, no report data read', (
      tester,
    ) async {
      final h = _ChildHarness();
      await h.pump(tester, '/progress/lifetime/report?curriculum=mishnayos');
      expect(find.byType(LifetimeReportScreen), findsNothing);
      expect(find.byType(LifetimeKnowledgeScreen), findsOneWidget);
      expect(h.reportReads, 0);
      _expectNoParentData(tester);
    });

    testWidgets('nested navigation: Lifetime offers no Report entry', (
      tester,
    ) async {
      final h = _ChildHarness();
      await h.pump(tester, '/progress/lifetime');
      expect(_entry, findsNothing);
      _expectNoParentData(tester);
    });

    testWidgets('a parent PIN locked on an open report drops every pace '
        'value', (tester) async {
      final h = _ChildHarness(unlocked: true);
      await h.pump(tester, '/progress/lifetime');
      await tester.tap(_entry);
      await tester.pumpAndSettle();
      expect(_paceSection, findsOneWidget);
      expect(_onTrack, findsOneWidget);

      h.lockPin();
      await tester.pumpAndSettle();
      expect(find.byType(LifetimeReportScreen), findsNothing);
      _expectNoParentData(tester);
    });
  });
}

/// Calls [onRead] whenever a [lifetimeReportProvider] is built.
final class _ReportReads extends ProviderObserver {
  _ReportReads(this.onRead);

  final void Function() onRead;

  @override
  void didAddProvider(ProviderObserverContext context, Object? value) {
    if (context.provider.from == lifetimeReportProvider) onRead();
  }
}

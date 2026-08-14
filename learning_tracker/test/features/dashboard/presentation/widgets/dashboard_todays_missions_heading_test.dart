// R1v2-(6) regression: the "Today's Missions" heading on DashboardBody shared a
// horizontal Row with the pink "N remaining" pill and was capped at
// maxLines:1 + ellipsis. At font scale 1.3 the fixed-width pill ate the row
// width, so the heading clipped to "Today's Mi…" (en) / "…היום" (he).
//
// The fix lets the heading wrap (maxLines:2, softWrap) and lets the pill yield
// width (Flexible). These tests assert the heading's RenderParagraph does NOT
// exceed its max lines (i.e. is not truncated) at font scale 1.3 in BOTH en
// and he — which would have failed under the old single-line cap.
@Tags(['dashboard', 'i18n', 'overflow'])
library;

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/dashboard_body.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/progress/presentation/providers/journey_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

class _ActiveProfileIdOverride extends ActiveProfileId {
  @override
  String build() => '01J6Q2H4A8M7K3P9R5T6V8WXYB';
}

class _HebrewTermsOff extends UseHebrewTerms {
  @override
  bool build() => false;
}

class _NoTutorSession extends ActiveTutoredProfileSelection {
  @override
  TutoredProfileSelection? build() => null;
}

CurriculumTrackEntity _track() => CurriculumTrackEntity(
  curriculumId: CurriculumId.mishnayos,
  state: 'active',
  stateChangedAt: DateTime.utc(2026, 1, 1),
  activatedAt: DateTime.utc(2026, 1, 1),
);

LifetimeTotals _lifetimeTotals() => LifetimeTotals(
  learnedSections: 0,
  totalSections: 100,
  totalCurricula: CurriculumId.values.length,
);

JourneyViewModel _journey() => const JourneyViewModel(
  curricula: [],
  totalCompletions: 0,
  totalUniqueUnits: 0,
  unitLevelSiyumimCount: 0,
  aggregateLevelSiyumimCount: 0,
  curriculumLevelSiyumimCount: 0,
);

Widget _buildApp({
  required _MockStackRouter router,
  required Locale locale,
  Future<List<DailyTask>>? dailyTasksFuture,
}) {
  final track = _track();
  return ProviderScope(
    overrides: [
      activeProfileIdProvider.overrideWith(() => _ActiveProfileIdOverride()),
      useHebrewTermsProvider.overrideWith(() => _HebrewTermsOff()),
      currentTransliterationVariantProvider.overrideWithValue(
        TransliterationVariant.ashkenazi,
      ),
      activeTutoredProfileSelectionProvider.overrideWith(
        () => _NoTutorSession(),
      ),
      selectedProfileProvider.overrideWith((ref) => Future.value(null)),
      dashboardActiveCurriculaStreamProvider.overrideWith(
        (ref) => Stream.value([CurriculumId.mishnayos]),
      ),
      dashboardActiveTracksStreamProvider.overrideWith(
        (ref) => Stream.value([track]),
      ),
      dashboardUserModeProvider.overrideWith(
        (ref) => Future.value(ProfileMode.adult),
      ),
      dashboardGlobalPointsProvider.overrideWith((ref) => Future.value(0)),
      // Keep the Firestore-backed dashboard data seams deterministic; this
      // widget test is focused on heading layout.
      dashboardStreakProvider.overrideWith(
        (ref) => Stream.value((currentStreak: 7, maxStreak: 7)),
      ),
      allDailyTasksProvider.overrideWith(
        (ref) => dailyTasksFuture ?? Future.value(const []),
      ),
      journeyViewModelProvider.overrideWith((ref) => Future.value(_journey())),
      lifetimeTotalsAcrossAllCurriculaProvider.overrideWith(
        (ref) => Future.value(_lifetimeTotals()),
      ),
      trackDualProgressMetricsProvider.overrideWith(
        (ref) => Future.value(const []),
      ),
      anyActiveTrackHasChazaraProvider.overrideWith(
        (ref) => Future.value(false),
      ),
      trackHasChazaraProvider(
        CurriculumId.mishnayos,
      ).overrideWith((ref) => Future.value(false)),
      for (final c in CurriculumId.values)
        dashboardHasProgramEnrollmentProvider(
          c,
        ).overrideWith((ref) => Future.value(false)),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: StackRouterScope(
        controller: router,
        stateHash: 0,
        child: Scaffold(
          body: DashboardBody(
            activeTracks: [_track()],
            userMode: ProfileMode.adult,
            currentStreak: 7,
          ),
        ),
      ),
    ),
  );
}

/// Locates the "Today's Missions" heading [RenderParagraph] and asserts it is
/// not truncated (does not exceed its allowed line count).
void _expectHeadingNotTruncated(WidgetTester tester, String headingText) {
  final textFinder = find.text(headingText);
  expect(
    textFinder,
    findsOneWidget,
    reason: 'Heading "$headingText" should be present and not split/clipped',
  );
  final paragraph = tester.renderObject<RenderParagraph>(textFinder);
  expect(
    paragraph.didExceedMaxLines,
    isFalse,
    reason:
        'Heading "$headingText" is ellipsis-truncated at this width/scale — '
        'it must wrap (maxLines:2 + softWrap) so the full heading shows.',
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
    SharedPreferences.setMockInitialValues({});
  });

  late _MockStackRouter router;

  setUp(() {
    router = _MockStackRouter();
    when(() => router.canPop()).thenReturn(false);
    when(() => router.isRouteActive(any())).thenReturn(false);
  });

  Future<void> pumpAt(
    WidgetTester tester, {
    required Locale locale,
    required double textScale,
    Future<List<DailyTask>>? dailyTasksFuture,
  }) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: _buildApp(
          router: router,
          locale: locale,
          dailyTasksFuture: dailyTasksFuture,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    // This test targets ONLY the "Today's Missions" heading, which uses a
    // Wrap (so it cannot itself RenderFlex-overflow) and is asserted
    // separately below via _expectHeadingNotTruncated. Any OTHER exception
    // raised anywhere in the pumped tree — a provider throwing, or a real
    // overflow in a sibling widget — must fail this test rather than be
    // silently swallowed, so we capture (and clear) at most one pending
    // exception here and assert there isn't one, instead of blind-draining
    // a while loop that would mask a real regression.
    expect(
      tester.takeException(),
      isNull,
      reason:
          'An exception was raised while pumping DashboardBody — this is a '
          'real regression, not something this heading test should silently '
          'swallow.',
    );
  }

  testWidgets('en: "Today\'s Missions" heading is not clipped at font 1.3', (
    tester,
  ) async {
    await pumpAt(tester, locale: const Locale('en'), textScale: 1.3);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    _expectHeadingNotTruncated(tester, l10n.todaysMissions);
  });

  testWidgets('en: "Today\'s Missions" heading is not clipped at font 1.0', (
    tester,
  ) async {
    await pumpAt(tester, locale: const Locale('en'), textScale: 1.0);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    _expectHeadingNotTruncated(tester, l10n.todaysMissions);
  });

  testWidgets('he: missions heading is not clipped at font 1.3', (
    tester,
  ) async {
    await pumpAt(tester, locale: const Locale('he'), textScale: 1.3);
    final l10n = await AppLocalizations.delegate.load(const Locale('he'));
    _expectHeadingNotTruncated(tester, l10n.todaysMissions);
  });

  // P3(5558) regression: on cold start the "N remaining" pill read the daily
  // task list's default placeholder (an empty list substituted while
  // allDailyTasksProvider is still loading — see dashboard_body.dart's
  // `allTasks = dailyTasksAsync.value ?? const <DailyTask>[]`), so it showed
  // a concrete "0 remaining" for ~1-2s before the real count arrived — even
  // though the adjacent OVERDUE/TODAY/CHAZARA bubbles correctly show "…"
  // while not ready. These two tests pin: (1) the pill must NOT show a
  // concrete count while allDailyTasksProvider is still loading, and (2) once
  // the provider resolves — even with a genuine zero — the pill DOES show
  // "0 remaining".
  testWidgets(
    'en: missions pill shows a placeholder (not "0 remaining") while tasks '
    'are still loading',
    (tester) async {
      final neverCompletes = Completer<List<DailyTask>>();
      addTearDown(() {
        // Complete after the test so no dangling unhandled-Future/leak
        // assertions fire; flutter_test only guards against pending Timers,
        // but completing tidily avoids an "unhandled exception in a
        // disposed test zone" if anything were to await this later.
        if (!neverCompletes.isCompleted) {
          neverCompletes.complete(const []);
        }
      });
      await pumpAt(
        tester,
        locale: const Locale('en'),
        textScale: 1.0,
        dailyTasksFuture: neverCompletes.future,
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      final pillFinder = find.byKey(const Key('todaysMissionsRemainingPill'));
      expect(pillFinder, findsOneWidget);
      final pillText = tester.widget<Text>(pillFinder).data;
      expect(
        pillText,
        isNot(equals(l10n.remaining(0))),
        reason:
            'The missions pill showed a concrete "0 remaining" while '
            'allDailyTasksProvider was still loading — it must show a '
            'placeholder instead, matching the sibling OVERDUE/TODAY/CHAZARA '
            'bubbles.',
      );
      expect(pillText, equals('…'));
    },
  );

  testWidgets(
    'en: missions pill shows "0 remaining" once tasks resolve with zero '
    'items',
    (tester) async {
      await pumpAt(
        tester,
        locale: const Locale('en'),
        textScale: 1.0,
        dailyTasksFuture: Future.value(const []),
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      final pillFinder = find.byKey(const Key('todaysMissionsRemainingPill'));
      expect(pillFinder, findsOneWidget);
      expect(
        tester.widget<Text>(pillFinder).data,
        equals(l10n.remaining(0)),
        reason:
            'Once the local Drift query genuinely resolves with zero tasks, '
            'the pill must show the real "0 remaining" — the loading-state '
            'placeholder fix must not suppress a legitimate zero.',
      );
    },
  );
}

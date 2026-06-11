// Regression test for E1 — streak chip on DashboardBody navigates to
// GamificationRoute when tapped.
//
// The streak chip (fire icon + number) sits in the top-right of the dashboard
// header row. Tapping it must call router.push(GamificationRoute()).
@Tags(['dashboard', 'navigation', 'gamification'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/sync/initial_sync_state.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/dashboard_body.dart';
import 'package:learning_tracker/features/gamification/domain/models/streak_recovery_info.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/progress/presentation/providers/journey_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

// ── Notifier stubs ────────────────────────────────────────────────────────────

class _ActiveProfileIdOverride extends ActiveProfileId {
  @override
  int build() => 1;
}

class _HebrewTermsOff extends UseHebrewTerms {
  @override
  bool build() => false;
}

class _NoTutorSession extends ActiveTutoredProfileSelection {
  @override
  TutoredProfileSelection? build() => null;
}

// ── Fixtures ──────────────────────────────────────────────────────────────────

CurriculumTrack _track() => CurriculumTrack(
  id: 1,
  profileId: 1,
  curriculumId: CurriculumId.mishnayos.storageKey,
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

// ── Build helper ──────────────────────────────────────────────────────────────

Widget _buildApp({
  required _MockStackRouter router,
  int currentStreak = 7,
  ProfileMode userMode = ProfileMode.child,
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
      dashboardUserModeProvider.overrideWith((ref) => Future.value(userMode)),
      dashboardStreakProvider.overrideWith(
        (ref) => Stream.value((
          currentStreak: currentStreak,
          maxStreak: currentStreak,
        )),
      ),
      dashboardGlobalPointsProvider.overrideWith((ref) => Stream.value(0)),
      dashboardStreakRecoveryProvider.overrideWith(
        (ref) => Future.value(
          const StreakRecoveryInfo(wasRecovered: false, currentStreak: 0),
        ),
      ),
      allDailyTasksProvider.overrideWith((ref) => Future.value(const [])),
      initialSyncCompleteProvider.overrideWith((ref) => Future.value(true)),
      journeyViewModelProvider(
        1,
      ).overrideWith((ref) => Future.value(_journey())),
      lifetimeTotalsAcrossAllCurriculaProvider(
        1,
      ).overrideWith((ref) => Future.value(_lifetimeTotals())),
      trackDualProgressMetricsProvider(
        1,
      ).overrideWith((ref) => Future.value(const [])),
      anyActiveTrackHasChazaraProvider.overrideWith(
        (ref) => Future.value(false),
      ),
      for (final c in CurriculumId.values)
        dashboardHasProgramEnrollmentProvider(
          c,
        ).overrideWith((ref) => Future.value(false)),
    ],
    child: MaterialApp(
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
            userMode: userMode,
            currentStreak: currentStreak,
          ),
        ),
      ),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
    SharedPreferences.setMockInitialValues({});
  });

  late _MockStackRouter router;

  setUp(() {
    router = _MockStackRouter();
    when(() => router.canPop()).thenReturn(false);
    when(() => router.maybePop<Object?>(any())).thenAnswer((_) async => false);
    when(
      () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
    ).thenAnswer((_) async => null);
    when(
      () => router.navigate(any(), onFailure: any(named: 'onFailure')),
    ).thenAnswer((_) async {});
    // GA-4: isRouteActive is called by the double-push guard; default to false
    // so the first push is always allowed in these navigation tests.
    when(() => router.isRouteActive(any())).thenReturn(false);
  });

  testWidgets(
    'E1: tapping the streak chip in CHILD mode pushes GamificationRoute',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(
          router: router,
          currentStreak: 7,
          userMode: ProfileMode.child,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Locate the streak chip via its fire icon (local_fire_department_rounded)
      // in the header row (not the compact mission card, which uses the same
      // icon but is further down the list and may be scrolled out).
      final fireIcons = find.byIcon(Icons.local_fire_department_rounded);
      expect(fireIcons, findsWidgets);

      // Tap the first fire icon — the streak chip in the dashboard header.
      await tester.tap(fireIcons.first);
      await tester.pump();

      // Verify router.push was called with a GamificationRoute.
      final captured = verify(
        () => router.push<Object?>(
          captureAny(),
          onFailure: any(named: 'onFailure'),
        ),
      ).captured;
      expect(
        captured.any(
          (arg) => arg is PageRouteInfo && arg.routeName == 'GamificationRoute',
        ),
        isTrue,
        reason: 'Tapping the streak chip must push GamificationRoute (E1 fix)',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets('E1: tapping the streak chip in ADULT mode does NOT navigate '
      '(GamificationRoute is childModeGuard-gated, so the push would be a '
      'silently-rejected dead no-op)', (tester) async {
    await tester.pumpWidget(
      _buildApp(router: router, currentStreak: 7, userMode: ProfileMode.adult),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final fireIcons = find.byIcon(Icons.local_fire_department_rounded);
    expect(fireIcons, findsWidgets);

    await tester.tap(fireIcons.first);
    await tester.pump();

    // No navigation should be attempted in adult mode — the chip is a passive
    // streak indicator, not a dead link into a guard that rejects it.
    verifyNever(
      () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
